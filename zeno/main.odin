package zeno

import "core:fmt"
import "core:os"

main :: proc() {
	lexer := new(Lexer)

	data, ok := os.read_entire_file(os.args[1])
	if !ok {
		panic("could not read file!")
	}

	lexer.source = data
	lexer_scan(lexer)

	if !true {
		for token in lexer.tokens {
			if token.value != nil {
				fmt.println(token.type, token.value)

			} else {
				fmt.println(token.type)
			}
		}
	}

	parser := new(Parser)
	parser.source = data
	parser.tokens = lexer.tokens[:]
	parser_parse(parser)

	if true {
		for top_stmt in parser.top_stmts {
			fmt.println(top_stmt)
		}
	}
}
