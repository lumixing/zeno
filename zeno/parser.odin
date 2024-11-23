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
	case .EOF, .Newline:
		prs.current += 1
		top_stmt = nil
	case:
		err = error(token.span, "Expected top statement but got %v", token.type)
	}

	return
}

prs_func_sign :: proc(prs: ^Parser) -> (func_sign: FuncSign, err: Maybe(Error)) {
	span_lo := prs.current

	name := prs_expect(prs, .Ident) or_return
	prs_expect(prs, .LParen) or_return

	params: [dynamic]Param
	param, param_err := prs_param(prs)
	if param_err, param_err_ok := param_err.?; !param_err_ok {
		append(&params, param)
		has_variadic := false

		for prs_peek(prs^).type != .RParen {
			prs_expect(prs, .Comma) or_return
			param := prs_param(prs) or_return

			if has_variadic {
				// todo: add span!
				err = error(
					span(span_lo),
					"Function cannot have any parameters after variadic one",
				)
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

	func_sign = {name.(string), params[:], ret_type}
	return
}

prs_func_def :: proc(prs: ^Parser) -> (func_def: Spanned(TopStmt), err: Maybe(Error)) {
	span_lo := prs.current

	sign := prs_func_sign(prs) or_return
	body := prs_block(prs) or_return

	func_def.span = span(span_lo)
	func_def.value = FuncDef{sign, body}
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
		stmt = prs_var_def(prs) or_return
	case:
		err = error(token.span, "Expected statement but got %v", token.type)
	}

	prs_expect(prs, .Newline) or_return
	prs_newline(prs)

	return
}

prs_var_def :: proc(prs: ^Parser) -> (var_def: Spanned(Stmt), err: Maybe(Error)) {
	span_lo := prs.current

	name := prs_expect(prs, .Ident) or_return
	type := prs_type(prs) or_return
	prs_expect(prs, .Equals) or_return
	value := prs_expr(prs) or_return

	var_def.span = span(span_lo)
	var_def.value = VarDef{name.(string), type, value}
	return
}

prs_expr :: proc(prs: ^Parser) -> (expr: Expr, err: Maybe(Error)) {
	token := prs_consume(prs)

	#partial switch token.type {
	case .Ident:
		expr = Ident(token.value.(string))
	case .String:
		expr = token.value.(string)
	case .Int:
		expr = token.value.(int)
	case .Bool:
		expr = token.value.(bool)
	case:
		err = error(token.span, "Expected expression but got %v", token.type)
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

	param = {name.(string), type, variadic}
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
