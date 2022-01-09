package main

import (
	"fmt"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestCow(t *testing.T) {
	require.NoError(t, nil)
	d := NewDog("Fibi", 4)
	fmt.Println(d.name)
	if d.name != "Fibi" {
		t.Errorf("NewDog failled %v", d)
	}
}

func TestHorse(t *testing.T) {
	d := NewDog("Fibi cat", 4)
	fmt.Println(d.name)
	if d.name != "Fibi cat" {
		t.Errorf("NewDog failled %v", d)

	}
}
