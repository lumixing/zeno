package zeno

import "core:fmt"
import "core:os"
import "core:strconv"
import "core:unicode"

Lexer :: struct {
	source:  []u8,
	tokens:  [dynamic]Token,
	start:   int,
	current: int,
}

lexer_scan :: proc(lexer: ^Lexer) -> Maybe(Error) {
	for !lexer_end(lexer^) {
		lexer.start = lexer.current
		char := lexer_advance(lexer)

		switch char {
		case ' ', '\t', '\r':
			for lexer_peek(lexer^) == ' ' ||
			    lexer_peek(lexer^) == '\t' ||
			    lexer_peek(lexer^) == '\r' {
				lexer.current += 1
			}
		case '\n':
			lexer_add(lexer, .Newline)
		case '/':
			// todo: hangs on EOF (check other similar cases)
			if lexer_advance(lexer) == '/' {
				for lexer_peek(lexer^) != '\n' {
					lexer.current += 1
				}
			} else {
				return Error{"Expected another slash for a comment", lexer_span(lexer^)}
			}
		case '(':
			lexer_add(lexer, .LParen)
		case ')':
			lexer_add(lexer, .RParen)
		case '{':
			lexer_add(lexer, .LBrace)
		case '}':
			lexer_add(lexer, .RBrace)
		case '=':
			lexer_add(lexer, .Equals)
		case ',':
			lexer_add(lexer, .Comma)
		case '"':
			terminated := true
			str: [dynamic]u8

			for lexer_peek(lexer^) != '"' {
				if lexer_end(lexer^) || lexer_peek(lexer^) == '\n' {
					terminated = false
					break
				}
				if lexer_peek(lexer^) == '\\' {
					lexer.current += 1
					if lexer_peek(lexer^) == 'n' {
						lexer.current += 1
						append(&str, '\n')
					} else {
						return Error{"Invalid escape character", lexer_span(lexer^)}
					}
					continue
				}
				append(&str, lexer_peek(lexer^))
				lexer.current += 1
			}

			if !terminated {
				return Error{"Unterminated string", lexer_span(lexer^)}
			}

			lexer.current += 1
			// str := string(lexer.source[lexer.start + 1:lexer.current - 1])
			lexer_add(lexer, .String, string(str[:]))
		case '#':
			for unicode.is_alpha(rune(lexer_peek(lexer^))) {
				lexer.current += 1
			}

			name := string(lexer.source[lexer.start + 1:lexer.current])
			switch name {
			case "foreign":
				lexer_add(lexer, .Directive, Directive.Foreign)
			case:
				return Error{"Invalid directive", lexer_span(lexer^)}
			}
		case:
			if is_ident_char(char) {
				for is_ident_char(lexer_peek(lexer^), true) {
					lexer.current += 1
				}

				ident := string(lexer.source[lexer.start:lexer.current])
				switch ident {
				case "int":
					lexer_add(lexer, .KW_Int)
				case "str":
					lexer_add(lexer, .KW_Str)
				case "void":
					lexer_add(lexer, .KW_Void)
				case "bool":
					lexer_add(lexer, .KW_Bool)
				case "true":
					lexer_add(lexer, .Bool, true)
				case "false":
					lexer_add(lexer, .Bool, false)
				case "if":
					lexer_add(lexer, .KW_If)
				case:
					lexer_add(lexer, .Ident, ident)
				}
			} else if unicode.is_digit(rune(char)) {
				for unicode.is_digit(rune(lexer_peek(lexer^))) {
					lexer.current += 1
				}

				str := string(lexer.source[lexer.start:lexer.current])
				int_value, ok := strconv.parse_int(str)
				if !ok {
					return Error{"Could not parse int", lexer_span(lexer^)}
				}
				lexer_add(lexer, .Int, int_value)
			} else {
				return Error{"Invalid character", lexer_span(lexer^)}
			}
		}
	}

	lexer_add(lexer, .EOF)
	return nil
}

lexer_advance :: proc(lexer: ^Lexer) -> u8 {
	defer lexer.current += 1
	return lexer_peek(lexer^)
}

lexer_peek :: proc(lexer: Lexer) -> u8 {
	if lexer_end(lexer) {
		return 0
	}
	return lexer.source[lexer.current]
}

lexer_span :: proc(lexer: Lexer) -> Span {
	return {lexer.start, lexer.current}
}

lexer_add :: proc(lexer: ^Lexer, type: TokenType, value: TokenValue = nil) {
	append(&lexer.tokens, Token{type, value, lexer_span(lexer^)})
}

lexer_end :: proc(lexer: Lexer) -> bool {
	return lexer.current >= len(lexer.source)
}

is_ident_char :: proc(char: u8, use_digits := false) -> bool {
	is := unicode.is_alpha(rune(char)) || char == '_'
	if use_digits {
		is ||= unicode.is_digit(rune(char))
	}
	return is
}
