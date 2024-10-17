package zeno

TopStmt :: union {
	FuncDeclare,
	ForeignFuncDeclare,
}

FuncDeclare :: struct {
	name:        string,
	// params: []Param,
	body:        []Stmt,
	return_type: Type,
}

ForeignFuncDeclare :: struct {
	name:        string,
	params:      []Param,
	return_type: Type,
}

Param :: struct {
	name: string,
	type: Type,
}

Stmt :: union {
	FuncCall,
	VarDecl,
}

FuncCall :: struct {
	name: string,
	args: []Expr,
}

VarDecl :: struct {
	name:  string,
	type:  Type,
	value: Value,
}

Expr :: union {
	string,
	int,
}

Type :: enum {
	Void,
	Int,
	String,
}

Value :: union {
	int,
}
