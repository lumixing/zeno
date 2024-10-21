```c
// ·▄▄▄▄•▄▄▄ . ▐ ▄       
// ▪▀·.█▌▀▄.▀·•█▌▐█▪     
// ▄█▀▀▀•▐▀▀▪▄▐█▐▐▌ ▄█▀▄ 
// █▌▪▄█▀▐█▄▄▌██▐█▌▐█▌.▐▌
// ·▀▀▀ • ▀▀▀ ▀▀ █▪ ▀█▄▀▪
```
## zeno, a small simple compiled language
nothing serious, just a small language i'm working on to learn about compilers.  
here's a snippet:

```go
// hello.zn
main() {
    printf("hello zen!\n")
}
```

written in odin using qbe as the backend ir  
currently only works for linux  


## usage
```shell
$ odin build zeno
$ zeno run hello.zn
```

you can also just build without running
```shell
$ zeno build hello.zn
```

or keep files when running which get deleted
```shell
$ zeno run hello.zn -bin # keep binary
$ zeno run hello.zn -ssa # keep qbe ssa file (for debugging)
```

or print some stuff
```shell
$ zeno run hello.zn -tokens # print tokens
$ zeno run hello.zn -stmts  # print statements
$ zeno run hello.zn -v      # print verbose info
```

## docs
documentation about the language is not available since it is still a work in progress.  
here is a rough vision of the language though:

```go
#import "fmt"

main() {
    a int
    a = 1
    b int = 2
    c := 3
    sum := add(a, b)

    fmt.println("% + % = %", a, b, c)
    fmt.println("sum is", sum)

    rect Rect = {10, 20}
    fmt.println(rect, rect.get_area()) // Rect{width=10,height=20} 200
    rect.increase_width(5)
    fmt.println(rect, rect.get_area()) // Rect{width=15,height=20} 300
}

add(a, b int) int {
    return a + b
}

Rectangle struct {
    width, height int
}

Rectangle.get_area() int {
    return it.width * it.height
}

&Rectangle.increase_width(width int) (rc) {
    rc.width += width
}
```
