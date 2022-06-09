/*
  Copyright (C) 2016  Tristan Gingold <tgingold@free.fr>

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <https://www.gnu.org/licenses/>.

*/

#include "kernel/yosys.h"
#include "kernel/sigtools.h"
#include "kernel/log.h"
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

USING_YOSYS_NAMESPACE

#ifdef YOSYS_ENABLE_GHDL

#include "ghdl/synth.h"

using namespace GhdlSynth;

static Name_Id nameid_gclk = {0};

// Convert an Sname_User to a string.  Deals with extended names
// Subroutine of to_str
static std::string user_to_str(Name_Id id)
{
	const char *s = get_cstr(id);

	if (s[0] != '\\')
		return string(s);

	// Extended name
	// Case it can be converted to a name without the
	// escape sequence.
	int len = 1;
	while (1) {
		char c = s[len];
		if (c == 0)
			break;
		if (c == '\\' && s[len + 1] == 0 && len > 1)
			break;
		if (!((c >= 'a' && c <= 'z')
		      || (c >= 'A' && c <= 'Z')
		      || (c >= '0' && c <= '9')
		      || (c == '_' || c == '.')))
			//  Unexpected character, return the name as is.
			return string(s);
		len++;
	}
	return string(s + 1, len - 1);
}

//  Convert an Sname to a string.
static std::string to_str(Sname name)
{
	std::string res;
	bool is_sys = false;

	log_assert(is_valid(name));

	for (Sname pfx = name; is_valid(pfx); pfx = get_sname_prefix(pfx)) {
		switch (get_sname_kind(pfx)) {
		case Sname_Artificial:
			is_sys = true;
			// fallthrough
		case Sname_User:
			res = '.' + user_to_str(get_sname_suffix(pfx)) + res;
			break;
		case Sname_Version:
			//  Use ':' for versions.  '%' is not supported by Xilinx ISE edif2ngc.
			//  ('$' is boring with tcl scripts)
			res = ':' + stringf("%u", get_sname_version(pfx)) + res;
			break;
		}
	}
	res[0] = is_sys ? '$' : '\\';
	return res;
}

//  Get the corresponding wire for net N (or null if not found).
static Wire *get_wire(std::vector<RTLIL::Wire *> &net_map, Net n)
{
	log_assert(n.id != 0);

	//  Search if N is the output of a cell.
	Wire *res = n.id < net_map.size() ? net_map.at(n.id) : nullptr;
	return res;
}

//  Convert bit I of V to State.
static RTLIL::State logic32_to_state(struct logic_32 v, unsigned int i)
{
	i &= 31;

	switch((((v.va >> i)) & 1) + ((v.zx >> i) & 1)*2)
	{
	case 0:
		return RTLIL::State::S0;
	case 1:
		return RTLIL::State::S1;
	case 2:
		return RTLIL::State::Sz;
	case 3:
	default:
		return RTLIL::State::Sx;
	}
}

//  Convert V to a Const.
static RTLIL::Const pval_to_const(Pval v)
{
	const unsigned wd = get_pval_length(v);
	std::vector<RTLIL::State> bits(wd);
	struct logic_32 val;

	for (unsigned i = 0; i < wd; i++) {
		if (i % 32 == 0)
			val = read_pval(v, i / 32);
		bits[i] = logic32_to_state(val, i);
	}
	return RTLIL::Const(bits);
}

static RTLIL::SigSpec get_src(std::vector<RTLIL::Wire *> &net_map, Net n);
static RTLIL::SigSpec get_src_extract(std::vector<RTLIL::Wire *> &net_map, Net n, unsigned off, unsigned wd);

//  Concatenate the NBR_IN inputs of INST (ie handle Id_ConcatX).
static RTLIL::SigSpec get_src_concat(std::vector<RTLIL::Wire *> &net_map, Instance inst, unsigned nbr_in)
{
        RTLIL::SigSpec res;
        //  ConcatN means { I0; I1; .. IN}, but append() adds
        //  bits to the MSB side.
        for (unsigned i = nbr_in; i > 0; i--)
                res.append(get_src(net_map, get_input_net(inst, (i - 1))));
        return res;
}

//  Extract WD bits at OFF from concatenation INST.  Do not compute unused bits.
static RTLIL::SigSpec get_src_concat_extract(std::vector<RTLIL::Wire *> &net_map, Instance inst, unsigned nbr_in, unsigned off, unsigned wd)
{
        RTLIL::SigSpec res;

        //  ConcatN means { I0; I1; .. IN}, but append() adds
        //  bits to the MSB side.
        for (unsigned i = nbr_in; i > 0; i--) {
                Net p = get_input_net(inst, (i - 1));
                unsigned pw = get_width(p);
                if (off < pw) {
                        unsigned sub_wd = (off + wd < pw ? wd : pw - off);
                        res.append(get_src_extract(net_map, p, off, sub_wd));
                        //  sub_wd bits have been extracted.
                        wd -= sub_wd;
                        if (wd == 0)
                                break;
                        off = 0;
                }
                else {
                        off -= pw;
                }
        }
        return res;
}

//  Extract WD bits at OFF from N.  Try to avoid computing unused bits as it may result in an infinite recursion if parts of a concatenation are defined by the concatenation.
static RTLIL::SigSpec get_src_extract(std::vector<RTLIL::Wire *> &net_map, Net n, unsigned off, unsigned wd)
{
	Instance inst = get_net_parent(n);
	switch(get_id(inst)) {
	case Id_Port:
        case Id_Output:
                return get_src_extract(net_map, get_input_net(inst, 0), off, wd);
	case Id_Extract:
                log_assert(wd <= get_width(n));
                return get_src_extract(net_map, get_input_net(inst, 0), get_param_uns32(inst, 0) + off, wd);
	case Id_Concat2:
                return get_src_concat_extract(net_map, inst, 2, off, wd);
	case Id_Concat3:
                return get_src_concat_extract(net_map, inst, 3, off, wd);
	case Id_Concat4:
                return get_src_concat_extract(net_map, inst, 4, off, wd);
	case Id_Concatn:
                return get_src_concat_extract(net_map, inst, get_param_uns32(inst, 0), off, wd);
        default:
                RTLIL::SigSpec res = get_src(net_map, n);
                return res.extract(off, wd);
        }
}

static RTLIL::SigSpec get_src(std::vector<RTLIL::Wire *> &net_map, Net n)
{
	log_assert(n.id != 0);

	//  Search if N is the output of a cell.
	Wire *w = get_wire(net_map, n);
	if (w != nullptr)
		return w;

	Instance inst = get_net_parent(n);
	switch(get_id(inst)) {
#define IN(N) get_src(net_map, get_input_net(inst, (N)))
	case Id_Port:
	case Id_Output:
		return IN(0);
	case Id_Uextend:
		{
			RTLIL::SigSpec res = IN(0);
			res.extend_u0(get_width(n), false);
			return res;
		}
	case Id_Sextend:
		{
			RTLIL::SigSpec res = IN(0);
			res.extend_u0(get_width(n), true);
			return res;
		}
	case Id_Utrunc:
	case Id_Strunc:
		{
			RTLIL::SigSpec res = IN(0);
			return res.extract(0, get_width(n));
		}
	case Id_Const_Bit: // arbitrary width binary
		{
			const unsigned wd = get_width(n);
			std::vector<RTLIL::State> bits(wd);
			unsigned int val = 0;
			for (unsigned i = 0; i < wd; i++) {
				if (i % 32 == 0)
					val = get_param_uns32(inst, i / 32);
				bits[i] = (val >> (i%32)) & 1 ? RTLIL::State::S1 : RTLIL::State::S0;
			}
			return RTLIL::SigSpec(RTLIL::Const(bits));
		}
	case Id_Const_UB32: // zero padded binary
		{
			const unsigned wd = get_width(n);
			std::vector<RTLIL::State> bits(wd);
			unsigned int val = get_param_uns32(inst, 0);
			for (unsigned i = 0; i < wd && i < 32; i++) {
				bits[i] = (val >> i) & 1 ? RTLIL::State::S1 : RTLIL::State::S0;
			}
			return RTLIL::SigSpec(RTLIL::Const(bits));
		}
	case Id_Const_SB32: // sign extended binary
		{
			const unsigned wd = get_width(n);
			std::vector<RTLIL::State> bits(wd);
			unsigned int val = get_param_uns32(inst, 0);
			for (unsigned i = 0; i < wd; i++) {
				unsigned idx = i < 32 ? i : 31;
				bits[i] = (val >> idx) & 1 ? RTLIL::State::S1 : RTLIL::State::S0;
			}
			return RTLIL::SigSpec(RTLIL::Const(bits));
		}
	case Id_Const_Z:
		{
			return SigSpec(RTLIL::State::Sz, get_width(n));
		}
	case Id_Const_X:
		{
			return SigSpec(RTLIL::State::Sx, get_width(n));
		}
	case Id_Const_0:
		{
			return SigSpec(RTLIL::State::S0, get_width(n));
		}
	case Id_Const_Log: // arbitrary length 01ZX
		{
			const unsigned wd = get_width(n);
			std::vector<RTLIL::State> bits(wd);
			struct logic_32 v;
			for (unsigned i = 0; i < wd; i++) {
				if (i % 32 == 0) {
					v.va = get_param_uns32(inst, 2*(i / 32));
					v.zx = get_param_uns32(inst, 2*(i / 32) + 1);
				}
				bits[i] = logic32_to_state(v, i);

			}
			return RTLIL::SigSpec(RTLIL::Const(bits));
		}
	case Id_Const_UL32: // zero padded 01ZX
		{
			const unsigned wd = get_width(n);
			std::vector<RTLIL::State> bits(wd);
			unsigned int val01 = get_param_uns32(inst, 0);
			unsigned int valzx = get_param_uns32(inst, 1);
			for (unsigned i = 0; i < wd && i < 32; i++) {
				switch(((val01 >> i)&1)+((valzx >> i)&1)*2)
				{
				case 0:
					bits[i] = RTLIL::State::S0;
					break;
				case 1:
					bits[i] = RTLIL::State::S1;
					break;
				case 2:
					bits[i] = RTLIL::State::Sz;
					break;
				case 3:
					bits[i] = RTLIL::State::Sx;
					break;
				}

			}
			return RTLIL::SigSpec(RTLIL::Const(bits));
		}
	case Id_Extract:
                return get_src_extract(net_map, get_input_net(inst, 0), get_param_uns32(inst, 0), get_width(n));
	case Id_Concat2:
                return get_src_concat(net_map, inst, 2);
	case Id_Concat3:
                return get_src_concat(net_map, inst, 3);
	case Id_Concat4:
                return get_src_concat(net_map, inst, 4);
	case Id_Concatn:
                return get_src_concat(net_map, inst, get_param_uns32(inst, 0));
	default:
		log_cmd_error("wire not found for %s\n", to_str(get_module_name(get_module(inst))).c_str());
		break;
	}
#undef IN
}

static bool is_set(std::vector<RTLIL::Wire *> &net_map, Net n)
{
	//  If not in the map, then certainly not present.
	if (n.id >= net_map.size())
		return false;

	Wire *res = net_map[n.id];
	return (res != nullptr);
}

static void set_src(std::vector<RTLIL::Wire *> &net_map, Net n, Wire *wire)
{
	if (n.id >= net_map.size())
		net_map.resize(n.id + 1, nullptr);
	log_assert(net_map[n.id] == nullptr);
	net_map[n.id] = wire;
}

//  Create a value from an attribute
static RTLIL::Const build_attribute_val(Attribute attr)
{
	RTLIL::Const cst = pval_to_const(get_attribute_pval(attr));
	if (get_attribute_type(attr) == Param_Pval_String)
		cst.flags |= RTLIL::CONST_FLAG_STRING;
	return cst;

}

//  Create the identifier of an attribute
static IdString build_attribute_id(Attribute attr)
{
	return IdString('\\' + string(get_cstr(get_attribute_name(attr))));
}

static void add_attributes_chain(RTLIL::AttrObject &obj, Attribute attr)
{
	while (attr.id != 0) {
		IdString id = build_attribute_id(attr);
		obj.attributes[id] = build_attribute_val(attr);

		attr = get_attribute_next(attr);
	}
}

//  Convert attributes of INST to OBJ.
static void add_attributes_from_instance(RTLIL::AttrObject &obj, Instance inst)
{
	add_attributes_chain(obj, get_instance_first_attribute (inst));
}

//  Extract the polarity from net N (output of an edge gate).
static RTLIL::State extract_clk_pol(Net n)
{
	Instance edge = get_net_parent(n);

	switch (get_id(edge)) {
	case Id_Posedge:
		return RTLIL::State::S1;
	case Id_Negedge:
		return RTLIL::State::S0;
	default:
		log_cmd_error("clock edge expected\n");
		return RTLIL::State::S1;
	}
}

//  Extract the clock from net N (output of an edge gate).
static RTLIL::SigSpec extract_clk_sig(std::vector<RTLIL::Wire *> &net_map, Net n)
{
	Instance edge = get_net_parent(n);
	return get_src(net_map, get_input_net(edge, 0));
}

//  INST is an Id_Memory or an Id_Memory_Init
//  All the inputs have been connected, all the outputs have been pushed.
static void import_memory(RTLIL::Module *module, std::vector<RTLIL::Wire *> &net_map, Instance inst)
{
	Net mem_o = get_output(inst, 0);
	Input first_port = get_first_sink (mem_o);
	std::string mem_str = to_str(get_instance_name(inst));

	//  Memories appear only once.
	log_assert(!is_set(net_map, mem_o));

	//  Count number of read and write ports.
	//  Extract width, size, abits.
	int nbr_rd = 0;
	int nbr_wr = 0;
	unsigned width = 0;
	unsigned abits = 0;
	for (Input port = first_port; ;) {
		Instance port_inst = get_input_parent(port);
		Net addr;
		Net dat;
		switch(get_id(port_inst)) {
		case Id_Mem_Rd:
		case Id_Mem_Rd_Sync:
			dat = get_output(port_inst, 1);
			addr = get_input_net(port_inst, 1);
			nbr_rd++;
			break;
		case Id_Mem_Wr_Sync:
			dat = get_input_net(port_inst, 4);
			addr = get_input_net(port_inst, 1);
			nbr_wr++;
			break;
		case Id_Memory:
		case Id_Memory_Init:
			port.id = 0;
			break;
		default:
			log_assert(0);
		}
		if (port.id == 0)
			break;

		if (width == 0) {
			width = get_width(dat);
			abits = get_width(addr);
		} else {
			//  All the ports must have the same width and abits.
			log_assert(width == get_width(dat));
			log_assert(abits == get_width(addr));
		}
		port = get_first_sink(get_output(port_inst,  0));
	}

	unsigned size = get_width(mem_o) / width;

	//  Create the memory.
	RTLIL::Memory *mem1 = new RTLIL::Memory;
	mem1->width = width;
	mem1->start_offset = 0;
	mem1->size = size;
	RTLIL::Memory *mem = module->addMemory(mem_str, mem1);
	delete mem1;

	//  Set attributes.
	add_attributes_from_instance(*mem, inst);

	//  Initial value
	if (get_id(inst) == Id_Memory_Init) {
		Cell *init = module->addCell(mem_str + "$init", ID($meminit_v2));
		init->parameters[ID::MEMID] = Const(mem_str);
		init->parameters[ID::ABITS] = Const(abits);
		init->parameters[ID::WIDTH] = Const(width);
		init->parameters[ID::PRIORITY] = Const(0);
		init->parameters[ID::WORDS] = Const(size);
		init->setPort(ID::EN, Const(RTLIL::State::S1, width));
		init->setPort(ID::ADDR, SigSpec(0, abits));

		Net iinp = get_input_net(inst, 1);
		Instance iinst = get_net_parent(iinp);
		Module_Id imod = get_id(iinst);
		if (imod == Id_Signal || imod == Id_Isignal)
			iinp = get_input_net(iinst, 0);
		init->setPort(ID::DATA, get_src(net_map, iinp));
	}

	//  Ports
	//  The first port is the output of the memory_init/memory cell.
	//  It points to the first actor (so the one with the least priority).
	std::vector<RTLIL::State> vec;
	Net clk_net;
	int ridx = -1;
	int widx = -1;
	for (Input port = first_port; ; ) {
		Instance port_inst = get_input_parent(port);
		Input next_port = get_first_sink(get_output(port_inst, 0));

		Module_Id id = get_id(port_inst);
#define IN(N) get_src(net_map, get_input_net(port_inst, (N)))
#define OUT(N) get_src(net_map, get_output(port_inst, (N)))
		Cell *p;

		//  Create the cell
		switch(id) {
		case Id_Mem_Rd:
		case Id_Mem_Rd_Sync:
			p = module->addCell(mem_str + stringf("$r%u", ++ridx),
					    ID($memrd_v2));
			break;
		case Id_Mem_Wr_Sync:
			p = module->addCell(mem_str + stringf("$w%u", ++widx),
					    ID($memwr_v2));
			break;
		case Id_Memory:
		case Id_Memory_Init:
			// Finished
			return;
		default:
			log_abort();
		}

		// Common parameters
		p->parameters[ID::MEMID] = Const(mem_str);
		p->parameters[ID::ABITS] = Const(abits);
		p->parameters[ID::WIDTH] = Const(width);

		// Common ports
		p->setPort(ID::ADDR, IN(1));

		// Common to memrd ports
		switch(id) {
		case Id_Mem_Rd:
		case Id_Mem_Rd_Sync:
			p->setPort(ID::DATA, OUT(1));
			p->setPort(ID::ARST, Const(RTLIL::State::S0));
			p->setPort(ID::SRST, Const(RTLIL::State::S0));
			p->parameters[ID::ARST_VALUE] = Const(RTLIL::State::Sx, width);
			p->parameters[ID::SRST_VALUE] = Const(RTLIL::State::Sx, width);
                        p->parameters[ID::INIT_VALUE] = Const(RTLIL::State::Sx, width);
                        p->parameters[ID::CE_OVER_SRST] = Const(RTLIL::State::S1);
			// The read port is transparent to the emitted write ports.
                        vec.resize(nbr_wr);
                        for (int j = 0; j < nbr_wr; j++)
                                vec[j] = j <= widx ? RTLIL::State::S1 : RTLIL::State::S0;
                        p->parameters[ID::TRANSPARENCY_MASK] = Const(vec);
                        for (int j = 0; j < nbr_wr; j++)
                                vec[j] = RTLIL::State::S0;
                        p->parameters[ID::COLLISION_X_MASK] = Const(vec);
                        break;
		case Id_Mem_Wr_Sync:
                        p->setPort(ID::DATA, IN(4));
                        p->parameters[ID::PORTID] = Const(widx);
                        vec.resize(nbr_wr);
			// Emitted write ports (ie j <= widx) don't have priority.
                        for (int j = 0; j < nbr_wr; j++)
                                vec[j] = j <= widx ? RTLIL::State::S0 : RTLIL::State::S1;
                        p->parameters[ID::PRIORITY_MASK] = Const(vec);
                        break;
		default:
			log_abort();
                }

                // Clocks
                switch(id) {
		case Id_Mem_Rd:
                        p->parameters[ID::CLK_ENABLE] = Const(RTLIL::State::S0);
                        p->parameters[ID::CLK_POLARITY] = Const(RTLIL::State::S1);
                        p->setPort(ID::CLK, Const(RTLIL::State::S0));
                        p->setPort(ID::EN, Const(RTLIL::State::S1));
			break;
		case Id_Mem_Rd_Sync:
		case Id_Mem_Wr_Sync:
                        p->parameters[ID::CLK_ENABLE] = Const(RTLIL::State::S1);
                        clk_net = get_input_net(port_inst, 2);
                        p->parameters[ID::CLK_POLARITY] = extract_clk_pol(clk_net);
                        p->setPort(ID::CLK, extract_clk_sig(net_map, clk_net));
                        p->setPort(ID::EN, SigSpec(SigBit(IN(3)), width));
                        break;
		default:
			log_abort();
                }

                // EN
                switch(id) {
		case Id_Mem_Rd:
                        p->setPort(ID::EN, Const(RTLIL::State::S1));
			break;
		case Id_Mem_Rd_Sync:
                        p->setPort(ID::EN, IN(3));
                        break;
		case Id_Mem_Wr_Sync:
			p->setPort(ID::EN, SigSpec(SigBit(IN(3)), width));
                        break;
		default:
			log_abort();
                }

                port = next_port;
	}
#undef IN
#undef OUT
}

static void add_formal_input(RTLIL::Module *module, std::vector<RTLIL::Wire *> &net_map, Instance inst, const char *cellname)
{
	RTLIL::Cell *cell = module->addCell(to_str(get_instance_name(inst)), cellname);
	Net n = get_output(inst, 0);
	cell->setParam(ID::WIDTH, get_width(n));
	cell->setPort(ID::Y, get_src(net_map, n));
}

static bool has_attribute_gclk(Net n)
{
	Instance inst = get_net_parent(n);
	switch(get_id(inst)) {
        case Id_Signal:
	case Id_Isignal:
		break;
	default:
		return false;
	}

	Attribute attr = get_instance_first_attribute (inst);
	while (attr.id != 0) {
		if (get_attribute_name(attr).id == nameid_gclk.id)
			return true;
		attr = get_attribute_next(attr);
	}
	return false;
}

static void import_module(RTLIL::Design *design, GhdlSynth::Module m)
{
	Instance self_inst = get_self_instance (m);

	std::string module_name = to_str(get_module_name(m));

	if (design->has(module_name)) {
		if (is_valid(self_inst)) {
			//  Error message only for non-black-boxes.
			log_cmd_error("Re-definition of module `%s'.\n", module_name.c_str());
		}
		return;
	}

	RTLIL::Module *module = new RTLIL::Module;
	module->name = module_name;
	design->add(module);

	log("Importing module %s.\n", RTLIL::id2cstr(module->name));

	//  TODO: support submodules (currently they aren't generated)
	if (is_valid(get_first_sub_module(m))) {
		log_cmd_error("Unsupported: submodules in `%s'.\n", module_name.c_str());
		return;
	}

	//  List of all memories.
	std::vector<Instance> memories;

	if (!is_valid(self_inst)) { // blackbox
		module->set_bool_attribute(ID::blackbox);

		Port_Idx nbr_inputs = get_nbr_inputs(m);
		for (Port_Idx idx = 0; idx < nbr_inputs; idx++) {
			RTLIL::Wire *wire = module->addWire(
				to_str(get_input_name(m, idx)),
				get_input_width(m, idx));
			wire->port_input = true;
                        add_attributes_chain(*wire, get_input_port_first_attribute(m, idx));
		}
		Port_Idx nbr_outputs = get_nbr_outputs(m);
		for (Port_Idx idx = 0; idx < nbr_outputs; idx++) {
			RTLIL::Wire *wire = module->addWire(
				to_str(get_output_name(m, idx)),
				get_output_width(m, idx));
			if (get_inout_flag(m, idx))
				wire->port_input = true;
			wire->port_output = true;
                        add_attributes_chain(*wire, get_output_port_first_attribute(m, idx));
                }
		Param_Idx nbr_params = get_nbr_params(m);
		for (Param_Idx idx = 0; idx < nbr_params; idx++) {
			module->avail_parameters(to_str(get_param_name(m, idx)));
		}

		module->fixup_ports();
		return;
	}

	//  Create input ports.
	std::vector<RTLIL::Wire *> net_map;
	Port_Idx nbr_inputs = get_nbr_inputs(m);
	for (Port_Idx idx = 0; idx < nbr_inputs; idx++) {
		//  They correspond to ouputs of the self instance.
		Net port = get_output(self_inst, idx);

		RTLIL::Wire *wire = module->addWire(to_str(get_input_name(m, idx)));
		wire->port_id = idx + 1;
		wire->port_input = true;
		wire->width = get_width(port);
		set_src(net_map, port, wire);
                add_attributes_chain(*wire, get_input_port_first_attribute(m, idx));
	}
	//  Create inout ports, so that they can be read.
	Port_Idx nbr_outputs = get_nbr_outputs(m);
	for (Port_Idx idx = 0; idx < nbr_outputs; idx++) {
		if (!get_inout_flag(m, idx))
			continue;

		//  They correspond to inputs of the self instance.
		Net output_out = get_input_net(self_inst, idx);

		//  Create wire
		RTLIL::Wire *wire = module->addWire(to_str(get_output_name(m, idx)));
		wire->port_id = nbr_inputs + idx + 1;
		wire->port_output = true;
		wire->port_input = true;
		wire->width = get_width(output_out);
                add_attributes_chain(*wire, get_output_port_first_attribute(m, idx));

		Instance inout_inst = get_net_parent(output_out);
		Net inout_rd = get_output(inout_inst, 0);
		set_src(net_map, inout_rd, wire);
	}

	//  Create wires for outputs of (real) cells.
	for (Instance inst = get_first_instance(m);
	     is_valid(inst);
	     inst = get_next_instance(inst)) {
		GhdlSynth::Module im = get_module(inst);
		Module_Id id = get_id(im);
		switch (id) {
		case Id_And:
		case Id_Or:
		case Id_Xor:
		case Id_Nand:
		case Id_Nor:
		case Id_Xnor:
		case Id_Add:
		case Id_Sub:
		case Id_Neg:
		case Id_Mux2:
		case Id_Mux4:
		case Id_Pmux:
		case Id_Dff:
		case Id_Idff:
		case Id_Adff:
		case Id_Iadff:
		case Id_Eq:
		case Id_Ne:
		case Id_Ult:
		case Id_Ule:
		case Id_Ugt:
		case Id_Uge:
		case Id_Slt:
		case Id_Sle:
		case Id_Sgt:
		case Id_Sge:
		case Id_Not:
		case Id_Abs:
		case Id_Red_Or:
		case Id_Red_And:
		case Id_Red_Xor:
		case Id_Lsr:
		case Id_Lsl:
		case Id_Asr:
		case Id_Smin:
		case Id_Umin:
		case Id_Smax:
		case Id_Umax:
		case Id_Smul:
		case Id_Umul:
		case Id_Sdiv:
		case Id_Udiv:
		case Id_Srem:
		case Id_Smod:
		case Id_Umod:
		case Id_Allconst:
		case Id_Allseq:
		case Id_Anyconst:
		case Id_Anyseq:
		case Id_Mem_Rd:
		case Id_Mem_Rd_Sync:
		case Id_Tri:
		case Id_Resolver:
		case Id_User_None:
		case Id_User_Parameters:
			for (Port_Idx idx = 0; idx < get_nbr_outputs(im); idx++) {
				Net o = get_output(inst, idx);
				//  The wire may have been created for a module output
				if (is_set(net_map, o))
					continue;
				RTLIL::Wire *wire =
					module->addWire(NEW_ID, get_width(o));
				set_src(net_map, o, wire);
			}
			break;
		case Id_Signal:
		case Id_Isignal: {
		        Net s = get_output(inst, 0);

			//  The wire may have been created for a module output
			if (is_set(net_map, s))
				break;
			Sname iname = get_instance_name(inst);
			RTLIL::Wire *wire =
				module->addWire(to_str(iname), get_width(s));
			set_src(net_map, s, wire);

			//  Attributes
			add_attributes_from_instance(*wire, inst);
			break;
		}
		case Id_Output:
		case Id_Inout:
		case Id_Iinout:
			//  The wire was created when the port was.
			break;
		case Id_Assert:
		case Id_Assume:
		case Id_Cover:
		case Id_Assert_Cover:
			//  No output
			break;
		case Id_Memory:
		case Id_Memory_Init:
		case Id_Mem_Wr_Sync:
			//  Handled by import_memory.
			break;
		case Id_Port:
		case Id_Const_UB32:
		case Id_Const_SB32:
		case Id_Const_UL32:
		case Id_Const_Bit:
		case Id_Const_Log:
		case Id_Const_Z:
		case Id_Const_X:
		case Id_Const_0:
		case Id_Uextend:
		case Id_Sextend:
		case Id_Utrunc:
		case Id_Strunc:
		case Id_Extract:
		case Id_Concat2:
		case Id_Concat3:
		case Id_Concat4:
		case Id_Concatn:
			//  Skip: these won't create cells.
			break;
		case Id_Posedge:
		case Id_Negedge:
			//  The cell is ignored.
			break;
		default:
			log_cmd_error("Unsupported(1): instance %s of %s.\n",
			              to_str(get_instance_name(inst)).c_str(),
			              to_str(get_module_name(get_module(inst))).c_str());
			return;
		}
	}

	//  Create cells and connect.
	for (Instance inst = get_first_instance(m);
	     is_valid(inst);
	     inst = get_next_instance(inst)) {
		Module_Id id = get_id(inst);
		Sname iname = get_instance_name(inst);
		switch (id) {
#define IN(N) get_src(net_map, get_input_net(inst, (N)))
#define OUT(N) get_src(net_map, get_output(inst, (N)))
		case Id_And:
			module->addAnd(to_str(iname), IN(0), IN(1), OUT(0));
			break;
		case Id_Or:
			module->addOr(to_str(iname), IN(0), IN(1), OUT(0));
			break;
		case Id_Xor:
			module->addXor(to_str(iname), IN(0), IN(1), OUT(0));
			break;
		case Id_Nand:
			{
				SigSpec r = OUT(0);
				RTLIL::Wire *w = module->addWire(NEW_ID, r.size());
				module->addAnd(NEW_ID, IN(0), IN(1), w);
				module->addNot(to_str(iname), w, r);
			}
			break;
		case Id_Nor:
			{
				SigSpec r = OUT(0);
				RTLIL::Wire *w = module->addWire(NEW_ID, r.size());
				module->addOr(NEW_ID, IN(0), IN(1), w);
				module->addNot(to_str(iname), w, r);
			}
			break;
		case Id_Xnor:
			module->addXnor(to_str(iname), IN(0), IN(1), OUT(0));
			break;
		case Id_Add:
			module->addAdd(to_str(iname), IN(0), IN(1), OUT(0));
			break;
		case Id_Sub:
			module->addSub(to_str(iname), IN(0), IN(1), OUT(0));
			break;
		case Id_Neg:
			module->addNeg(to_str(iname), IN(0), OUT(0), true);
			break;
		case Id_Not:
			module->addNot(to_str(iname), IN(0), OUT(0));
			break;
		case Id_Abs:
			{
				SigSpec isNegative = IN(0).extract(IN(0).size() - 1, 1);
				RTLIL::Wire *negated = module->addWire(NEW_ID, IN(0).size());
				module->addNeg(NEW_ID, IN(0), negated);
				module->addMux(NEW_ID, IN(0), negated, isNegative, OUT(0));
			}
			break;
		case Id_Eq:
			module->addEq(to_str(iname), IN(0), IN(1), OUT(0));
			break;
		case Id_Ne:
			module->addNe(to_str(iname), IN(0), IN(1), OUT(0));
			break;
		case Id_Ult:
			module->addLt(to_str(iname), IN(0), IN(1), OUT(0));
			break;
		case Id_Ule:
			module->addLe(to_str(iname), IN(0), IN(1), OUT(0));
			break;
		case Id_Ugt:
			module->addGt(to_str(iname), IN(0), IN(1), OUT(0));
			break;
		case Id_Uge:
			module->addGe(to_str(iname), IN(0), IN(1), OUT(0));
			break;
		case Id_Slt:
			module->addLt(to_str(iname), IN(0), IN(1), OUT(0), true);
			break;
		case Id_Sle:
			module->addLe(to_str(iname), IN(0), IN(1), OUT(0), true);
			break;
		case Id_Sgt:
			module->addGt(to_str(iname), IN(0), IN(1), OUT(0), true);
			break;
		case Id_Sge:
			module->addGe(to_str(iname), IN(0), IN(1), OUT(0), true);
			break;
		case Id_Red_Or:
			module->addReduceOr(to_str(iname), IN(0), OUT(0));
			break;
		case Id_Red_And:
			module->addReduceAnd(to_str(iname), IN(0), OUT(0));
			break;
		case Id_Red_Xor:
			module->addReduceXor(to_str(iname), IN(0), OUT(0));
			break;
		case Id_Lsl:
			module->addShl(to_str(iname), IN(0), IN(1), OUT(0));
			break;
		case Id_Lsr:
			module->addShr(to_str(iname), IN(0), IN(1), OUT(0));
			break;
		case Id_Asr:
			module->addSshr(to_str(iname), IN(0), IN(1), OUT(0), true);
			break;
		case Id_Smin:
		case Id_Umin:
		case Id_Smax:
		case Id_Umax:
			{
				bool is_signed = (id == Id_Smin || id == Id_Smax);

				RTLIL::Wire *select_rhs = module->addWire(NEW_ID);
				if (id == Id_Smin || id == Id_Umin) {
					module->addGt(NEW_ID, IN(0), IN(1), select_rhs, is_signed);
				} else {
					module->addLt(NEW_ID, IN(0), IN(1), select_rhs, is_signed);
				}

				module->addMux(to_str(iname), IN(0), IN(1), select_rhs, OUT(0));
			}
			break;
		case Id_Smul:
			module->addMul(to_str(iname), IN(0), IN(1), OUT(0), true);
			break;
		case Id_Umul:
			module->addMul(to_str(iname), IN(0), IN(1), OUT(0), false);
			break;
		case Id_Sdiv:
			module->addDiv(to_str(iname), IN(0), IN(1), OUT(0), true);
			break;
		case Id_Udiv:
			module->addDiv(to_str(iname), IN(0), IN(1), OUT(0), false);
			break;
		case Id_Srem:
			// Id_Urem would be the same as Id_Umod, so only the latter exists
			// $mod: modulo of truncating division, "rem" in VHDL
			module->addMod(to_str(iname), IN(0), IN(1), OUT(0), true);
			break;
		case Id_Smod:
		case Id_Umod:
			// $modfloor: modulo of flooring division, "mod" in VHDL
			module->addModFloor(to_str(iname), IN(0), IN(1), OUT(0), id == Id_Smod);
			break;
		case Id_Mux2:
			module->addMux(to_str(iname), IN(1), IN(2), IN(0), OUT(0));
			break;
		case Id_Mux4:
			{
				SigSpec Sel0 = IN(0).extract(0, 1);
				SigSpec Sel1 = IN(0).extract(1, 1);
				SigSpec in1 = IN(1);
				RTLIL::Wire *w0 = module->addWire(NEW_ID, in1.size());
				RTLIL::Wire *w1 = module->addWire(NEW_ID, in1.size());
				module->addMux(NEW_ID, in1, IN (2), Sel0, w0);
				module->addMux(NEW_ID, IN (3), IN (4), Sel0, w1);
				module->addMux(NEW_ID, w0, w1, Sel1, OUT (0));
			}
			break;
		case Id_Pmux:
		        {
		            RTLIL::SigSpec b;
			    RTLIL::SigSpec s = IN(0);
			    for (int i = 0; i < s.size(); i++)
				    b.append(IN(2 + i));
			    module->addPmux(to_str(iname), IN(1), b, s, OUT(0));
			}
			break;
		case Id_Dff:
		case Id_Idff:
			{
				Net edge_clk = get_input_net(inst, 0);
				Net clk = get_input_net(get_net_parent(edge_clk), 0);
				RTLIL::SigSpec sig_clk = get_src(net_map, clk);
				if (has_attribute_gclk(clk))
					module->addFf(to_str(iname), IN(1), OUT(0));
				else
					module->addDff(to_str(iname), sig_clk, IN(1), OUT(0), extract_clk_pol(edge_clk) == RTLIL::State::S1);
				//  For idff, the initial value is set on the output wire.
				if (id == Id_Idff) {
					net_map[get_output(inst, 0).id]->attributes[ID::init] = IN(2).as_const();
				}
			}
			break;
		case Id_Adff:
		case Id_Iadff:
		        {
				Net clk = get_input_net(inst, 0);
				SigSpec rval = IN(3);
				SigSpec clk_sig = extract_clk_sig(net_map, clk);
				bool clk_pol = extract_clk_pol(clk) == RTLIL::State::S1;
				SigSpec arst = IN(2);
				SigSpec d = IN(1);
				SigSpec q = OUT(0);

				// If the reset value (rval) is a constant, use a classic asynchronous dff.
				if (rval.is_fully_const())
					module->addAdff(to_str(iname), clk_sig, arst, d, q, rval.as_const(), clk_pol);
				else {
					// Otherwise, use a dffsr.
					// set <= arst ? d : 0
					SigSpec zero = SigSpec(RTLIL::State::S0, d.size());
					RTLIL::Wire *set = module->addWire(NEW_ID, d.size());
					module->addMux(NEW_ID, zero, d, arst, set);
					//  clr <= arst ? ~d : 0
					RTLIL::Wire *d_n = module->addWire(NEW_ID, d.size());
					module->addNot(NEW_ID, d, d_n);
					RTLIL::Wire *clr = module->addWire(NEW_ID, d.size());
					module->addMux(NEW_ID, zero, d_n, arst, clr);
					//  Use dffsr
					module->addDffsr(to_str(iname), clk_sig, set, clr, d, q, clk_pol);
				}
				//  For iadff, the initial value is set on the output
				//  wire.
				if (id == Id_Iadff) {
					net_map[get_output(inst, 0).id]->attributes[ID::init] = IN(4).as_const();
				}
			}
			break;
		case Id_User_None:
		case Id_User_Parameters:
			{
				RTLIL::Cell *cell = module->addCell(
					to_str(iname),
					to_str(get_module_name(get_module(inst))));
				GhdlSynth::Module submod = get_module(inst);
				Port_Idx nbr_inputs = get_nbr_inputs(submod);
				for (Port_Idx idx = 0; idx < nbr_inputs; idx++) {
					cell->setPort(to_str(get_input_name(submod, idx)), IN(idx));
				}
				Port_Idx nbr_outputs = get_nbr_outputs(submod);
				for (Port_Idx idx = 0; idx < nbr_outputs; idx++) {
					cell->setPort(to_str(get_output_name(submod, idx)), OUT(idx));
				}
				if (id == Id_User_Parameters) {
					Param_Idx nbr_params = get_nbr_params(submod);
					for (Param_Idx idx = 0; idx < nbr_params; idx++) {
						RTLIL::Const cst = pval_to_const(get_param_pval(inst, idx));
						if (get_param_type(submod, idx) == Param_Pval_String)
							cst.flags |= RTLIL::CONST_FLAG_STRING;
						cell->setParam(to_str(get_param_name(submod, idx)), cst);
					}
				}
			}
			break;
		case Id_Signal:
		case Id_Isignal:
			module->connect(OUT (0), IN (0));
			break;
		case Id_Output:
		case Id_Port:
			module->connect(OUT (0), IN (0));
			break;
		case Id_Inout:
		case Id_Iinout:
			// Virtual gate.
			// Connect input to output.
			module->connect(OUT(0), IN(0));
			break;
		case Id_Assert:
			module->addAssert(to_str(iname), IN(0), State::S1);
			break;
		case Id_Assume:
			module->addAssume(to_str(iname), IN(0), State::S1);
			break;
		case Id_Cover:
		case Id_Assert_Cover:
			module->addCover(to_str(iname), IN(0), State::S1);
			break;
		case Id_Allconst:
			add_formal_input(module, net_map, inst, "$allconst");
			break;
		case Id_Allseq:
			add_formal_input(module, net_map, inst, "$allseq");
			break;
		case Id_Anyconst:
			add_formal_input(module, net_map, inst, "$anyconst");
			break;
		case Id_Anyseq:
			add_formal_input(module, net_map, inst, "$anyseq");
			break;
		case Id_Tri:
			module->addTribuf(to_str(iname), IN(1), IN(0), OUT(0));
			break;
		case Id_Resolver:
			module->connect(OUT(0), IN(0));
			module->connect(OUT(0), IN(1));
			break;
		case Id_Memory:
		case Id_Memory_Init:
			//  Will be handled later.
			memories.push_back(inst);
			break;
		case Id_Mem_Rd:
		case Id_Mem_Rd_Sync:
		case Id_Mem_Wr_Sync:
			break;
		case Id_Const_UB32:
		case Id_Const_SB32:
		case Id_Const_UL32:
		case Id_Const_Bit:
		case Id_Const_Log:
		case Id_Const_Z:
		case Id_Const_X:
		case Id_Const_0:
		case Id_Uextend:
		case Id_Sextend:
		case Id_Utrunc:
		case Id_Strunc:
		case Id_Extract:
		case Id_Concat2:
		case Id_Concat3:
		case Id_Concat4:
		case Id_Concatn:
		case Id_Posedge:
		case Id_Negedge:
			break;
#undef IN
#undef OUT
		default:
			log_cmd_error("Unsupported(2): instance %s of %s.\n",
			              to_str(get_instance_name(inst)).c_str(),
			              to_str(get_module_name(get_module(inst))).c_str());
			return;
		}
	}

	for (auto i : memories) {
		import_memory(module, net_map, i);
	}

	//  Create output ports
	for (Port_Idx idx = 0; idx < nbr_outputs; idx++) {
		if (get_inout_flag(m, idx))
			continue;

		Net output_out = get_input_net(self_inst, idx);

		//  Create wire
		RTLIL::Wire *wire = module->addWire(to_str(get_output_name(m, idx)));
		wire->port_id = nbr_inputs + idx + 1;
		wire->port_output = true;
		wire->width = get_width(output_out);
                add_attributes_chain(*wire, get_output_port_first_attribute(m, idx));

		module->connect(wire, get_src(net_map, output_out));

		Instance inst = get_net_parent(output_out);
		switch(get_id(inst)) {
		case Id_Output:
			add_attributes_from_instance(*wire, inst);
			break;
		default:
			break;
		}
	}

	module->fixup_ports();
}

static void import_netlist(RTLIL::Design *design, GhdlSynth::Module top)
{
	for (GhdlSynth::Module m = get_first_sub_module (top);
	     is_valid(m);
	     m = get_next_sub_module (m)) {
		//  Do not try to synthesize predefined gates.
		if (get_id (m) < Id_User_None)
			continue;
		import_module(design, m);
	}
}

extern "C" void libghdl__set_hooks_for_analysis(void);
extern "C" int libghdl__set_option(const char* opt, int len);
extern "C" int libghdl__analyze_init_status();
extern "C" int libghdl__analyze_file(const char* file, int len);
extern "C" void libraries__save_work_library(void);

#endif /* YOSYS_ENABLE_GHDL */

YOSYS_NAMESPACE_BEGIN

struct GhdlPass : public Pass {
	GhdlPass() : Pass("ghdl", "load VHDL designs using GHDL") { }
	virtual void help()
	{
		//   |---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|
		log("\n");
		log("    ghdl -a [OPTIONS] <vhdl-file>..\n");
		log("\n");
		log("Analyze the specified VHDL files.\n");
		log("\n");
		log("\n");
		log("    ghdl [options] unit [arch]\n");
		log("\n");
		log("Elaborate the already analyzed unit design and import it\n");
		log("\n");
		log("    ghdl [options] files... -e [unit]\n");
		log("\n");
		log("Analyse files, elaborate unit and import it\n");
		log("If unit is not specified, it is automatically found\n");
		log("\n");
		log("Full list of options are described in ghdl documentation.\n");
		log("\n");
		log("    --std=(93|08)\n");
		log("        set the vhdl standard.\n");
		log("\n");
		log("    -C\n");
		log("        allow UTF-8 in comments.\n");
		log("\n");
		log("    --ieee=synopsys\n");
		log("        allow use of ieee.std_logic_arith.\n");
		log("\n");
		log("    -fpsl\n");
		log("        parse PSL in comments.\n");
		log("\n");
		log("    --top-name=hash\n");
		log("        use hash to encode the top entity name\n");
	}
#ifdef YOSYS_ENABLE_GHDL
	virtual void execute(std::vector<std::string> args, RTLIL::Design *design)
	{
		static bool lib_initialized;
		static unsigned work_initialized;
		log_header(design, "Executing GHDL.\n");

		//  Initialize the library.
		if (!lib_initialized) {
			lib_initialized = 1;
			libghdl_init ();
		}

		if (args.size() == 2 && args[1] == "--disp-config") {
			ghdlcomp__disp_config();
			log("yosys plugin compiled on " __DATE__ " " __TIME__
#ifdef GHDL_VER_HASH
			    ", git hash:" GHDL_VER_HASH
#endif
			    "\n");
		}
		else if (args.size() > 1 && args[1] == "-a") {
			libghdl__set_hooks_for_analysis();

			size_t arg = 2;
			for (; arg < args.size() && args[arg][0] == '-'; ++arg) {
				if (libghdl__set_option(args[arg].c_str(), args[arg].size()) != 0) {
					log_cmd_error("set option (%s) failed.\n", args[arg].c_str());
				}
			}

			if (libghdl__analyze_init_status() != 0) {
				log_cmd_error("analyze init failed.\n");
			}

			for (; arg < args.size(); ++arg) {
				if (libghdl__analyze_file(args[arg].c_str(), args[arg].size()) == 0) {
					log_cmd_error("analyze file (%s) failed.\n", args[arg].c_str());
				}
			}

			libraries__save_work_library();
		}
		else {
			ghdlsynth__init_for_ghdl_synth();

			int cmd_argc = args.size() - 1;
			const char **cmd_argv = new const char *[cmd_argc];
			for (int i = 0; i < cmd_argc; i++)
				cmd_argv[i] = args[i + 1].c_str();

			GhdlSynth::Module top;
			top = ghdl_synth(!work_initialized, cmd_argc, cmd_argv);
			work_initialized++;
			if (!is_valid(top)) {
				log_cmd_error("vhdl import failed.\n");
			}
			//  For the gclk attribute.
			nameid_gclk = get_identifier("gclk");

			import_netlist(design, top);
		}
	}
#else /* YOSYS_ENABLE_GHDL */
	virtual void execute(std::vector<std::string>, RTLIL::Design *) {
		log_cmd_error("This version of Yosys is built without GHDL support.\n");
	}
#endif
} GhdlPass;

YOSYS_NAMESPACE_END

// vim: ts=8:sw=8:noet
