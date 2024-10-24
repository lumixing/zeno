package zeno

import "../qbe"
import "core:c/libc"
import "core:flags"
import "core:fmt"
import "core:os"
import "core:strings"

Subcmd :: enum {
	run,
	build,
}

Options :: struct {
	subcmd:       Subcmd `args:"pos=0,required"`,
	input:        os.Handle `args:"pos=1,required,file=r"`,
	print_tokens: bool `args:"name=tokens"`,
	print_stmts:  bool `args:"name=stmts"`,
	keep_ssa:     bool `args:"name=ssa"`,
	keep_bin:     bool `args:"name=bin"`,
}

main :: proc() {
	opt: Options
	flags.parse_or_exit(&opt, os.args)

	lexer := new(Lexer)

	data, ok := os.read_entire_file(opt.input)
	if !ok {
		panic("could not read file!")
	}

	lexer.source = data
	lexer_scan(lexer)

	if opt.print_tokens {
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
	prs_parse(parser)

	if opt.print_stmts {
		for top_stmt in parser.top_stmts {
			fmt.printfln("%#v", top_stmt)
		}
	}

	datas, funcs := gen_qbe(parser.top_stmts[:])
	// lines_str := strings.join(lines, "")
	qbestr := qbe.bake(datas, funcs)
	os.write_entire_file("samples/out.ssa", transmute([]u8)qbestr)

	if opt.subcmd == .run {
		fmt.println("finished compiling! running...")
		libc.system("qbe -o out.s samples/out.ssa && cc out.s && rm out.s && ./a.out")

		if !opt.keep_ssa {
			libc.system("rm samples/out.ssa")
		}
		if !opt.keep_bin {
			libc.system("rm a.out")
		}
	} else {
		fmt.println("finished compiling! wrote to samples/out.ssa")
	}
}
