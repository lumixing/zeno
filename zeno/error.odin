package zeno

import "core:fmt"
import "core:os"

Error :: struct {
	lo:  int,
	str: string,
}

err :: proc(source: []u8, lo: int, str: string, args: ..any) -> ! {
	line, col := get_line_col(source, lo)
	fmt.printf("error at %d:%d: ", line, col)
	fmt.printfln(str, ..args)
	os.exit(1)
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
