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
	parse,
	qbe,
}

Options :: struct {
	subcmd:       Subcmd `args:"pos=0,required"`,
	input:        os.Handle `args:"pos=1,required,file=r"`,
	print_tokens: bool `args:"name=tokens"`,
	print_stmts:  bool `args:"name=stmts"`,
	print_qbe:    bool `args:"name=qbe"`,
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
	err := lexer_scan(lexer)
	if err, ok := err.?; ok {
		fmt.printfln("Lexer error at %v:%v: %v", get_line_col(data, err.location.lo), err.message)
		os.exit(1)
	}

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
	// parser.source = data
	parser.tokens = lexer.tokens[:]
	err = prs_parse(parser)
	if err, ok := err.?; ok {
		fmt.printfln("Parse error at %v:%v: %v", get_line_col(data, err.location.lo), err.message)
		os.exit(1)
	}

	if opt.print_stmts {
		for top_stmt in parser.top_stmts {
			fmt.printfln("%#v", top_stmt)
		}
	}

	if opt.subcmd == .parse {
		return
	}

	out, qbe_err := gen_qbe(parser.top_stmts[:])
	if err, ok := qbe_err.?; ok {
		fmt.printfln("Error at %v:%v: %v", get_line_col(data, err.location.lo), err.message)
		os.exit(1)
	}

	qbestr := qbe.bake(out.datas[:], out.funcs[:])
	os.write_entire_file("samples/out.ssa", transmute([]u8)qbestr)

	if opt.print_qbe {
		fmt.println(qbestr)
	}

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
