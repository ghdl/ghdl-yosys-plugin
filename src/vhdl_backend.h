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
 *  A VHDL backend for Yosys.  Keyword table and reserved-word checker.
 */

#ifndef VHDL_BACKEND_H
#define VHDL_BACKEND_H

#include "kernel/yosys.h"
#include <string>

YOSYS_NAMESPACE_BEGIN
namespace VHDL_BACKEND
{

const pool<string> vhdl_keywords();
bool id_is_vhdl_reserved(const std::string &str);

}; /* namespace VHDL_BACKEND */
YOSYS_NAMESPACE_END

#endif /* VHDL_BACKEND_H */
