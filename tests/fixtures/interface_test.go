package main

import "fmt"

func interfaceTest() {
	r := rect{width: 3, height: 4}
	c := circle{radius: 5}
	measure(r)
	measure(c)
	d := circle{radius: 10}
	fmt.Println(d)
}
