#!/usr/bin/env python3
"""
Linter de convenções Python para esta codebase.
Usa AST — sem falsos positivos de regex em strings ou comentários.

Convenções verificadas:
  - Sem f-strings       → use .format()
  - Sem else após if    → use early return  (for/else e try/except/else são permitidos)
  - Sem type hints      → nem em parâmetros nem em retorno
  - Sem docstrings      → nem em funções nem em classes

Uso: python3 python_style_check.py <arquivo.py>
Saída: uma violação por linha, vazio se ok.
Exit code: sempre 0 (quem decide bloquear é o shell wrapper).
"""

import ast
import sys


def check(path):
    try:
        source = open(path).read()
        tree = ast.parse(source, filename=path)
    except SyntaxError as e:
        print("[syntax] linha {}: {}".format(e.lineno, e.msg))
        sys.exit(0)
    except Exception:
        sys.exit(0)

    violations = []

    for node in ast.walk(tree):

        # F-strings — ast.JoinedStr é exatamente o nó de f-string
        if isinstance(node, ast.JoinedStr):
            violations.append((node.lineno, "[f-string] linha {}: Use .format() em vez de f-strings"))

        # else após if — ast.If.orelse que não é outro If (elif) é um else real
        # for/else e try/except/else usam ast.For/ast.Try, não ast.If — não são capturados
        if isinstance(node, ast.If) and node.orelse:
            is_elif = len(node.orelse) == 1 and isinstance(node.orelse[0], ast.If)
            if not is_elif:
                else_line = node.orelse[0].lineno
                violations.append((else_line, "[else] linha {}: Evite else — use early return"))

        # Type hints em funções e métodos
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

            # Docstring de função: primeira instrução é uma string constante
            if _is_docstring(node):
                doc_line = node.body[0].lineno
                violations.append((doc_line, "[docstring] linha {}: Não use docstrings — nomes descritivos bastam"))

        # Docstring de classe
        if isinstance(node, ast.ClassDef) and _is_docstring(node):
            doc_line = node.body[0].lineno
            violations.append((doc_line, "[docstring] linha {}: Não use docstrings — nomes descritivos bastam"))

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
