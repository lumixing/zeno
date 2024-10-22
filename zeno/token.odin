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

	// literals
	String,
	Int,
	Bool,

	// kw
	KW_Int,
	KW_Str,
	KW_Void,
	KW_Bool,
}

TokenValue :: union {
	string,
	int,
	bool,
	Directive,
}

Directive :: enum {
	Foreign,
}

Span :: struct {
	lo, hi: int,
}
