/*
 * ghdl_rename -- rename GHDL-mangled VHDL identifiers
 *
 * GHDL flattens VHDL record-typed ports into escaped identifiers:
 *   \port[field]\        -> port_field
 *   \port[outer][inner]\ -> port_outer_inner   (with GHDL patch)
 *   \instance:NNN\       -> instance_NNN
 *   \:NNN\               -> _anon_NNN
 *
 * Plain ports (std_logic, vectors, arrays-of-records) are left as-is.
 *
 * Collision detection: if two source names would produce the same
 * target name, a numeric suffix (_0, _1, ...) is appended to all
 * conflicting names and a warning is emitted.
 *
 * -map <file>: emit a JSON file recording every rename performed,
 *   including port direction and width.  Used by gen_wrapper.py to
 *   generate a VHDL wrapper that re-exposes the original record-typed
 *   interface over the renamed flat-port netlist.
 *
 * Registers the Yosys pass "vhdl_rename".
 * Also invoked by the "ghdl --rename" flag (see ghdl.cc).
 *
 * Copyright (C) 2026  Donald J Dionne
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

#include "kernel/yosys.h"
#include "kernel/log.h"
#include <fstream>

USING_YOSYS_NAMESPACE
PRIVATE_NAMESPACE_BEGIN

// ---------------------------------------------------------------------------
// Name transformation
// ---------------------------------------------------------------------------

// Return true if this IdString needs renaming (is an escaped GHDL name
// containing '[', ']', or ':' after the leading backslash).
static bool needs_rename(const IdString &id)
{
	const std::string &s = id.str();
	// Public names start with '\'; private with '$' (leave those alone).
	if (s.empty() || s[0] != '\\')
		return false;
	// Scan for GHDL-specific characters
	for (char c : s)
		if (c == '[' || c == ']' || c == ':')
			return true;
	return false;
}

// Convert a GHDL-mangled escaped identifier to a clean name.
//
// Input is the full IdString including the leading '\' and trailing '\'.
// Examples:
//	 \port[field]\		  -> port_field
//	 \port[outer][inner]\ -> port_outer_inner
//	 \inst:649\			  -> inst_649
//	 \:1132\			  -> _anon_1132
static std::string transform_name(const IdString &id)
{
	const std::string &s = id.str();
	// s is e.g. "\\port[field]\\" -- strip leading '\', the IdString
	// representation has the leading backslash but no trailing one.
	// (Yosys stores escaped ids as "\name" without trailing backslash.)
	std::string raw = s.substr(1); // strip leading '\'

	std::string result;
	result.reserve(raw.size());

	size_t i = 0;

	// Handle the \:NNN\ anonymous pattern -- name starts with ':'
	if (!raw.empty() && raw[0] == ':') {
		result = "_anon_";
		i = 1; // skip the leading ':'
		while (i < raw.size())
			result += raw[i++];
		return result;
	}

	// General case: replace '[' and ']' with '_', strip extra '_',
	// replace ':' (from instance:NNN) with '_'.
	bool last_was_sep = false;
	for (; i < raw.size(); i++) {
		char c = raw[i];
		if (c == '[' || c == ']' || c == ':') {
			// Treat as separator -> underscore, but collapse runs
			if (!result.empty() && !last_was_sep)
				result += '_';
			last_was_sep = true;
		} else {
			result += c;
			last_was_sep = false;
		}
	}

	// Strip any trailing '_' that might result from a trailing ']'
	while (!result.empty() && result.back() == '_')
		result.pop_back();

	return result;
}

// ---------------------------------------------------------------------------
// Per-module rename: collect renames, detect collisions, apply
// ---------------------------------------------------------------------------

// Represents one pending rename within a module
struct RenameEntry {
	IdString old_id;
	std::string proposed; // before collision resolution
};

// One completed rename record emitted to the -map JSON file.
struct MapEntry {
	std::string module;   // module name (without leading backslash)
	std::string old_name; // original escaped identifier (e.g. \bi[en]\)
	std::string new_name; // renamed identifier (e.g. bi_en)
	bool is_port;  // true if the wire is a port
	bool port_in;  // true = input; false = output (only valid if is_port)
	int width;     // bit width
};

// Compute all renames needed for a module's wires, apply them, and
// update any cell port connections that reference renamed wires.
//
// Phase 1: collect proposed renames for all wires needing it
// Phase 2: detect collisions among proposed names (and existing names)
// Phase 3: apply renames via module->rename()
//
// Cell port connections: Yosys stores cell connections as SigSpec
// (which references Wire* objects), so renaming the wire automatically
// updates all connections -- no separate phase needed.
//
// If map_out is non-null, completed renames are appended to it for
// JSON export via the -map option.
static int rename_module_wires(Module *module, bool verbose,
	   std::vector<MapEntry> *map_out)
{
	int count = 0;

	// --- Phase 1: collect proposed renames ---
	std::vector<RenameEntry> entries;
	for (auto wire : module->wires()) {
		if (!needs_rename(wire->name))
			continue;
		std::string proposed = transform_name(wire->name);
		entries.push_back({wire->name, proposed});
	}

	if (entries.empty())
		return 0;

	// --- Phase 2: collision detection ---
	// Build a map from proposed name -> list of source IdStrings
	std::map<std::string, std::vector<IdString>> proposed_map;
	for (auto &e : entries)
		proposed_map[e.proposed].push_back(e.old_id);

	// Also collect existing wire names that are NOT being renamed,
	// to avoid colliding with them.
	std::set<std::string> existing_names;
	for (auto wire : module->wires()) {
		if (!needs_rename(wire->name))
			existing_names.insert(wire->name.str().substr(1)); // strip '\'
	}

	// Build the final rename map: old IdString -> new IdString
	std::map<IdString, IdString> rename_map;

	for (auto &kv : proposed_map) {
		const std::string &proposed = kv.first;
		const std::vector<IdString> &sources = kv.second;

		if (sources.size() == 1) {
			// No collision among renamed wires; check against existing
			std::string candidate = proposed;
			int suffix = 0;
			while (existing_names.count(candidate)) {
				candidate = proposed + "_" + std::to_string(suffix++);
			}
			if (candidate != proposed)
				log_warning("vhdl_rename: in module %s: '%s' collides with "
							"existing name, renamed to '%s'\n",
							log_id(module->name),
							sources[0].c_str(), candidate.c_str());
			rename_map[sources[0]] = IdString("\\" + candidate);
		} else {
			// Multiple sources map to same proposed name -- disambiguate
			log_warning("vhdl_rename: in module %s: %zu names all map to "
						"'%s', disambiguating with numeric suffix\n",
						log_id(module->name), sources.size(),
						proposed.c_str());
			for (size_t i = 0; i < sources.size(); i++) {
				std::string candidate = proposed + "_" + std::to_string(i);
				// Make sure even the suffixed name doesn't collide
				while (existing_names.count(candidate) ||
					   proposed_map.count(candidate))
					candidate += "_";
				rename_map[sources[i]] = IdString("\\" + candidate);
			}
		}
	}

	// --- Phase 3: apply renames ---
	// Snapshot wire metadata before renaming (wire object is still valid
	// during iteration; we just need direction + width before rename).
	std::map<IdString, Wire*> wire_snapshot;
	for (auto wire : module->wires())
		wire_snapshot[wire->name] = wire;

	for (auto &kv : rename_map) {
		if (verbose)
			log("  %s.%s  ->  %s\n",
				log_id(module->name),
				kv.first.c_str(),
				kv.second.c_str());

		// Populate map output before renaming (name still valid)
		if (map_out) {
			Wire *w = wire_snapshot.count(kv.first) ? wire_snapshot[kv.first] : nullptr;
			MapEntry me;
			me.module	= log_id(module->name);	 // strips leading backslash
			me.old_name = kv.first.str();
			me.new_name = kv.second.str().substr(1); // strip leading '\'
			me.is_port	= w ? w->port_input || w->port_output : false;
			me.port_in	= w ? w->port_input : false;
			me.width	= w ? w->width : 1;
			map_out->push_back(me);
		}

		module->rename(kv.first, kv.second);
		count++;
	}

	// Rebuild the module's port list to reflect renamed wires.
	// This is required because module->ports is a separate IdString
	// vector that is not automatically updated by module->rename().
	if (count > 0)
		module->fixup_ports();

	return count;
}

// ---------------------------------------------------------------------------
// Yosys Pass
// ---------------------------------------------------------------------------

struct VhdlRenamePass : public Pass {
	VhdlRenamePass() : Pass("vhdl_rename", "rename GHDL-mangled VHDL record port identifiers") {}

	void help() override
	{
		log("\n");
		log("	 vhdl_rename [options]\n");
		log("\n");
		log("Rename escaped identifiers produced by GHDL's record port\n");
		log("flattening into clean underscore-separated names suitable\n");
		log("for downstream EDA tools (OpenROAD, LibreLane/OpenLane).\n");
		log("\n");
		log("Transformations applied:\n");
		log("  \\port[field]\\		  ->  port_field\n");
		log("  \\port[outer][inner]\\  ->  port_outer_inner\n");
		log("  \\instance:NNN\\		  ->  instance_NNN\n");
		log("  \\:NNN\\				  ->  _anon_NNN\n");
		log("\n");
		log("Plain ports (std_logic, vectors, unescaped names) are\n");
		log("left unchanged.\n");
		log("\n");
		log("Collisions: if two source names would produce the same\n");
		log("target name, a numeric suffix is appended to all\n");
		log("conflicting names and a warning is emitted.\n");
		log("\n");
		log("Options:\n");
		log("  -verbose		  print each rename operation\n");
		log("  -map <file>	  write a JSON file recording every rename\n");
		log("				  (used by gen_wrapper.py to generate a VHDL\n");
		log("				   wrapper re-exposing the original record interface)\n");
		log("\n");
	}

	void execute(std::vector<std::string> args, Design *design) override
	{
		bool verbose = false;
		std::string map_file;

		// Parse options
		size_t argidx;
		for (argidx = 1; argidx < args.size(); argidx++) {
			if (args[argidx] == "-verbose") {
				verbose = true;
				continue;
			}
			if (args[argidx] == "-map" && argidx + 1 < args.size()) {
				map_file = args[++argidx];
				continue;
			}
			break;
		}
		extra_args(args, argidx, design);

		log_header(design, "Executing VHDL_RENAME pass (rename GHDL record ports).\n");

		// Collect map entries across all modules (only used if -map given)
		std::vector<MapEntry> map_entries;
		std::vector<MapEntry> *map_out = map_file.empty() ? nullptr : &map_entries;

		int total = 0;
		// Rename wires in all modules -- including blackboxes loaded
		// from Verilog stubs.	Blackbox ports carry the same escaped
		// GHDL names and must be renamed so the cell rekey phase can
		// verify the new name exists on the module.
		for (auto module : design->modules()) {
			int n = rename_module_wires(module, verbose, map_out);
			if (n > 0)
				log("  Module %s: renamed %d wire(s).\n",
					log_id(module->name), n);
			total += n;
		}

		// Phase 2 (global): update cell port connection keys.
		// When a sub-module's ports are renamed, cell instantiations
		// in parent modules still use the old port name as the
		// connection key.	This applies to both:
		//	 (a) modules present in the design (ports were just renamed)
		//	 (b) blackbox cells (module not in design) whose port names
		//		 are still the raw GHDL-mangled escaped identifiers
		for (auto module : design->modules()) {
			for (auto cell : module->cells()) {
				Module *cell_mod = design->module(cell->type);
				// Collect rekeys needed (can't mutate dict while iterating)
				std::vector<std::pair<IdString,IdString>> rekeys;
				for (auto &conn : cell->connections()) {
					if (!needs_rename(conn.first))
						continue;
					std::string new_name = "\\" + transform_name(conn.first);
					IdString new_id(new_name);
					// For known modules: only rekey if the new name exists
					// (guards against false matches on non-GHDL cells)
					// For blackboxes: trust the transform unconditionally
					if (cell_mod != nullptr && cell_mod->wire(new_id) == nullptr)
						continue;
					rekeys.push_back({conn.first, new_id});
				}
				for (auto &rk : rekeys) {
					if (verbose)
						log("  cell %s.%s port %s -> %s\n",
							log_id(module->name), log_id(cell->name),
							rk.first.c_str(), rk.second.c_str());
					SigSpec sig = cell->getPort(rk.first);
					cell->unsetPort(rk.first);
					cell->setPort(rk.second, sig);
				}
			}
		}

		log("  Total: %d rename(s).\n", total);

		// Write JSON map file if requested
		if (!map_file.empty()) {
			std::ofstream f(map_file);
			if (!f)
				log_error("vhdl_rename: cannot open map file '%s'\n",
						  map_file.c_str());

			// Helper: JSON-escape a string (handles backslash and quotes)
			auto json_str = [](const std::string &s) -> std::string {
				std::string out;
				out += '"';
				for (char c : s) {
					if (c == '\\') out += "\\\\";
					else if (c == '"') out += "\\\"";
					else out += c;
				}
				out += '"';
				return out;
			};

			f << "[\n";
			for (size_t i = 0; i < map_entries.size(); i++) {
				const MapEntry &me = map_entries[i];
				f << "	{"
				  << " \"module\": "   << json_str(me.module)	<< ","
				  << " \"old\": "	   << json_str(me.old_name) << ","
				  << " \"new\": "	   << json_str(me.new_name) << ","
				  << " \"is_port\": "  << (me.is_port ? "true" : "false") << ","
				  << " \"dir\": "	   << (me.port_in ? "\"input\"" : "\"output\"") << ","
				  << " \"width\": "	   << me.width
				  << " }";
				if (i + 1 < map_entries.size()) f << ",";
				f << "\n";
			}
			f << "]\n";

			if (!f)
				log_error("vhdl_rename: error writing map file '%s'\n",
						  map_file.c_str());
			log("  Map written to %s (%zu entries).\n",
				map_file.c_str(), map_entries.size());
		}
	}

} VhdlRenamePass;

PRIVATE_NAMESPACE_END
