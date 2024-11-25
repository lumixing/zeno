package zeno

import "../qbe"
import "core:fmt"

QbeOut :: struct {
	datas: [dynamic]qbe.Data,
	funcs: [dynamic]qbe.Func,
}

Func :: struct {
	sign:       FuncSign,
	is_foreign: bool,
}

Var :: struct {
	name: union {
		qbe.Temp,
		qbe.Glob,
	},
	type: Type,
}

Funcs :: map[string]Func
Vars :: map[string]Var

Scope :: struct {
	parent:   Maybe(^Scope),
	children: [dynamic]^Scope,
	vars:     Vars,
}

gen_qbe :: proc(top_stmts: []Spanned(TopStmt)) -> (out: QbeOut, err: Maybe(Error)) {
	funcs: Funcs
	global_scope: Scope

	for span_tstmt in top_stmts {
		switch tstmt in span_tstmt.value {
		case ForeignFuncDecl:
			gen_foreign_func_decl(span_tstmt, &funcs) or_return
		case FuncDef:
			gen_func_def(span_tstmt, &funcs, &out, &global_scope) or_return
		}
	}

	return
}

gen_foreign_func_decl :: proc(span_tstmt: Spanned(TopStmt), funcs: ^Funcs) -> (err: Maybe(Error)) {
	tstmt := span_tstmt.value.(ForeignFuncDecl)

	gen_check_name_in_funcs(tstmt.sign.name, funcs^, span_tstmt.span) or_return

	funcs[tstmt.sign.name] = Func{tstmt.sign, true}

	return
}

gen_func_def :: proc(
	span_tstmt: Spanned(TopStmt),
	funcs: ^Funcs,
	out: ^QbeOut,
	global_scope: ^Scope,
) -> (
	err: Maybe(Error),
) {
	tstmt := span_tstmt.value.(FuncDef)

	gen_check_name_in_funcs(tstmt.sign.name, funcs^, span_tstmt.span) or_return
	// todo: check in scope aswell

	funcs[tstmt.sign.name] = Func{tstmt.sign, false}

	scope: Scope
	scope.parent = global_scope
	// add scope to global_scope children?

	func: qbe.Func
	func.name = tstmt.sign.name
	func.return_type = gen_type(tstmt.sign.return_type)

	params: [dynamic]qbe.Param
	for param in tstmt.sign.params {
		gen_check_name_in_scope(param.name, scope, span_tstmt.span) or_return
		gen_check_name_in_funcs(param.name, funcs^, span_tstmt.span) or_return

		scope.vars[param.name] = Var{qbe.Temp(param.name), param.type}

		append(&params, qbe.Param{param.name, gen_type(param.type)})
	}
	func.params = params[:]

	func.exported = true

	body: [dynamic]qbe.Stmt
	for stmt in tstmt.body {
		gstmt_maybe := gen_stmt(out, stmt, &scope, funcs^, funcs[tstmt.sign.name]) or_return
		gstmt := gstmt_maybe.? or_continue
		append(&body, gstmt)
	}
	func.body = body[:]

	append(&out.funcs, func)

	return
}

gen_stmt :: proc(
	out: ^QbeOut,
	span_stmt: Spanned(Stmt),
	scope: ^Scope,
	funcs: Funcs,
	func: Func,
) -> (
	qbe_stmt: Maybe(qbe.Stmt),
	err: Maybe(Error),
) {
	#partial switch stmt in span_stmt.value {
	case VarDef:
		qbe_stmt = gen_var_def(out, span_stmt, scope, funcs) or_return
	case Return:
		qbe_stmt = gen_return(out, span_stmt, scope, funcs, func) or_return
	case FuncCall:
		qbe_stmt = gen_func_call(out, span_stmt, scope, funcs) or_return
	}

	return
}

gen_var_def :: proc(
	out: ^QbeOut,
	span_stmt: Spanned(Stmt),
	scope: ^Scope,
	funcs: Funcs,
) -> (
	qbe_stmt: Maybe(qbe.Stmt),
	err: Maybe(Error),
) {
	stmt := span_stmt.value.(VarDef)

	gen_check_name_in_scope(stmt.name, scope^, span_stmt.span) or_return
	gen_check_name_in_funcs(stmt.name, funcs, span_stmt.span) or_return

	#partial switch stmt.type {
	case .String:
		#partial switch value in stmt.value {
		case string:
			glob_name := fmt.tprintf("%s.str", stmt.name)
			scope.vars[stmt.name] = Var{qbe.Glob(glob_name), stmt.type}
			append(&out.datas, qbe.Data{glob_name, qbe.args_str(value)})
		case Ident:
			// todo: recursive parents
			if string(value) not_in scope.vars {
				err = error(span_stmt.span, "Variable %q is not defined", string(value))
				return
			}

			var := scope.vars[string(value)]
			if var.type != stmt.type {
				err = error(
					span_stmt.span,
					"Variable %q expected %v as a value but %q is %v",
					stmt.name,
					stmt.type,
					string(value),
					stmt.type,
				)
				return
			}

			scope.vars[stmt.name] = var
		case:
			gen_err_var_type(span_stmt.span, stmt) or_return
		}
	case .Int:
		#partial switch value in stmt.value {
		case int:
			scope.vars[stmt.name] = Var{qbe.Temp(stmt.name), stmt.type}
			qbe_stmt = qbe.TempDef{stmt.name, gen_type(stmt.type), qbe.Copy(value)}
		case Ident:
			// todo: recursive parents
			if string(value) not_in scope.vars {
				err = error(span_stmt.span, "Variable %q is not defined", string(value))
				return
			}

			var := scope.vars[string(value)]
			if var.type != stmt.type {
				err = error(
					span_stmt.span,
					"Variable %q expected %v as a value but %q is %v",
					stmt.name,
					stmt.type,
					string(value),
					stmt.type,
				)
				return
			}

			scope.vars[stmt.name] = var
		case:
			gen_err_var_type(span_stmt.span, stmt) or_return
		}
	case:
		unimplemented()
	}

	return
}

gen_return :: proc(
	out: ^QbeOut,
	span_stmt: Spanned(Stmt),
	scope: ^Scope,
	funcs: Funcs,
	func: Func,
) -> (
	qbe_stmt: Maybe(qbe.Stmt),
	err: Maybe(Error),
) {
	stmt := span_stmt.value.(Return)

	if value, value_ok := stmt.value.?; value_ok {
		#partial switch func.sign.return_type {
		case .Int:
			#partial switch value in value {
			case int:
				qbe_stmt = qbe.Instr(qbe.Return(value))
			case Ident:
				if string(value) not_in scope.vars {
					err = error(span_stmt.span, "Variable %q is not defined", string(value))
					return
				}

				var := scope.vars[string(value)]
				if var.type != func.sign.return_type {
					err = error(
						span_stmt.span,
						"Function %q expected return type %v but %q is %v",
						func.sign.name,
						func.sign.return_type,
						string(value),
						var.type,
					)
					return
				}

				qbe_stmt = qbe.Instr(qbe.Return(gen_var_name_to_value(var)))
			case:
				err = error(
					span_stmt.span,
					"Function %q expected return type %v but got %v",
					func.sign.name,
					func.sign.return_type,
					value,
				)
			}
		case .Void:
			if stmt.value != nil {
				err = error(
					span_stmt.span,
					"Function %q expected return type %v but got %v",
					func.sign.name,
					func.sign.return_type,
					stmt.value,
				)
				return
			}

			qbe_stmt = qbe.Instr(qbe.Return(nil))
		}
	} else {
		if func.sign.return_type != .Void {
			err = error(
				span_stmt.span,
				"Function %q expected return type %v but got nothing",
				func.sign.name,
				func.sign.return_type,
			)
			return
		}

		qbe_stmt = qbe.Instr(qbe.Return(nil))
	}

	return
}

gen_func_call :: proc(
	out: ^QbeOut,
	span_stmt: Spanned(Stmt),
	scope: ^Scope,
	funcs: Funcs,
) -> (
	qbe_stmt: Maybe(qbe.Stmt),
	err: Maybe(Error),
) {
	stmt := span_stmt.value.(FuncCall)

	if stmt.name not_in funcs {
		err = error(span_stmt.span, "Function %q is not defined", stmt.name)
		return
	}

	func := funcs[stmt.name]

	// todo: variadic
	if len(func.sign.params) != len(stmt.args) {
		err = error(
			span_stmt.span,
			"Function %q expected %d arguments but got %d",
			stmt.name,
			len(func.sign.params),
			len(stmt.args),
		)
		return
	}

	args: [dynamic]qbe.Arg

	for param, i in func.sign.params {
		arg := stmt.args[i]

		if _, is_ident := arg.(Ident); !is_ident && param.type != gen_expr_to_type(arg) {
			err = error(
				span_stmt.span,
				"Parameter %q expected type %v but got %v",
				param.name,
				param.type,
				gen_expr_to_type(arg),
			)
			return
		}

		#partial switch arg in arg {
		case string:
			// todo: add gid
			str_name := fmt.tprintf("%s.%s.str", func.sign.name, param.name)
			append(&out.datas, qbe.Data{str_name, qbe.args_str(arg)})
			append(&args, qbe.Arg{.Long, qbe.Glob(str_name)})
		case Ident:
			if string(arg) not_in scope.vars {
				err = error(span_stmt.span, "Variable %q is not defined", string(arg))
				return
			}

			var := scope.vars[string(arg)]
			if var.type != param.type {
				err = error(
					span_stmt.span,
					"Parameter %q expected type %v but %q is %v",
					param.name,
					param.type,
					string(arg),
					var.type,
				)
				return
			}

			append(&args, qbe.Arg{gen_type(var.type), gen_var_name_to_value(var)})
		case:
			unimplemented()
		}
	}

	qbe_stmt = qbe.Instr(qbe.Call{stmt.name, args[:]})

	return
}

gen_expr_to_type :: proc(expr: Expr) -> (type: Type) {
	switch value in expr {
	case string:
		type = .String
	case int:
		type = .Int
	case bool:
		type = .Bool
	case Ident:
		unimplemented()
	}

	return
}

gen_var_name_to_value :: proc(var: Var) -> (value: qbe.Value) {
	switch name in var.name {
	case qbe.Glob:
		value = name
	case qbe.Temp:
		value = name
	}

	return
}

gen_err_var_type :: proc(span: Span, stmt: VarDef) -> Maybe(Error) {
	return error(
		span,
		"Variable %q expected %v as a value but got %v",
		stmt.name,
		stmt.type,
		stmt.value,
	)
}

gen_check_name_in_funcs :: proc(name: string, funcs: Funcs, span: Span) -> (err: Maybe(Error)) {
	if name in funcs {
		err = error(span, "%q is already declared as a function", name)
	}

	return
}

gen_check_name_in_scope :: proc(name: string, scope: Scope, span: Span) -> (err: Maybe(Error)) {
	// todo: recursive for parent
	if name in scope.vars {
		err = error(span, "%q is already declared as a variable", name)
	}

	return
}

gen_type :: proc(type: Type) -> (qbe_type: qbe.Type) {
	switch type {
	case .Any:
		unimplemented()
	case .Bool, .Int:
		qbe_type = .Word
	case .String:
		qbe_type = .Long
	case .Void:
		qbe_type = nil
	}

	return
}
