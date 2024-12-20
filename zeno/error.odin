package zeno

import "core:fmt"
import "core:os"

Error :: struct {
	message:  string,
	location: Span,
	consumed: int,
}

error :: proc(span: Span, fmtstr: string, args: ..any, consumed := 0) -> Error {
	return {fmt.tprintf(fmtstr, ..args), span, consumed}
}

get_line_col :: proc(src: []u8, lo: int) -> (line, col: int) {
	line = 1
	col = 1
	for i in 0 ..< lo {
		if src[i] == '\n' {
			line += 1
			col = 1
		} else {
			col += 1
		}
	}
	return line, col
}
