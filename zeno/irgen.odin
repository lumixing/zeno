package zeno

import "../qbe"
import "core:fmt"

Gen :: struct {
	out:   QbeOut,
	funcs: map[string]Func,
	scope: Scope,
}

QbeOut :: struct {
	datas: [dynamic]qbe.Data,
	funcs: [dynamic]qbe.Func,
}

Func :: struct {
	sign: FuncSign,
	kind: FuncKind,
}

FuncKind :: enum {
	Normal,
	Foreign,
	Builtin,
}

Scope :: struct {
	parent:   Maybe(^Scope),
	children: [dynamic]^Scope,
	vars:     map[string]Var,
}

Var :: struct {
	name:     string,
	qbe_name: union {
		qbe.Temp,
		qbe.Glob,
	},
	type:     Type,
	ptr:      Maybe(^Var),
}

var_new_temp :: proc(name: string, type: Type, ptr: Maybe(^Var) = nil) -> Var {
	return Var{name = name, qbe_name = qbe.Temp(name), type = type, ptr = ptr}
}

var_new_glob :: proc(name: string, type: Type, ptr: Maybe(^Var) = nil) -> Var {
	return Var{name = name, qbe_name = qbe.Glob(name), type = type, ptr = ptr}
}

gen_qbe :: proc(top_stmts: []Spanned(TopStmt)) -> (out: Gen, err: Maybe(Error)) {
	gen: Gen

	for span_tstmt in top_stmts {
		switch tstmt in span_tstmt.value {
		case ForeignFuncDecl:
			gen_func_decl(&gen, span_tstmt, .Foreign, ForeignFuncDecl) or_return
		case BuiltinFuncDecl:
			gen_func_decl(&gen, span_tstmt, .Builtin, BuiltinFuncDecl) or_return
		case FuncDef:
			gen_func_def(&gen, span_tstmt) or_return
		}
	}

	out = gen
	return
}

gen_func_decl :: proc(
	gen: ^Gen,
	span_tstmt: Spanned(TopStmt),
	func_kind: FuncKind,
	$T: typeid,
) -> (
	err: Maybe(Error),
) {
	assert(func_kind != .Normal)
	tstmt := span_tstmt.value.(T)

	gen_check_name_in_funcs(gen^, tstmt.sign.name, span_tstmt.span) or_return

	gen.funcs[tstmt.sign.name] = Func {
		sign = tstmt.sign,
		kind = .Foreign,
	}

	return
}

gen_func_def :: proc(gen: ^Gen, span_tstmt: Spanned(TopStmt)) -> (err: Maybe(Error)) {
	tstmt := span_tstmt.value.(FuncDef)

	gen_check_name_in_funcs(gen^, tstmt.sign.name, span_tstmt.span) or_return
	// todo: validate return type (for example no any)

	gen.funcs[tstmt.sign.name] = Func {
		sign = tstmt.sign,
		kind = .Normal,
	}

	scope := new(Scope)
	scope.parent = &gen.scope
	append(&gen.scope.children, scope)

	qbe_func := qbe.Func {
		name        = tstmt.sign.name,
		return_type = gen_type(tstmt.sign.return_type),
		exported    = true,
	}

	params: [dynamic]qbe.Param
	for param in tstmt.sign.params {
		gen_check_name_in_funcs(gen^, tstmt.sign.name, span_tstmt.span) or_return
		gen_check_name_in_scope(scope^, tstmt.sign.name, span_tstmt.span) or_return

		scope.vars[param.name] = var_new_temp(param.name, param.type)

		append(&params, qbe.Param{name = param.name, type = gen_type(param.type)})
	}
	qbe_func.params = params[:]

	body: [dynamic]qbe.Stmt
	append(&body, qbe.Label("start"))

	for stmt in tstmt.body {
		stmts := gen_stmt(gen, stmt, scope, gen.funcs[tstmt.sign.name]) or_return
		for stmt in stmts {
			append(&body, stmt)
		}
	}
	qbe_func.body = body[:]

	append(&gen.out.funcs, qbe_func)

	return
}

gen_stmt :: proc(
	gen: ^Gen,
	span_stmt: Spanned(Stmt),
	scope: ^Scope,
	func: Func,
) -> (
	qbe_stmts: []qbe.Stmt,
	err: Maybe(Error),
) {
	qbe_stmts_dyn: [dynamic]qbe.Stmt

	#partial switch stmt in span_stmt.value {
	case VarDef:
		qbe_stmts_dyn = gen_var_def(gen, span_stmt, scope) or_return
	case Return:
	case FuncCall:
	}

	// insert newline after each loc
	if len(qbe_stmts_dyn) != 0 {
		append(&qbe_stmts_dyn, nil)
	}

	qbe_stmts = qbe_stmts_dyn[:]
	return
}

gen_var_def :: proc(
	gen: ^Gen,
	span_stmt: Spanned(Stmt),
	scope: ^Scope,
) -> (
	qbe_stmts: [dynamic]qbe.Stmt,
	err: Maybe(Error),
) {
	stmt := span_stmt.value.(VarDef)
	span := span_stmt.span

	gen_check_name_in_funcs(gen^, stmt.name, span) or_return
	gen_check_name_in_scope(scope^, stmt.name, span) or_return

	#partial switch type in stmt.type {
	case BaseType:
		#partial switch type {
		case .String:

		case .Int:
			ptr_var_name := fmt.tprintf("%s.ptr", stmt.name)
			ptr_var_type := new_clone(PointerType(.Int))

			ptr_var := new_clone(var_new_temp(ptr_var_name, ptr_var_type))
			scope.vars[ptr_var_name] = ptr_var^

			var := var_new_temp(stmt.name, .Int, ptr_var)
			scope.vars[stmt.name] = var

			append(&qbe_stmts, qbe.TempDef{ptr_var_name, .Long, qbe.Alloc{.a8, size_of(i32)}})

			#partial switch value in stmt.value {
			case Literal:
				if _, is_int := value.(int); !is_int {
					gen_err_var_type(span, stmt) or_return
				}

				store_instr := qbe.Store{gen_type(type), value.(int), gen_var(ptr_var^)}
				append(&qbe_stmts, qbe.Instr(store_instr))

				load_instr := qbe.Load{.Word, gen_var(ptr_var^)}
				append(&qbe_stmts, qbe.TempDef{stmt.name, gen_type(type), load_instr})
			case Variable:
				var := gen_get_var(scope^, string(value), span) or_return

				if var.type != stmt.type {
					err_msg := "Variable %q expected type %v but variable %q has type %v"
					err = error(span, err_msg, stmt.name, stmt.type, var.name, var.type)
					return
				}

				store_instr := qbe.Store{gen_type(type), gen_var(var), gen_var(ptr_var^)}
				append(&qbe_stmts, qbe.Instr(store_instr))

				load_instr := qbe.Load{.Word, gen_var(ptr_var^)}
				append(&qbe_stmts, qbe.TempDef{stmt.name, gen_type(type), load_instr})
			}
		}
	}

	return
}

gen_get_var :: proc(scope: Scope, name: string, span: Span) -> (var: Var, err: Maybe(Error)) {
	if name not_in scope.vars {
		err = error(span, "Variable %q is not declared", name)
		return
	}

	var = scope.vars[name]
	return
}

gen_check_name_in_funcs :: proc(gen: Gen, name: string, span: Span) -> (err: Maybe(Error)) {
	if name in gen.funcs {
		err = error(span, "%q is already declared as a function", name)
	}

	return
}

gen_check_name_in_scope :: proc(scope: Scope, name: string, span: Span) -> (err: Maybe(Error)) {
	// todo: recursive for parent
	if name in scope.vars {
		err = error(span, "%q is already declared as a variable", name)
	}

	return
}

gen_type :: proc(type: Type) -> (qbe_type: qbe.Type) {
	switch type in type {
	case BaseType:
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
	case ^PointerType:
		qbe_type = .Long
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

gen_var :: proc(var: Var) -> (value: qbe.Value) {
	switch name in var.qbe_name {
	case qbe.Glob:
		value = name
	case qbe.Temp:
		value = name
	}

	return
}
