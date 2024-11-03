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

	// literals
	String,
	Int,
	Bool,

	// kw
	KW_Int,
	KW_Str,
	KW_Void,
	KW_Bool,
	KW_If,
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
