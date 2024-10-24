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

lexer_scan :: proc(lexer: ^Lexer) {
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
		// lexer_add(lexer, .Whitespace)
		case '\n':
			lexer_add(lexer, .Newline)
		case '/':
			// todo: hangs on EOF (check other similar cases)
			if lexer_advance(lexer) == '/' {
				for lexer_peek(lexer^) != '\n' {
					lexer.current += 1
				}
			} else {
				err_log(lexer.source, lexer.start, "expected another slash for a comment")
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

			for lexer_peek(lexer^) != '"' {
				if lexer_end(lexer^) || lexer_peek(lexer^) == '\n' {
					terminated = false
					break
				}
				lexer.current += 1
			}

			if !terminated {
				err_log(lexer.source, lexer.start, "unterminated string")
			}

			lexer.current += 1
			str := string(lexer.source[lexer.start + 1:lexer.current - 1])
			lexer_add(lexer, .String, str)
		case '#':
			for unicode.is_alpha(rune(lexer_peek(lexer^))) {
				lexer.current += 1
			}

			name := string(lexer.source[lexer.start + 1:lexer.current])
			switch name {
			case "foreign":
				lexer_add(lexer, .Directive, Directive.Foreign)
			case:
				err_log(lexer.source, lexer.start, "%q is not a valid directive", name)
			}
		case:
			if unicode.is_alpha(rune(char)) {
				for unicode.is_alpha(rune(lexer_peek(lexer^))) {
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
					err_log(lexer.source, lexer.start, "could not parse int %q", str)
				}
				lexer_add(lexer, .Int, int_value)
			} else {
				err_log(lexer.source, lexer.start, "invalid char %c (%d)", char, char)
			}
		}
	}

	lexer_add(lexer, .EOF)
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

lexer_add :: proc(lexer: ^Lexer, type: TokenType, value: TokenValue = nil) {
	span := Span{lexer.start, lexer.current}
	append(&lexer.tokens, Token{type, value, span})
}

lexer_end :: proc(lexer: Lexer) -> bool {
	return lexer.current >= len(lexer.source)
}
