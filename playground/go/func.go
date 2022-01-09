package main

import (
	// "net/http"
	"net/http/httptest"
	"time"
)

type Dog struct {
	name  string
	age   int
	owner string
}

func NewDog(name string, age int) *Dog {
	return &Dog{name: name, age: age}
}

// SetOwner
func (d *Dog) SetOwner(owner string) {
	d.owner = owner
}

// SetDogName
func (d *Dog) SetDogName(name string) {
	if d == nil {
		d = NewDog(name, 0)
		d.name = name
	} else {
		d.name = name
	}
}

func (d *Dog) SetOwnerUtf8(name []byte) {
}

func fun1() {
}

func fun1_test() {
	d := NewDog("", 1)
	NewDog("abc", 12)
	// fmt.Printf("abc", 1)
	time.Date(12, 12, 12, 33, 12, 55, 22, nil)

	d.SetOwnerUtf8([]byte{1})
	w := httptest.NewRecorder()
	w.Write([]byte{})
}
