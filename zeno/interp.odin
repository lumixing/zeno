package zeno

import "../qbe"

interp :: proc(source: []u8, top_stmts: []TopStmt) {
	if len(top_stmts) == 0 {
		err_log(source, 0, "no func declarations found")
	}

	lines: [dynamic]string

	for top_stmt in top_stmts {
		main_found := false

		switch tstmt in top_stmt {
		case FuncDeclare:
			is_main := tstmt.name == "main"

			instrs: [dynamic]qbe.Instr
			for stmt in tstmt.body {
				#partial switch st in stmt {
				case FuncCall:
				// append(&instrs, qbe.Call{st.name})
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
}
