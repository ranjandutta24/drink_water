import re, sys, pathlib

# Dart privates are library-scoped and every file here is its own library (no
# `part` directives in this project), so any _private name a file uses must also
# be declared in that same file. The analyzer catches this; dartcheck.py, which
# only balances brackets, cannot.

# Words that can sit immediately before a call and would otherwise be mistaken
# for the return type of a declaration.
KEYWORDS = {
    'return', 'await', 'yield', 'throw', 'else', 'case', 'is', 'in', 'as',
    'new', 'const', 'assert', 'if', 'while', 'do', 'switch', 'default',
    'required', 'super', 'this', 'and', 'or', 'not', 'of', 'the', 'to',
}

DECL_PATTERNS = [
    r'\b(?:class|mixin|enum|extension|typedef)\s+(_\w+)',   # types
    r'\bthis\.(_\w+)',                                      # field params
    r'\b\w+\.(_\w+)\s*\(',                                  # named ctors
    r'\bget\s+(_\w+)',                                      # getters
    r'\bset\s+(_\w+)',                                      # setters
    # Untyped `const _x = ...` / `final _x = ...`: the modifier is blacklisted
    # below (a `const _Foo(...)` call site looks the same), so match it here
    # where the `=` proves it is a declaration.
    r'\b(?:const|final|var|late)\s+(_\w+)\s*=',
]

def declarations(code):
    found = set()
    for pattern in DECL_PATTERNS:
        found |= set(re.findall(pattern, code))
    # A member or local declaration is preceded on the same line by a type or a
    # modifier -- that is exactly what a bare call site lacks.
    for prefix, name in re.findall(r'([\w>?\]]+)[ \t]+(_\w+)\s*[({;=,)]', code):
        if prefix not in KEYWORDS:
            found.add(name)
    return found

bad = 0
for path in sys.argv[1:]:
    src = pathlib.Path(path).read_text(encoding='utf-8')
    code = re.sub(r'//[^\n]*', '', src)
    code = re.sub(r'/\*.*?\*/', '', code, flags=re.S)
    code = re.sub(r"'''.*?'''|\"\"\".*?\"\"\"", "''", code, flags=re.S)
    code = re.sub(r"'(\\.|[^'\\\n])*'|\"(\\.|[^\"\\\n])*\"", "''", code)

    used = set(re.findall(r'(?<![\w$.])(_[A-Za-z]\w*)', code))
    missing = sorted(used - declarations(code))
    if missing:
        bad += 1
        for name in missing:
            line = next(
                (i for i, l in enumerate(src.splitlines(), 1)
                 if re.search(r'(?<![\w$.])' + name + r'\b', l)), 0)
            print(f'{path}:{line}: undefined private name {name}')
print(f'{len(sys.argv) - 1} files checked, {bad} with findings')
