package simple_test

import "testing"

func TestAdd(t *testing.T) {
	result := 1 + 2
	if result != 3 {
		t.Errorf("got %q, wanted %q", result, 3)
	}
}
