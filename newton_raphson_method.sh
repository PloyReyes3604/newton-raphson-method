#!/usr/bin/env bash
# Newton-Raphson root finder for real-valued functions.
#
# This library is intentionally tiny: it provides a single numerical
# routine plus a couple of helpers that make the routine usable from a
# shell script without pulling in a calculator.  All arithmetic is done
# with `awk` because POSIX shell has no floating point support of its
# own, and `awk` is part of the POSIX base utilities that ship with the
# coreutils+bash environment this library targets.
#
# The function under consideration is passed as a *name*, not as a
# string of source.  The caller defines two shell functions, say `f` and
# `df`, and passes their names to `newton_raphson`.  Those functions must
# print a single numeric value to stdout and exit 0.  Keeping the
# contract at "print a number" rather than "return a number" avoids the
# quoting minefield of passing arbitrary expressions through `eval`.

set -euo pipefail

# newton_raphson FN DF X0 [TOL [MAX_ITER]]
#
#   FN       name of a shell function computing f(x)
#   DF       name of a shell function computing f'(x)
#   X0       initial guess
#   TOL      convergence tolerance (default 1e-10)
#   MAX_ITER maximum iterations (default 100)
#
# Prints the estimated root on stdout.  Returns 0 on success.  Returns 1
# if the derivative is too close to zero to divide by, and 2 if the
# iteration limit is reached without meeting TOL.  The two failure modes
# are distinguished because a caller can legitimately want to retry with
# a different X0 on a flat derivative but not on mere slow convergence.
newton_raphson() {
    local fn="$1"
    local df="$2"
    local x="$3"
    local tol="${4:-1e-10}"
    local max_iter="${5:-100}"

    if ! [[ "$x" =~ ^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)([eE][+-]?[0-9]+)?$ ]]; then
        printf 'newton_raphson: initial guess is not numeric: %s\n' "$x" >&2
        return 1
    fi
    if ! [[ "$tol" =~ ^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)([eE][+-]?[0-9]+)?$ ]]; then
        printf 'newton_raphson: tolerance is not numeric: %s\n' "$tol" >&2
        return 1
    fi
    if ! [[ "$max_iter" =~ ^[0-9]+$ ]] || [ "$max_iter" -lt 1 ]; then
        printf 'newton_raphson: max_iter must be a positive integer: %s\n' "$max_iter" >&2
        return 1
    fi

    local i fx dfx step
    i=0
    while [ "$i" -lt "$max_iter" ]; do
        fx=$("$fn" "$x")
        dfx=$("$df" "$x")

        # A derivative of exactly zero is the classic Newton-Raphson
        # failure.  We treat anything below a small absolute threshold
        # the same way, because dividing by 1e-300 produces an overflow
        # long before the division itself is mathematically undefined.
        if awk -v d="$dfx" 'BEGIN { exit !(d < 1e-15 && d > -1e-15) }'; then
            printf 'newton_raphson: derivative near zero at x=%s\n' "$x" >&2
            return 1
        fi

        step=$(awk -v f="$fx" -v d="$dfx" 'BEGIN { printf "%.17g", f/d }')
        x=$(awk -v x="$x" -v s="$step" 'BEGIN { printf "%.17g", x-s }')

        # Convergence is measured on the size of the Newton step, not on
        # |f(x)|.  A function with a large slope can have |f| above TOL
        # while the root is already pinned down to machine precision; the
        # step is the honest measure of how much the estimate moved.
        if awk -v s="$step" -v t="$tol" 'BEGIN { exit !(s < t && s > -t) }'; then
            printf '%s\n' "$x"
            return 0
        fi

        i=$((i + 1))
    done

    printf 'newton_raphson: did not converge within %s iterations (last x=%s)\n' \
        "$max_iter" "$x" >&2
    return 2
}

# newton_raphson_sqrt VALUE [TOL [MAX_ITER]]
#
# Convenience wrapper that finds sqrt(VALUE) using f(x) = x^2 - VALUE.
# This exists mostly so that callers who just want a square root do not
# have to write two little helper functions themselves.  Negative inputs
# are rejected up front: Newton-Raphson on x^2 - c with c < 0 wanders
# forever (the derivative is zero at the origin and the iterates
# oscillate), so a clear error beats a hung script.
newton_raphson_sqrt() {
    local value="$1"
    local tol="${2:-1e-10}"
    local max_iter="${3:-100}"

    if ! awk -v v="$value" 'BEGIN { exit !(v >= 0) }'; then
        printf 'newton_raphson_sqrt: negative input: %s\n' "$value" >&2
        return 1
    fi

    # Seed with the value itself when it is >= 1, and with 1 otherwise.
    # Starting at 0 for small inputs is safe only because the derivative
    # at 0 is 2*0 = 0, which our zero-derivative guard rejects; starting
    # at 1 sidesteps that entirely.
    local seed
    seed=$(awk -v v="$value" 'BEGIN { if (v >= 1) print v; else print 1 }')

    # shellcheck disable=SC2317  # functions are invoked indirectly by name
    _nr_sqrt_f() { awk -v x="$1" -v c="$value" 'BEGIN { printf "%.17g", x*x - c }'; }
    # shellcheck disable=SC2317
    _nr_sqrt_df() { awk -v x="$1" 'BEGIN { printf "%.17g", 2*x }'; }

    newton_raphson _nr_sqrt_f _nr_sqrt_df "$seed" "$tol" "$max_iter"
}
