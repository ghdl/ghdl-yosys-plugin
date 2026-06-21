/*
 *  yosys -- Yosys Open SYnthesis Suite
 *
 *  Based upon verilog_backend
 *  Copyright (C) 2012-2026  Claire Xenia Wolf <claire@yosyshq.com>
 *
 *  Copyright (C) 2026  D. Jeff Dionne, via Claude Opus 4.6
 *
 *  Permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 *  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 *  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 *  ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 *  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 *  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 *  OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 *  SPDX-License-Identifier: ISC
 *
 *  A VHDL-1993 / VHDL-2008 backend for Yosys.
 */

#include "vhdl_backend.h"
#include "kernel/celltypes.h"
#include "kernel/ff.h"
#include "kernel/log.h"
#include "kernel/mem.h"
#include "kernel/register.h"
#include "kernel/sigtools.h"
#include <algorithm>
#include <cctype>
#include <map>
#include <set>
#include <sstream>
#include <string>

USING_YOSYS_NAMESPACE

const pool<string> VHDL_BACKEND::vhdl_keywords()
{
	static const pool<string> res = {
	  // VHDL-2008 reserved words (IEEE 1076-2008)
	  "abs",	   "access",	"after",     "alias",	 "all",	      "and",	    "architecture", "array",	 "assert",
	  "assume",	   "attribute", "begin",     "block",	 "body",      "buffer",	    "bus",	    "case",	 "component",
	  "configuration", "constant",	"context",   "cover",	 "default",   "disconnect", "downto",	    "else",	 "elsif",
	  "end",	   "entity",	"exit",	     "fairness", "file",      "for",	    "force",	    "function",	 "generate",
	  "generic",	   "group",	"guarded",   "if",	 "impure",    "in",	    "inertial",	    "inout",	 "is",
	  "label",	   "library",	"linkage",   "literal",	 "loop",      "map",	    "mod",	    "nand",	 "new",
	  "next",	   "nor",	"not",	     "null",	 "of",	      "on",	    "open",	    "or",	 "others",
	  "out",	   "package",	"parameter", "port",	 "postponed", "procedure",  "process",	    "property",	 "protected",
	  "pure",	   "range",	"record",    "register", "reject",    "release",    "rem",	    "report",	 "restrict",
	  "return",	   "rol",	"ror",	     "select",	 "sequence",  "severity",   "signal",	    "shared",	 "sla",
	  "sll",	   "sra",	"srl",	     "strong",	 "subtype",   "then",	    "to",	    "transport", "type",
	  "unaffected",	   "units",	"until",     "use",	 "variable",  "view",	    "vpkg",	    "vmode",	 "vprop",
	  "vunit",	   "wait",	"when",	     "while",	 "with",      "xnor",	    "xor",
	};
	return res;
}

bool VHDL_BACKEND::id_is_vhdl_reserved(const std::string &str)
{
	std::string lower = str;
	std::transform(lower.begin(), lower.end(), lower.begin(), ::tolower);
	return vhdl_keywords().count(lower) != 0;
}

PRIVATE_NAMESPACE_BEGIN

bool verbose, norename, noattr, noexpr;
int auto_name_counter, auto_name_offset, auto_name_digits;
dict<RTLIL::IdString, int> auto_name_map;
std::string auto_prefix;
int vhdl_std;		  // 93 or 2008
std::string work_library; // VHDL work library name for output

RTLIL::Module *active_module;
dict<RTLIL::SigBit, RTLIL::State> active_initdata;
SigMap active_sigmap;
FfInitVals active_initvals;

// Set of wire names that are driven by clocked processes (need signal, not variable)
std::set<RTLIL::IdString> reg_wires;

// VHDL-93 output port shadow signals: maps output port wire name to shadow signal name.
// In VHDL-93, output ports cannot be read internally, so we create shadow signals
// and drive the output port from the shadow.
dict<RTLIL::IdString, std::string> outport_shadows;

// Helper: if 'body' matches /^<prefix>(\d+)$/ for the given prefix
// (length prefix_len), update auto_name_offset to be above that number.
void reserve_auto_num(const char *body, const char *prefix, size_t prefix_len)
{
	if (strncmp(body, prefix, prefix_len) != 0)
		return;
	const char *digits = body + prefix_len;
	if (*digits == '\0')
		return;
	for (const char *q = digits; *q; q++)
		if (*q < '0' || *q > '9')
			return;
	int num = atoi(digits);
	if (num >= auto_name_offset)
		auto_name_offset = num + 1;
}

// Return true if 'body' (the RTLIL name after stripping the leading '\\' prefix)
// is a cleanly-wrapped VHDL extended identifier of the form \\X\\ -- i.e. it
// starts with '\\', ends with '\\', and has no '\\' anywhere in between.
// Such names round-trip correctly through GHDL: GHDL reads \\X\\ as the extended
// identifier \\X\\ and stores the RTLIL name as "\\\\X\\\\".
bool is_clean_extended_id_body(const char *body)
{
	size_t len = strlen(body);
	if (len < 2 || body[0] != '\\' || body[len - 1] != '\\')
		return false;
	// Check no '\\' in the interior
	for (size_t i = 1; i < len - 1; i++)
		if (body[i] == '\\')
			return false;
	return true;
}

void reset_auto_counter_id(RTLIL::IdString id_val, bool may_rename)
{
	const char *str = id_val.c_str();
	if (*str == '$' && may_rename && !norename)
		auto_name_map[id_val] = auto_name_counter++;

	if (*str != '\\')
		return;
	const char *body = str + 1; // body after stripping RTLIL '\\' prefix

	// If the body contains any '\\' but is NOT a clean \\X\\ extended-identifier
	// wrapper (e.g. GHDL-generated composite names like "\\yk:1.yp\\:554" where
	// the body is "\\yk:1.yp\\:554"), the name cannot be represented as any valid
	// VHDL identifier (basic or extended) because '\\' is illegal inside VHDL
	// extended identifiers.  Force such names into auto_name_map for renaming.
	if (strchr(body, '\\') && !is_clean_extended_id_body(body)) {
		if (may_rename && !norename)
			auto_name_map[id_val] = auto_name_counter++;
		return;
	}

	// Verilog-backend-style names: \\_N_ (e.g. \\_42_)
	if (*body == '_') {
		bool all_digits = true;
		const char *p = body + 1;
		std::string s;
		for (; *p; p++) {
			if (*p == '_' && *(p + 1) == '\0')
				break;
			if (*p < '0' || *p > '9') {
				all_digits = false;
				break;
			}
			s.push_back(*p);
		}
		if (all_digits && !s.empty()) {
			int num = atoi(s.c_str());
			if (num >= auto_name_offset)
				auto_name_offset = num + 1;
		}
	}

	// VHDL-backend-style names: nN (e.g. n0, n42) -- generated by this backend
	// when auto_prefix is empty (the default).  We must reserve these numbers
	// in auto_name_offset so that freshly auto-renamed $-signals don't collide
	// with user-visible wire names that the VHDL backend emitted in a prior run
	// and that a VHDL front-end (e.g. GHDL) has preserved verbatim.
	reserve_auto_num(body, "n", 1);

	// Also check for the current auto_prefix if non-empty.
	if (!auto_prefix.empty())
		reserve_auto_num(body, auto_prefix.c_str(), auto_prefix.size());
}

void reset_auto_counter(RTLIL::Module *module)
{
	auto_name_map.clear();
	auto_name_counter = 0;
	auto_name_offset = 0;

	reset_auto_counter_id(module->name, false);

	for (auto w : module->wires())
		reset_auto_counter_id(w->name, true);

	for (auto cell : module->cells()) {
		reset_auto_counter_id(cell->name, true);
		reset_auto_counter_id(cell->type, false);
	}

	for (auto it = module->processes.begin(); it != module->processes.end(); ++it)
		reset_auto_counter_id(it->second->name, false);

	auto_name_digits = 1;
	for (size_t i = 10; i < auto_name_offset + auto_name_map.size(); i = i * 10)
		auto_name_digits++;

	if (verbose)
		for (auto it = auto_name_map.begin(); it != auto_name_map.end(); ++it)
			log("  renaming `%s' to `%s%0*d'.\n", it->first.c_str(), auto_prefix.empty() ? "n" : auto_prefix.c_str(), auto_name_digits,
			    auto_name_offset + it->second);
}

std::string next_auto_id()
{
	// Use "n" prefix to ensure VHDL-legal identifiers (no leading/trailing underscores)
	if (auto_prefix.empty())
		return stringf("n%0*d", auto_name_digits, auto_name_offset + auto_name_counter++);
	return stringf("%s%0*d", auto_prefix.c_str(), auto_name_digits, auto_name_offset + auto_name_counter++);
}

// Auxiliary signal declarations (FF internals, split-Y temporaries, and
// bool-to-vector intermediates) emitted before "begin" in the architecture.
std::vector<std::string> aux_signal_decls;

// Check if a character needs extended identifier escaping in VHDL
bool char_needs_vhdl_escape(char c)
{
	if (c >= 'a' && c <= 'z')
		return false;
	if (c >= 'A' && c <= 'Z')
		return false;
	if (c >= '0' && c <= '9')
		return false;
	if (c == '_')
		return false;
	return true;
}

// Convert an RTLIL IdString to a valid VHDL identifier
std::string vhdl_id(RTLIL::IdString internal_id, bool may_rename)
{
	const char *str = internal_id.c_str();

	if (may_rename && auto_name_map.count(internal_id) != 0) {
		if (auto_prefix.empty())
			return stringf("n%0*d", auto_name_digits, auto_name_offset + auto_name_map[internal_id]);
		return stringf("%s%0*d", auto_prefix.c_str(), auto_name_digits, auto_name_offset + auto_name_map[internal_id]);
	}

	if (*str == '\\')
		str++;

	std::string result = str;

	// Handle the case where a VHDL frontend (e.g. GHDL) has read a VHDL
	// extended identifier \X\ and stored it in RTLIL as a user-visible name
	// whose body is \X\ (i.e. the full IdString c_str() is "\\X\", where the
	// first '\\' is the RTLIL user-visible prefix and "\X\" is the name body).
	// After stripping the RTLIL prefix above, result = "\X\" -- it starts with
	// '\\' AND ends with '\\', with no '\\' in between.
	// We must not wrap this literally inside a new VHDL extended identifier
	// because '\\' is not allowed inside extended identifiers.  Instead, strip
	// both the leading and trailing '\\' to recover the inner content "X",
	// then re-emit it as the extended identifier \X\.
	// Names whose body has '\\' in positions other than the clean \\X\\
	// wrapper pattern (e.g. GHDL-generated "\\yk:1.yp\\:554") should have
	// been forced into auto_name_map by reset_auto_counter_id and resolved
	// via the auto_name_map lookup above.  The is_clean_extended_id_body()
	// check is the canonical test; we reuse it here for correctness.
	if (is_clean_extended_id_body(result.c_str())) {
		std::string inner = result.substr(1, result.size() - 2);
		if (!inner.empty())
			return "\\" + inner + "\\";
	}

	// Check if we need extended identifier
	bool needs_escape = false;
	if (result.empty() || (result[0] >= '0' && result[0] <= '9'))
		needs_escape = true;
	// VHDL basic identifiers cannot start or end with underscore
	if (!result.empty() && (result[0] == '_' || result.back() == '_'))
		needs_escape = true;
	// Check for double underscores (illegal in VHDL basic identifiers)
	if (result.find("__") != std::string::npos)
		needs_escape = true;
	for (size_t i = 0; i < result.size() && !needs_escape; i++)
		if (char_needs_vhdl_escape(result[i]))
			needs_escape = true;
	if (VHDL_BACKEND::id_is_vhdl_reserved(result))
		needs_escape = true;

	if (needs_escape)
		return "\\" + result + "\\";
	return result;
}

std::string id(RTLIL::IdString internal_id, bool may_rename = true) { return vhdl_id(internal_id, may_rename); }

// Return VHDL type string for a given width
std::string vhdl_type_str(int width)
{
	if (width == 1)
		return "std_logic";
	return stringf("std_logic_vector(%d downto 0)", width - 1);
}

void dump_const(std::ostream &f, const RTLIL::Const &data, int width = -1, int offset = 0)
{
	if (width < 0)
		width = data.size() - offset;

	if (width == 0) {
		f << "\"\"";
		return;
	}

	if ((data.flags & RTLIL::CONST_FLAG_STRING) != 0 && width == (int)data.size()) {
		std::string str = data.decode_string();
		f << "\"";
		for (size_t i = 0; i < str.size(); i++) {
			if (str[i] == '"')
				f << "\"\""; // VHDL escapes quotes by doubling
			else
				f << str[i];
		}
		f << "\"";
		return;
	}

	if (width == 1) {
		log_assert(offset < (int)data.size());
		switch (data[offset]) {
		case State::S0:
			f << "'0'";
			break;
		case State::S1:
			f << "'1'";
			break;
		case RTLIL::Sx:
			f << "'X'";
			break;
		case RTLIL::Sz:
			f << "'Z'";
			break;
		case RTLIL::Sa:
			f << "'-'";
			break;
		case RTLIL::Sm:
			log_error("Found marker state in final netlist.");
			break;
		}
		return;
	}

	// Multi-bit: use bit string literal "01010..."
	f << "\"";
	for (int i = offset + width - 1; i >= offset; i--) {
		log_assert(i < (int)data.size());
		switch (data[i]) {
		case State::S0:
			f << "0";
			break;
		case State::S1:
			f << "1";
			break;
		case RTLIL::Sx:
			f << "X";
			break;
		case RTLIL::Sz:
			f << "Z";
			break;
		case RTLIL::Sa:
			f << "-";
			break;
		case RTLIL::Sm:
			log_error("Found marker state in final netlist.");
			break;
		}
	}
	f << "\"";
}

void dump_sigchunk(std::ostream &f, const RTLIL::SigChunk &chunk)
{
	if (chunk.wire == NULL) {
		dump_const(f, chunk.data, chunk.width, chunk.offset);
	} else {
		// In VHDL-93, output ports can't be read; use shadow signal if available
		std::string wire_name;
		if (outport_shadows.count(chunk.wire->name))
			wire_name = outport_shadows[chunk.wire->name];
		else
			wire_name = id(chunk.wire->name);

		if (chunk.width == chunk.wire->width && chunk.offset == 0) {
			f << wire_name;
		} else if (chunk.width == 1) {
			int idx;
			if (chunk.wire->upto)
				idx = (chunk.wire->width - chunk.offset - 1) + chunk.wire->start_offset;
			else
				idx = chunk.offset + chunk.wire->start_offset;
			f << wire_name << "(" << idx << ")";
		} else {
			int hi, lo;
			if (chunk.wire->upto) {
				hi = (chunk.wire->width - chunk.offset - 1) + chunk.wire->start_offset;
				lo = (chunk.wire->width - (chunk.offset + chunk.width - 1) - 1) + chunk.wire->start_offset;
			} else {
				hi = (chunk.offset + chunk.width - 1) + chunk.wire->start_offset;
				lo = chunk.offset + chunk.wire->start_offset;
			}
			f << wire_name << "(" << hi << " downto " << lo << ")";
		}
	}
}

void dump_sigspec(std::ostream &f, const RTLIL::SigSpec &sig)
{
	if (GetSize(sig) == 0) {
		f << "\"\"";
		return;
	}
	if (sig.is_chunk()) {
		dump_sigchunk(f, sig.as_chunk());
	} else {
		// VHDL concatenation uses &
		auto chunks = sig.chunks();
		bool first = true;
		// Chunks in RTLIL are LSB-first, VHDL concat is MSB-first
		for (auto it = chunks.rbegin(); it != chunks.rend(); ++it) {
			if (!first)
				f << " & ";
			first = false;
			dump_sigchunk(f, *it);
		}
	}
}

void dump_attributes(std::ostream &f, std::string indent, dict<RTLIL::IdString, RTLIL::Const> &attributes)
{
	if (noattr)
		return;
	for (auto it = attributes.begin(); it != attributes.end(); ++it) {
		if (it->first == ID::single_bit_vector)
			continue;
		f << indent << "-- attribute " << id(it->first) << " = ";
		dump_const(f, it->second);
		f << "\n";
	}
}

void dump_wire(std::ostream &f, std::string indent, RTLIL::Wire *wire)
{
	// Port wires are handled in the entity declaration; only emit non-port signals here
	if (wire->port_id)
		return;

	dump_attributes(f, indent, wire->attributes);
	f << indent << "signal " << id(wire->name) << " : " << vhdl_type_str(wire->width);

	// Emit signal initializer from init attribute (important for VHDL simulation)
	if (wire->attributes.count(ID::init)) {
		Const init_val = wire->attributes.at(ID::init);
		// Check if any bits are actually defined (not all x)
		bool has_defined = false;
		for (int i = 0; i < GetSize(init_val) && i < wire->width; i++)
			if (init_val[i] == State::S0 || init_val[i] == State::S1)
				has_defined = true;
		if (has_defined) {
			f << " := ";
			dump_const(f, init_val, wire->width, 0);
		}
	}

	f << ";\n";
}

// Emit a port declaration line for entity
void dump_port(std::ostream &f, std::string indent, RTLIL::Wire *wire)
{
	dump_attributes(f, indent, wire->attributes);
	f << indent << id(wire->name) << " : ";
	if (wire->port_input && !wire->port_output)
		f << "in ";
	else if (!wire->port_input && wire->port_output)
		f << "out ";
	else if (wire->port_input && wire->port_output)
		f << "inout ";
	f << vhdl_type_str(wire->width);
}

// For arithmetic results: std_logic_vector(resize(EXPR, W)) for W>1,
// or resize(EXPR, 1)(0) for W=1 (can't index a type conversion in VHDL).
std::string arith_open(int y_width)
{
	if (y_width == 1)
		return "resize(";
	return "std_logic_vector(resize(";
}

std::string arith_close(int y_width)
{
	if (y_width == 1)
		return stringf(", %d)(0)", y_width);
	return stringf(", %d))", y_width);
}

// Generate a VHDL bit string literal of width N, qualified to std_logic_vector
std::string vhdl_zero_const(int width) { return "std_logic_vector'(\"" + std::string(width, '0') + "\")"; }

std::string vhdl_ones_const(int width) { return "std_logic_vector'(\"" + std::string(width, '1') + "\")"; }

void dump_sigspec_unsigned(std::ostream &f, const RTLIL::SigSpec &sig)
{
	if (sig.is_fully_const() && GetSize(sig) == 1) {
		// 1-bit constant: unsigned'("0") or unsigned'("1")
		f << "unsigned'(\"\" & ";
		dump_sigspec(f, sig);
		f << ")";
	} else if (sig.is_fully_const()) {
		f << "unsigned'(";
		dump_sigspec(f, sig);
		f << ")";
	} else if (GetSize(sig) == 1) {
		f << "unsigned'(\"\" & ";
		dump_sigspec(f, sig);
		f << ")";
	} else if (!sig.is_chunk()) {
		// Multi-chunk: concatenation. Must qualify as std_logic_vector first.
		f << "unsigned(std_logic_vector'(";
		dump_sigspec(f, sig);
		f << "))";
	} else {
		f << "unsigned(";
		dump_sigspec(f, sig);
		f << ")";
	}
}

void dump_sigspec_signed(std::ostream &f, const RTLIL::SigSpec &sig)
{
	if (sig.is_fully_const() && GetSize(sig) == 1) {
		f << "signed'(\"\" & ";
		dump_sigspec(f, sig);
		f << ")";
	} else if (sig.is_fully_const()) {
		f << "signed'(";
		dump_sigspec(f, sig);
		f << ")";
	} else if (!sig.is_chunk()) {
		// Multi-chunk: concatenation. Must qualify as std_logic_vector first.
		f << "signed(std_logic_vector'(";
		dump_sigspec(f, sig);
		f << "))";
	} else {
		f << "signed(";
		dump_sigspec(f, sig);
		f << ")";
	}
}

// Emit process sensitivity list. In VHDL-2008: process(all).
// In VHDL-93: process(sig1, sig2, ...) with explicit signal names.
// The signals parameter lists all SigSpecs that should appear in the sensitivity list.
void dump_process_sens(std::ostream &f, std::string indent, std::vector<RTLIL::SigSpec> signals = {})
{
	if (vhdl_std >= 2008) {
		f << indent << "process(all)\n";
		return;
	}
	// VHDL-93: build explicit sensitivity list from signal names
	pool<std::string> sens;
	for (auto &sig : signals)
		for (auto &chunk : sig.chunks())
			if (chunk.wire != NULL)
				sens.insert(id(chunk.wire->name));
	f << indent << "process(";
	bool first = true;
	for (auto &s : sens) {
		if (!first)
			f << ", ";
		first = false;
		f << s;
	}
	if (first) {
		// An empty sensitivity list cannot occur in valid synthesisable RTL,
		// but guard against it rather than emitting invalid VHDL.
		log_warning("VHDL backend: process with empty sensitivity list -- using 'all'\n");
		f << "all";
	}
	f << ")\n";
}

// Forward declarations
void dump_conn(std::ostream &f, std::string indent, const RTLIL::SigSpec &left, const RTLIL::SigSpec &right);
void dump_expr_assign(std::ostream &f, std::string indent, const RTLIL::SigSpec &left, const std::string &expr);

// Emit a boolean result into signal Y with the given condition string.
//
// For y_width == 1:
//   Y <= '1' when COND else '0';
//
// For y_width > 1, VHDL-93 s7.3.2 forbids conditional expressions inside
// aggregates, so an intermediate std_logic signal is introduced:
//   bool_sig <= '1' when COND else '0';
//   Y        <= (0 => bool_sig, others => '0');
//
// cond must be a complete VHDL boolean expression (no surrounding 'when'/'else').
void dump_bool_assign(std::ostream &f, std::string indent,
	const RTLIL::SigSpec &y, const std::string &cond)
{
	if (GetSize(y) == 1) {
		f << indent;
		dump_sigspec(f, y);
		f << " <= '1' when " << cond << " else '0';\n";
	} else {
		std::string bool_sig = next_auto_id();
		aux_signal_decls.push_back(
			stringf("signal %s : std_logic;", bool_sig.c_str()));
		f << indent << bool_sig << " <= '1' when " << cond << " else '0';\n";
		f << indent;
		dump_sigspec(f, y);
		f << " <= (0 => " << bool_sig << ", others => '0');\n";
	}
}

bool dump_cell_expr(std::ostream &f, std::string indent, RTLIL::Cell *cell)
{
	// Gate-level NOT
	if (cell->type == ID($_NOT_)) {
		f << indent;
		dump_sigspec(f, cell->getPort(ID::Y));
		f << " <= not ";
		dump_sigspec(f, cell->getPort(ID::A));
		f << ";\n";
		return true;
	}

	// Gate-level BUF and $buf
	if (cell->type.in(ID($_BUF_), ID($buf))) {
		f << indent;
		dump_sigspec(f, cell->getPort(ID::Y));
		f << " <= ";
		dump_sigspec(f, cell->getPort(ID::A));
		f << ";\n";
		return true;
	}

	// Gate-level 2-input logic gates
	if (cell->type.in(ID($_AND_), ID($_NAND_), ID($_OR_), ID($_NOR_), ID($_XOR_), ID($_XNOR_), ID($_ANDNOT_), ID($_ORNOT_))) {
		f << indent;
		dump_sigspec(f, cell->getPort(ID::Y));
		f << " <= ";

		bool inv_result = cell->type.in(ID($_NAND_), ID($_NOR_), ID($_XNOR_));
		bool inv_b = cell->type.in(ID($_ANDNOT_), ID($_ORNOT_));

		if (inv_result)
			f << "not (";

		dump_sigspec(f, cell->getPort(ID::A));

		if (cell->type.in(ID($_AND_), ID($_NAND_), ID($_ANDNOT_)))
			f << " and ";
		else if (cell->type.in(ID($_OR_), ID($_NOR_), ID($_ORNOT_)))
			f << " or ";
		else
			f << " xor ";

		if (inv_b)
			f << "not ";
		dump_sigspec(f, cell->getPort(ID::B));

		if (inv_result)
			f << ")";
		f << ";\n";
		return true;
	}

	// Gate-level MUX
	if (cell->type == ID($_MUX_)) {
		f << indent;
		dump_sigspec(f, cell->getPort(ID::Y));
		f << " <= ";
		dump_sigspec(f, cell->getPort(ID::B));
		f << " when ";
		dump_sigspec(f, cell->getPort(ID::S));
		f << " = '1' else ";
		dump_sigspec(f, cell->getPort(ID::A));
		f << ";\n";
		return true;
	}

	// Gate-level NMUX
	if (cell->type == ID($_NMUX_)) {
		f << indent;
		dump_sigspec(f, cell->getPort(ID::Y));
		f << " <= not (";
		dump_sigspec(f, cell->getPort(ID::B));
		f << " when ";
		dump_sigspec(f, cell->getPort(ID::S));
		f << " = '1' else ";
		dump_sigspec(f, cell->getPort(ID::A));
		f << ");\n";
		return true;
	}

	// Gate-level AOI3/OAI3
	if (cell->type.in(ID($_AOI3_), ID($_OAI3_))) {
		f << indent;
		dump_sigspec(f, cell->getPort(ID::Y));
		f << " <= not ((";
		dump_sigspec(f, cell->getPort(ID::A));
		f << (cell->type == ID($_AOI3_) ? " and " : " or ");
		dump_sigspec(f, cell->getPort(ID::B));
		f << (cell->type == ID($_AOI3_) ? ") or " : ") and ");
		dump_sigspec(f, cell->getPort(ID::C));
		f << ");\n";
		return true;
	}

	// Gate-level AOI4/OAI4
	if (cell->type.in(ID($_AOI4_), ID($_OAI4_))) {
		f << indent;
		dump_sigspec(f, cell->getPort(ID::Y));
		f << " <= not ((";
		dump_sigspec(f, cell->getPort(ID::A));
		f << (cell->type == ID($_AOI4_) ? " and " : " or ");
		dump_sigspec(f, cell->getPort(ID::B));
		f << (cell->type == ID($_AOI4_) ? ") or (" : ") and (");
		dump_sigspec(f, cell->getPort(ID::C));
		f << (cell->type == ID($_AOI4_) ? " and " : " or ");
		dump_sigspec(f, cell->getPort(ID::D));
		f << "));\n";
		return true;
	}

	// $not -- bitwise NOT
	if (cell->type == ID($not)) {
		f << indent;
		dump_sigspec(f, cell->getPort(ID::Y));
		f << " <= not ";
		dump_sigspec(f, cell->getPort(ID::A));
		f << ";\n";
		return true;
	}

	// $pos -- identity / sign-extension
	if (cell->type == ID($pos)) {
		int a_width = cell->getParam(ID::A_WIDTH).as_int();
		int y_width = cell->getParam(ID::Y_WIDTH).as_int();
		bool a_signed = cell->getParam(ID::A_SIGNED).as_bool();

		f << indent;
		dump_sigspec(f, cell->getPort(ID::Y));
		f << " <= ";
		if (a_width == y_width) {
			dump_sigspec(f, cell->getPort(ID::A));
		} else {
			// Use arith_open/close so y_width==1 produces std_logic (not
			// std_logic_vector(0 downto 0) which would be a type mismatch).
			f << arith_open(y_width) << "resize(";
			if (a_signed)
				f << "signed(";
			else
				f << "unsigned(";
			dump_sigspec(f, cell->getPort(ID::A));
			f << "), " << y_width << ")" << arith_close(y_width);
		}
		f << ";\n";
		return true;
	}

	// $neg -- arithmetic negation
	if (cell->type == ID($neg)) {
		int y_width = cell->getParam(ID::Y_WIDTH).as_int();
		f << indent;
		dump_sigspec(f, cell->getPort(ID::Y));
		f << " <= " << arith_open(y_width) << "-signed(";
		dump_sigspec(f, cell->getPort(ID::A));
		f << ")" << arith_close(y_width) << ";\n";
		return true;
	}

	// Bitwise binary: $and, $or, $xor, $xnor
	if (cell->type.in(ID($and), ID($or), ID($xor), ID($xnor))) {
		int y_width = cell->getParam(ID::Y_WIDTH).as_int();
		int a_width = cell->getParam(ID::A_WIDTH).as_int();
		int b_width = cell->getParam(ID::B_WIDTH).as_int();
		bool a_signed = cell->getParam(ID::A_SIGNED).as_bool();
		bool b_signed = cell->getParam(ID::B_SIGNED).as_bool();

		std::string op;
		if (cell->type == ID($and))
			op = "and";
		else if (cell->type == ID($or))
			op = "or";
		else if (cell->type == ID($xor))
			op = "xor";
		else
			op = "xnor";

		f << indent;
		dump_sigspec(f, cell->getPort(ID::Y));
		f << " <= ";

		if (a_width == 1 && b_width == 1 && y_width == 1) {
			// All single-bit: use native std_logic operators
			dump_sigspec(f, cell->getPort(ID::A));
			f << " " << op << " ";
			dump_sigspec(f, cell->getPort(ID::B));
		} else {
			f << "std_logic_vector(";
			// Resize both operands to y_width, then apply bitwise op
			f << "resize(";
			if (a_signed)
				dump_sigspec_signed(f, cell->getPort(ID::A));
			else
				dump_sigspec_unsigned(f, cell->getPort(ID::A));
			f << ", " << y_width << ") " << op << " resize(";
			if (b_signed)
				dump_sigspec_signed(f, cell->getPort(ID::B));
			else
				dump_sigspec_unsigned(f, cell->getPort(ID::B));
			f << ", " << y_width << "))";
		}
		f << ";\n";
		return true;
	}

	// Reduction operators: $reduce_and, $reduce_or, $reduce_xor, $reduce_xnor, $reduce_bool
	if (cell->type.in(ID($reduce_and), ID($reduce_or), ID($reduce_xor), ID($reduce_xnor), ID($reduce_bool))) {
		int y_width = GetSize(cell->getPort(ID::Y));
		int a_width = GetSize(cell->getPort(ID::A));

		std::string op;
		if (cell->type == ID($reduce_and))
			op = "and";
		else if (cell->type.in(ID($reduce_or), ID($reduce_bool)))
			op = "or";
		else if (cell->type == ID($reduce_xor))
			op = "xor";
		else
			op = "xnor";

		f << indent << "-- reduce_" << op << "\n";

		if (a_width == 1) {
			// Single bit: just pass through (possibly with inversion for xnor)
			f << indent;
			dump_sigspec(f, cell->getPort(ID::Y));
			f << " <= ";
			if (cell->type == ID($reduce_xnor))
				f << "not ";
			if (y_width == 1) {
				dump_sigspec(f, cell->getPort(ID::A));
			} else {
				f << "(0 => ";
				dump_sigspec(f, cell->getPort(ID::A));
				if (GetSize(cell->getPort(ID::A)) > 1)
					f << "(0)";
				f << ", others => '0')";
			}
			f << ";\n";
		} else {
			std::stringstream cond;
			if (cell->type == ID($reduce_and)) {
				cond << "(";
				dump_sigspec(cond, cell->getPort(ID::A));
				cond << ") = " << vhdl_ones_const(a_width);
			} else if (cell->type.in(ID($reduce_or), ID($reduce_bool))) {
				cond << "(";
				dump_sigspec(cond, cell->getPort(ID::A));
				cond << ") /= " << vhdl_zero_const(a_width);
			} else if (cell->type == ID($reduce_xor)) {
				cond << "(";
				for (int i = 0; i < a_width; i++) {
					if (i > 0)
						cond << " xor ";
					dump_sigspec(cond, cell->getPort(ID::A));
					cond << "(" << i << ")";
				}
				cond << ") = '1'";
			} else { // reduce_xnor
				cond << "(";
				for (int i = 0; i < a_width; i++) {
					if (i > 0)
						cond << " xor ";
					dump_sigspec(cond, cell->getPort(ID::A));
					cond << "(" << i << ")";
				}
				cond << ") = '0'";
			}
			dump_bool_assign(f, indent, cell->getPort(ID::Y), cond.str());
		}
		return true;
	}

	// $logic_not -- logical NOT (Y = A == 0)
	if (cell->type == ID($logic_not)) {
		std::stringstream cond;
		dump_sigspec(cond, cell->getPort(ID::A));
		if (GetSize(cell->getPort(ID::A)) == 1)
			cond << " = '0'";
		else
			cond << " = " << vhdl_zero_const(GetSize(cell->getPort(ID::A)));
		dump_bool_assign(f, indent, cell->getPort(ID::Y), cond.str());
		return true;
	}

	// $logic_and, $logic_or
	if (cell->type.in(ID($logic_and), ID($logic_or))) {
		bool is_and = cell->type == ID($logic_and);
		std::stringstream cond;
		cond << "(";
		// A != 0
		dump_sigspec(cond, cell->getPort(ID::A));
		if (GetSize(cell->getPort(ID::A)) == 1)
			cond << " = '1'";
		else
			cond << " /= " << vhdl_zero_const(GetSize(cell->getPort(ID::A)));
		cond << (is_and ? " and " : " or ");
		// B != 0
		dump_sigspec(cond, cell->getPort(ID::B));
		if (GetSize(cell->getPort(ID::B)) == 1)
			cond << " = '1'";
		else
			cond << " /= " << vhdl_zero_const(GetSize(cell->getPort(ID::B)));
		cond << ")";
		dump_bool_assign(f, indent, cell->getPort(ID::Y), cond.str());
		return true;
	}

	// Arithmetic binary ops: $add, $sub, $mul, $div, $mod, $pow, $divfloor, $modfloor
	if (cell->type.in(ID($add), ID($sub), ID($mul), ID($div), ID($mod), ID($pow))) {
		int y_width = cell->getParam(ID::Y_WIDTH).as_int();
		bool a_signed = cell->getParam(ID::A_SIGNED).as_bool();
		bool b_signed = cell->getParam(ID::B_SIGNED).as_bool();
		bool use_signed = a_signed && b_signed;

		std::string op;
		if (cell->type == ID($add))
			op = "+";
		else if (cell->type == ID($sub))
			op = "-";
		else if (cell->type == ID($mul))
			op = "*";
		else if (cell->type == ID($div))
			op = "/";
		else if (cell->type == ID($mod))
			op = "mod";
		else
			op = "**";

		f << indent;
		dump_sigspec(f, cell->getPort(ID::Y));
		f << " <= " << arith_open(y_width);
		if (use_signed) {
			dump_sigspec_signed(f, cell->getPort(ID::A));
			f << " " << op << " ";
			dump_sigspec_signed(f, cell->getPort(ID::B));
		} else {
			dump_sigspec_unsigned(f, cell->getPort(ID::A));
			f << " " << op << " ";
			dump_sigspec_unsigned(f, cell->getPort(ID::B));
		}
		f << arith_close(y_width) << ";\n";
		return true;
	}

	// $divfloor / $modfloor -- for unsigned, same as $div/$mod
	if (cell->type.in(ID($divfloor), ID($modfloor))) {
		int y_width = cell->getParam(ID::Y_WIDTH).as_int();
		bool a_signed = cell->getParam(ID::A_SIGNED).as_bool();
		bool b_signed = cell->getParam(ID::B_SIGNED).as_bool();

		// For unsigned or same-sign: same as truncating
		std::string op = (cell->type == ID($divfloor)) ? "/" : "mod";

		f << indent << "-- " << (cell->type == ID($divfloor) ? "divfloor" : "modfloor") << "\n";
		f << indent;
		dump_sigspec(f, cell->getPort(ID::Y));
		f << " <= " << arith_open(y_width);
		if (a_signed && b_signed) {
			dump_sigspec_signed(f, cell->getPort(ID::A));
			f << " " << op << " ";
			dump_sigspec_signed(f, cell->getPort(ID::B));
		} else {
			dump_sigspec_unsigned(f, cell->getPort(ID::A));
			f << " " << op << " ";
			dump_sigspec_unsigned(f, cell->getPort(ID::B));
		}
		f << arith_close(y_width) << ";\n";
		return true;
	}

	// Shift operators: $shl, $shr, $sshl, $sshr
	if (cell->type.in(ID($shl), ID($shr), ID($sshl), ID($sshr))) {
		int y_width = cell->getParam(ID::Y_WIDTH).as_int();
		bool a_signed = cell->getParam(ID::A_SIGNED).as_bool();

		f << indent;
		dump_sigspec(f, cell->getPort(ID::Y));
		f << " <= std_logic_vector(resize(";

		if (cell->type.in(ID($shl), ID($sshl))) {
			f << "shift_left(";
		} else {
			f << "shift_right(";
		}

		if (a_signed && cell->type.in(ID($sshl), ID($sshr))) {
			f << "signed(";
			dump_sigspec(f, cell->getPort(ID::A));
			f << ")";
		} else {
			f << "unsigned(";
			dump_sigspec(f, cell->getPort(ID::A));
			f << ")";
		}
		f << ", to_integer(unsigned(";
		dump_sigspec(f, cell->getPort(ID::B));
		f << ")))";

		f << ", " << y_width << "))";
		if (y_width == 1)
			f << "(0)";
		f << ";\n";
		return true;
	}

	// $shift -- bidirectional shift (B can be signed -> negative means left)
	if (cell->type == ID($shift)) {
		int y_width = cell->getParam(ID::Y_WIDTH).as_int();
		bool b_signed = cell->getParam(ID::B_SIGNED).as_bool();

		f << indent << "-- $shift\n";
		f << indent;
		dump_sigspec(f, cell->getPort(ID::Y));
		f << " <= std_logic_vector(resize(";
		if (b_signed) {
			// When B is negative, shift left; when positive, shift right
			f << "shift_right(unsigned(";
			dump_sigspec(f, cell->getPort(ID::A));
			f << "), to_integer(signed(";
			dump_sigspec(f, cell->getPort(ID::B));
			f << ")))";
		} else {
			f << "shift_right(unsigned(";
			dump_sigspec(f, cell->getPort(ID::A));
			f << "), to_integer(unsigned(";
			dump_sigspec(f, cell->getPort(ID::B));
			f << ")))";
		}
		f << ", " << y_width << "))";
		if (y_width == 1)
			f << "(0)";
		f << ";\n";
		return true;
	}

	// $shiftx -- shift with undefined fill
	if (cell->type == ID($shiftx)) {
		int y_width = cell->getParam(ID::Y_WIDTH).as_int();
		// Same as $shift for VHDL output purposes
		f << indent << "-- $shiftx\n";
		f << indent;
		dump_sigspec(f, cell->getPort(ID::Y));
		f << " <= std_logic_vector(resize(shift_right(unsigned(";
		dump_sigspec(f, cell->getPort(ID::A));
		f << "), to_integer(unsigned(";
		dump_sigspec(f, cell->getPort(ID::B));
		f << "))), " << y_width << "))";
		if (y_width == 1)
			f << "(0)";
		f << ";\n";
		return true;
	}

	// Comparison operators: $lt, $le, $eq, $ne, $ge, $gt, $eqx, $nex
	if (cell->type.in(ID($lt), ID($le), ID($eq), ID($ne), ID($ge), ID($gt), ID($eqx), ID($nex))) {
		bool a_signed = cell->getParam(ID::A_SIGNED).as_bool();
		bool b_signed = cell->getParam(ID::B_SIGNED).as_bool();
		bool use_signed = a_signed && b_signed;

		std::string op;
		if (cell->type.in(ID($lt)))
			op = "<";
		else if (cell->type.in(ID($le)))
			op = "<=";
		else if (cell->type.in(ID($eq), ID($eqx)))
			op = "=";
		else if (cell->type.in(ID($ne), ID($nex)))
			op = "/=";
		else if (cell->type.in(ID($ge)))
			op = ">=";
		else
			op = ">";

		int a_width = cell->getParam(ID::A_WIDTH).as_int();
		int b_width = cell->getParam(ID::B_WIDTH).as_int();

		std::stringstream cond;
		if (a_width == 1 && b_width == 1 && cell->type.in(ID($eq), ID($eqx), ID($ne), ID($nex))) {
			// 1-bit equality/inequality: compare as std_logic directly
			dump_sigspec(cond, cell->getPort(ID::A));
			cond << " " << op << " ";
			dump_sigspec(cond, cell->getPort(ID::B));
		} else if (use_signed) {
			dump_sigspec_signed(cond, cell->getPort(ID::A));
			cond << " " << op << " ";
			dump_sigspec_signed(cond, cell->getPort(ID::B));
		} else {
			dump_sigspec_unsigned(cond, cell->getPort(ID::A));
			cond << " " << op << " ";
			dump_sigspec_unsigned(cond, cell->getPort(ID::B));
		}
		dump_bool_assign(f, indent, cell->getPort(ID::Y), cond.str());
		return true;
	}

	// $mux -- 2:1 multiplexer
	if (cell->type == ID($mux)) {
		f << indent;
		dump_sigspec(f, cell->getPort(ID::Y));
		f << " <= ";
		dump_sigspec(f, cell->getPort(ID::B));
		f << " when ";
		RTLIL::SigSpec s = cell->getPort(ID::S);
		if (GetSize(s) == 1) {
			dump_sigspec(f, s);
			f << " = '1'";
		} else {
			dump_sigspec(f, s);
			f << " /= " << vhdl_zero_const(GetSize(s));
		}
		f << " else ";
		dump_sigspec(f, cell->getPort(ID::A));
		f << ";\n";
		return true;
	}

	// $pmux -- priority multiplexer
	if (cell->type == ID($pmux)) {
		int width = cell->parameters[ID::WIDTH].as_int();
		int s_width = cell->getPort(ID::S).size();

		f << indent << "-- $pmux\n";
		f << indent;
		dump_sigspec(f, cell->getPort(ID::Y));
		f << " <= ";

		RTLIL::SigSpec b = cell->getPort(ID::B);
		RTLIL::SigSpec s = cell->getPort(ID::S);
		for (int i = s_width - 1; i >= 0; i--) {
			dump_sigspec(f, b.extract(i * width, width));
			f << " when ";
			dump_sigspec(f, s.extract(i, 1));
			f << " = '1' else\n" << indent << "    ";
		}
		dump_sigspec(f, cell->getPort(ID::A));
		f << ";\n";
		return true;
	}

	// $tribuf -- tri-state buffer
	if (cell->type == ID($tribuf)) {
		int width = cell->parameters.at(ID::WIDTH).as_int();
		f << indent;
		dump_sigspec(f, cell->getPort(ID::Y));
		f << " <= ";
		dump_sigspec(f, cell->getPort(ID::A));
		f << " when ";
		dump_sigspec(f, cell->getPort(ID::EN));
		f << " = '1' else ";
		if (width == 1)
			f << "'Z'";
		else
			f << "(others => 'Z')";
		f << ";\n";
		return true;
	}

	// $slice -- extract bit range
	if (cell->type == ID($slice)) {
		int offset = cell->parameters.at(ID::OFFSET).as_int();
		int y_width = GetSize(cell->getPort(ID::Y));
		f << indent;
		dump_sigspec(f, cell->getPort(ID::Y));
		f << " <= ";
		dump_sigspec(f, cell->getPort(ID::A));
		if (y_width == 1)
			f << "(" << offset << ")";
		else
			f << "(" << (offset + y_width - 1) << " downto " << offset << ")";
		f << ";\n";
		return true;
	}

	// $concat -- bit concatenation
	if (cell->type == ID($concat)) {
		f << indent;
		dump_sigspec(f, cell->getPort(ID::Y));
		f << " <= ";
		dump_sigspec(f, cell->getPort(ID::B));
		f << " & ";
		dump_sigspec(f, cell->getPort(ID::A));
		f << ";\n";
		return true;
	}

	// $lut -- lookup table
	if (cell->type == ID($lut)) {
		// Implement as a case-like concurrent select
		int lut_width = GetSize(cell->getPort(ID::A));
		RTLIL::Const lut = cell->parameters.at(ID::LUT);
		f << indent << "-- $lut\n";
		f << indent;
		dump_sigspec(f, cell->getPort(ID::Y));
		f << " <= ";

		// Output the LUT as a nested when/else chain
		for (int i = (1 << lut_width) - 1; i >= 0; i--) {
			if (i < (int)lut.size() && lut[i] == State::S1)
				f << "'1'";
			else
				f << "'0'";
			if (i > 0) {
				f << " when unsigned(";
				dump_sigspec(f, cell->getPort(ID::A));
				f << ") = " << i << " else\n" << indent << "    ";
			}
		}
		f << ";\n";
		return true;
	}

	// $input_port -- skip
	if (cell->type == ID($input_port))
		return true;

	// Flip-flops and latches via FfData abstraction
	if (cell->is_builtin_ff()) {
		FfData ff(&active_initvals, cell);

		// $ff / $_FF_ (global clock): not directly representable in VHDL
		if (ff.has_gclk)
			return false;

		std::string sig_name = next_auto_id();

		// Collect signal declaration with optional init value
		// Check if the FF Q output wire has init data
		std::string init_str;
		if (!ff.val_init.is_fully_undef()) {
			std::stringstream init_ss;
			dump_const(init_ss, ff.val_init, ff.width, 0);
			init_str = " := " + init_ss.str();
		}
		if (ff.width == 1)
			aux_signal_decls.push_back(stringf("signal %s : std_logic%s;", sig_name.c_str(), init_str.c_str()));
		else
			aux_signal_decls.push_back(
			  stringf("signal %s : std_logic_vector(%d downto 0)%s;", sig_name.c_str(), ff.width - 1, init_str.c_str()));

		f << indent << "-- FF " << id(cell->name) << "\n";

		// For SR cells, we need per-bit processes
		int chunks = ff.has_sr ? ff.width : 1;
		bool chunky = ff.has_sr && ff.width != 1;

		for (int i = 0; i < chunks; i++) {
			SigSpec sig_d, sig_ad;
			Const val_arst, val_srst;
			std::string reg_bit;

			if (chunky) {
				reg_bit = stringf("%s(%d)", sig_name.c_str(), i);
				if (ff.has_clk)
					sig_d = ff.sig_d[i];
				if (ff.has_aload)
					sig_ad = ff.sig_ad[i];
			} else {
				reg_bit = sig_name;
				sig_d = ff.sig_d;
				sig_ad = ff.sig_ad;
			}
			if (ff.has_arst)
				val_arst = chunky ? ff.val_arst[i] : ff.val_arst;
			if (ff.has_srst)
				val_srst = chunky ? ff.val_srst[i] : ff.val_srst;

			dump_attributes(f, indent, cell->attributes);

			if (ff.has_clk) {
				// === Clocked flip-flops ===
				// Build sensitivity list
				f << indent << "process(";
				dump_sigspec(f, ff.sig_clk);
				if (ff.has_sr) {
					f << ", ";
					dump_sigspec(f, ff.sig_set[chunky ? i : 0]);
					f << ", ";
					dump_sigspec(f, ff.sig_clr[chunky ? i : 0]);
				} else if (ff.has_arst) {
					f << ", ";
					dump_sigspec(f, ff.sig_arst);
				} else if (ff.has_aload) {
					f << ", ";
					dump_sigspec(f, ff.sig_aload);
				}
				f << ")\n";
				f << indent << "begin\n";

				// Async conditions first (outermost if)
				std::string inner_indent = indent + "  ";
				if (ff.has_sr) {
					f << inner_indent << "if ";
					dump_sigspec(f, ff.sig_clr[chunky ? i : 0]);
					f << " = '" << (ff.pol_clr ? "1" : "0") << "' then\n";
					f << inner_indent << "  " << reg_bit << " <= '0';\n";
					f << inner_indent << "elsif ";
					dump_sigspec(f, ff.sig_set[chunky ? i : 0]);
					f << " = '" << (ff.pol_set ? "1" : "0") << "' then\n";
					f << inner_indent << "  " << reg_bit << " <= '1';\n";
					f << inner_indent << "els";
				} else if (ff.has_arst) {
					f << inner_indent << "if ";
					dump_sigspec(f, ff.sig_arst);
					f << " = '" << (ff.pol_arst ? "1" : "0") << "' then\n";
					f << inner_indent << "  " << reg_bit << " <= ";
					dump_const(f, val_arst);
					f << ";\n";
					f << inner_indent << "els";
				} else if (ff.has_aload) {
					f << inner_indent << "if ";
					dump_sigspec(f, ff.sig_aload);
					f << " = '" << (ff.pol_aload ? "1" : "0") << "' then\n";
					f << inner_indent << "  " << reg_bit << " <= ";
					dump_sigspec(f, sig_ad);
					f << ";\n";
					f << inner_indent << "els";
				}

				// Clock edge
				if (!ff.has_sr && !ff.has_arst && !ff.has_aload)
					f << inner_indent;
				f << "if " << (ff.pol_clk ? "rising" : "falling") << "_edge(";
				dump_sigspec(f, ff.sig_clk);
				f << ") then\n";

				std::string clk_indent = inner_indent + "  ";

				// Sync reset + clock enable logic
				if (ff.has_srst && ff.has_ce && ff.ce_over_srst) {
					f << clk_indent << "if ";
					dump_sigspec(f, ff.sig_ce);
					f << " = '" << (ff.pol_ce ? "1" : "0") << "' then\n";
					f << clk_indent << "  if ";
					dump_sigspec(f, ff.sig_srst);
					f << " = '" << (ff.pol_srst ? "1" : "0") << "' then\n";
					f << clk_indent << "    " << reg_bit << " <= ";
					dump_const(f, val_srst);
					f << ";\n";
					f << clk_indent << "  else\n";
					f << clk_indent << "    " << reg_bit << " <= ";
					dump_sigspec(f, sig_d);
					f << ";\n";
					f << clk_indent << "  end if;\n";
					f << clk_indent << "end if;\n";
				} else {
					if (ff.has_srst) {
						f << clk_indent << "if ";
						dump_sigspec(f, ff.sig_srst);
						f << " = '" << (ff.pol_srst ? "1" : "0") << "' then\n";
						f << clk_indent << "  " << reg_bit << " <= ";
						dump_const(f, val_srst);
						f << ";\n";
						if (ff.has_ce)
							f << clk_indent << "els";
						else
							f << clk_indent << "else\n";
					}
					if (ff.has_ce) {
						if (!ff.has_srst)
							f << clk_indent;
						f << "if ";
						dump_sigspec(f, ff.sig_ce);
						f << " = '" << (ff.pol_ce ? "1" : "0") << "' then\n";
						f << clk_indent << "  " << reg_bit << " <= ";
						dump_sigspec(f, sig_d);
						f << ";\n";
						f << clk_indent << "end if;\n";
					} else {
						if (ff.has_srst) {
							f << clk_indent << "  " << reg_bit << " <= ";
						} else {
							f << clk_indent << reg_bit << " <= ";
						}
						dump_sigspec(f, sig_d);
						f << ";\n";
						if (ff.has_srst)
							f << clk_indent << "end if;\n";
					}
				}

				f << inner_indent << "end if;\n";
				f << indent << "end process;\n";
			} else {
				// === Latches ===
				std::vector<RTLIL::SigSpec> latch_sens;
				if (ff.has_sr) {
					latch_sens.push_back(chunky ? SigSpec(ff.sig_set[i]) : ff.sig_set);
					latch_sens.push_back(chunky ? SigSpec(ff.sig_clr[i]) : ff.sig_clr);
				}
				if (ff.has_arst)
					latch_sens.push_back(ff.sig_arst);
				if (ff.has_aload) {
					latch_sens.push_back(ff.sig_aload);
					latch_sens.push_back(sig_ad);
				}
				dump_process_sens(f, indent, latch_sens);
				f << indent << "begin\n";

				std::string inner_indent = indent + "  ";

				if (ff.has_sr) {
					f << inner_indent << "if ";
					dump_sigspec(f, ff.sig_clr[chunky ? i : 0]);
					f << " = '" << (ff.pol_clr ? "1" : "0") << "' then\n";
					f << inner_indent << "  " << reg_bit << " <= '0';\n";
					f << inner_indent << "elsif ";
					dump_sigspec(f, ff.sig_set[chunky ? i : 0]);
					f << " = '" << (ff.pol_set ? "1" : "0") << "' then\n";
					f << inner_indent << "  " << reg_bit << " <= '1';\n";
					if (ff.has_aload) {
						f << inner_indent << "els";
					} else {
						f << inner_indent << "end if;\n";
					}
				} else if (ff.has_arst) {
					f << inner_indent << "if ";
					dump_sigspec(f, ff.sig_arst);
					f << " = '" << (ff.pol_arst ? "1" : "0") << "' then\n";
					f << inner_indent << "  " << reg_bit << " <= ";
					dump_const(f, val_arst);
					f << ";\n";
					if (ff.has_aload) {
						f << inner_indent << "els";
					} else {
						f << inner_indent << "end if;\n";
					}
				}
				if (ff.has_aload) {
					if (!ff.has_sr && !ff.has_arst)
						f << inner_indent;
					f << "if ";
					dump_sigspec(f, ff.sig_aload);
					f << " = '" << (ff.pol_aload ? "1" : "0") << "' then\n";
					f << inner_indent << "  " << reg_bit << " <= ";
					dump_sigspec(f, sig_ad);
					f << ";\n";
					f << inner_indent << "end if;\n";
				}

				f << indent << "end process;\n";
			}
		}

		// Connect FF output to the actual output signal
		dump_expr_assign(f, indent, ff.sig_q, sig_name);

		return true;
	}

	// $assert, $assume, $cover -- formal verification
	if (cell->type.in(ID($assert), ID($assume), ID($cover))) {
		// VHDL-2008: assert, report, severity
		// $assert -> assert A when EN
		// $assume -> treated as assert (VHDL has no assume)
		// $cover  -> treated as comment (no direct equivalent)
		if (cell->type == ID($cover)) {
			f << indent << "-- cover point (not representable in synthesizable VHDL)\n";
			return true;
		}

		f << indent << "-- " << cell->type.c_str() + 1 << "\n";
		dump_process_sens(f, indent, {cell->getPort(ID::EN), cell->getPort(ID::A)});
		f << indent << "begin\n";
		f << indent << "  if ";
		dump_sigspec(f, cell->getPort(ID::EN));
		if (GetSize(cell->getPort(ID::EN)) == 1)
			f << " = '1'";
		else
			f << " /= " << vhdl_zero_const(GetSize(cell->getPort(ID::EN)));
		f << " then\n";
		f << indent << "    assert ";
		dump_sigspec(f, cell->getPort(ID::A));
		if (GetSize(cell->getPort(ID::A)) == 1)
			f << " = '1'";
		else
			f << " /= " << vhdl_zero_const(GetSize(cell->getPort(ID::A)));
		f << "\n";
		f << indent << "      report \"" << cell->type.c_str() + 1 << " failed\"\n";
		f << indent << "      severity ";
		if (cell->type == ID($assert))
			f << "failure";
		else
			f << "warning";
		f << ";\n";
		f << indent << "  end if;\n";
		f << indent << "end process;\n";
		return true;
	}

	// $specify2, $specify3, $specrule -- timing specifications
	// No VHDL equivalent; emit as comments
	if (cell->type.in(ID($specify2), ID($specify3), ID($specrule))) {
		f << indent << "-- specify cell " << id(cell->name) << " (";
		f << cell->type.c_str() + 1 << ", no VHDL equivalent)\n";
		return true;
	}

	// $print -- display/write statement
	if (cell->type == ID($print)) {
		// Sync $print cells would need trigger handling; for now emit as comment
		if (cell->getParam(ID::TRG_ENABLE).as_bool()) {
			f << indent << "-- sync $print (trigger-based, skipped)\n";
			return true;
		}

		f << indent << "-- $print\n";
		dump_process_sens(f, indent, {cell->getPort(ID::EN)});
		f << indent << "begin\n";
		f << indent << "  if ";
		dump_sigspec(f, cell->getPort(ID::EN));
		if (GetSize(cell->getPort(ID::EN)) == 1)
			f << " = '1'";
		else
			f << " /= " << vhdl_zero_const(GetSize(cell->getPort(ID::EN)));
		f << " then\n";
		f << indent << "    report \"$print\";\n";
		f << indent << "  end if;\n";
		f << indent << "end process;\n";
		return true;
	}

	// $check -- check statement (similar to assert but with flavors)
	if (cell->type == ID($check)) {
		if (cell->getParam(ID::TRG_ENABLE).as_bool()) {
			f << indent << "-- sync $check (trigger-based, skipped)\n";
			return true;
		}

		std::string flavor = cell->getParam(ID::FLAVOR).decode_string();
		f << indent << "-- $check (" << flavor << ")\n";
		dump_process_sens(f, indent, {cell->getPort(ID::EN), cell->getPort(ID::A)});
		f << indent << "begin\n";
		f << indent << "  if ";
		dump_sigspec(f, cell->getPort(ID::EN));
		if (GetSize(cell->getPort(ID::EN)) == 1)
			f << " = '1'";
		else
			f << " /= " << vhdl_zero_const(GetSize(cell->getPort(ID::EN)));
		f << " then\n";
		f << indent << "    assert ";
		dump_sigspec(f, cell->getPort(ID::A));
		if (GetSize(cell->getPort(ID::A)) == 1)
			f << " = '1'";
		else
			f << " /= " << vhdl_zero_const(GetSize(cell->getPort(ID::A)));
		f << "\n";
		f << indent << "      report \"" << flavor << " failed\"\n";
		f << indent << "      severity ";
		if (flavor == "assert")
			f << "failure";
		else
			f << "warning";
		f << ";\n";
		f << indent << "  end if;\n";
		f << indent << "end process;\n";
		return true;
	}

	// $connect -- bidirectional connection (tran gate)
	if (cell->type == ID($connect)) {
		f << indent << "-- bidirectional connection (no direct VHDL equivalent)\n";
		f << indent;
		dump_sigspec(f, cell->getPort(ID::A));
		f << " <= ";
		dump_sigspec(f, cell->getPort(ID::B));
		f << ";\n";
		return true;
	}

	// FIXME: $fsm
	return false;
}

// Memory type and signal declarations (for the declarative region)
std::vector<std::string> mem_type_decls;

void dump_memory(std::ostream &f, std::string indent, Mem &mem)
{
	// Use auto-generated names to avoid issues with internal RTLIL names
	// containing characters that break VHDL extended identifiers
	std::string mem_id = next_auto_id();
	std::string type_name = mem_id + "_type";

	// Type and signal declaration (collected for the declarative region)
	mem_type_decls.push_back(
	  stringf("type %s is array(0 to %d) of std_logic_vector(%d downto 0);", type_name.c_str(), mem.size - 1, mem.width - 1));

	// Init data
	bool has_init = false;
	for (auto &init : mem.inits)
		if (GetSize(init.data) > 0)
			has_init = true;

	if (has_init) {
		// Build aggregate initializer
		Const init_data = mem.get_init_data();
		std::string init_str = "(";
		for (int i = 0; i < mem.size; i++) {
			if (i > 0)
				init_str += ", ";
			if (i > 0 && (i % 4) == 0)
				init_str += "\n" + indent + "    ";
			init_str += "\"";
			for (int j = mem.width - 1; j >= 0; j--) {
				int bit = i * mem.width + j;
				if (bit < GetSize(init_data)) {
					switch (init_data[bit]) {
					case State::S0:
						init_str += "0";
						break;
					case State::S1:
						init_str += "1";
						break;
					default:
						init_str += "0";
						break;
					}
				} else {
					init_str += "0";
				}
			}
			init_str += "\"";
		}
		init_str += ")";
		mem_type_decls.push_back(stringf("signal %s : %s := %s;", mem_id.c_str(), type_name.c_str(), init_str.c_str()));
	} else {
		mem_type_decls.push_back(stringf("signal %s : %s;", mem_id.c_str(), type_name.c_str()));
	}

	// Read ports
	for (int pidx = 0; pidx < GetSize(mem.rd_ports); pidx++) {
		auto &port = mem.rd_ports[pidx];

		if (!port.clk_enable) {
			// Async read -- concurrent assignment
			int num_sub = 1 << port.wide_log2;
			for (int sub = 0; sub < num_sub; sub++) {
				SigSpec addr = port.sub_addr(sub);
				SigSpec data = port.data.extract(sub * mem.width, mem.width);
				f << indent;
				dump_sigspec(f, data);
				f << " <= " << mem_id << "(to_integer(unsigned(";
				dump_sigspec(f, addr);
				f << ")));\n";
			}
		} else {
			// Sync read -- clocked process
			std::string temp_name = next_auto_id();
			aux_signal_decls.push_back(stringf("signal %s : std_logic_vector(%d downto 0);", temp_name.c_str(), mem.width - 1));

			f << indent << "process(";
			dump_sigspec(f, port.clk);
			f << ")\n";
			f << indent << "begin\n";
			f << indent << "  if " << (port.clk_polarity ? "rising" : "falling") << "_edge(";
			dump_sigspec(f, port.clk);
			f << ") then\n";

			int num_sub = 1 << port.wide_log2;
			for (int sub = 0; sub < num_sub; sub++) {
				SigSpec addr = port.sub_addr(sub);
				std::string indent3 = indent + "    ";

				// Enable check
				bool has_en = port.en != State::S1;
				if (has_en) {
					f << indent3 << "if ";
					dump_sigspec(f, port.en);
					f << " = '1' then\n";
					indent3 += "  ";
				}

				f << indent3 << temp_name << " <= " << mem_id << "(to_integer(unsigned(";
				dump_sigspec(f, addr);
				f << ")));\n";

				if (has_en)
					f << indent << "    end if;\n";
			}

			f << indent << "  end if;\n";
			f << indent << "end process;\n";

			// Connect temp to actual read data output
			f << indent;
			dump_sigspec(f, port.data);
			f << " <= " << temp_name << ";\n";
		}
	}

	// Write ports
	for (int pidx = 0; pidx < GetSize(mem.wr_ports); pidx++) {
		auto &port = mem.wr_ports[pidx];

		if (!port.clk_enable) {
			// Unclocked write (latch-like) -- unusual
			f << indent << "-- unclocked write port (latch)\n";
			dump_process_sens(f, indent, {port.en, port.data, port.addr});
		} else {
			f << indent << "process(";
			dump_sigspec(f, port.clk);
			f << ")\n";
		}
		f << indent << "begin\n";

		if (port.clk_enable) {
			f << indent << "  if " << (port.clk_polarity ? "rising" : "falling") << "_edge(";
			dump_sigspec(f, port.clk);
			f << ") then\n";
		}

		std::string wr_indent = port.clk_enable ? indent + "    " : indent + "  ";

		int num_sub = 1 << port.wide_log2;
		for (int sub = 0; sub < num_sub; sub++) {
			SigSpec addr = port.sub_addr(sub);
			SigSpec data = port.data.extract(sub * mem.width, mem.width);
			SigSpec en = port.en.extract(sub * mem.width, mem.width);

			// Group consecutive bits by enable signal
			int bit = 0;
			while (bit < mem.width) {
				SigBit en_bit = en[bit];
				int start = bit;

				// Find run of bits with same enable
				while (bit < mem.width && en[bit] == en_bit)
					bit++;

				// Skip bits that are never written
				if (en_bit == State::S0)
					continue;

				bool need_if = (en_bit != State::S1);
				std::string assign_indent = wr_indent;

				if (need_if) {
					f << wr_indent << "if ";
					dump_sigspec(f, en_bit);
					f << " = '1' then\n";
					assign_indent += "  ";
				}

				if (start == 0 && bit == mem.width) {
					// Full word write
					f << assign_indent << mem_id << "(to_integer(unsigned(";
					dump_sigspec(f, addr);
					f << "))) <= ";
					dump_sigspec(f, data);
					f << ";\n";
				} else {
					// Partial word write
					f << assign_indent << mem_id << "(to_integer(unsigned(";
					dump_sigspec(f, addr);
					f << ")))(" << (bit - 1) << " downto " << start << ") <= ";
					dump_sigspec(f, data.extract(start, bit - start));
					f << ";\n";
				}

				if (need_if)
					f << wr_indent << "end if;\n";
			}
		}

		if (port.clk_enable)
			f << indent << "  end if;\n";

		f << indent << "end process;\n";
	}
}

void dump_cell(std::ostream &f, std::string indent, RTLIL::Cell *cell)
{
	// Skip $scopeinfo cells
	if (cell->type == ID($scopeinfo))
		return;

	// Memory cells handled by dump_memory
	if (cell->is_mem_cell())
		return;

	// Try to express as concurrent VHDL
	if (cell->type[0] == '$' && !noexpr) {
		// If Y port is multi-chunk, we need to redirect output to a temp signal
		// because VHDL doesn't allow concatenation on LHS of assignment.
		RTLIL::SigSpec orig_y;
		bool y_needs_split = cell->hasPort(ID::Y) && !cell->getPort(ID::Y).is_chunk() && cell->getPort(ID::Y).size() > 0;

		if (y_needs_split) {
			orig_y = cell->getPort(ID::Y);
			int width = orig_y.size();
			std::string y_tmp = next_auto_id();
			aux_signal_decls.push_back(stringf("signal %s : %s;", y_tmp.c_str(), vhdl_type_str(width).c_str()));

			// Create a temporary wire to hold the Y output
			RTLIL::Wire *tmp_wire = active_module->addWire(RTLIL::IdString("\\" + y_tmp), width);
			cell->setPort(ID::Y, RTLIL::SigSpec(tmp_wire));

			if (dump_cell_expr(f, indent, cell)) {
				// Restore original Y and emit split assignments
				cell->setPort(ID::Y, orig_y);
				int offset = 0;
				for (auto &chunk : orig_y.chunks()) {
					f << indent;
					dump_sigchunk(f, chunk);
					f << " <= ";
					if (chunk.width == width) {
						f << y_tmp;
					} else if (chunk.width == 1) {
						f << y_tmp << "(" << offset << ")";
					} else {
						f << y_tmp << "(" << (offset + chunk.width - 1) << " downto " << offset << ")";
					}
					f << ";\n";
					offset += chunk.width;
				}
				return;
			}
			// Didn't handle -- restore Y and fall through to generic instantiation
			cell->setPort(ID::Y, orig_y);
		} else {
			if (dump_cell_expr(f, indent, cell))
				return;
		}
	}

	// Generic cell instantiation (component instantiation in VHDL)
	std::string cell_type_str = id(cell->type, false);
	std::string inst_name = id(cell->name);

	// Port map intermediates
	// In VHDL-93, port actuals must be signal names (not arbitrary expressions like concatenation).
	// If a port connects to a multi-chunk sigspec, we need an intermediate signal.
	// For outputs: assign intermediate -> chunks after instantiation.
	// For inputs: assign chunks -> intermediate before instantiation.

	// Determine port directions from the sub-module if available
	RTLIL::Module *sub_mod = active_module ? active_module->design->module(cell->type) : nullptr;

	std::vector<std::pair<std::string, std::pair<RTLIL::SigSpec, bool>>> port_intermediates;
	// port_intermediates: { tmp_name, { sigspec, is_output } }

	for (auto it = cell->connections().begin(); it != cell->connections().end(); ++it) {
		if (it->second.size() == 0 || it->second.is_chunk())
			continue;

		bool is_output = false;
		bool is_input = false;
		if (sub_mod) {
			RTLIL::Wire *w = sub_mod->wire(it->first);
			if (w) {
				if (w->port_output)
					is_output = true;
				if (w->port_input)
					is_input = true;
			}
		} else {
			// No sub-module info: assume input
			is_input = true;
		}

		if (is_output || is_input) {
			std::string tmp = next_auto_id();
			int width = it->second.size();
			aux_signal_decls.push_back(stringf("signal %s : %s;", tmp.c_str(), vhdl_type_str(width).c_str()));
			port_intermediates.push_back({tmp, {it->second, is_output}});
		}
	}

	// Pre-instantiation: drive intermediate signals for multi-chunk input ports
	for (auto &pi : port_intermediates) {
		if (pi.second.second) // skip outputs, handled post-instantiation
			continue;
		auto &sig = pi.second.first;
		f << indent << pi.first << " <= ";
		dump_sigspec(f, sig);
		f << ";\n";
	}

	// Build a lookup from sigspec identity to intermediate signal name
	dict<RTLIL::SigSpec, std::string> port_tmp_map;
	for (auto &pi : port_intermediates)
		port_tmp_map[pi.second.first] = pi.first;

	dump_attributes(f, indent, cell->attributes);

	f << indent << inst_name << " : " << cell_type_str << "\n";

	// Generic map (parameters)
	if (!cell->parameters.empty()) {
		f << indent << "  generic map (\n";
		bool first = true;
		for (auto it = cell->parameters.begin(); it != cell->parameters.end(); ++it) {
			if (!first)
				f << ",\n";
			first = false;
			f << indent << "    " << id(it->first) << " => ";
			if ((it->second.flags & RTLIL::CONST_FLAG_STRING) != 0) {
				// String parameter -- emit as VHDL string
				dump_const(f, it->second);
			} else if (GetSize(it->second) <= 32 && (it->second.flags & RTLIL::CONST_FLAG_REAL) == 0) {
				// Small constant -- emit as integer
				if (it->second.flags & RTLIL::CONST_FLAG_SIGNED)
					f << it->second.as_int();
				else
					f << (uint32_t)it->second.as_int();
			} else {
				dump_const(f, it->second);
			}
		}
		f << "\n" << indent << "  )\n";
	}

	f << indent << "  port map (\n";
	bool first = true;
	for (auto it = cell->connections().begin(); it != cell->connections().end(); ++it) {
		if (!first)
			f << ",\n";
		first = false;
		f << indent << "    " << id(it->first) << " => ";
		if (it->second.size() == 0) {
			f << "open";
			continue;
		}

		// Use intermediate signal if we created one
		if (port_tmp_map.count(it->second)) {
			f << port_tmp_map[it->second];
		} else {
			dump_sigspec(f, it->second);
		}
	}
	f << "\n" << indent << "  );\n";

	// Post-instantiation: split intermediate signals for multi-chunk output ports
	for (auto &pi : port_intermediates) {
		if (!pi.second.second) // skip inputs, handled pre-instantiation
			continue;
		auto &sig = pi.second.first;
		int offset = 0;
		for (auto &chunk : sig.chunks()) {
			f << indent;
			dump_sigchunk(f, chunk);
			f << " <= ";
			if (chunk.width == sig.size()) {
				f << pi.first;
			} else if (chunk.width == 1) {
				f << pi.first << "(" << offset << ")";
			} else {
				f << pi.first << "(" << (offset + chunk.width - 1) << " downto " << offset << ")";
			}
			f << ";\n";
			offset += chunk.width;
		}
	}
}

// Emit concurrent signal assignment(s) for an RTLIL connection.
// Multi-chunk LHS is split into one assignment per chunk.
// Self-assignments (same VHDL name on both sides) are suppressed; they arise
// on VHDL round-trips when shadow signals coincide with existing wire names.
void dump_conn(std::ostream &f, std::string indent, const RTLIL::SigSpec &left, const RTLIL::SigSpec &right)
{
	if (!left.is_chunk()) {
		int offset = 0;
		for (auto &chunk : left.chunks()) {
			std::stringstream lhs_ss, rhs_ss;
			dump_sigchunk(lhs_ss, chunk);
			dump_sigspec(rhs_ss, right.extract(offset, chunk.width));
			// Skip self-assignments (can arise on VHDL round-trips when shadow
			// signals coincide with existing wires of the same VHDL name).
			if (lhs_ss.str() != rhs_ss.str()) {
				f << indent << lhs_ss.str() << " <= " << rhs_ss.str() << ";\n";
			}
			offset += chunk.width;
		}
		return;
	}
	std::stringstream lhs_ss, rhs_ss;
	dump_sigspec(lhs_ss, left);
	dump_sigspec(rhs_ss, right);
	if (lhs_ss.str() == rhs_ss.str())
		return; // skip self-assignment
	f << indent << lhs_ss.str() << " <= " << rhs_ss.str() << ";\n";
}

// Assign an expression string to a potentially multi-chunk sigspec.
// Creates an intermediate signal if the target is multi-chunk.
void dump_expr_assign(std::ostream &f, std::string indent, const RTLIL::SigSpec &left, const std::string &expr)
{
	if (!left.is_chunk()) {
		// Multi-chunk target: need intermediate signal
		std::string tmp = next_auto_id();
		int width = left.size();
		aux_signal_decls.push_back(stringf("signal %s : %s;", tmp.c_str(), vhdl_type_str(width).c_str()));
		f << indent << tmp << " <= " << expr << ";\n";
		// Split into per-chunk assignments
		int offset = 0;
		for (auto &chunk : left.chunks()) {
			f << indent;
			dump_sigchunk(f, chunk);
			f << " <= ";
			if (chunk.width == width) {
				f << tmp;
			} else if (chunk.width == 1) {
				f << tmp << "(" << offset << ")";
			} else {
				f << tmp << "(" << (offset + chunk.width - 1) << " downto " << offset << ")";
			}
			f << ";\n";
			offset += chunk.width;
		}
		return;
	}
	f << indent;
	dump_sigspec(f, left);
	f << " <= " << expr << ";\n";
}

// Collect component declarations needed for non-internal cell types
void collect_components(std::ostream &f, std::string indent, RTLIL::Module *module, RTLIL::Design *design)
{
	pool<RTLIL::IdString> seen;
	// Build a map from cell type -> first cell instance (for inferring param types)
	dict<RTLIL::IdString, RTLIL::Cell *> type_to_cell;
	for (auto cell : module->cells()) {
		if (cell->type[0] == '$')
			continue;
		if (!type_to_cell.count(cell->type))
			type_to_cell[cell->type] = cell;
	}
	for (auto cell : module->cells()) {
		if (cell->type[0] == '$')
			continue;
		if (seen.count(cell->type))
			continue;
		seen.insert(cell->type);

		// Look up the module to get its port info
		RTLIL::Module *mod = design->module(cell->type);
		if (!mod)
			continue;

		f << indent << "component " << id(cell->type, false) << " is\n";

		// Generics (from avail_parameters)
		// Infer types from actual parameter values on first cell instance
		if (!mod->avail_parameters.empty()) {
			RTLIL::Cell *sample = type_to_cell.count(cell->type) ? type_to_cell[cell->type] : nullptr;
			f << indent << "  generic (\n";
			bool gfirst = true;
			for (auto &param_name : mod->avail_parameters) {
				if (!gfirst)
					f << ";\n";
				gfirst = false;
				std::string type_str = "integer";
				if (sample && sample->parameters.count(param_name)) {
					auto &val = sample->parameters.at(param_name);
					if ((val.flags & RTLIL::CONST_FLAG_STRING) != 0)
						type_str = "string";
				}
				f << indent << "    " << id(param_name) << " : " << type_str;
			}
			f << "\n" << indent << "  );\n";
		}

		// Ports
		std::vector<RTLIL::Wire *> ports;
		for (auto port_name : mod->ports) {
			RTLIL::Wire *w = mod->wire(port_name);
			if (w)
				ports.push_back(w);
		}

		if (!ports.empty()) {
			f << indent << "  port (\n";
			for (size_t i = 0; i < ports.size(); i++) {
				auto w = ports[i];
				f << indent << "    " << id(w->name) << " : ";
				if (w->port_input && !w->port_output)
					f << "in ";
				else if (!w->port_input && w->port_output)
					f << "out ";
				else
					f << "inout ";
				f << vhdl_type_str(w->width);
				if (i + 1 < ports.size())
					f << ";";
				f << "\n";
			}
			f << indent << "  );\n";
		}

		f << indent << "end component;\n\n";
	}
}

// Compute the canonical VHDL identifier string for an RTLIL name without
// consulting auto_name_map (used during the collision-detection pass before
// auto_name_map is finalised).
std::string vhdl_id_raw(RTLIL::IdString internal_id)
{
	const char *str = internal_id.c_str();
	if (*str == '\\')
		str++;
	std::string result = str;
	/* Clean \X\ extended identifier body: decode to \X\ */
	if (is_clean_extended_id_body(result.c_str()))
		return "\\" + result.substr(1, result.size() - 2) + "\\";
	// Generic escaping
	bool needs_escape = false;
	if (result.empty() || (result[0] >= '0' && result[0] <= '9'))
		needs_escape = true;
	if (!result.empty() && (result[0] == '_' || result.back() == '_'))
		needs_escape = true;
	if (result.find("__") != std::string::npos)
		needs_escape = true;
	for (size_t i = 0; i < result.size() && !needs_escape; i++)
		if (char_needs_vhdl_escape(result[i]))
			needs_escape = true;
	if (VHDL_BACKEND::id_is_vhdl_reserved(result))
		needs_escape = true;
	if (needs_escape)
		return "\\" + result + "\\";
	return result;
}

void dump_module(std::ostream &f, std::string indent, RTLIL::Module *module, RTLIL::Design *design)
{
	reg_wires.clear();
	reset_auto_counter(module);

	// Collision detection: two different RTLIL wire/cell names can produce the
	// same VHDL identifier after escaping (e.g. \cpu1:415 escapes to \cpu1:415\
	// and \\cpu1:415\\ decodes to \cpu1:415\ as well).  Build a set of already-
	// seen VHDL names and force any collision into auto_name_map for renaming.
	// VHDL identifiers are case-insensitive so we compare lower-cased forms.
	if (!norename) {
		dict<std::string, RTLIL::IdString> seen_vhdl;
		// Check wires first (order: same as module->wires() iteration)
		for (auto w : module->wires()) {
			if (auto_name_map.count(w->name))
				continue;
			std::string vn = vhdl_id_raw(w->name);
			std::string vnlc = vn;
			std::transform(vnlc.begin(), vnlc.end(), vnlc.begin(), ::tolower);
			if (seen_vhdl.count(vnlc)) {
				auto_name_map[w->name] = auto_name_counter++;
			} else {
				seen_vhdl[vnlc] = w->name;
			}
		}
		// Recompute digits now that map may have grown
		auto_name_digits = 1;
		for (size_t i = 10; i < auto_name_offset + auto_name_map.size(); i = i * 10)
			auto_name_digits++;
	}

	active_module = module;
	active_sigmap.set(module);
	active_initvals.set(&active_sigmap, module);
	active_initdata.clear();

	for (auto wire : module->wires())
		if (wire->attributes.count(ID::init)) {
			SigSpec sig = active_sigmap(wire);
			Const val = wire->attributes.at(ID::init);
			for (int i = 0; i < GetSize(sig) && i < GetSize(val); i++)
				if (val[i] == State::S0 || val[i] == State::S1)
					active_initdata[sig[i]] = val[i];
		}

	// Detect reg wires (driven by FFs)
	if (!noexpr) {
		std::set<std::pair<RTLIL::Wire *, int>> reg_bits;
		for (auto cell : module->cells()) {
			if (!cell->is_builtin_ff() || !cell->hasPort(ID::Q) || cell->type.in(ID($ff), ID($_FF_)))
				continue;
			RTLIL::SigSpec sig = cell->getPort(ID::Q);
			if (sig.is_chunk()) {
				RTLIL::SigChunk chunk = sig.as_chunk();
				if (chunk.wire != NULL)
					for (int i = 0; i < chunk.width; i++)
						reg_bits.insert(std::pair<RTLIL::Wire *, int>(chunk.wire, chunk.offset + i));
			}
		}
		for (auto wire : module->wires()) {
			for (int i = 0; i < wire->width; i++)
				if (reg_bits.count(std::pair<RTLIL::Wire *, int>(wire, i)) == 0)
					goto this_wire_aint_reg;
			if (wire->width)
				reg_wires.insert(wire->name);
		this_wire_aint_reg:;
		}
	}

	// VHDL-93: detect output ports that are read internally (illegal in VHDL-93).
	// Create shadow signals for them.
	outport_shadows.clear();
	if (vhdl_std < 2008) {
		// Collect all output port wires
		pool<RTLIL::Wire *> output_ports;
		for (auto port_name : module->ports) {
			RTLIL::Wire *w = module->wire(port_name);
			if (w && w->port_output && !w->port_input)
				output_ports.insert(w);
		}

		// Find which output ports are read as sources anywhere
		pool<RTLIL::Wire *> read_outputs;
		// Check connections (RHS = source)
		for (auto &conn : module->connections()) {
			for (auto &chunk : conn.second.chunks())
				if (chunk.wire && output_ports.count(chunk.wire))
					read_outputs.insert(chunk.wire);
		}
		// Check cell port connections -- any port that reads an output wire
		for (auto cell : module->cells()) {
			for (auto &conn : cell->connections()) {
				// For cells, any connection could be reading the output port
				// (input ports of child cells read parent signals)
				bool is_cell_input = true;
				if (cell->type[0] != '$') {
					RTLIL::Module *sub = module->design->module(cell->type);
					if (sub) {
						RTLIL::Wire *pw = sub->wire(conn.first);
						if (pw && pw->port_output && !pw->port_input)
							is_cell_input = false;
					}
				}
				if (is_cell_input) {
					for (auto &chunk : conn.second.chunks())
						if (chunk.wire && output_ports.count(chunk.wire))
							read_outputs.insert(chunk.wire);
				}
			}
		}

		// Collect all wire names that exist in the module (for collision detection)
		pool<std::string> existing_wire_names;
		for (auto wire : module->wires())
			existing_wire_names.insert(id(wire->name));

		for (auto w : read_outputs) {
			std::string base = id(w->name);
			std::string shadow;
			// If extended identifier (\...\), insert suffix before closing backslash
			if (base.size() >= 2 && base.front() == '\\' && base.back() == '\\')
				shadow = base.substr(0, base.size() - 1) + "_obuf\\";
			else
				shadow = base + "_obuf";

			// If a wire with the proposed shadow name already exists in the module
			// (e.g. from a previous write_vhdl round-trip that GHDL preserved),
			// check whether it matches -- if so, reuse it; if not, pick a fresh
			// auto-name to avoid duplicate signal declarations.
			if (existing_wire_names.count(shadow)) {
				// The shadow name conflicts.  Find the existing wire: if there is
				// a wire whose vhdl_id equals the proposed shadow, that wire IS
				// the shadow from the previous pass -- use it directly.
				// Otherwise pick a fresh name that does not collide.
				bool found_match = false;
				for (auto wire : module->wires()) {
					if (id(wire->name) == shadow && !wire->port_id) {
						// This wire is the existing shadow; reuse its name.
						found_match = true;
						break;
					}
				}
				if (!found_match) {
					// Name collision with a different wire: use auto-name.
					shadow = next_auto_id();
					// Ensure this name is not already taken.
					while (existing_wire_names.count(shadow))
						shadow = next_auto_id();
				}
				// If found_match, shadow already equals the correct name and
				// the wire will be emitted by dump_wire -- skip re-declaring it.
				// We record whether we need to emit the shadow declaration below.
			}
			outport_shadows[w->name] = shadow;
		}
	}

	// Library/use clauses (must appear before each design unit in VHDL)
	f << "\n" << indent << "library ieee;\n";
	f << indent << "use ieee.std_logic_1164.all;\n";
	f << indent << "use ieee.numeric_std.all;\n";

	// Entity declaration
	f << "\n" << indent << "entity " << id(module->name, false) << " is\n";

	// Ports
	std::vector<RTLIL::Wire *> ports;
	for (auto port_name : module->ports) {
		RTLIL::Wire *w = module->wire(port_name);
		if (w)
			ports.push_back(w);
	}

	if (!ports.empty()) {
		f << indent << "  port (\n";
		for (size_t i = 0; i < ports.size(); i++) {
			dump_port(f, indent + "    ", ports[i]);
			if (i + 1 < ports.size())
				f << ";";
			f << "\n";
		}
		f << indent << "  );\n";
	}

	f << indent << "end entity " << id(module->name, false) << ";\n\n";

	// Architecture
	f << indent << "architecture rtl of " << id(module->name, false) << " is\n";

	// Signal declarations (non-port wires)
	for (auto w : module->wires()) {
		if (w->port_id)
			continue;
		dump_wire(f, indent + "  ", w);
	}

	// Shadow signals for VHDL-93 output port read-back.
	// Only declare the shadow if no wire in the module already maps to that
	// VHDL name (which happens on a round-trip where GHDL preserved the shadow
	// signal from the previous write_vhdl output as a regular wire).
	for (auto &shadow : outport_shadows) {
		RTLIL::Wire *w = module->wire(shadow.first);
		if (!w)
			continue;
		// Check if any non-port wire already has this shadow name
		bool already_declared = false;
		for (auto wire : module->wires()) {
			if (!wire->port_id && id(wire->name) == shadow.second) {
				already_declared = true;
				break;
			}
		}
		if (!already_declared)
			f << indent << "  signal " << shadow.second << " : " << vhdl_type_str(w->width) << ";\n";
	}

	// Component declarations
	collect_components(f, indent + "  ", module, design);

	// Pre-pass: dump cells, memories, and connections to a buffer
	// to collect FF/memory signal declarations for the declarative region
	aux_signal_decls.clear();
	mem_type_decls.clear();
	std::stringstream body_buf;

	// Memory blocks
	for (auto &mem : Mem::get_all_memories(module))
		dump_memory(body_buf, indent + "  ", mem);

	for (auto cell : module->cells())
		dump_cell(body_buf, indent + "  ", cell);
	for (auto it = module->connections().begin(); it != module->connections().end(); ++it)
		dump_conn(body_buf, indent + "  ", it->first, it->second);

	// Emit memory type and signal declarations
	for (auto &decl : mem_type_decls)
		f << indent << "  " << decl << "\n";

	// Emit collected FF signal declarations in the architecture declarative region
	for (auto &decl : aux_signal_decls)
		f << indent << "  " << decl << "\n";

	f << indent << "begin\n";

	// Emit the buffered body
	f << body_buf.str();

	// VHDL-93: drive output ports from shadow signals
	for (auto &shadow : outport_shadows) {
		f << indent << "  " << id(shadow.first) << " <= " << shadow.second << ";\n";
	}

	f << indent << "end architecture rtl;\n";

	active_module = NULL;
	active_initvals.clear();
	active_sigmap.clear();
	active_initdata.clear();
}

struct VhdlBackend : public Backend {
	VhdlBackend() : Backend("vhdl", "write design to VHDL file") {}
	void help() override
	{
		//   |---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|
		log("\n");
		log("    write_vhdl [options] [filename]\n");
		log("\n");
		log("Write the current design to a VHDL file.\n");
		log("\n");
		log("    -std <93|2008>\n");
		log("        select VHDL standard version. default: 93.\n");
		log("        VHDL-2008 enables process(all) sensitivity lists.\n");
		log("        VHDL-93 generates explicit sensitivity lists.\n");
		log("\n");
		log("    -work <library_name>\n");
		log("        set the VHDL work library name used in the output.\n");
		log("        default: work. useful when compiling into a separate library\n");
		log("        (e.g. yosys_work) for testbench integration.\n");
		log("\n");
		log("    -norename\n");
		log("        without this option all internal object names (the ones with a dollar\n");
		log("        instead of a backslash prefix) are changed to short names in the\n");
		log("        format '_<number>_'.\n");
		log("\n");
		log("    -renameprefix <prefix>\n");
		log("        insert this prefix in front of auto-generated instance names\n");
		log("\n");
		log("    -noattr\n");
		log("        with this option no attributes are included in the output\n");
		log("\n");
		log("    -noexpr\n");
		log("        without this option all internal cells are converted to VHDL\n");
		log("        expressions.\n");
		log("\n");
		log("    -blackboxes\n");
		log("        usually modules with the 'blackbox' attribute are ignored. with\n");
		log("        this option set only the modules with the 'blackbox' attribute\n");
		log("        are written to the output file.\n");
		log("\n");
		log("    -selected\n");
		log("        only write selected modules. modules must be selected entirely or\n");
		log("        not at all.\n");
		log("\n");
		log("    -v\n");
		log("        verbose output (print new names of all renamed wires and cells)\n");
		log("\n");
		log("Note that RTLIL processes can't always be mapped directly to VHDL\n");
		log("process blocks. This backend should only be used to export an RTLIL\n");
		log("netlist, i.e. after the \"proc\" pass has been used to convert all\n");
		log("processes to logic networks and registers. A warning is generated when\n");
		log("this command is called on a design with RTLIL processes.\n");
		log("\n");
	}
	void execute(std::ostream *&f, std::string filename, std::vector<std::string> args, RTLIL::Design *design) override
	{
		log_header(design, "Executing VHDL backend.\n");

		verbose = false;
		norename = false;
		noattr = false;
		noexpr = false;
		auto_prefix = "";
		vhdl_std = 93;
		work_library = "work";

		bool blackboxes = false;
		bool selected = false;

		auto_name_map.clear();
		reg_wires.clear();

		size_t argidx;
		for (argidx = 1; argidx < args.size(); argidx++) {
			std::string arg = args[argidx];
			if (arg == "-std" && argidx + 1 < args.size()) {
				std::string std_str = args[++argidx];
				if (std_str == "93")
					vhdl_std = 93;
				else if (std_str == "2008" || std_str == "08")
					vhdl_std = 2008;
				else
					log_cmd_error("Invalid VHDL standard `%s'. Use 93 or 2008.\n", std_str.c_str());
				continue;
			}
			if (arg == "-work" && argidx + 1 < args.size()) {
				work_library = args[++argidx];
				continue;
			}
			if (arg == "-norename") {
				norename = true;
				continue;
			}
			if (arg == "-renameprefix" && argidx + 1 < args.size()) {
				auto_prefix = args[++argidx];
				continue;
			}
			if (arg == "-noattr") {
				noattr = true;
				continue;
			}
			if (arg == "-noexpr") {
				noexpr = true;
				continue;
			}
			if (arg == "-blackboxes") {
				blackboxes = true;
				continue;
			}
			if (arg == "-selected") {
				selected = true;
				continue;
			}
			if (arg == "-v") {
				verbose = true;
				continue;
			}
			break;
		}
		extra_args(f, filename, args, argidx);

		log_push();
		if (!noexpr) {
			Pass::call(design, "bmuxmap");
			Pass::call(design, "demuxmap");
		}
		Pass::call(design, "clean_zerowidth");
		log_pop();

		design->sort_modules();

		*f << "-- Generated by " << yosys_maybe_version() << "\n";
		*f << "-- VHDL standard: " << (vhdl_std >= 2008 ? "2008" : "93") << "\n";
		if (work_library != "work")
			*f << "-- Work library: " << work_library << "\n";

		for (auto module : design->modules()) {
			if (module->get_blackbox_attribute() != blackboxes)
				continue;
			if (selected && !design->selected_whole_module(module->name)) {
				if (design->selected_module(module->name))
					log_cmd_error("Can't handle partially selected module %s!\n", log_id(module->name));
				continue;
			}

			bool has_sync_rules = false;
			for (auto process : module->processes)
				if (!process.second->syncs.empty())
					has_sync_rules = true;
			if (has_sync_rules)
				log_warning("Module %s contains RTLIL processes with sync rules. Such RTLIL "
					    "processes can't always be mapped directly to VHDL process blocks. "
					    "Unintended changes in simulation behavior are possible! Use \"proc\" "
					    "to convert processes to logic networks and registers.\n",
					    log_id(module));

			log("Dumping module `%s'.\n", module->name);
			module->sort();
			dump_module(*f, "", module, design);
		}

		auto_name_map.clear();
		reg_wires.clear();
	}
} VhdlBackend;

PRIVATE_NAMESPACE_END
