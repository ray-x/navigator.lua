package test

import (
	"fmt"
	"testing"
)

func TestDog(t *testing.T) {
	d := NewDog("Fibi", 4)
	fmt.Println(d.name)
	if d.name != "Fibi" {
		t.Errorf("NewDog failled %v", d)
	}
}

func TestCat(t *testing.T) {
	d := NewDog("Fibi cat", 4)
	fmt.Println(d.name)
	if d.name != "Fibi cat" {
		t.Errorf("NewDog failled %v", d)
	}
}
