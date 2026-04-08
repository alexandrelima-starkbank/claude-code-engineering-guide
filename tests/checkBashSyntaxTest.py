import json
import os
import shutil
import subprocess
import tempfile
from unittest import TestCase, main, skipUnless

PROJECT_ROOT = os.path.join(os.path.dirname(__file__), "..")
HOOK = os.path.join(PROJECT_ROOT, ".claude", "hooks", "check-bash-syntax.sh")

HAS_JQ = subprocess.run(["which", "jq"], capture_output=True).returncode == 0


def run(file_path):
    payload = json.dumps({"tool_input": {"file_path": file_path}})
    return subprocess.run(
        ["bash", HOOK],
        input=payload,
        capture_output=True,
        text=True,
        cwd=PROJECT_ROOT,
    )


def makeSh(content):
    f = tempfile.NamedTemporaryFile(suffix=".sh", mode="w", delete=False, encoding="utf-8")
    f.write(content)
    f.close()
    return f.name


@skipUnless(HAS_JQ, "jq not installed")
class SyntaxCheckTest(TestCase):

    def testValidScript_noViolations(self):
        path = makeSh("#!/bin/bash\necho 'hello'\n")
        try:
            result = run(path)
            self.assertEqual(result.returncode, 0)
            self.assertNotIn("decision", result.stdout)
        finally:
            os.unlink(path)

    def testInvalidSyntax_blocked(self):
        path = makeSh("#!/bin/bash\nif [ $x == 1\n  echo broken\n")
        try:
            result = run(path)
            self.assertEqual(result.returncode, 0)
            self.assertIn("decision", result.stdout)
            self.assertIn("block", result.stdout)
        finally:
            os.unlink(path)

    def testUnclosedSubshell_blocked(self):
        path = makeSh("#!/bin/bash\nresult=$(echo hello\n")
        try:
            result = run(path)
            self.assertEqual(result.returncode, 0)
            self.assertIn("block", result.stdout)
        finally:
            os.unlink(path)

    def testNonShFile_ignored(self):
        f = tempfile.NamedTemporaryFile(suffix=".py", mode="w", delete=False)
        f.write("def foo(): pass\n")
        f.close()
        try:
            result = run(f.name)
            self.assertEqual(result.returncode, 0)
            self.assertEqual(result.stdout.strip(), "")
        finally:
            os.unlink(f.name)

    def testNonexistentFile_ignored(self):
        result = run("/tmp/nonexistent_hook_test.sh")
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout.strip(), "")


@skipUnless(HAS_JQ, "jq not installed")
class MultiEditTest(TestCase):

    def testMultiEdit_validFiles_noViolations(self):
        path1 = makeSh("#!/bin/bash\necho 'a'\n")
        path2 = makeSh("#!/bin/bash\necho 'b'\n")
        try:
            payload = json.dumps({"tool_input": {"edits": [
                {"file_path": path1},
                {"file_path": path2},
            ]}})
            result = subprocess.run(
                ["bash", HOOK],
                input=payload,
                capture_output=True,
                text=True,
                cwd=PROJECT_ROOT,
            )
            self.assertEqual(result.returncode, 0)
            self.assertNotIn("block", result.stdout)
        finally:
            os.unlink(path1)
            os.unlink(path2)

    def testMultiEdit_oneInvalid_blocked(self):
        good = makeSh("#!/bin/bash\necho 'ok'\n")
        bad = makeSh("#!/bin/bash\nif [ $x\n")
        try:
            payload = json.dumps({"tool_input": {"edits": [
                {"file_path": good},
                {"file_path": bad},
            ]}})
            result = subprocess.run(
                ["bash", HOOK],
                input=payload,
                capture_output=True,
                text=True,
                cwd=PROJECT_ROOT,
            )
            self.assertIn("block", result.stdout)
        finally:
            os.unlink(good)
            os.unlink(bad)

    def testMultiEdit_duplicateFile_checkedOnce(self):
        path = makeSh("#!/bin/bash\nif [ $x\n")
        try:
            payload = json.dumps({"tool_input": {"edits": [
                {"file_path": path},
                {"file_path": path},
            ]}})
            result = subprocess.run(
                ["bash", HOOK],
                input=payload,
                capture_output=True,
                text=True,
                cwd=PROJECT_ROOT,
            )
            self.assertEqual(result.stdout.count("sintaxe"), 1)
        finally:
            os.unlink(path)


@skipUnless(HAS_JQ, "jq not installed")
class ShellcheckAbsentTest(TestCase):

    def testShellcheckAbsent_warningInStderr(self):
        shellcheck_path = shutil.which("shellcheck")
        if shellcheck_path:
            # Exclui tanto o diretório do symlink quanto o do binário real
            real_path = os.path.realpath(shellcheck_path)
            dirs_to_exclude = {
                os.path.dirname(shellcheck_path),
                os.path.dirname(real_path),
            }
            filtered = ":".join(
                d for d in os.environ.get("PATH", "").split(":") if d not in dirs_to_exclude
            )
            env = {**os.environ, "PATH": filtered}
        else:
            env = os.environ.copy()

        path = makeSh("#!/bin/bash\necho 'hello'\n")
        try:
            payload = json.dumps({"tool_input": {"file_path": path}})
            result = subprocess.run(
                ["bash", HOOK],
                input=payload,
                capture_output=True,
                text=True,
                cwd=PROJECT_ROOT,
                env=env,
            )
            self.assertEqual(result.returncode, 0)
            self.assertNotIn("block", result.stdout)
            self.assertIn("shellcheck", result.stderr)
        finally:
            os.unlink(path)


if __name__ == "__main__":
    main()
