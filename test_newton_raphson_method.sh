#!/usr/bin/env bash
# Tests for newton_raphson_method.sh.
#
# Run with:  bash test_newton_raphson_method.sh
#
# The suite prints TAP-like output and exits non-zero on the first
# failure.  Numeric comparisons use a tolerance because Newton-Raphson
# is an iterative method and the last bit of the result depends on how
# the platform's awk rounds.

set -euo pipefail

# shellcheck source=newton_raphson_method.sh
. "$(dirname "$0")/newton_raphson_method.sh"

assert_eq() {
    local expected="$1"
    local actual="$2"
    local label="${3:-}"
    if [ "$expected" = "$actual" ]; then
        printf 'ok - %s\n' "$label"
    else
        printf 'not ok - %s\n' "$label"
        printf '  expected: %s\n' "$expected"
        printf '  actual:   %s\n' "$actual"
        exit 1
    fi
}

assert_close() {
    local expected="$1"
    local actual="$2"
    local tol="${3:-1e-8}"
    local label="${4:-}"
    if awk -v e="$expected" -v a="$actual" -v t="$tol" \
        'BEGIN { d = e - a; if (d < 0) d = -d; exit !(d <= t) }'; then
        printf 'ok - %s\n' "$label"
    else
        printf 'not ok - %s\n' "$label"
        printf '  expected: %s (+/- %s)\n' "$expected" "$tol"
        printf '  actual:   %s\n' "$actual"
        exit 1
    fi
}

# --- helper functions used by several tests -------------------------------

# f(x) = x^2 - 2, root at sqrt(2).
f_sq2() { awk -v x="$1" 'BEGIN { printf "%.17g", x*x - 2 }'; }
df_sq2() { awk -v x="$1" 'BEGIN { printf "%.17g", 2*x }'; }

# f(x) = cos(x) - x, root around 0.7390851332151607.
f_cos() { awk -v x="$1" 'BEGIN { printf "%.17g", cos(x) - x }'; }
df_cos() { awk -v x="$1" 'BEGIN { printf "%.17g", -sin(x) - 1 }'; }

# f(x) = x^3 - x - 2, root around 1.5213797068045676.
f_cubic() { awk -v x="$1" 'BEGIN { printf "%.17g", x*x*x - x - 2 }'; }
df_cubic() { awk -v x="$1" 'BEGIN { printf "%.17g", 3*x*x - 1 }'; }

# f(x) = x - 5, linear, should converge in one step.
f_linear() { awk -v x="$1" 'BEGIN { printf "%.17g", x - 5 }'; }
df_linear() { awk -v x="$1" 'BEGIN { printf "%.17g", 1 }'; }

# --- tests ----------------------------------------------------------------

result=$(newton_raphson f_sq2 df_sq2 1)
assert_close "1.4142135623730951" "$result" 1e-10 "sqrt(2) from x0=1"

result=$(newton_raphson f_sq2 df_sq2 100)
assert_close "1.4142135623730951" "$result" 1e-10 "sqrt(2) from a far-away guess"

result=$(newton_raphson f_sq2 df_sq2 -1)
assert_close "-1.4142135623730951" "$result" 1e-10 "negative root of x^2-2"

result=$(newton_raphson f_cos df_cos 1)
assert_close "0.7390851332151607" "$result" 1e-10 "cos(x) = x"

result=$(newton_raphson f_cubic df_cubic 1)
assert_close "1.5213797068045676" "$result" 1e-10 "cubic root"

# A linear function converges in a single step.  The loop still runs once
# because it checks the step size after updating x, so the answer is
# exact to awk's printing precision.
result=$(newton_raphson f_linear df_linear 0)
assert_close "5" "$result" 1e-12 "linear function"

# --- error paths ----------------------------------------------------------

# Zero derivative: f(x) = 1 has f'(x) = 0 everywhere.
f_const() { printf '1\n'; }
df_zero() { printf '0\n'; }

if newton_raphson f_const df_zero 0 >/dev/null 2>&1; then
    printf 'not ok - zero derivative should fail\n'
    exit 1
else
    printf 'ok - zero derivative is rejected\n'
fi

# Non-numeric initial guess.
if newton_raphson f_sq2 df_sq2 "not-a-number" >/dev/null 2>&1; then
    printf 'not ok - non-numeric guess should fail\n'
    exit 1
else
    printf 'ok - non-numeric guess is rejected\n'
fi

# max_iter must be a positive integer.
if newton_raphson f_sq2 df_sq2 1 1e-10 0 >/dev/null 2>&1; then
    printf 'not ok - zero max_iter should fail\n'
    exit 1
else
    printf 'ok - zero max_iter is rejected\n'
fi

# Convergence failure: a function whose derivative is tiny but nonzero
# takes many steps.  We cap at 1 iteration to force the failure path.
f_slow() { awk -v x="$1" 'BEGIN { printf "%.17g", x*x - 2 }'; }
df_slow() { awk -v x="$1" 'BEGIN { printf "%.17g", 1e-6 }'; }

if newton_raphson f_slow df_slow 1 1e-10 1 >/dev/null 2>&1; then
    printf 'not ok - iteration cap should fail\n'
    exit 1
else
    printf 'ok - iteration cap is enforced\n'
fi

# --- newton_raphson_sqrt --------------------------------------------------

result=$(newton_raphson_sqrt 2)
assert_close "1.4142135623730951" "$result" 1e-10 "sqrt(2) via wrapper"

result=$(newton_raphson_sqrt 9)
assert_close "3" "$result" 1e-10 "sqrt(9) via wrapper"

result=$(newton_raphson_sqrt 0)
assert_close "0" "$result" 1e-10 "sqrt(0) via wrapper"

result=$(newton_raphson_sqrt 0.25)
assert_close "0.5" "$result" 1e-10 "sqrt(0.25) via wrapper"

if newton_raphson_sqrt -1 >/dev/null 2>&1; then
    printf 'not ok - negative sqrt should fail\n'
    exit 1
else
    printf 'ok - negative sqrt is rejected\n'
fi

printf '# all tests passed\n'
