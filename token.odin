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
	String,
}

TokenValue :: union {
	string,
}

Span :: struct {
	lo, hi: int,
}
