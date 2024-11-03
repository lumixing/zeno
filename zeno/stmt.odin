package zeno

TopStmt :: union {
	FuncDeclare,
	ForeignFuncDeclare,
}

FuncDeclare :: struct {
	name:        string,
	params:      []Param,
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
	IfBranch,
}

FuncCall :: struct {
	name: string,
	args: []Expr,
}

VarDecl :: struct {
	name:  string,
	type:  Type,
	value: Expr,
}

IfBranch :: struct {
	cond: Expr,
	body: []Stmt,
}

VarIdent :: distinct string

Expr :: union {
	VarIdent,
	string,
	int,
	bool,
}

Type :: enum {
	Void,
	Int,
	String,
	Bool,
}
