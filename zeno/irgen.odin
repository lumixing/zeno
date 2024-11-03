package zeno

import "../qbe"
import "core:fmt"

Func :: struct {
	params:      []Param,
	return_type: Type,
}

Var :: struct {
	gid:       int,
	type:      Type,
	temp_name: string,
}

gid := 0
func_map: map[string]Func
var_map: map[string]Var

datas: [dynamic]qbe.Data
funcs: [dynamic]qbe.Func

// todo: split code into procs
gen_qbe :: proc(top_stmts: []TopStmt) -> ([]qbe.Data, []qbe.Func) {
	for top_stmt in top_stmts {
		switch tst in top_stmt {
		case FuncDeclare:
			return_type := type_to_qbe_type(tst.return_type)
			// todo: main func checking
			if tst.name in func_map {
				err_log({}, 0, "%q is already declared as a function.", tst.name)
			}

			func_map[tst.name] = {{}, tst.return_type}
			body: [dynamic]qbe.Stmt
			append(&body, qbe.Label("start"))

			for stmt in tst.body {
				do_stmt(stmt, &body)
			}

			if tst.name == "main" {
				return_type = .Word
			}

			append(&body, qbe.Instr(qbe.Return(tst.name == "main" ? 0 : nil)))

			append(&funcs, qbe.Func{tst.name, return_type, {}, true, body[:]})
		case ForeignFuncDeclare:
			if tst.name in func_map {
				err_log({}, 0, "%q is already declared as a function.", tst.name)
			}

			func_map[tst.name] = {tst.params, tst.return_type}
		}
	}

	return datas[:], funcs[:]
}

do_stmt :: proc(stmt: Stmt, body: ^[dynamic]qbe.Stmt) {
	switch st in stmt {
	case FuncCall:
		// todo: type checking for args
		if st.name not_in func_map {
			err_log({}, 0, "%q is not declared as a function.", st.name)
		}

		args: [dynamic]qbe.Arg
		for arg in st.args {
			// todo: remove partial!
			#partial switch arg in arg {
			case VarIdent:
				// todo: also check name in func_map and vice versa
				if string(arg) not_in var_map {
					err_log({}, 0, "%q is not declared as a variable.", string(arg))
				}

				var := var_map[string(arg)]
				// todo: remove partial!
				#partial switch var.type {
				case .Int:
					append(&args, qbe.Arg{.Word, qbe.Temp(var.temp_name)})
				case .String:
					append(&args, qbe.Arg{.Long, qbe.Glob(var.temp_name)})
				case .Void:
					fmt.panicf("variable %q has a type of void!", string(arg))
				}
			case string:
				defer gid += 1
				name := fmt.tprintf("%s.%d", ".strlit", gid)
				append(&datas, qbe.Data{name, qbe.args_str(arg)})
				append(&args, qbe.Arg{.Long, qbe.Glob(name)})
			case int:
				panic("unimpl!")
			}
		}
		append(body, qbe.Instr(qbe.Call{st.name, args[:]}))
	case VarDecl:
		// todo: type checking between type and expr type
		if st.name in var_map {
			err_log({}, 0, "%q is already declared as a variable.", st.name)
		}

		defer gid += 1
		name := fmt.tprintf("%s.%d", st.name, gid)
		var_map[st.name] = {gid, st.type, name}

		type: qbe.Type
		// todo: remove partial!
		switch st.type {
		case .Int:
			defer gid += 1
			name := fmt.tprintf("%s.%d", st.name, gid)
			append(body, qbe.TempDef{name, .Word, qbe.Copy(st.value.(int))})
		case .String:
			defer gid += 1
			name := fmt.tprintf("%s.%d", st.name, gid)
			append(&datas, qbe.Data{name, qbe.args_str(st.value.(string))})
		case .Bool:
			defer gid += 1
			name := fmt.tprintf("%s.%d", st.name, gid)
			append(body, qbe.TempDef{name, .Word, qbe.Copy(st.value.(bool) ? 1 : 0)})
		case .Void:
			err_log({}, 0, "trying to declare variable %q of type void!", st.name)
		}
	case IfBranch:
		// todo: expand this
		if var_name, ok := st.cond.(VarIdent); ok {
			if string(var_name) not_in var_map {
				err_log({}, 0, "%q is not declared as a variable.", string(var_name))
			}

			var := var_map[string(var_name)]
			if var.type != .Bool {
				err_log(
					{},
					0,
					"%q is of type %s but needed to be %s.",
					string(var_name),
					var.type,
					Type.Bool,
				)
			}

			append(body, qbe.Instr(qbe.CondJump{qbe.Temp(var.temp_name), "true", "end"}))
			append(body, qbe.Label("true"))
			for ifst in st.body {
				do_stmt(ifst, body)
			}
			append(body, qbe.Label("end"))
		} else {
			err_log({}, 0, "Invalid boolean expression in if condition.")
		}
	}
}

type_to_qbe_type :: proc(type: Type) -> Maybe(qbe.Type) {
	switch type {
	case .Int, .Bool:
		return .Word
	case .String:
		return .Long
	case .Void:
		return nil
	}

	fmt.panicf("unreach (%v)", type)
}
