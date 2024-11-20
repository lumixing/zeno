package zeno

import "core:fmt"

Parser :: struct {
	tokens:    []Token,
	top_stmts: [dynamic]TopStmt,
	start:     int,
	current:   int,
}

prs_parse :: proc(prs: ^Parser) -> Maybe(Error) {
	for !prs_end(prs^) {
		prs.start = prs.current
		token := prs_peek(prs^)

		#partial switch token.type {
		case .Ident:
			tstmt := prs_func_decl(prs) or_return
			append(&prs.top_stmts, tstmt)
		case .Directive:
			switch token.value.(Directive) {
			case .Foreign:
				tstmt := prs_foreign_func_decl(prs) or_return
				append(&prs.top_stmts, tstmt)
			}
		case .Newline, .EOF:
			prs.current += 1
		case:
			return error(token.span, "Expected top statement but got %v", token.type)
		}
	}

	return nil
}

prs_func_sign :: proc(
	prs: ^Parser,
) -> (
	func_name: string,
	func_params: []Param,
	func_ret_type: Type,
	err: Maybe(Error),
) {
	name := prs_expect(prs, .Ident) or_return
	prs_expect(prs, .LParen) or_return

	params: [dynamic]Param
	if prs_peek(prs^).type == .Ident {
		param := prs_param(prs) or_return
		append(&params, param)

		for prs_peek(prs^).type != .RParen {
			prs_expect(prs, .Comma) or_return
			param := prs_param(prs) or_return
			append(&params, param)
		}
	}

	prs_expect(prs, .RParen) or_return
	ret_type := prs_type(prs).? or_else .Void

	return name.(string), params[:], ret_type, nil
}

prs_func_decl :: proc(prs: ^Parser) -> (func_decl: FuncDecl, err: Maybe(Error)) {
	name, params, ret_type := prs_func_sign(prs) or_return
	prs_expect(prs, .LBrace) or_return
	prs_newline(prs)

	stmts: [dynamic]Stmt
	for prs_peek(prs^).type != .RBrace {
		stmt := prs_stmt(prs) or_return
		append(&stmts, stmt)
	}

	prs_expect(prs, .RBrace) or_return

	return {name, params, stmts[:], ret_type}, nil
}

prs_foreign_func_decl :: proc(
	prs: ^Parser,
) -> (
	foreign_func_decl: ForeignFuncDecl,
	err: Maybe(Error),
) {
	prs_expect(prs, .Directive) or_return // directive type is already checked
	name, params, ret_type := prs_func_sign(prs) or_return
	prs_expect(prs, .Newline) or_return

	return {name, params, ret_type}, nil
}

prs_param :: proc(prs: ^Parser) -> (param: Param, err: Maybe(Error)) {
	param_name := prs_expect(prs, .Ident) or_return
	param_type := prs_type_err(prs) or_return

	return {param_name.(string), param_type}, nil
}

prs_stmt :: proc(prs: ^Parser) -> (stmt: Stmt, err: Maybe(Error)) {
	token := prs_peek(prs^)

	#partial switch token.type {
	case .Ident:
		token1 := prs_peek(prs^, 1)
		#partial switch token1.type {
		case .LParen:
			stmt := prs_func_call(prs) or_return
			return stmt, nil
		}
		stmt := prs_var_decl(prs) or_return
		return stmt, nil
	}

	return nil, error(token.span, "Expected statement but got %v", token.type)
}

prs_var_decl :: proc(prs: ^Parser) -> (stmt: VarDecl, err: Maybe(Error)) {
	name := prs_expect(prs, .Ident) or_return
	type := prs_type_err(prs) or_return
	prs_expect(prs, .Equals) or_return
	expr := prs_expr(prs) or_return
	prs_expect(prs, .Newline)
	prs_newline(prs)

	return {name.(string), type, expr}, nil
}

prs_func_call :: proc(prs: ^Parser) -> (func_call: FuncCall, err: Maybe(Error)) {
	name := prs_expect(prs, .Ident) or_return
	prs_expect(prs, .LParen) or_return

	args: [dynamic]Expr
	if expr, err := prs_expr(prs); err == nil {
		append(&args, expr)

		for prs_peek(prs^).type != .RParen {
			prs_expect(prs, .Comma) or_return
			expr := prs_expr(prs) or_return
			append(&args, expr)
		}
	} else {
		// todo: backtracking using (consumed: int) result
		// expr, consumed, err := prs_expr(prs)
		// prs.current -= consumed
		prs.current -= 1
	}

	prs_expect(prs, .RParen) or_return
	prs_newline(prs)

	return {name.(string), args[:]}, nil
}

prs_type :: proc(prs: ^Parser) -> Maybe(Type) {
	token := prs_consume(prs)
	type: Maybe(Type)

	#partial switch token.type {
	case .KW_Void:
		type = .Void
	case .KW_Str:
		type = .String
	case .KW_Int:
		type = .Int
	case .KW_Bool:
		type = .Bool
	case:
		type = nil
		prs.current -= 1
	}

	return type
}

prs_type_err :: proc(prs: ^Parser) -> (Type, Maybe(Error)) {
	token := prs_peek(prs^)

	if type, ok := prs_type(prs).?; ok {
		return type, nil
	}

	return nil, error(token.span, "Expected type but got %v", token.type)
}

prs_expr :: proc(prs: ^Parser) -> (expr: Expr, err: Maybe(Error)) {
	token := prs_consume(prs)

	#partial switch token.type {
	case .Ident:
		return VarIdent(token.value.(string)), nil
	case .String:
		return token.value.(string), nil
	case .Int:
		return token.value.(int), nil
	case .Bool:
		return token.value.(bool), nil
	}

	return nil, error(token.span, "Expected expression but got %v", token.type)
}

prs_newline :: proc(prs: ^Parser) {
	for prs_peek(prs^).type == .Newline {
		prs.current += 1
	}
}

prs_expect :: proc(prs: ^Parser, type: TokenType) -> (TokenValue, Maybe(Error)) {
	token := prs_consume(prs)

	if token.type == type {
		return token.value, nil
	}

	return nil, error(token.span, "Expected %v but got %v", type, token.type)
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
			"Tried to peek while parsing ended (%d~%d, %d) (%v)",
			prs.start,
			prs.current,
			len(prs.tokens),
			loc,
		)
	}

	return prs.tokens[prs.current + ahead]
}

prs_end :: proc(prs: Parser) -> bool {
	return prs.current >= len(prs.tokens)
}
