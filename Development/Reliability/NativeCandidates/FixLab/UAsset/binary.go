package uasset

import (
	"context"
	"crypto/sha256"
	"encoding/binary"
	"encoding/hex"
	"fmt"
	"unicode/utf16"
)

type reader struct {
	ctx      context.Context
	b        []byte
	pos, end int
	err      error
	limits   Limits
	fields   map[string]Span
}

func (r *reader) fail(kind error, what string) {
	if r.err == nil {
		r.err = fmt.Errorf("%w at %d: %s", kind, r.pos, what)
	}
}
func (r *reader) take(n int) []byte {
	if r.err != nil {
		return nil
	}
	if e := r.ctx.Err(); e != nil {
		r.err = e
		return nil
	}
	if n < 0 || r.pos < 0 || r.pos > r.end || n > r.end-r.pos {
		r.fail(ErrInvalid, "truncated or escaped range")
		return nil
	}
	b := r.b[r.pos : r.pos+n]
	r.pos += n
	return b
}
func (r *reader) u16() uint16 {
	b := r.take(2)
	if b == nil {
		return 0
	}
	return binary.LittleEndian.Uint16(b)
}
func (r *reader) u32() uint32 {
	b := r.take(4)
	if b == nil {
		return 0
	}
	return binary.LittleEndian.Uint32(b)
}
func (r *reader) i32() int32 { return int32(r.u32()) }
func (r *reader) i64() int64 {
	b := r.take(8)
	if b == nil {
		return 0
	}
	return int64(binary.LittleEndian.Uint64(b))
}
func (r *reader) field32(name string) int32 {
	p := r.pos
	v := r.i32()
	r.fields[name] = Span{p, 4}
	return v
}
func (r *reader) field64(name string) int64 {
	p := r.pos
	v := r.i64()
	r.fields[name] = Span{p, 8}
	return v
}
func (r *reader) count(max int) int {
	n := r.i32()
	if n < 0 {
		r.fail(ErrInvalid, "negative count")
		return 0
	}
	if int64(n) > int64(max) {
		r.fail(ErrLimit, "count")
		return 0
	}
	return int(n)
}
func (r *reader) boolean() bool {
	n := r.u32()
	if n > 1 {
		r.fail(ErrInvalid, "boolean is not 0/1")
	}
	return n == 1
}
func (r *reader) fname(names int) FName {
	v := FName{r.i32(), r.i32()}
	if v.Index < 0 || int64(v.Index) >= int64(names) || v.Number < 0 {
		r.fail(ErrInvalid, "FName out of range")
	}
	return v
}
func (r *reader) str() (string, bool) {
	n := int64(r.i32())
	if r.err != nil {
		return "", false
	}
	if n == 0 {
		return "", false
	}
	wide := n < 0
	if wide {
		n = -n
	}
	width := int64(1)
	if wide {
		width = 2
	}
	if n > int64(r.limits.StringBytes)/width {
		r.fail(ErrLimit, "FString")
		return "", wide
	}
	b := r.take(int(n * width))
	if b == nil {
		return "", wide
	}
	if !wide {
		if b[len(b)-1] != 0 {
			r.fail(ErrInvalid, "FString terminator")
			return "", false
		}
		for _, c := range b[:len(b)-1] {
			if c == 0 {
				r.fail(ErrInvalid, "embedded NUL")
				return "", false
			}
			if c > 127 {
				r.fail(ErrUnsupported, "non-ASCII narrow FString; no code-page guessing")
				return "", false
			}
		}
		return string(b[:len(b)-1]), false
	}
	if binary.LittleEndian.Uint16(b[len(b)-2:]) != 0 {
		r.fail(ErrInvalid, "UTF16 terminator")
		return "", true
	}
	runes := make([]rune, 0, len(b)/2)
	for i := 0; i < len(b)-2; i += 2 {
		u := binary.LittleEndian.Uint16(b[i:])
		if u == 0 {
			r.fail(ErrInvalid, "embedded UTF16 NUL")
			return "", true
		}
		if u >= 0xd800 && u <= 0xdbff {
			if i+4 > len(b)-2 {
				r.fail(ErrInvalid, "unpaired high surrogate")
				return "", true
			}
			v := binary.LittleEndian.Uint16(b[i+2:])
			if v < 0xdc00 || v > 0xdfff {
				r.fail(ErrInvalid, "unpaired high surrogate")
				return "", true
			}
			runes = append(runes, utf16.DecodeRune(rune(u), rune(v)))
			i += 2
		} else if u >= 0xdc00 && u <= 0xdfff {
			r.fail(ErrInvalid, "unpaired low surrogate")
			return "", true
		} else {
			runes = append(runes, rune(u))
		}
	}
	return string(runes), true
}
func (r *reader) engine() EngineVersion {
	e := EngineVersion{Major: r.u16(), Minor: r.u16(), Patch: r.u16(), Changelist: r.u32()}
	e.Branch, _ = r.str()
	return e
}
func hashBytes(ctx context.Context, b []byte) (string, error) {
	h := sha256.New()
	for len(b) > 0 {
		if e := ctx.Err(); e != nil {
			return "", e
		}
		n := 65536
		if n > len(b) {
			n = len(b)
		}
		h.Write(b[:n])
		b = b[n:]
	}
	if e := ctx.Err(); e != nil {
		return "", e
	}
	return hex.EncodeToString(h.Sum(nil)), nil
}
