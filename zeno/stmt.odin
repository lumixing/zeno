package zeno

TopStmt :: union {
	FuncDeclare,
}

FuncDeclare :: struct {
	name: string,
	// params: []Param,
	body: []Stmt,
}

// Param :: struct {
// 	name: string,
//     type:
// }

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
}

Type :: enum {
	Int,
}

Value :: union {
	int,
}
