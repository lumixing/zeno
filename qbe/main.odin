package qbe

import "core:fmt"
import "core:os"
import "core:strings"

type_to_str :: proc(type: Type) -> string {
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
		panic("invalid type")
	}
}

main :: proc() {
	funcs: [dynamic]Func
	datas: [dynamic]Data
	instrs: [dynamic]Instr

	append(&instrs, TempDecl{"temp", .Word, 69})
	append(&instrs, Call{"puts", {{.Long, Global("string")}}})
	append(&instrs, Return{0})
	append(&funcs, Func{"main", .Word, true, instrs[:]})
	append(&datas, Data{"string", {{.Byte, string("hello world\n")}, {.Byte, 0}}})

	lines: [dynamic]string
	for data in datas {
		append(&lines, fmt.tprintf("data $%s = {{ %s}}", data.name, args(data.body)))
	}
	for func in funcs {
		function(&lines, func.name, func.return_type, func.exported, func.body)
	}

	fmt.println(strings.join(lines[:], ""))

	// lines: [dynamic]string
	// data_string(&lines, "string", "hello world\n")
	// instrs := []Instr {
	// 	TempDecl{"temp", .Word, 69},
	// 	Call{"printf", []Arg{{.Long, Global("string")}}},
	// 	Return{0},
	// }
	// function(&lines, "main", .Word, true, instrs)

	// if len(os.args) == 1 {
	// 	fmt.println(strings.join(lines[:], ""))
	// } else {
	// 	os.write_entire_file(os.args[1], transmute([]u8)strings.join(lines[:], ""))
	// }
}

data_string :: proc(lines: ^[dynamic]string, name, str: string) {
	line := fmt.tprintfln("data $%s = {{ b %q, b 0 }}", name, str)
	append(lines, line)
}

function :: proc(
	lines: ^[dynamic]string,
	name: string,
	return_type: Type,
	export: bool,
	instrs: []Instr,
) {
	append(lines, "\n")

	if export {
		append(lines, "export ")
	}

	append(lines, fmt.tprintfln("function %s $%s() {{", type_to_str(return_type), name))
	defer append(lines, "}\n")

	append(lines, "@start\n")

	for ins in instrs {
		instr(lines, ins)
	}
}

instr :: proc(lines: ^[dynamic]string, instr: Instr) {
	switch ins in instr {
	case Call:
		append(lines, fmt.tprintfln("\tcall $%s(%s)", ins.name, args(ins.args)))
	case Return:
		append(lines, fmt.tprintfln("\tret %d", ins.value))
	case TempDecl:
		append(
			lines,
			fmt.tprintfln("\t%%%s =%s copy %d", ins.name, type_to_str(ins.type), ins.value),
		)
	}
}

args :: proc(args: []Arg) -> string {
	str: [dynamic]string
	for arg in args {
		append(&str, fmt.tprintf("%s %s, ", type_to_str(arg.type), value(arg.value)))
	}
	return strings.join(str[:], "")
}

value :: proc(value: Value) -> string {
	switch v in value {
	case int:
		return fmt.tprintf("%d", v)
	case string:
		return fmt.tprintf("%q", v)
	case Global:
		return fmt.tprintf("$%s", v)
	case Temp:
		return fmt.tprintf("%%%s", v)
	}

	return "INVALID_VALUE"
}
