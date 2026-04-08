#!/usr/bin/env python3
import ast
import sys


def check(path):
    try:
        with open(path, encoding="utf-8") as fh:
            source = fh.read()
        tree = ast.parse(source, filename=path)
    except SyntaxError:
        sys.exit(0)
    except Exception:
        sys.exit(0)

    violations = []

    for node in ast.walk(tree):

        if isinstance(node, ast.JoinedStr):
            violations.append((node.lineno, "[f-string] linha {}: Use .format() em vez de f-strings"))

        # else em if/else — exclui elif; try/except/else usa ast.Try (não capturado aqui)
        # for/while...else são construções legítimas do Python (executa se sem break) e não são flagadas
        if isinstance(node, ast.If) and node.orelse:
            is_elif = len(node.orelse) == 1 and isinstance(node.orelse[0], ast.If)
            if not is_elif:
                else_line = node.orelse[0].lineno
                violations.append((else_line, "[else] linha {}: Evite else — use early return"))

        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
            # camelCase — nome da função (exclui dunders e funções test*)
            is_dunder = node.name.startswith('__') and node.name.endswith('__')
            if not is_dunder and not node.name.startswith('test'):
                stripped = node.name.lstrip('_')
                if '_' in stripped:
                    violations.append((node.lineno, "[camelCase] linha {{}}: Use camelCase em funções: {n}".format(n=node.name)))

            if node.returns is not None:
                violations.append((node.lineno, "[type hint] linha {}: Return type hints não são usados"))

            all_args = (
                node.args.args
                + node.args.posonlyargs
                + node.args.kwonlyargs
                + ([node.args.vararg] if node.args.vararg else [])
                + ([node.args.kwarg] if node.args.kwarg else [])
            )
            for arg in all_args:
                if arg.annotation is not None:
                    violations.append((arg.lineno, "[type hint] linha {}: Parameter type hints não são usados"))
                # camelCase — parâmetros (exclui self/cls e nomes sem underscore)
                if '_' in arg.arg:
                    violations.append((arg.lineno, "[camelCase] linha {{}}: Use camelCase em parâmetros: {n}".format(n=arg.arg)))

            if _isDocstring(node):
                violations.append((node.body[0].lineno, "[docstring] linha {}: Não use docstrings — nomes descritivos bastam"))

        if isinstance(node, ast.ClassDef) and _isDocstring(node):
            violations.append((node.body[0].lineno, "[docstring] linha {}: Não use docstrings — nomes descritivos bastam"))

    seen = set()
    for lineno, template in sorted(violations):
        msg = template.format(lineno)
        if msg not in seen:
            seen.add(msg)
            print(msg)


def _isDocstring(node):
    return (
        node.body
        and isinstance(node.body[0], ast.Expr)
        and isinstance(node.body[0].value, ast.Constant)
        and isinstance(node.body[0].value.value, str)
    )


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("uso: python3 python_style_check.py <arquivo.py>", file=sys.stderr)
        sys.exit(1)
    check(sys.argv[1])
