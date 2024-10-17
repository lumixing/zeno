package zeno

import "../qbe"
import "core:fmt"

Var :: struct {
	gid:       int,
	type:      Type,
	temp_name: string,
}

Func :: struct {
	params:      []Param,
	return_type: Type,
}

interp :: proc(source: []u8, top_stmts: []TopStmt) -> []string {
	if len(top_stmts) == 0 {
		err_log(source, 0, "no func declarations found")
	}

	lines: [dynamic]string
	gid := 0
	var_map: map[string]Var
	func_map: map[string]Func

	main_found := false
	for top_stmt in top_stmts {
		#partial switch tstmt in top_stmt {
		case FuncDeclare:
			if tstmt.name in func_map {
				err_log(source, 0, "%q has already been declared as a function", tstmt.name)
			}

			is_main := tstmt.name == "main"

			instrs: [dynamic]qbe.Instr
			for stmt in tstmt.body {
				#partial switch st in stmt {
				case FuncCall:
					if st.name not_in func_map {
						err_log(source, 0, "%q has not been declared as a function", st.name)
					}

					// assert(len(st.args) == 1, "temp ass for printf")
					assert(
						len(st.args) == len(func_map[st.name].params),
						"decl and call param len doesnt match!",
					)
					arg_type := expr_to_type(st.args[0])
					par_type := func_map[st.name].params[0].type
					if arg_type != par_type {
						err_log(
							source,
							0,
							"mismatched argument type in %q (should be %v but is %v)",
							st.name,
							par_type,
							arg_type,
						)
					}
					arg_str := st.args[0].(string)
					str_gid := gid
					gid += 1
					tmp_str_name := fmt.tprintf("%s.%d", "strlit", str_gid)
					qbe.data_string(&lines, tmp_str_name, arg_str)
					append(&instrs, qbe.Call{st.name, []qbe.Arg{{.Long, tmp_str_name}}})
				case VarDecl:
					if st.name in var_map {
						err_log(source, 0, "%q has already been declared as a variable", st.name)
					}
					var := Var{gid, st.type, fmt.tprintf("%s.%d", st.name, gid)}
					var_map[st.name] = var
					gid += 1
					append(&instrs, qbe.TempDecl{var.temp_name, .Word, st.value.(int)})
				}
			}

			if is_main {
				main_found = true
				append(&instrs, qbe.Return{0})
			}

			qbe.function(&lines, tstmt.name, .Word, is_main, instrs[:])
		case ForeignFuncDeclare:
			if tstmt.name in func_map {
				err_log(source, 0, "%q has already been declared as a function", tstmt.name)
			}

			func_map[tstmt.name] = {tstmt.params, tstmt.return_type}
		}
	}

	if !main_found {
		err_log(source, 0, "no main func declaration found")
	}

	return lines[:]
}

expr_to_type :: proc(expr: Expr) -> Type {
	switch e in expr {
	case string:
		return .String
	case int:
		return .Int
	}
	return .Void
}
