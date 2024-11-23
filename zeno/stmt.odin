package zeno

Spanned :: struct($T: typeid) {
	span:  Span,
	value: T,
}

TopStmt :: union {
	FuncDef,
	ForeignFuncDecl,
}

FuncSign :: struct {
	name:        string,
	params:      []Param,
	return_type: Type,
}

FuncDef :: struct {
	sign: FuncSign,
	body: Block,
}

Block :: []Spanned(Stmt)

ForeignFuncDecl :: struct {
	sign: FuncSign,
}

Param :: struct {
	name:     string,
	type:     Type,
	variadic: bool,
}

Type :: enum {
	Void,
	String,
	Int,
	Bool,
	Any,
}

Stmt :: union {
	VarDef,
}

VarDef :: struct {
	name:  string,
	type:  Type,
	value: Expr,
}

Expr :: union {
	string,
	int,
	bool,
	Ident,
}

Ident :: distinct string
