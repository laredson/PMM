package dispatch

const (
	Host    = "host"
	Runtime = "runtime"
)

func Route(args []string) (string, []string) {
	if len(args) > 0 && args[0] == "runtime" {
		out := append([]string(nil), args[1:]...)
		return Runtime, out
	}
	return Host, append([]string(nil), args...)
}
