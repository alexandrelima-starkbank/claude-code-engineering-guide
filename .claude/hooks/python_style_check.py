#!/usr/bin/env python3
import ast
import sys


def check(path):
    try:
        with open(path, encoding="utf-8") as fh:
            source = fh.read()
        tree = ast.parse(source, filename=path)
    except SyntaxError as e:
        print("[syntax] linha {}: {}".format(e.lineno, e.msg))
        sys.exit(0)
    except Exception:
        sys.exit(0)

    violations = []

    for node in ast.walk(tree):

        if isinstance(node, ast.JoinedStr):
            violations.append((node.lineno, "[f-string] linha {}: Use .format() em vez de f-strings"))

        # else em if/else — exclui elif; try/except/else usa ast.Try (não capturado aqui)
        if isinstance(node, ast.If) and node.orelse:
            is_elif = len(node.orelse) == 1 and isinstance(node.orelse[0], ast.If)
            if not is_elif:
                else_line = node.orelse[0].lineno
                violations.append((else_line, "[else] linha {}: Evite else — use early return"))

        # else em for/while — também viola a convenção de no-else
        if isinstance(node, (ast.For, ast.While)) and node.orelse:
            else_line = node.orelse[0].lineno
            violations.append((else_line, "[else] linha {}: Evite for/while...else — use flag ou early return"))

        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
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

            if _is_docstring(node):
                violations.append((node.body[0].lineno, "[docstring] linha {}: Não use docstrings — nomes descritivos bastam"))

        if isinstance(node, ast.ClassDef) and _is_docstring(node):
            violations.append((node.body[0].lineno, "[docstring] linha {}: Não use docstrings — nomes descritivos bastam"))

    seen = set()
    for lineno, template in sorted(violations):
        msg = template.format(lineno)
        if msg not in seen:
            seen.add(msg)
            print(msg)


def _is_docstring(node):
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
