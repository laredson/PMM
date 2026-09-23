package dispatch

import (
	"reflect"
	"testing"
)

func TestRouteHost(t *testing.T) {
	role, args := Route([]string{"doctor", "--json"})
	if role != Host || !reflect.DeepEqual(args, []string{"doctor", "--json"}) {
		t.Fatalf("unexpected host route: %q %#v", role, args)
	}
}

func TestRouteRuntime(t *testing.T) {
	role, args := Route([]string{"runtime", "self-test"})
	if role != Runtime || !reflect.DeepEqual(args, []string{"self-test"}) {
		t.Fatalf("unexpected runtime route: %q %#v", role, args)
	}
}

func TestRouteDoesNotAliasInput(t *testing.T) {
	input := []string{"runtime", "doctor"}
	_, args := Route(input)
	args[0] = "changed"
	if input[1] != "doctor" {
		t.Fatalf("Route returned aliased input")
	}
}
