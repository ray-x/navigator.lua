package main

import (
	"fmt"
	"math"
	//"math"
)

type geometry interface {
	area() float64
	perim() float64
}

type rect struct {
	width  float64 `-line:"width"`
	height float64 `-line:"height"`
}

type rect2 struct {
	width  int `yml:"width"`
	height int `yml:"height"`
}

func (r rect) area() float64 {
	return r.width * r.height
}

func (r rect) perim() float64 {
	return 2*r.width + 2*r.height
}

type circle struct {
	radius float64
}

func (c circle) area() float64 {
	return math.Pi * c.radius * c.radius
}

func (c circle) perim() float64 {
	return 2 * math.Pi * c.radius
}

func measure(g geometry) int {
	fmt.Println(g)
	fmt.Println(g.area())
	fmt.Println(g.perim())
	return 1
}

func m2() {
	measure(rect{width: 3})
}

func M2() {
	measure(rect{width: 3})
}

func runinterface() {
	r := rect{width: 3, height: 4}
	c := circle{radius: 5}
	measure(r)
	measure(c)
	d := circle{radius: 10}
	fmt.Println(d)
}

func main() {
	M2()
	m2()
	runinterface()
}
