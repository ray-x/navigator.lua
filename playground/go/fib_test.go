package main

import (
	"fmt"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestFib(t *testing.T) {
	require.NoError(t, nil)
	d := Fib(1)
	fmt.Println(d)
	if d != 1 {
		t.Errorf("NewDog failled %v", d)
	}
}
