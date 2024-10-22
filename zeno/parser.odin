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

			parser_expect(parser, .LParen)
			parser_expect(parser, .RParen)
			ret_type, err := parse_type(parser)
			if err, ok := err.?; ok {
				err_log(parser.source, err.lo, err.str)
			}
			parser_expect(parser, .LBrace)

			func_stmts: [dynamic]Stmt
			for parser_peek(parser^).type != .RBrace {
				stmt, err := parse_stmt(parser)
				if err, ok := err.?; ok {
					err_log(parser.source, err.lo, err.str)
				}
				append(&func_stmts, stmt)
			}

			parser_expect(parser, .RBrace)

			append(&parser.top_stmts, FuncDeclare{func_name, func_stmts[:], ret_type})
		case .Directive:
			#partial switch token.value.(Directive) {
			case .Foreign:
				func_name := parser_expect(parser, .Ident).(string)
				parser_expect(parser, .LParen)
				param_type, err := parse_type(parser)
				if err, ok := err.?; ok {
					err_log(parser.source, err.lo, err.str)
				}
				parser_expect(parser, .RParen)
				return_type: Type
				return_type, err = parse_type(parser)
				if err, ok := err.?; ok {
					err_log(parser.source, err.lo, err.str)
				}

				parser_whitespace(parser, false)
				parser_expect(parser, .Newline, false)
				parser_whitespace(parser)

				params := [dynamic]Param{{"", param_type}}

				append(&parser.top_stmts, ForeignFuncDeclare{func_name, params[:], return_type})
			}
		case .Whitespace, .Newline, .EOF:
		case:
			err_log(parser.source, token.span.lo, "expected function name but got %v", token.type)
		}
	}
}

parse_stmt :: proc(parser: ^Parser) -> (Stmt, Maybe(Error)) {
	stmt: Stmt
	parser_whitespace(parser)

	token := parser_advance(parser)
	#partial switch token.type {
	case .Ident:
		call_name := token.value.(string)
		parser_whitespace(parser)

		if parser_peek(parser^).type == .LParen {
			parser_expect(parser, .LParen)
			// call_str := parser_expect(parser, .String).(string)
			arg_expr, err := parse_expr(parser)
			parser_whitespace(parser)
			parser_expect(parser, .RParen, false)

			stmt = FuncCall{call_name, [dynamic]Expr{arg_expr}[:]}
		} else if type, err := parse_type(parser); err == nil {
			parser_expect(parser, .Equals)
			expr: Expr

			switch type {
			case .Int:
				expr = parser_expect(parser, .Int, false).(int)
			case .String:
				expr = parser_expect(parser, .String, false).(string)
			case .Void:
				err_log(
					parser.source,
					token.span.lo,
					"tried declaring variable %q of type void",
					call_name,
				)
			}

			stmt = VarDecl{call_name, type, expr}
		} else {
			err_log(parser.source, token.span.lo, "expected LParen or type but got %v", token.type)
		}

		parser_whitespace(parser, false)
		parser_expect(parser, .Newline, false)
		parser_whitespace(parser)
	case:
		err_log(parser.source, token.span.lo, "expected statement but got %v", token.type)
	}

	return stmt, nil
}

parse_expr :: proc(parser: ^Parser) -> (Expr, Maybe(Error)) {
	parser_whitespace(parser)

	token := parser_advance(parser)
	#partial switch token.type {
	case .String:
		return token.value.(string), nil
	case .Int:
		return token.value.(int), nil
	case .Ident:
		return VarIdent(token.value.(string)), nil
	}

	parser.current -= 1 // prob error prone due to whitespace, pls fix
	return {}, Error{token.span.lo, fmt.tprintf("expected an expression but got %v", token.type)}
}

parse_type :: proc(parser: ^Parser) -> (Type, Maybe(Error)) {
	token := parser_advance(parser)
	#partial switch token.type {
	case .KW_Int:
		return .Int, nil
	case .KW_Str:
		return .String, nil
	case .KW_Void:
		return .Void, nil
	}

	// err_log(parser.source, token.span.lo, "expected a type but got %v", token.type)
	return {}, Error{token.span.lo, fmt.tprintf("expected a type but got %v", token.type)}
}

parser_whitespace :: proc(parser: ^Parser, newline := true) {
	for parser_peek(parser^).type == .Whitespace ||
	    (newline && parser_peek(parser^).type == .Newline) {
		parser.current += 1
	}
}

parser_expect :: proc(
	parser: ^Parser,
	token_type: TokenType,
	whitespace_between := true,
) -> TokenValue {
	if whitespace_between {
		parser_whitespace(parser)
	}
	defer if whitespace_between {
		parser_whitespace(parser)
	}

	if token := parser_advance(parser); token.type == token_type {
		return token.value
	} else {
		err_log(parser.source, token.span.lo, "expected %v but got %v", token_type, token.type)
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
