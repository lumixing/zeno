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
	KW_Ptr,
	KW_If,
	KW_Return,
}

TokenValue :: union {
	string,
	int,
	Directive,
	bool,
}

Directive :: enum {
	Foreign,
}

Span :: struct {
	lo, hi: int,
}

span :: proc(lo: int) -> Span {
	return {lo, lo}
}
