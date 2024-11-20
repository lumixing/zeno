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
		case .Newline, .EOF:
			prs.current += 1
		case:
			return error(token.span, "Expected top statement but got %v", token.type)
		}
	}

	return nil
}

prs_func_decl :: proc(prs: ^Parser) -> (func_decl: FuncDecl, err: Maybe(Error)) {
	name := prs_expect(prs, .Ident) or_return
	prs_expect(prs, .LParen) or_return
	prs_expect(prs, .RParen) or_return
	type := prs_type(prs).? or_else .Void
	prs_expect(prs, .LBrace) or_return
	prs_newline(prs)

	stmts: [dynamic]Stmt
	for prs_peek(prs^).type != .RBrace {
		stmt := prs_stmt(prs) or_return
		append(&stmts, stmt)
	}

	prs_expect(prs, .RBrace) or_return

	return {name.(string), {}, stmts[:], type}, nil
}

prs_stmt :: proc(prs: ^Parser) -> (stmt: Stmt, err: Maybe(Error)) {
	token := prs_peek(prs^)

	#partial switch token.type {
	case .Ident:
		stmt := prs_var_decl(prs) or_return
		return stmt, nil
	}

	return nil, error(token.span, "Expected statement but got %v", token.type)
}

prs_var_decl :: proc(prs: ^Parser) -> (stmt: VarDecl, err: Maybe(Error)) {
	name := prs_expect(prs, .Ident) or_return
	type := prs_type_err(prs) or_return
	prs_expect(prs, .Equals) or_return
	str := prs_expect(prs, .String) or_return
	prs_expect(prs, .Newline)
	prs_newline(prs)

	return {name.(string), type, str.(string)}, nil
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

prs_peek :: proc(prs: Parser, loc := #caller_location) -> Token {
	if prs_end(prs) {
		fmt.panicf(
			"Tried to peek while parsing ended (%d~%d, %d) (%v)",
			prs.start,
			prs.current,
			len(prs.tokens),
			loc,
		)
	}

	return prs.tokens[prs.current]
}

prs_end :: proc(prs: Parser) -> bool {
	return prs.current >= len(prs.tokens)
}
