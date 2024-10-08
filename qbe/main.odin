package qbe

import "core:fmt"
import "core:os"
import "core:strings"

Type :: enum {
	Byte,
	Halfword,
	Word,
	Long,
	Single,
	Double,
}

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

Instr :: union {
	Call,
	Return,
}

Call :: struct {
	name: string,
	args: []Arg,
}

Arg :: struct {
	type: Type,
	name: string,
}

Return :: struct {
	value: int,
}

main :: proc() {
	lines: [dynamic]string
	data_string(&lines, "string", "hello world\n")
	instrs := []Instr{Call{"printf", []Arg{{.Long, "string"}}}, Return{0}}
	function(&lines, "main", .Word, true, instrs)

	if len(os.args) == 1 {
		fmt.println(strings.join(lines[:], ""))
	} else {
		os.write_entire_file(os.args[1], transmute([]u8)strings.join(lines[:], ""))
	}
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
	}
}

args :: proc(args: []Arg) -> string {
	str: [dynamic]string
	for arg in args {
		append(&str, fmt.tprintf("%s $%s, ", type_to_str(arg.type), arg.name))
	}
	return strings.join(str[:], "")
}
