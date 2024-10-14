package zeno

import "core:c/libc"
import "core:fmt"
import "core:os"
import "core:strings"

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
			fmt.printfln("%#v", top_stmt)
		}
	}

	lines := interp(data, parser.top_stmts[:])
	lines_str := strings.join(lines, "")
	//fmt.println(strings.join(lines, ""))
	os.write_entire_file("samples/out.ssa", transmute([]u8)lines_str)
	libc.system("qbe -o out.s samples/out.ssa && cc out.s && ./a.out")
}
