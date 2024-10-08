package zeno

import "core:fmt"
import "core:os"
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
			lexer_add(lexer, .Whitespace)
		case '\n':
			lexer_add(lexer, .Newline)
		case '(':
			lexer_add(lexer, .LParen)
		case ')':
			lexer_add(lexer, .RParen)
		case '{':
			lexer_add(lexer, .LBrace)
		case '}':
			lexer_add(lexer, .RBrace)
		case '"':
			terminated := true

			for lexer_peek(lexer^) != '"' {
				if lexer_end(lexer^) {
					terminated = false
					break
				}
				lexer.current += 1
			}

			if !terminated {
				panic("unterminated string!")
			}

			lexer.current += 1
			str := string(lexer.source[lexer.start + 1:lexer.current - 1])
			lexer_add(lexer, .String, str)
		case:
			if unicode.is_alpha(rune(char)) {
				for unicode.is_alpha(rune(lexer_peek(lexer^))) {
					lexer.current += 1
				}

				ident := string(lexer.source[lexer.start:lexer.current])
				lexer_add(lexer, .Ident, ident)
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
