package zeno

import "../qbe"

QbeOut :: struct {
	datas: [dynamic]qbe.Data,
	funcs: [dynamic]qbe.Func,
}

Func :: struct {
	sign:       FuncSign,
	is_foreign: bool,
}

Var :: struct {
	name: string,
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

		scope.vars[param.name] = Var{param.name, param.type}

		append(&params, qbe.Param{param.name, gen_type(param.type)})
	}
	func.params = params[:]

	func.exported = true

	append(&out.funcs, func)

	return
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
		unreachable()
	case .Bool, .Int:
		qbe_type = .Word
	case .String:
		qbe_type = .Long
	case .Void:
		qbe_type = nil
	}

	return
}
