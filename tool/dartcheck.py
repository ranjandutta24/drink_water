#!/usr/bin/env python3
"""A delimiter/lexical sanity check for Dart files.

Not a parser. It tokenises far enough to know what is code and what is not --
line comments, nestable block comments, single and triple quoted strings, raw
strings, escapes, and ${...} interpolation with nested braces -- and then checks
that (), [] and {} balance in the code regions. That catches the overwhelming
majority of hand-editing slips (a missing closing brace, a stray paren, an
unterminated string) which is what `dart format` was being used for as a gate.
"""
import sys

OPEN = {')': '(', ']': '[', '}': '{'}


def check(path):
    src = open(path, encoding='utf-8').read()
    i, n = 0, len(src)
    line = 1
    stack = []            # (char, line) for code delimiters
    # Each interpolation pushes the string state to return to.
    interp = []           # (quote, triple, raw, brace_depth_at_entry)
    quote = None          # current string delimiter, None when in code
    triple = raw = False
    block_depth = 0       # /* */ nesting

    while i < n:
        c = src[i]
        if c == '\n':
            line += 1
            if quote is not None and not triple:
                return f'{path}:{line}: unterminated string'
            i += 1
            continue

        # --- inside a block comment ---
        if block_depth:
            if src.startswith('/*', i):
                block_depth += 1
                i += 2
                continue
            if src.startswith('*/', i):
                block_depth -= 1
                i += 2
                continue
            i += 1
            continue

        # --- inside a string ---
        if quote is not None:
            if not raw and c == '\\':
                i += 2
                continue
            if not raw and src.startswith('${', i):
                interp.append((quote, triple, raw, len(stack)))
                quote, triple, raw = None, False, False
                stack.append(('{', line))
                i += 2
                continue
            if triple and src.startswith(quote * 3, i):
                i += 3
                quote = None
                continue
            if not triple and c == quote:
                quote = None
                i += 1
                continue
            i += 1
            continue

        # --- code ---
        if src.startswith('//', i):
            j = src.find('\n', i)
            i = n if j < 0 else j
            continue
        if src.startswith('/*', i):
            block_depth = 1
            i += 2
            continue

        if c == 'r' and i + 1 < n and src[i + 1] in '\'"':
            raw = True
            i += 1
            continue

        if c in '\'"':
            if src.startswith(c * 3, i):
                quote, triple = c, True
                i += 3
            else:
                quote, triple = c, False
                i += 1
            continue
        raw = False

        if c in '([{':
            stack.append((c, line))
            i += 1
            continue
        if c in ')]}':
            if c == '}' and interp and len(stack) - 1 == interp[-1][3]:
                # Closing brace of a ${...}: pop back into the string.
                if not stack or stack[-1][0] != '{':
                    return f'{path}:{line}: unbalanced }} in interpolation'
                stack.pop()
                quote, triple, raw, _ = interp.pop()
                i += 1
                continue
            if not stack:
                return f'{path}:{line}: closing {c!r} with nothing open'
            want = OPEN[c]
            got, opened = stack.pop()
            if got != want:
                return (f'{path}:{line}: closing {c!r} but innermost open is '
                        f'{got!r} from line {opened}')
            i += 1
            continue
        i += 1

    if block_depth:
        return f'{path}: unterminated block comment'
    if quote is not None:
        return f'{path}: unterminated string at end of file'
    if stack:
        got, opened = stack[-1]
        return f'{path}: {got!r} opened at line {opened} is never closed'
    return None


bad = 0
for p in sys.argv[1:]:
    err = check(p)
    if err:
        bad += 1
        print('FAIL', err)
print(f'{len(sys.argv) - 1 - bad} ok, {bad} failed')
sys.exit(1 if bad else 0)
