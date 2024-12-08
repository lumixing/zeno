package zeno

Token :: struct {
	type:  TokenType,
	value: TokenValue,
	span:  Span,
}

TokenType :: enum {
	Whitespace,
	Newline,
	EOF,

	// sumn
	Ident,
	Directive,

	// punc
	LParen,
	RParen,
	LBrace,
	RBrace,
	Equals,
	Comma,
	DotDot,
	At,

	// literals
	String,
	Int,
	Bool,

	// kw
	KW_Int,
	KW_Str,
	KW_Void,
	KW_Bool,
	KW_Any,
	KW_If,
	KW_Return,
}

TokenValue :: union {
	Literal,
	Directive,
}

Literal :: union #no_nil {
	string,
	int,
	bool,
}

Directive :: enum {
	Foreign,
	Builtin,
}

Span :: struct {
	lo, hi: int,
}

span :: proc(lo: int) -> Span {
	return {lo, lo}
}
