package zeno

Spanned :: struct($T: typeid) {
	span:  Span,
	value: T,
}

TopStmt :: union {
	FuncDef,
	ForeignFuncDecl,
	BuiltinFuncDecl,
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

BuiltinFuncDecl :: struct {
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
	Pointer,
}

Stmt :: union {
	VarDef,
	FuncCall,
	Return,
	BuiltinFuncCall,
}

VarDef :: struct {
	name:  string,
	type:  Type,
	value: Expr,
}

FuncCall :: struct {
	name: string,
	args: []Expr,
}

BuiltinFuncCall :: distinct FuncCall

Return :: struct {
	value: Maybe(Expr),
}

Expr :: union #no_nil {
	string,
	int,
	bool,
	Ident,
	FuncCall,
	BuiltinFuncCall,
}

Ident :: distinct string
