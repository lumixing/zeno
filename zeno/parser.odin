package zeno

import "core:fmt"

Parser :: struct {
	tokens:    []Token,
	top_stmts: [dynamic]Spanned(TopStmt),
	start:     int,
	current:   int,
}

prs_parse :: proc(prs: ^Parser) -> (err: Maybe(Error)) {
	for !prs_end(prs^) {
		prs.start = prs.current
		top_stmt_maybe := prs_top_stmt(prs) or_return
		top_stmt := top_stmt_maybe.? or_continue
		append(&prs.top_stmts, top_stmt)
	}

	return
}

prs_top_stmt :: proc(prs: ^Parser) -> (top_stmt: Maybe(Spanned(TopStmt)), err: Maybe(Error)) {
	token := prs_peek(prs^)

	#partial switch token.type {
	case .Ident:
		top_stmt = prs_func_def(prs) or_return
	case .Directive:
		switch token.value.(Directive) {
		case .Foreign:
			top_stmt = prs_foreign_dir(prs) or_return
		case .Builtin:
			top_stmt = prs_builtin_dir(prs) or_return
		}
	case .EOF, .Newline:
		prs.current += 1
		top_stmt = nil
	case:
		err = error(token.span, "Expected top statement but got %v", token.type)
	}

	return
}

prs_func_sign :: proc(prs: ^Parser) -> (func_sign: FuncSign, err: Maybe(Error)) {
	span := prs_peek(prs^).span

	name := prs_expect(prs, .Ident) or_return
	prs_expect(prs, .LParen) or_return

	params: [dynamic]Param
	param, param_err := prs_param(prs)
	if param_err, param_err_ok := param_err.?; !param_err_ok {
		append(&params, param)
		// todo: not handled for first parameter variadic
		has_variadic := false

		for prs_peek(prs^).type != .RParen {
			prs_expect(prs, .Comma) or_return
			param := prs_param(prs) or_return

			if has_variadic {
				// todo: add span!
				err = error(span, "Function cannot have any parameters after variadic one")
				return
			}

			if param.variadic {
				has_variadic = true
			}

			append(&params, param)
		}
	} else {
		prs.current -= param_err.consumed
		// todo: error is not correct!
		// there should be an error for the first error (ignore since optional)
		// and for the other errors (param error) but thats too complicated!!
		// err = param_err
		// return
	}

	prs_expect(prs, .RParen) or_return

	ret_type, ret_type_err := prs_type(prs)
	if ret_type_err, ret_type_err_ok := ret_type_err.?; ret_type_err_ok {
		prs.current -= ret_type_err.consumed
		ret_type = .Void
	}

	func_sign = {name.(Literal).(string), params[:], ret_type}
	return
}

prs_func_def :: proc(prs: ^Parser) -> (func_def: Spanned(TopStmt), err: Maybe(Error)) {
	span := prs_peek(prs^).span

	sign := prs_func_sign(prs) or_return
	body := prs_block(prs) or_return

	func_def.span = span
	func_def.value = FuncDef{sign, body}
	return
}

prs_foreign_dir :: proc(prs: ^Parser) -> (foreign_dir: Spanned(TopStmt), err: Maybe(Error)) {
	span := prs_peek(prs^).span

	prs_expect(prs, .Directive) or_return
	sign := prs_func_sign(prs) or_return
	prs_expect(prs, .Newline) or_return

	foreign_dir.span = span
	foreign_dir.value = ForeignFuncDecl{sign}
	return
}

prs_builtin_dir :: proc(prs: ^Parser) -> (builtin_dir: Spanned(TopStmt), err: Maybe(Error)) {
	span := prs_peek(prs^).span

	prs_expect(prs, .Directive) or_return
	sign := prs_func_sign(prs) or_return
	prs_expect(prs, .Newline) or_return

	builtin_dir.span = span
	builtin_dir.value = BuiltinFuncDecl{sign}
	return
}

prs_block :: proc(prs: ^Parser) -> (stmts: []Spanned(Stmt), err: Maybe(Error)) {
	prs_expect(prs, .LBrace) or_return
	prs_newline(prs)

	dyn_stmts: [dynamic]Spanned(Stmt)
	for prs_peek(prs^).type != .RBrace {
		stmt := prs_stmt(prs) or_return
		append(&dyn_stmts, stmt)
	}
	stmts = dyn_stmts[:]

	prs_expect(prs, .RBrace) or_return

	return
}

prs_stmt :: proc(prs: ^Parser) -> (stmt: Spanned(Stmt), err: Maybe(Error)) {
	token := prs_peek(prs^)

	#partial switch token.type {
	case .Ident:
		#partial switch prs_peek(prs^, 1).type {
		case .LParen:
			stmt = prs_func_call(prs) or_return
		case:
			stmt = prs_var_def(prs) or_return
		}
	case .KW_Return:
		stmt = prs_return(prs) or_return
	case:
		err = error(token.span, "Expected statement but got %v", token.type)
	}

	prs_expect(prs, .Newline) or_return
	prs_newline(prs)

	return
}

prs_var_def :: proc(prs: ^Parser) -> (var_def: Spanned(Stmt), err: Maybe(Error)) {
	span := prs_peek(prs^).span

	name := prs_expect(prs, .Ident) or_return
	type := prs_type(prs) or_return
	prs_expect(prs, .Equals) or_return
	value := prs_expr(prs) or_return

	var_def.span = span
	var_def.value = VarDef{name.(Literal).(string), type, value}
	return
}

prs_func_call :: proc(
	prs: ^Parser,
	is_builtin := false,
) -> (
	func_call: Spanned(Stmt),
	err: Maybe(Error),
) {
	span := prs_peek(prs^).span

	name := prs_expect(prs, .Ident) or_return

	prs_expect(prs, .LParen) or_return

	args: [dynamic]Expr
	expr, expr_err := prs_expr(prs)
	if expr_err, expr_err_ok := expr_err.?; !expr_err_ok {
		append(&args, expr)
		// todo: not handled for first parameter variadic
		has_variadic := false

		for prs_peek(prs^).type != .RParen {
			prs_expect(prs, .Comma) or_return
			expr := prs_expr(prs) or_return

			append(&args, expr)
		}
	} else {
		prs.current -= expr_err.consumed
	}

	prs_expect(prs, .RParen) or_return

	func_call.span = span
	func_call.value = FuncCall{name.(Literal).(string), args[:], is_builtin}
	return
}

prs_return :: proc(prs: ^Parser) -> (ret: Spanned(Stmt), err: Maybe(Error)) {
	span := prs_peek(prs^).span

	prs_expect(prs, .KW_Return) or_return

	expr, expr_err := prs_expr(prs)
	if expr_err, expr_err_ok := expr_err.?; expr_err_ok {
		prs.current -= expr_err.consumed
		ret.value = Return{nil}
	} else {
		ret.value = Return{expr}
	}

	ret.span = span
	return
}

prs_expr :: proc(prs: ^Parser) -> (expr: Expr, err: Maybe(Error)) {
	init_current := prs.current
	token := prs_peek(prs^)

	#partial switch token.type {
	case .Ident:
		if prs_peek(prs^, 1).type == .LParen {
			func_call := prs_func_call(prs) or_return
			expr = func_call.value.(FuncCall)
			return
		}

		prs.current += 1
		expr = Variable(token.value.(Literal).(string))
	case .String:
		prs.current += 1
		expr = token.value.(Literal)
	case .Int:
		prs.current += 1
		expr = token.value.(Literal)
	case .Bool:
		prs.current += 1
		expr = token.value.(Literal)
	case .At:
		prs.current += 1
		func_call := prs_func_call(prs) or_return
		expr = func_call.value.(FuncCall)
	case:
		cons := prs.current - init_current
		err = error(token.span, "Expected expression but got %v", token.type, consumed = cons)
	}

	return
}

prs_param :: proc(prs: ^Parser) -> (param: Param, err: Maybe(Error)) {
	init_current := prs.current

	// name := prs_expect(prs, .Ident) or_return
	name, name_err := prs_expect(prs, .Ident)
	if name_err, name_err_ok := name_err.?; name_err_ok {
		name_err.consumed = prs.current - init_current
		err = name_err
		return
	}

	variadic := false
	if prs_peek(prs^).type == .DotDot {
		prs.current += 1
		variadic = true
	}

	// type := prs_type(prs) or_return
	type, type_err := prs_type(prs)
	if type_err, type_err_ok := type_err.?; type_err_ok {
		type_err.consumed = prs.current - init_current
		err = type_err
		return
	}

	param = {name.(Literal).(string), type, variadic}
	return
}

prs_type :: proc(prs: ^Parser) -> (type: Type, err: Maybe(Error)) {
	init_current := prs.current
	token := prs_consume(prs)

	#partial switch token.type {
	case .KW_Void:
		type = .Void
	case .KW_Str:
		type = .String
	case .KW_Int:
		type = .Int
	case .KW_Bool:
		type = .Bool
	case .KW_Any:
		type = .Any
	case:
		cons := prs.current - init_current
		err = error(token.span, "Expected type but got %v", token.type, consumed = cons)
	}

	return
}

prs_newline :: proc(prs: ^Parser) {
	for prs_peek(prs^).type == .Newline {
		prs.current += 1
	}
}

prs_expect :: proc(prs: ^Parser, exp_type: TokenType) -> (value: TokenValue, err: Maybe(Error)) {
	token := prs_consume(prs)

	if token.type == exp_type {
		return token.value, nil
	}

	err = error(token.span, "Expected %v but got %v", exp_type, token.type)

	return
}

prs_consume :: proc(prs: ^Parser, loc := #caller_location) -> Token {
	if prs_end(prs^) {
		fmt.panicf(
			"Tried to consume while parsing ended (%d~%d, %d) (%v)",
			prs.start,
			prs.current,
			len(prs.tokens),
			loc,
		)
	}

	defer prs.current += 1
	return prs_peek(prs^)
}

prs_peek :: proc(prs: Parser, ahead := 0, loc := #caller_location) -> Token {
	if prs_end(prs) {
		fmt.panicf(
			"Tried to peek while parsing ended (%d~%d+%d, %d) (%v)",
			prs.start,
			prs.current,
			ahead,
			len(prs.tokens),
			loc,
		)
	}

	return prs.tokens[prs.current + ahead]
}

prs_end :: proc(prs: Parser) -> bool {
	return prs.current >= len(prs.tokens)
}
