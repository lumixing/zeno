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

	// kw
	KW_Int,
	KW_Str,
	KW_Void,
}

TokenValue :: union {
	string,
	int,
	Directive,
}

Directive :: enum {
	Foreign,
}

Span :: struct {
	lo, hi: int,
}
