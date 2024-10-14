package zeno

import "../qbe"
import "core:fmt"

interp :: proc(source: []u8, top_stmts: []TopStmt) -> []string {
	if len(top_stmts) == 0 {
		err_log(source, 0, "no func declarations found")
	}

	lines: [dynamic]string
	gid := 0

	for top_stmt in top_stmts {
		main_found := false

		switch tstmt in top_stmt {
		case FuncDeclare:
			is_main := tstmt.name == "main"

			instrs: [dynamic]qbe.Instr
			for stmt in tstmt.body {
				#partial switch st in stmt {
				case FuncCall:
					assert(len(st.args) == 1, "temp ass for printf")
					arg_str := st.args[0].(string)
					str_gid := gid
					gid += 1
					tmp_str_name := fmt.tprintf("%s.%d", "strlit", str_gid)
					qbe.data_string(&lines, tmp_str_name, arg_str)
					append(&instrs, qbe.Call{st.name, []qbe.Arg{{.Long, tmp_str_name}}})
				}
			}

			if is_main {
				main_found = true
				append(&instrs, qbe.Return{0})
			}

			qbe.function(&lines, tstmt.name, .Word, is_main, instrs[:])
		}

		if !main_found {
			err_log(source, 0, "no main func declaration found")
		}
	}

	return lines[:]
}