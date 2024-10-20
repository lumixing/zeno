package qbe

Type :: enum {
	Byte,
	Halfword,
	Word,
	Long,
	Single,
	Double,
}

Data :: struct {
	name: string,
	body: []Arg,
}

Func :: struct {
	name:        string,
	return_type: Type,
	// params:      []Param,
	exported:    bool,
	body:        []Instr,
}

Instr :: union {
	Call,
	Return,
	TempDecl,
}

Call :: struct {
	name: string,
	args: []Arg,
}

Arg :: struct {
	type:  Type,
	value: Value,
}

Global :: distinct string
Temp :: distinct string

Value :: union {
	int,
	string,
	Global,
	Temp,
}

Return :: struct {
	value: int,
}

TempDecl :: struct {
	name:  string,
	type:  Type,
	value: int, // only call int for now due to illegal cycle
}
