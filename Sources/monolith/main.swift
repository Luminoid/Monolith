import Foundation
import MonolithLib

// Line-buffer stdout, so progress reaches a pipe or file before the error
// ArgumentParser writes to stderr on failure, instead of after it.
setvbuf(stdout, nil, _IOLBF, 0)

Monolith.main()
