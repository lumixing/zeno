package qbe

import "core:fmt"
import "core:os"
import "core:strings"

type_to_str :: proc(type: Type, loc := #caller_location) -> string {
	switch type {
	case .Byte:
		return "b"
	case .Halfword:
		return "h"
	case .Word:
		return "w"
	case .Long:
		return "l"
	case .Single:
		return "s"
	case .Double:
		return "d"
	case:
		fmt.panicf("invalid type: %v (%v)", type, loc)
	}
}

args_str :: proc(str: string) -> []Arg {
	// cant return compound literal of slice
	// return {{.Byte, str}, {.Byte, 0}}
	args: [dynamic]Arg
	append(&args, ..[]Arg{{.Byte, str}, {.Byte, 0}})
	return args[:]
}

main :: proc() {
	datas: [dynamic]Data
	funcs: [dynamic]Func

	append(&datas, Data{".0", {{.Byte, string("welcome!!!")}, {.Byte, 0}}})
	// append(&datas, Data{".1", {{.Byte, string("saknigga")}, {.Byte, 0}}})
	append(&datas, Data{".1", args_str("saknigga")})

	body: [dynamic]Stmt
	append(&body, Label("start"))
	append(&body, Instr(Call{"puts", {{.Long, Glob(".0")}}}))
	append(&body, Instr(Call{"puts", {{.Long, Glob(".1")}}}))
	append(&body, Instr(Return{0}))
	append(&funcs, Func{"main", .Word, {}, true, body[:]})

	fmt.println(bake(datas[:], funcs[:]))
}

bake :: proc(datas: []Data, funcs: []Func) -> string {
	lines: [dynamic]string

	for data in datas {
		append(&lines, fmt.tprintfln("data $%s = {{ %s}}", data.name, args(data.body)))
	}
	append(&lines, "\n")

	for func in funcs {
		signature := fmt.tprintfln(
			"%sfunction %s $%s(%s) {{",
			func.exported ? "export " : "",
			type_to_str(func.return_type),
			func.name,
			params(func.params),
		)

		append(&lines, signature)
		defer append(&lines, "}")

		for stmt in func.body {
			switch st in stmt {
			case Label:
				append(&lines, fmt.tprintfln("@%s", st))
			case TempDef:
				append(
					&lines,
					fmt.tprintfln("\t%%%s =%s %s", st.name, type_to_str(st.type), instr(st.instr)),
				)
			case Instr:
				append(&lines, fmt.tprintfln("\t%s", instr(st)))
			}
		}
	}

	return fmt.tprintln(strings.join(lines[:], ""))
}

instr :: proc(instr: Instr) -> string {
	switch ins in instr {
	case Call:
		return fmt.tprintf("call $%s(%s)", ins.name, args(ins.args))
	case Return:
		return fmt.tprintf("ret %s", value(ins.value))
	case Copy:
		return fmt.tprintf("call %s", value(Value(ins)))
	}

	return "INVALID_INSTR"
}

args :: proc(args: []Arg) -> string {
	str: [dynamic]string
	for arg in args {
		append(&str, fmt.tprintf("%s %s, ", type_to_str(arg.type), value(arg.value)))
	}
	return strings.join(str[:], "")
}

params :: proc(params: []Param) -> string {
	str: [dynamic]string
	for par in params {
		append(&str, fmt.tprintf("%s %s, ", type_to_str(par.type), value(Temp(par.name))))
	}
	return strings.join(str[:], "")
}

value :: proc(value: Value) -> string {
	switch v in value {
	case int:
		return fmt.tprintf("%d", v)
	case string:
		return fmt.tprintf("%q", v)
	case Glob:
		return fmt.tprintf("$%s", v)
	case Temp:
		return fmt.tprintf("%%%s", v)
	}

	return "INVALID_VALUE"
}
