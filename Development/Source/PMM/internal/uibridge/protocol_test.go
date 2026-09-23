package uibridge

import (
	"bytes"
	"encoding/binary"
	"errors"
	"io"
	"strings"
	"testing"
)

func hello() Message {
	m := Control("test-session", 1, "HELLO", 0)
	m.PID = "101"
	m.Created = "1000"
	return m
}
func TestWireRoundTrip(t *testing.T) {
	for _, m := range []Message{hello(), Control("test-session", 2, "PING", 0), register(2, 1, Identity{202, 2000}, "wpf"), ready(3, 1, 42), Control("test-session", 4, "EXIT", 1), Control("test-session", 5, "CLOSE", 0), Control("test-session", 2, "ACK", 1)} {
		var b bytes.Buffer
		if e := WriteFrame(&b, m); e != nil {
			t.Fatal(e)
		}
		got, e := ReadFrame(&b)
		if e != nil || got != m || b.Len() != 0 {
			t.Fatalf("%+v %v", got, e)
		}
	}
}
func TestDecoderRejectsAmbiguity(t *testing.T) {
	b, _ := Encode(hello())
	s := string(b)
	cases := map[string]string{
		"duplicate":         strings.Replace(s, `"pid":"101"`, `"pid":"101","pid":"101"`, 1),
		"escaped-duplicate": strings.Replace(s, `"pid":"101"`, `"pid":"101","\u0070id":"101"`, 1),
		"case":              strings.Replace(s, `"pid"`, `"PID"`, 1),
		"unknown":           strings.Replace(s, `"pid"`, `"command"`, 1),
		"numeric":           strings.Replace(s, `"pid":"101"`, `"pid":101`, 1),
		"float":             strings.Replace(s, `"pid":"101"`, `"pid":101.0`, 1),
		"null":              strings.Replace(s, `"pid":"101"`, `"pid":null`, 1),
		"array":             strings.Replace(s, `"pid":"101"`, `"pid":[]`, 1),
		"object":            strings.Replace(s, `"pid":"101"`, `"pid":{}`, 1),
		"missing":           strings.Replace(s, `"pid":"101",`, "", 1),
		"trailing":          s + "{}", "invalid-utf8": s + string([]byte{0xff}),
		"overlong":  strings.Repeat(" ", MaxFrame) + s,
		"version":   strings.Replace(s, `"version":"1"`, `"version":"2"`, 1),
		"truncated": s[:len(s)-1], "root-null": "null", "root-array": "[]",
	}
	for name, v := range cases {
		t.Run(name, func(t *testing.T) {
			if _, e := Decode([]byte(v)); e == nil {
				t.Fatal("accepted invalid message")
			}
		})
	}
}
func TestCanonicalIntegers(t *testing.T) {
	for _, s := range []string{"", "-1", "+1", "01", "1.0", "1e2", " 1", "1 ", "18446744073709551616", "0"} {
		if _, e := Decimal(s, 64, false); e == nil {
			t.Fatalf("accepted %q", s)
		}
	}
	if _, e := Decimal("4294967296", 32, true); e == nil {
		t.Fatal("PID overflow")
	}
	if _, e := Decimal("18446744073709551615", 64, false); e != nil {
		t.Fatal(e)
	}
}
func TestFramingRejectsPartialAndOversize(t *testing.T) {
	for _, n := range []uint32{0, 4097, 0xffffffff} {
		var b [4]byte
		binary.BigEndian.PutUint32(b[:], n)
		if _, e := ReadFrame(bytes.NewReader(b[:])); e == nil {
			t.Fatal(n)
		}
	}
	var b bytes.Buffer
	_ = WriteFrame(&b, hello())
	full := b.Bytes()
	for _, n := range []int{0, 1, 3, 4, 5, len(full) - 1} {
		if _, e := ReadFrame(bytes.NewReader(full[:n])); e == nil {
			t.Fatal(n)
		}
	}
}

type shortWriter struct{}

func (shortWriter) Write(b []byte) (int, error) { return len(b) - 1, nil }

type brokenWriter struct{}

func (brokenWriter) Write([]byte) (int, error) { return 0, errors.New("fixture write error") }
func TestWriterErrors(t *testing.T) {
	if e := WriteFrame(shortWriter{}, hello()); !errors.Is(e, io.ErrShortWrite) {
		t.Fatal(e)
	}
	if e := WriteFrame(brokenWriter{}, hello()); e == nil {
		t.Fatal("error ignored")
	}
}
func TestTypedMessageConstraints(t *testing.T) {
	cases := []Message{Control("../bad", 1, "PING", 0), Control("test-session", 0, "PING", 0), Control("test-session", 1, "RUN", 0), Control("test-session", 1, "READY", 0), Control("test-session", 1, "EXIT", 0), Control("test-session", 1, "HELLO", 0)}
	for _, m := range cases {
		if _, e := Encode(m); e == nil {
			t.Fatalf("invalid %+v", m)
		}
	}
}
func FuzzDecode(f *testing.F) {
	b, _ := Encode(hello())
	f.Add(b)
	f.Add([]byte(`{"pid":null}`))
	f.Fuzz(func(t *testing.T, b []byte) {
		m, e := Decode(b)
		if e == nil {
			out, e := Encode(m)
			if e != nil {
				t.Fatal(e)
			}
			other, e := Decode(out)
			if e != nil || other != m {
				t.Fatal("roundtrip")
			}
		}
	})
}

func TestAckBoundToExactRequest(t *testing.T) {
	req := register(2, 1, Identity{202, 2000}, "wpf")
	ack := Control("test-session", 2, "ACK", 1)
	if e := ValidateAck(req, ack); e != nil {
		t.Fatal(e)
	}
	for _, field := range []string{"session", "sequence", "generation", "kind"} {
		t.Run(field, func(t *testing.T) {
			bad := ack
			switch field {
			case "session":
				bad.Session = "other"
			case "sequence":
				bad.Seq = "3"
			case "generation":
				bad.Generation = "2"
			case "kind":
				bad.Kind = "EXIT"
			}
			if e := ValidateAck(req, bad); e == nil {
				t.Fatal("wrong ACK accepted")
			}
		})
	}
}
