// Package uibridge implements candidate-only UI ownership coordination.
// A decoded message is NOT authenticated until its pipe peer is verified by OS.
package uibridge

import (
	"bytes"
	"encoding/binary"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"strconv"
	"unicode/utf8"
)

const Version = "1"
const MaxFrame = 4096

// All wire values are strings, including unsigned decimal identities. The wire
// schema is deliberately flat and closed: no paths, commands or executable data.
type Message struct {
	Version    string `json:"version"`
	Session    string `json:"session"`
	Seq        string `json:"seq"`
	Kind       string `json:"kind"`
	Generation string `json:"generation"`
	PID        string `json:"pid"`
	Created    string `json:"created"`
	Route      string `json:"route"`
	HWND       string `json:"hwnd"`
}

func Decimal(s string, bits int, zero bool) (uint64, error) {
	if s == "" || (len(s) > 1 && s[0] == '0') {
		return 0, errors.New("non-canonical integer")
	}
	for _, c := range s {
		if c < '0' || c > '9' {
			return 0, errors.New("unsigned decimal required")
		}
	}
	n, err := strconv.ParseUint(s, 10, bits)
	if err != nil || (!zero && n == 0) {
		return 0, errors.New("integer out of range")
	}
	return n, nil
}
func ValidSession(s string) bool {
	if len(s) < 1 || len(s) > 96 {
		return false
	}
	for _, c := range s {
		if !(c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z' || c >= '0' && c <= '9' || c == '-' || c == '_' || c == '.') {
			return false
		}
	}
	return true
}
func Control(session string, seq uint64, kind string, generation uint64) Message {
	return Message{Version, session, strconv.FormatUint(seq, 10), kind, strconv.FormatUint(generation, 10), "0", "0", "", "0"}
}
func (m Message) Validate() error {
	if m.Version != Version || !ValidSession(m.Session) {
		return errors.New("invalid protocol/session")
	}
	if _, e := Decimal(m.Seq, 64, false); e != nil {
		return e
	}
	gen, e := Decimal(m.Generation, 64, true)
	if e != nil {
		return e
	}
	pid, e := Decimal(m.PID, 32, true)
	if e != nil {
		return e
	}
	created, e := Decimal(m.Created, 64, true)
	if e != nil {
		return e
	}
	hwnd, e := Decimal(m.HWND, 64, true)
	if e != nil {
		return e
	}
	switch m.Kind {
	case "HELLO":
		if gen != 0 || pid == 0 || created == 0 || m.Route != "" || hwnd != 0 {
			return errors.New("invalid HELLO")
		}
	case "REGISTER":
		if gen == 0 || pid == 0 || created == 0 || (m.Route != "native" && m.Route != "wpf") || hwnd != 0 {
			return errors.New("invalid REGISTER")
		}
	case "READY":
		if gen == 0 || pid != 0 || created != 0 || m.Route != "" || hwnd == 0 {
			return errors.New("invalid READY")
		}
	case "EXIT", "FAILED":
		if gen == 0 || pid != 0 || created != 0 || m.Route != "" || hwnd != 0 {
			return errors.New("invalid retirement")
		}
	case "CLOSE", "PING":
		if gen != 0 || pid != 0 || created != 0 || m.Route != "" || hwnd != 0 {
			return errors.New("invalid control")
		}
	case "ACK":
		if pid != 0 || created != 0 || m.Route != "" || hwnd != 0 {
			return errors.New("invalid ACK")
		}
	default:
		return errors.New("unknown message kind")
	}
	return nil
}
func Encode(m Message) ([]byte, error) {
	if e := m.Validate(); e != nil {
		return nil, e
	}
	b, e := json.Marshal(m)
	if e != nil {
		return nil, e
	}
	if len(b) > MaxFrame {
		return nil, errors.New("frame too large")
	}
	return b, nil
}
func Decode(b []byte) (Message, error) {
	var m Message
	if len(b) == 0 || len(b) > MaxFrame || !utf8.Valid(b) {
		return m, errors.New("invalid frame size/UTF-8")
	}
	d := json.NewDecoder(bytes.NewReader(b))
	t, e := d.Token()
	if e != nil || t != json.Delim('{') {
		return m, errors.New("object required")
	}
	fields := map[string]*string{"version": &m.Version, "session": &m.Session, "seq": &m.Seq, "kind": &m.Kind, "generation": &m.Generation, "pid": &m.PID, "created": &m.Created, "route": &m.Route, "hwnd": &m.HWND}
	seen := map[string]bool{}
	for d.More() {
		key, e := d.Token()
		if e != nil {
			return m, e
		}
		k, ok := key.(string)
		if !ok {
			return m, errors.New("invalid field")
		}
		dst, ok := fields[k]
		if !ok || seen[k] {
			return m, fmt.Errorf("unknown/duplicate field %q", k)
		}
		seen[k] = true
		v, e := d.Token()
		if e != nil {
			return m, e
		}
		s, ok := v.(string)
		if !ok {
			return m, errors.New("string value required")
		}
		*dst = s
	}
	if t, e = d.Token(); e != nil || t != json.Delim('}') || len(seen) != len(fields) {
		return m, errors.New("incomplete object")
	}
	if _, e = d.Token(); e != io.EOF {
		return m, errors.New("trailing data")
	}
	return m, m.Validate()
}

// ReadFrame does NOT supply transport deadlines. Only use with a bounded,
// cancellable transport or an in-memory fixture. Header is uint32 big-endian.
func ReadFrame(r io.Reader) (Message, error) {
	var h [4]byte
	if _, e := io.ReadFull(r, h[:]); e != nil {
		return Message{}, e
	}
	n := binary.BigEndian.Uint32(h[:])
	if n == 0 || n > MaxFrame {
		return Message{}, errors.New("invalid frame length")
	}
	b := make([]byte, n)
	if _, e := io.ReadFull(r, b); e != nil {
		return Message{}, e
	}
	return Decode(b)
}
func WriteFrame(w io.Writer, m Message) error {
	b, e := Encode(m)
	if e != nil {
		return e
	}
	h := make([]byte, 4)
	binary.BigEndian.PutUint32(h, uint32(len(b)))
	for _, part := range [][]byte{h, b} {
		n, e := w.Write(part)
		if e != nil {
			return e
		}
		if n != len(part) {
			return io.ErrShortWrite
		}
	}
	return nil
}

// ValidateAck binds a reply to the exact request. An ACK is not meaningful merely
// because its JSON parsed. Client code must retire the connection on mismatch.
func ValidateAck(request, ack Message) error {
	if e := request.Validate(); e != nil {
		return e
	}
	if e := ack.Validate(); e != nil {
		return e
	}
	if request.Kind == "ACK" || ack.Kind != "ACK" || ack.Version != request.Version || ack.Session != request.Session || ack.Seq != request.Seq || ack.Generation != request.Generation {
		return errors.New("ACK does not match request")
	}
	return nil
}
