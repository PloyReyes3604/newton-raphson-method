# newton-raphson-method

A tiny shell library that finds a root of a real-valued function by Newton-Raphson iteration.

```bash
. ./newton_raphson_method.sh

f()  { awk -v x="$1" 'BEGIN { printf "%.17g", x*x - 2 }'; }
df() { awk -v x="$1" 'BEGIN { printf "%.17g", 2*x }'; }

newton_raphson f df 1
# => 1.4142135623730951

newton_raphson_sqrt 2
# => 1.4142135623730951
```

## Why this exists

POSIX shell has no floating-point arithmetic.  A shell script that needs a
square root, or any other root, usually shells out to `bc`, `python`, or a
one-off `awk` snippet.  This library packages the one `awk` snippet that
matters — the Newton-Raphson loop — behind two shell functions, so callers
can define `f` and `f'` as ordinary shell functions and get a root back
without writing the iteration themselves.

The trade-off is that the caller must supply both the function and its
derivative.  Automatic differentiation is out of scope for a shell
library; if you cannot differentiate your function by hand, this is not
the tool for you.

## API

### `newton_raphson FN DF X0 [TOL [MAX_ITER]]`

Runs the iteration and prints the estimated root on stdout.

- `FN` — name of a shell function computing `f(x)`.
- `DF` — name of a shell function computing `f'(x)`.
- `X0` — initial guess.
- `TOL` — convergence tolerance on the size of the Newton step
  (default `1e-10`).
- `MAX_ITER` — iteration cap (default `100`).

Returns `0` on success, `1` if the derivative is near zero or an argument
is malformed, and `2` if the iteration cap is reached without meeting
`TOL`.  The two failure modes are distinguished so a caller can retry
with a different `X0` on a flat derivative but treat slow convergence as
a real problem.

### `newton_raphson_sqrt VALUE [TOL [MAX_ITER]]`

Convenience wrapper that finds `sqrt(VALUE)` using `f(x) = x^2 - VALUE`.
Rejects negative inputs up front, because Newton-Raphson on `x^2 - c`
with `c < 0` oscillates rather than converging.

## The awkward edge

Convergence is measured on the size of the Newton step, not on `|f(x)|`.
For a function with a large slope, `|f|` can stay above `TOL` long after
the root is pinned down to machine precision; the step is the honest
measure of how much the estimate moved.  If you need `|f|`-based
convergence, check it yourself after the call.

A second edge: if the derivative at some iterate is smaller than `1e-15`
in absolute value, the function returns `1` rather than dividing by a
number that would overflow.  A function with a genuine root at a point
where `f'(x) = 0` (for example, `f(x) = x^2` at `x = 0`) will hit this
path; that is a property of Newton-Raphson, not a bug in the wrapper.
