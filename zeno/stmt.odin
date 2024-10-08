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
}

FuncCall :: struct {
	name: string,
	args: []Expr,
}

Expr :: union {
	string,
}
