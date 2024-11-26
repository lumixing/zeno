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
	name:     string, // used when key isnt available
	qbe_name: union {
		qbe.Temp,
		qbe.Glob,
	},
	type:     Type,
}

Funcs :: map[string]Func
Vars :: map[string]Var

Scope :: struct {
	parent:   Maybe(^Scope),
	children: [dynamic]^Scope,
	vars:     Vars,
}

// todo: remove global, global bad, grr
gid := 0

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
	func.return_type = tstmt.sign.return_type == .Void ? nil : gen_type(tstmt.sign.return_type)

	params: [dynamic]qbe.Param
	for param in tstmt.sign.params {
		gen_check_name_in_scope(param.name, scope, span_tstmt.span) or_return
		gen_check_name_in_funcs(param.name, funcs^, span_tstmt.span) or_return

		scope.vars[param.name] = Var{param.name, qbe.Temp(param.name), param.type}

		append(&params, qbe.Param{param.name, gen_type(param.type)})
	}
	func.params = params[:]

	func.exported = true

	body: [dynamic]qbe.Stmt
	append(&body, qbe.Label("start"))

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
			scope.vars[stmt.name] = Var{stmt.name, qbe.Glob(glob_name), stmt.type}
			append(&out.datas, qbe.Data{glob_name, qbe.args_str(value)})
		case Ident:
			var := gen_get_var(scope^, string(value), span_stmt.span) or_return
			gen_same_type(stmt, var, span_stmt.span) or_return

			scope.vars[stmt.name] = var
		case:
			gen_err_var_type(span_stmt.span, stmt) or_return
		}
	case .Int:
		#partial switch value in stmt.value {
		case int:
			scope.vars[stmt.name] = Var{stmt.name, qbe.Temp(stmt.name), stmt.type}
			qbe_stmt = qbe.TempDef{stmt.name, gen_type(stmt.type), qbe.Copy(value)}
		case Ident:
			var := gen_get_var(scope^, string(value), span_stmt.span) or_return
			gen_same_type(stmt, var, span_stmt.span) or_return

			new_var := var
			new_var.name = stmt.name
			scope.vars[stmt.name] = new_var

			// this might not work!
			qbe_stmt = qbe.TempDef {
				stmt.name,
				gen_type(stmt.type),
				qbe.Copy(gen_var_name_to_value(var)),
			}
		case:
			gen_err_var_type(span_stmt.span, stmt) or_return
		}
	case .Bool:
		#partial switch value in stmt.value {
		case bool:
			scope.vars[stmt.name] = Var{stmt.name, qbe.Temp(stmt.name), stmt.type}
			qbe_stmt = qbe.TempDef{stmt.name, gen_type(stmt.type), qbe.Copy(value ? 1 : 0)}
		case Ident:
			var := gen_get_var(scope^, string(value), span_stmt.span) or_return
			gen_same_type(stmt, var, span_stmt.span) or_return

			new_var := var
			new_var.name = stmt.name
			scope.vars[stmt.name] = new_var

			// this might not work!
			qbe_stmt = qbe.TempDef {
				stmt.name,
				gen_type(stmt.type),
				qbe.Copy(gen_var_name_to_value(var)),
			}
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
				var := gen_get_var(scope^, string(value), span_stmt.span) or_return
				gen_same_type(func, var, span_stmt.span) or_return

				qbe_stmt = qbe.Instr(qbe.Return(gen_var_name_to_value(var)))
			case:
				err = gen_same_type(func, value, span_stmt.span)
				assert(err != nil)
				return
			}
		case .Void:
			if value, value_ok := stmt.value.?; value_ok {
				err = gen_same_type(func, value, span_stmt.span)
				assert(err != nil)
				return
			}

			qbe_stmt = qbe.Instr(qbe.Return(nil))
		}
	} else {
		if func.sign.return_type != .Void {
			err = gen_same_type(func, Param{"_return_", .Void, false}, span_stmt.span)
			assert(err != nil)
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
	has_variadic :=
		len(func.sign.params) != 0 && func.sign.params[len(func.sign.params) - 1].variadic

	if !has_variadic && len(func.sign.params) != len(stmt.args) {
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

	for arg, i in stmt.args {
		params_len := len(func.sign.params)
		// param := i < params_len ? func.sign.params[i] : func.sign.params[params_len - 1]
		param := func.sign.params[i < params_len ? i : params_len - 1]

		if _, is_ident := arg.(Ident); !is_ident {
			gen_same_type(param, arg, span_stmt.span) or_return
		}

		#partial switch arg in arg {
		case string:
			defer gid += 1
			str_name := fmt.tprintf("%s.%s.str.%d", func.sign.name, param.name, gid)
			append(&out.datas, qbe.Data{str_name, qbe.args_str(arg)})
			append(&args, qbe.Arg{.Long, qbe.Glob(str_name)})
		case int:
			append(&args, qbe.Arg{.Long, arg})
		case Ident:
			var := gen_get_var(scope^, string(arg), span_stmt.span) or_return
			gen_same_type(param, var, span_stmt.span) or_return

			append(&args, qbe.Arg{gen_type(var.type), gen_var_name_to_value(var)})
		case:
			unimplemented()
		}
	}

	qbe_stmt = qbe.Instr(qbe.Call{stmt.name, args[:]})

	return
}

Typable :: union #no_nil {
	Var,
	Func,
	Expr,
	Param,
	VarDef,
}

gen_typable_type :: proc(typable: Typable) -> (type: Type) {
	switch t in typable {
	case Var:
		type = t.type
	case Func:
		type = t.sign.return_type
	case Expr:
		type = gen_expr_to_type(t)
	case Param:
		type = t.type
	case VarDef:
		type = t.type
	}

	return
}

gen_typable_main_str :: proc(typable: Typable) -> (str: string) {
	type := gen_typable_type(typable)

	switch t in typable {
	case Var:
		str = fmt.tprintf("Variable %q expected type %v", t.name, type)
	case Func:
		str = fmt.tprintf("Function %q expected return type %v", t.sign.name, type)
	case Expr:
		unimplemented()
	case Param:
		str = fmt.tprintf("Parameter %q expected type %v", t.name, type)
	case VarDef:
		str = fmt.tprintf("Variable %q expected type %v", t.name, type)
	}

	return
}

gen_typable_sec_str :: proc(typable: Typable) -> (str: string) {
	type := gen_typable_type(typable)

	switch t in typable {
	case Var:
		str = fmt.tprintf("but variable %q is %v", t.name, type)
	case Func:
		str = fmt.tprintf("but function %q return type is %v", t.sign.name, type)
	case Expr:
		str = fmt.tprintf("but %v is %v", t, type)
	case Param:
		str = fmt.tprintf("but parameter %q is %v", t.name, type)
	case VarDef:
		str = fmt.tprintf("but variable %q is %v", t.name, type)
	}

	return
}

gen_same_type :: proc(main: Typable, sec: Typable, span: Span) -> (err: Maybe(Error)) {
	main_type := gen_typable_type(main)
	sec_type := gen_typable_type(sec)

	if (main_type != .Any) && (main_type != sec_type) {
		main_str := gen_typable_main_str(main)
		sec_str := gen_typable_sec_str(sec)

		err = error(span, "%s %s", main_str, sec_str)
	}

	return
}

// todo: recursive parents
gen_get_var :: proc(scope: Scope, name: string, span: Span) -> (var: Var, err: Maybe(Error)) {
	if name not_in scope.vars {
		err = error(span, "Variable %q is not defined", name)
		return
	}

	var = scope.vars[name]
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
	switch name in var.qbe_name {
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
