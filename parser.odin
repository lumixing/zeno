package zeno

import "core:fmt"

Parser :: struct {
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
				stmt := parse_stmt(parser)
				append(&func_stmts, stmt.?)
			}

			parser_whitespace(parser)
			parser_expect(parser, .RBrace)
			parser_whitespace(parser)

			append(&parser.top_stmts, FuncDeclare{func_name, func_stmts[:]})
		case .EOF:
		case:
			fmt.panicf("expected Ident (for funcdecl) but got %v", token)
		}
	}
}

parse_stmt :: proc(parser: ^Parser) -> Maybe(Stmt) {
	parser_whitespace(parser)

	call_name, ok := parser_expect_ok(parser, .Ident).(string)
	if !ok do return nil

	if _, ok := parser_expect_ok(parser, .LParen); !ok do return nil

	call_str, ok2 := parser_expect_ok(parser, .String).(string)
	if !ok2 do return nil

	if _, ok := parser_expect_ok(parser, .RParen); !ok do return nil
	parser_whitespace(parser, false)
	if _, ok := parser_expect_ok(parser, .Newline); !ok do return nil
	parser_whitespace(parser)

	return FuncCall{call_name, [dynamic]Expr{call_str}[:]}
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
		fmt.panicf("expected %v, got %v", token_type, token.type)
	}
}

parser_expect_ok :: proc(
	parser: ^Parser,
	token_type: TokenType,
) -> (
	TokenValue,
	bool,
) #optional_ok {
	if token := parser_advance(parser); token.type == token_type {
		return token.value, true
	} else {
		return nil, false
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

get_line_col :: proc(src: string, lo: int) -> (line, col: int) {
	line = 1
	col = 1
	for i in 0 ..< lo {
		if src[i] == '\n' {
			line += 1
			col = 1
		} else {
			col += 1
		}
	}
	return line, col
}
