package main

import (
	"errors"
	"fmt"
	"io/fs"
	"unsafe"
)

// main
// note: this is main func
func main() {
	i := 32
	i = i + 1
	fmt.Println("hello, world", i)
	var uns1 unsafe.Pointer

	var x struct {
		a int64
		b bool
		c string
	}
	const M, N = unsafe.Sizeof(x.c), unsafe.Sizeof(x)
	fmt.Println(M, N, uns1) // 16 32

	var perr *fs.PathError
	if errors.As(nil, &perr) {
		fmt.Println(perr.Path)
	}
	myfunc3("a", "b")
}
