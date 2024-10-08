package zeno

import "core:fmt"

Parser :: struct {
	source:    []u8,
	tokens:    []Token,
	top_stmts: [dynamic]TopStmt,
	start:     int,
	current:   int,
}

parser_parse :: proc(parser: ^Parser) {
	for !parser_end(parser^) {
		parser.start = parser.current
		token := parser_advance(parser)

		#partial switch token.type {
		case .Ident:
			func_name := token.value.(string)

			parser_whitespace(parser)
			parser_expect(parser, .LParen)
			parser_whitespace(parser)
			parser_expect(parser, .RParen)
			parser_whitespace(parser)
			parser_expect(parser, .LBrace)
			parser_whitespace(parser)

			func_stmts: [dynamic]Stmt
			for parser_peek(parser^).type == .Ident {
				stmt, error := parse_stmt(parser)
				if error != nil {
					// panic("a  fucking error occurd")
					err(parser.source, error.?.lo, error.?.str)
				}
				append(&func_stmts, stmt.?)
			}

			parser_whitespace(parser)
			parser_expect(parser, .RBrace)
			parser_whitespace(parser)

			append(&parser.top_stmts, FuncDeclare{func_name, func_stmts[:]})
		case .EOF:
		case:
			err(parser.source, token.span.lo, "expected function name but got %v", token.type)
		}
	}
}

parse_stmt :: proc(parser: ^Parser) -> (Stmt, Maybe(Error)) {
	parser_whitespace(parser)

	call_name, err := parser_expect_err(parser, .Ident)
	if err != nil do return nil, err

	if _, err := parser_expect_err(parser, .LParen); err != nil do return nil, err

	call_str, err2 := parser_expect_err(parser, .String)
	if err2 != nil do return nil, err2

	if _, err := parser_expect_err(parser, .RParen); err != nil do return nil, err
	parser_whitespace(parser, false)
	if _, err := parser_expect_err(parser, .Newline); err != nil do return nil, err
	parser_whitespace(parser)

	return FuncCall{call_name.(string), [dynamic]Expr{call_str.(string)}[:]}, nil
}

parser_whitespace :: proc(parser: ^Parser, newline := true) {
	for parser_peek(parser^).type == .Whitespace ||
	    (newline && parser_peek(parser^).type == .Newline) {
		parser.current += 1
	}
}

parser_expect :: proc(parser: ^Parser, token_type: TokenType) -> TokenValue {
	if token := parser_advance(parser); token.type == token_type {
		return token.value
	} else {
		err(parser.source, token.span.lo, "expected %v but got %v", token_type, token.type)
	}
}

parser_expect_err :: proc(parser: ^Parser, token_type: TokenType) -> (TokenValue, Maybe(Error)) {
	if token := parser_advance(parser); token.type == token_type {
		return token.value, nil
	} else {
		return nil, Error {
			token.span.lo,
			fmt.tprintf("expected %v but got %v", token_type, token.type),
		}
	}
}

parser_end :: proc(parser: Parser) -> bool {
	return parser.current >= len(parser.tokens)
}

parser_advance :: proc(parser: ^Parser) -> Token {
	defer parser.current += 1
	return parser_peek(parser^)
}

parser_peek :: proc(parser: Parser) -> Token {
	if parser_end(parser) {
		return {}
	}
	return parser.tokens[parser.current]
}
