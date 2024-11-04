package qbe

Type :: enum {
	Byte,
	Halfword,
	Word,
	Long,
	Single,
	Double,
}

Param :: struct {
	name: string,
	type: Type,
}

Data :: struct {
	name: string,
	body: []Arg,
}

Func :: struct {
	name:        string,
	return_type: Maybe(Type),
	params:      []Param,
	exported:    bool,
	body:        []Stmt,
}

Stmt :: union {
	Label,
	TempDef,
	Instr,
}

Label :: distinct string

TempDef :: struct {
	name:  string,
	type:  Type,
	instr: Instr,
}

Instr :: union {
	Copy,
	Call,
	Return,
	CondJump,
}

InstrArg :: struct {
	value: Value,
	type:  Type,
}

Copy :: distinct Value

Call :: struct {
	name: string,
	args: []Arg,
}

Arg :: struct {
	type:  Type,
	value: Value,
}

Glob :: distinct string
Temp :: distinct string

Value :: union {
	int,
	string,
	Glob,
	Temp,
}

Return :: distinct Maybe(Value)

CondJump :: struct {
	value:          Value,
	non_zero_label: Label,
	zero_label:     Label,
}
