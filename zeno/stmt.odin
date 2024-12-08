package zeno

Spanned :: struct($T: typeid) {
	span:  Span,
	value: T,
}

TopStmt :: union #no_nil {
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

Type :: union #no_nil {
	BaseType,
	^PointerType,
}

BaseType :: enum {
	Void,
	String,
	Int,
	Bool,
	Any,
}

PointerType :: distinct Type

Stmt :: union #no_nil {
	VarDef,
	FuncCall,
	Return,
}

VarDef :: struct {
	name:  string,
	type:  Type,
	value: Expr,
}

FuncCall :: struct {
	name:       string,
	args:       []Expr,
	is_builtin: bool,
}

Return :: struct {
	value: Maybe(Expr),
}

Expr :: union #no_nil {
	Literal,
	Variable,
	FuncCall,
}

Variable :: distinct string
