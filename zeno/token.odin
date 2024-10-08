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
	Ident,
	LParen,
	RParen,
	LBrace,
	RBrace,
	Equals,
	String,
	Int,
	KW_Int,
}

TokenValue :: union {
	string,
	int,
}

Span :: struct {
	lo, hi: int,
}
