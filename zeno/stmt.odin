package zeno

TopStmt :: union {
	FuncDecl,
	ForeignFuncDeclare,
}

FuncDecl :: struct {
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
	Block,
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

Block :: distinct []Stmt

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
