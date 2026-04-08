#!/usr/bin/env python3
"""
Convention Verifier — checks Python files against project conventions.

Usage:
    python3 verify.py file1.py file2.py
    python3 verify.py --git
    python3 verify.py --git-staged
"""
import re
import sys
import subprocess
from pathlib import Path


class Violation:
    def __init__(self, file, line, rule, message):
        self.file = file
        self.line = line
        self.rule = rule
        self.message = message

    def __str__(self):
        return "{file}:{line} [{rule}] {message}".format(
            file=self.file, line=self.line, rule=self.rule, message=self.message,
        )


def check_fstrings(filepath, lines):
    violations = []
    for i, line in enumerate(lines, 1):
        if line.strip().startswith("#"):
            continue
        if re.search(r'\bf["\']', line):
            violations.append(Violation(
                filepath, i, "NO-FSTRING",
                "f-string detected — use .format() instead",
            ))
    return violations


def check_else_blocks(filepath, lines):
    violations = []
    for i, line in enumerate(lines, 1):
        stripped = line.strip()
        if not (stripped == "else:" or stripped.startswith("else:")):
            continue
        is_allowed = False
        for j in range(i - 2, max(0, i - 20), -1):
            prev = lines[j].strip()
            if prev.startswith("except") or prev.startswith("try:"):
                is_allowed = True
                break
            if prev.startswith("def ") or prev.startswith("class "):
                break
        if not is_allowed:
            for j in range(i - 2, max(0, i - 30), -1):
                prev = lines[j].strip()
                if prev.startswith("for ") or prev.startswith("while "):
                    indent_for = len(lines[j]) - len(lines[j].lstrip())
                    indent_else = len(line) - len(line.lstrip())
                    if indent_for == indent_else:
                        is_allowed = True
                        break
                if prev.startswith("def ") or prev.startswith("class "):
                    break
        if not is_allowed:
            violations.append(Violation(
                filepath, i, "NO-ELSE",
                "else block detected — use early return pattern",
            ))
    return violations


def check_naming_conventions(filepath, lines):
    violations = []
    for i, line in enumerate(lines, 1):
        match = re.match(r"^\s*def\s+([a-z][a-z0-9_]*[a-z0-9])\s*\(", line)
        if not match:
            continue
        func_name = match.group(1)
        if func_name.startswith("__") and func_name.endswith("__"):
            continue
        if "_" not in func_name:
            continue
        if func_name.startswith("test"):
            continue
        if re.match(r"^_?[a-z]+(_[a-z]+)+$", func_name):
            violations.append(Violation(
                filepath, i, "NAMING",
                "snake_case function '{name}' — use camelCase".format(name=func_name),
            ))
    return violations


def check_trailing_comma(filepath, lines):
    violations = []
    for i, line in enumerate(lines, 1):
        if line.strip() != ")":
            continue
        if i < 2:
            continue
        prev = lines[i - 2].rstrip()
        if not prev:
            continue
        if prev.endswith(",") or prev.endswith("("):
            continue
        if prev.strip().startswith("#") or prev.strip().startswith(")"):
            continue
        if "=" in prev or prev.strip().startswith('"') or prev.strip().startswith("'"):
            violations.append(Violation(
                filepath, i - 1, "TRAILING-COMMA",
                "missing trailing comma on last argument",
            ))
    return violations


def check_forbidden_files(filepath):
    violations = []
    name = Path(filepath).name
    forbidden = {"main_local.py", "query_dev.py", "test_local.sh"}
    if name in forbidden:
        violations.append(Violation(
            filepath, 0, "FORBIDDEN-FILE",
            "file should not be committed: {n}".format(n=name),
        ))
    if "/it_tests/" in filepath or "\\it_tests\\" in filepath:
        violations.append(Violation(
            filepath, 0, "FORBIDDEN-FILE",
            "integration test files should not be committed",
        ))
    return violations


def get_git_files(staged_only=False):
    cmd = ["git", "diff", "--name-only"]
    if staged_only:
        cmd.append("--staged")
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        return [f for f in result.stdout.strip().split("\n") if f.endswith(".py") and f]
    except subprocess.CalledProcessError:
        return []


def verify_file(filepath):
    violations = check_forbidden_files(filepath)
    try:
        with open(filepath) as f:
            lines = f.read().split("\n")
    except (FileNotFoundError, PermissionError) as e:
        violations.append(Violation(filepath, 0, "READ-ERROR", str(e)))
        return violations
    violations.extend(check_fstrings(filepath, lines))
    violations.extend(check_else_blocks(filepath, lines))
    violations.extend(check_naming_conventions(filepath, lines))
    violations.extend(check_trailing_comma(filepath, lines))
    return violations


def main():
    args = sys.argv[1:]
    if not args:
        print("Usage: python3 verify.py <files...> | --git | --git-staged")
        sys.exit(1)
    if args[0] == "--git":
        files = get_git_files()
    elif args[0] == "--git-staged":
        files = get_git_files(staged_only=True)
    else:
        files = args
    if not files:
        print("No Python files to check.")
        sys.exit(0)
    all_violations = []
    for filepath in files:
        all_violations.extend(verify_file(filepath))
    if all_violations:
        print("FAIL — {n} violation(s):\n".format(n=len(all_violations)))
        for v in all_violations:
            print("  {v}".format(v=v))
        print("\nFix before proceeding.")
        sys.exit(1)
    else:
        print("PASS — {n} file(s) checked, no violations.".format(n=len(files)))
        sys.exit(0)


if __name__ == "__main__":
    main()
