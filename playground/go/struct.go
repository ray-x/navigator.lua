package main

import "fmt"

// import "fmt"

type person struct {
	name string
	age  int
}

type say interface {
	hello() string
}

type strudent struct {
	person struct {
		name string
		age  int
	}
}

func newPerson(name string) *person {
	p := person{name: name}
	fmt.Println("")
	p.age = 42
	return &p
}

func newPerson2(name, say string) {
	fmt.Println(name, say)
}

func b() {
	newPerson2("a", "say")

	ret := measure(rect{width: 3})
	fmt.Println(ret)
}
