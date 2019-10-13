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

#include "ghdlsynth.h"

using namespace GhdlSynth;

static std::string to_str(Sname name)
{
	std::string res;
	bool is_sys = false;

	for (Sname pfx = name; is_valid(pfx); pfx = get_sname_prefix(pfx)) {
		switch (get_sname_kind(pfx)) {
		case Sname_Artificial:
			is_sys = true;
			// fallthrough
		case Sname_User:
			res = '.' + string(get_cstr(get_sname_suffix(pfx))) + res;
			break;
		case Sname_Version:
			res = '%' + stringf("%u", get_sname_version(pfx)) + res;
			break;
		}
	}
	res[0] = is_sys ? '$' : '\\';
	return res;
}

static RTLIL::SigSpec get_src(std::vector<RTLIL::Wire *> &net_map, Net n)
{
	log_assert(n.id != 0);

	//  Search if N is the output of a cell.
	Wire *res = n.id < net_map.size() ? net_map.at(n.id) : nullptr;
	if (res != nullptr)
		return res;

	Instance inst = get_net_parent(n);
	switch(get_id(inst)) {
#define IN(N) get_src(net_map, get_input_net(inst, (N)))
	case Id_Signal:
	case Id_Isignal:
	case Id_Port:
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
	case Id_Const_Bit:
		{
		       const unsigned wd = get_width(n);
		       std::vector<RTLIL::State> bits(wd);
		       unsigned int val;
		       for (unsigned i = 0; i < wd; i++) {
			       if (i % 32 == 0)
			               val = get_param_uns32(inst, i / 32);
			       bits[i] = (val >> i) & 1 ? RTLIL::State::S1 : RTLIL::State::S0;
		       }
		       return RTLIL::SigSpec(RTLIL::Const(bits));
		}
	case Id_Const_UB32:
		{
		       const unsigned wd = get_width(n);
		       std::vector<RTLIL::State> bits(wd);
		       int32_t val = get_param_uns32(inst, 0);
		       for (unsigned i = 0; i < wd; i++) {
                   // signed right shift is technically implementation defined
                   // but arithmetic in practice
			       bits[i] = (val >> i) & 1 ? RTLIL::State::S1 : RTLIL::State::S0;
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
	case Id_Const_Log:
	        {
		       const unsigned wd = get_width(n);
		       std::vector<RTLIL::State> bits(wd);
		       unsigned int val01;
		       unsigned int valzx;
		       for (unsigned i = 0; i < wd; i++) {
			       if (i % 32 == 0) {
			               val01 = get_param_uns32(inst, 2*(i / 32));
				       valzx = get_param_uns32(inst, 2*(i / 32) + 1);
			       }
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
	case Id_Const_UL32:
	        {
		       const unsigned wd = get_width(n);
		       std::vector<RTLIL::State> bits(wd);
		       int32_t val01 = get_param_uns32(inst, 0);
		       int32_t valzx = get_param_uns32(inst, 0);
		       for (unsigned i = 0; i < wd; i++) {
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
		{
			RTLIL::SigSpec res = IN(0);
			return res.extract(get_param_uns32(inst, 0), get_width(n));
		}
	case Id_Concat2:
	case Id_Concat3:
	case Id_Concat4:
	       {
			RTLIL::SigSpec res;
			unsigned nbr_in = get_nbr_inputs(get_module(inst));
			//  ConcatN means { I0; I1; .. IN}, but append() adds
			//  bits to the MSB side.
			for (unsigned i = nbr_in; i > 0; i--)
				res.append(IN(i - 1));
			return res;
	       }
	case Id_Concatn:
	       {
			RTLIL::SigSpec res;
			unsigned nbr_in = get_param_uns32(inst, 0);
			//  ConcatN means { I0; I1; .. IN}, but append() adds
			//  bits to the MSB side.
			for (unsigned i = nbr_in; i > 0; i--)
				res.append(IN(i - 1));
			return res;
	       }
	default:
		log_cmd_error("wire not found for %s\n", to_str(get_module_name(get_module(inst))).c_str());
		break;
	}
	return SigSpec();
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

static void import_module(RTLIL::Design *design, GhdlSynth::Module m)
{
	std::string module_name = to_str(get_module_name(m));

	if (design->has(module_name)) {
		log_cmd_error("Re-definition of module `%s'.\n", module_name.c_str());
		return;
	}

	RTLIL::Module *module = new RTLIL::Module;
	module->name = module_name;
	design->add(module);

	log("Importing module %s.\n", RTLIL::id2cstr(module->name));

	//  TODO: support submodules
	if (is_valid(get_first_sub_module(m))) {
		log_cmd_error("Unsupported: submodules in `%s'.\n", module_name.c_str());
		return;
	}

	Instance self_inst = get_self_instance (m);
	if (!is_valid(self_inst)) { // blackbox
		module->set_bool_attribute("\\blackbox");

        Port_Idx nbr_inputs = get_nbr_inputs(m);
        for (Port_Idx idx = 0; idx < nbr_inputs; idx++) {
            RTLIL::Wire *wire = module->addWire(
                    to_str(get_input_name(m, idx)),
                    get_input_width(m, idx));
            wire->port_input = true;
        }
        Port_Idx nbr_outputs = get_nbr_outputs(m);
        for (Port_Idx idx = 0; idx < nbr_outputs; idx++) {
            RTLIL::Wire *wire = module->addWire(
                    to_str(get_output_name(m, idx)),
                    get_output_width(m, idx));
            wire->port_output = true;
        }
        module->fixup_ports();
		return;
    }

	//  Create input ports.
	//  They correspond to ouputs of the self instance.
	std::vector<RTLIL::Wire *> net_map;
	Port_Idx nbr_inputs = get_nbr_inputs(m);
	for (Port_Idx idx = 0; idx < nbr_inputs; idx++) {
		Net port = get_output(self_inst, idx);

		RTLIL::Wire *wire = module->addWire(to_str(get_input_name(m, idx)));
		wire->port_id = idx + 1;
		wire->port_input = true;
		wire->width = get_width(port);
		set_src(net_map, port, wire);
	}
	//  Create output ports
	Port_Idx nbr_outputs = get_nbr_outputs(m);
	for (Port_Idx idx = 0; idx < nbr_outputs; idx++) {
		Net output_out = get_input_net(self_inst, idx);

		//  Create wire
		RTLIL::Wire *wire = module->addWire(to_str(get_output_name(m, idx)));
		wire->port_id = nbr_inputs + idx + 1;
		wire->port_output = true;
		wire->width = get_width(output_out);
		set_src(net_map, output_out, wire);

		if (0) {
		//  If the driver for this output drives only this output,
		//  reuse this wire.
		Instance output_inst = get_net_parent(output_out);
		log_assert(get_id(get_module(output_inst)) == Id_Output);
		Net output_drv = get_input_net(output_inst, 0);
		if (has_one_connection (output_drv))
			set_src(net_map, output_drv, wire);
		}
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
		case Id_Mux2:
		case Id_Mux4:
		case Id_Dff:
		case Id_Adff:
		case Id_Idff:
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
                case Id_Red_Or:
                case Id_Red_And:
                case Id_Lsr:
                case Id_Lsl:
                case Id_Asr:
                case Id_Assert:  // No output
                case Id_Assume:  // No output
                case Id_Cover:  // No output
                case Id_User_None:
			for (Port_Idx idx = 0; idx < get_nbr_outputs(im); idx++) {
				Net o = get_output(inst, idx);
				//  The wire may have been created for an output
				if (!is_set(net_map, o)) {
					RTLIL::Wire *wire =
                                          module->addWire(NEW_ID, get_width(o));
					set_src(net_map, o, wire);
				}
			}
			break;
		case Id_Signal:
		case Id_Isignal:
		case Id_Output:
		case Id_Port:
		case Id_Const_UB32:
		case Id_Const_UL32:
		case Id_Const_Bit:
		case Id_Const_Log:
		case Id_Const_Z:
		case Id_Const_X:
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
                case Id_Edge:
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
		case Id_Not:
			module->addNot(to_str(iname), IN(0), OUT(0));
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
		case Id_Lsl:
			module->addShl(to_str(iname), IN(0), IN(1), OUT(0));
			break;
		case Id_Lsr:
			module->addShr(to_str(iname), IN(0), IN(1), OUT(0));
			break;
		case Id_Asr:
			module->addSshr(to_str(iname), IN(0), IN(1), OUT(0), true);
			break;
		case Id_Mux2:
			module->addMux(to_str(iname), IN(1), IN(2), IN(0), OUT(0));
			break;
		case Id_Dff:
		case Id_Idff:
                        module->addDff(to_str(iname), IN(0), IN(1), OUT(0));
			//  For idff, the initial value is set on the output
			//  wire.
			if (id == Id_Idff) {
				net_map[get_output(inst, 0).id]->attributes["\\init"] = IN(2).as_const();
			}
			break;
		case Id_Adff:
			module->addAdff(to_str(iname), IN(0), IN(2), IN(1), OUT(0), IN(3).as_const());
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
                case Id_User_None:
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
                            break;
                        }
		case Id_Signal:
		case Id_Isignal:
			{
				Net sig = get_input_net(inst, 0);
                                if (is_set(net_map, sig)) {
                                    Wire *w = net_map.at(sig.id);
                                    if (w)
                                        module->rename(w, to_str(iname));
                                }
			}
			break;
		case Id_Output:
                case Id_Port:
			module->connect(OUT (0), IN (0));
			break;
		case Id_Assert:
			module->addAssert(to_str(iname), IN(0), State::S1);
			break;
		case Id_Assume:
			module->addAssume(to_str(iname), IN(0), State::S1);
			break;
		case Id_Cover:
			module->addCover(to_str(iname), IN(0), State::S1);
			break;
		case Id_Const_UB32:
		case Id_Const_UL32:
		case Id_Const_Bit:
		case Id_Const_Log:
		case Id_Const_Z:
		case Id_Const_X:
		case Id_Uextend:
		case Id_Sextend:
		case Id_Utrunc:
		case Id_Strunc:
		case Id_Extract:
		case Id_Concat2:
		case Id_Concat3:
		case Id_Concat4:
		case Id_Concatn:
                case Id_Edge:
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

	//  Connect output drivers to output
	for (Port_Idx idx = 0; idx < nbr_outputs; idx++) {
		Net output_out = get_input_net(self_inst, idx);
		Instance output_inst = get_net_parent(output_out);
		log_assert(get_id(get_module(output_inst)) == Id_Output);
		Net output_drv = get_input_net(output_inst, 0);
		if (!has_one_connection (output_drv))
			module->connect(get_src(net_map, output_out), get_src(net_map, output_drv));
	}

	module->fixup_ports();
}

static void import_netlist(RTLIL::Design *design, GhdlSynth::Module top)
{
	for (GhdlSynth::Module m = get_first_sub_module (top);
	     is_valid(m);
	     m = get_next_sub_module (m)) {
		if (get_id (m) < Id_User_None)
			continue;
		import_module(design, m);
	}
}

#endif /* YOSYS_ENABLE_GHDL */

YOSYS_NAMESPACE_BEGIN

struct GhdlPass : public Pass {
	GhdlPass() : Pass("ghdl", "load VHDL designs using GHDL") { }
	virtual void help()
	{
		//   |---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|
#if 0
		log("\n");
		log("    ghdl -a [OPTIONS] <vhdl-file>..\n");
		log("\n");
		log("Analyze the specified VHDL files.\n");
		log("\n");
#endif
		log("\n");
		log("    ghdl [FILES... -e] UNIT\n");
		log("\n");
		log("Elaborate the design and import to Yosys\n");
		log("\n");
	}
#ifdef YOSYS_ENABLE_GHDL
	virtual void execute(std::vector<std::string> args, RTLIL::Design *design)
	{
		static bool initialized;
		log_header(design, "Executing GHDL.\n");

		//  Initialize the library.
		if (!initialized) {
			initialized = 1;
			libghdl_init ();
			ghdlsynth__init_for_ghdl_synth();
		}

		if (args.size() == 2 && args[1] == "--disp-config") {
			ghdlcomp__disp_config();
		}
		else {
			int cmd_argc = args.size() - 1;
			const char **cmd_argv = new const char *[cmd_argc];
			for (int i = 0; i < cmd_argc; i++)
				cmd_argv[i] = args[i + 1].c_str();

			GhdlSynth::Module top;
			top = ghdl_synth(cmd_argc, cmd_argv);
			if (!is_valid(top)) {
				log_cmd_error("vhdl import failed.\n");
			}
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
