package zeno

import "core:fmt"

Parser :: struct {
	source:    []u8,
	tokens:    []Token,
	top_stmts: [dynamic]TopStmt,
	start:     int,
	current:   int,
}

ParseReturn :: enum {
	Err,
	Nil,
}

prs_parse :: proc(prs: ^Parser) {
	for !prs_end(prs^) {
		prs.start = prs.current
		token := prs_advance(prs)

		#partial switch token.type {
		case .Ident:
			ident_name := token.value.(string)

			prs_expect(prs, .LParen)
			// todo: param parsing
			prs_expect(prs, .RParen)

			ret_type := prs_type(prs, .Nil).? or_else .Void

			prs_expect(prs, .LBrace)
			// todo: stmt parsing
			prs_expect(prs, .RBrace)

			append(&prs.top_stmts, FuncDeclare{ident_name, {}, ret_type})
		case .Directive:
			switch token.value.(Directive) {
			case .Foreign:
				params: [dynamic]Param

				func_name := prs_expect(prs, .Ident).(string)

				prs_expect(prs, .LParen)
				if param_type, ok := prs_type(prs, .Nil).?; ok {
					append(&params, Param{"", param_type})

					for prs_peek(prs^).type != .RParen {
						if _, ok := prs_expect(prs, .Comma, .Nil); ok {
							param_type := prs_type(prs).?
							append(&params, Param{"", param_type})
						} else {
							// todo: this
							panic("todo: give a meaningful error message here!")
						}
					}
				}
				prs_expect(prs, .RParen)

				ret_type := prs_type(prs, .Nil).? or_else .Void

				prs_expect(prs, .Newline)

				append(&prs.top_stmts, ForeignFuncDeclare{func_name, params[:], ret_type})
			}
		}
	}
}

prs_expect :: proc(
	prs: ^Parser,
	tk_type: TokenType,
	prs_ret: ParseReturn = .Err,
) -> (
	value: TokenValue,
	ok: bool,
) #optional_ok {
	if token := prs_advance(prs); token.type == tk_type {
		return token.value, true
	} else {
		if prs_ret == .Err {
			err_log(prs.source, token.span.lo, "expected %v but got %v", tk_type, token.type)
		} else {
			prs.current -= 1
			return nil, false
		}
	}
}

prs_type :: proc(prs: ^Parser, prs_ret: ParseReturn = .Err) -> Maybe(Type) {
	token := prs_advance(prs)
	#partial switch token.type {
	case .KW_Int:
		return .Int
	case .KW_Str:
		return .String
	case .KW_Void:
		return .Void
	case:
		if prs_ret == .Err {
			err_log(prs.source, token.span.lo, "expected a type but got %v", token.type)
		} else {
			prs.current -= 1
			return nil
		}
	}
}

prs_end :: proc(prs: Parser) -> bool {
	return prs.current >= len(prs.tokens)
}

prs_advance :: proc(prs: ^Parser) -> Token {
	defer prs.current += 1
	return prs_peek(prs^)
}

prs_peek :: proc(prs: Parser) -> Token {
	if prs_end(prs) {
		return {}
	}
	return prs.tokens[prs.current]
}
