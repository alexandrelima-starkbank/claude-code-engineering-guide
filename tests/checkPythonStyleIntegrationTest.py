import json
import os
import subprocess
import tempfile
from unittest import TestCase, main, skipUnless

PROJECT_ROOT = os.path.join(os.path.dirname(__file__), "..")
HOOK = os.path.join(PROJECT_ROOT, ".claude", "hooks", "check-python-style.sh")

HAS_JQ = subprocess.run(["which", "jq"], capture_output=True).returncode == 0


def runHook(payload):
    return subprocess.run(
        ["bash", HOOK],
        input=json.dumps(payload),
        capture_output=True,
        text=True,
        cwd=PROJECT_ROOT,
    )


def makePy(content):
    f = tempfile.NamedTemporaryFile(suffix=".py", mode="w", delete=False, encoding="utf-8")
    f.write(content)
    f.close()
    return f.name


@skipUnless(HAS_JQ, "jq not installed")
class EditSingleFileTest(TestCase):

    def testFString_hooksBlocks(self):
        path = makePy('x = f"hello {name}"\n')
        try:
            result = runHook({"tool_input": {"file_path": path}})
            self.assertEqual(result.returncode, 0)
            self.assertIn("block", result.stdout)
            self.assertIn("f-string", result.stdout)
        finally:
            os.unlink(path)

    def testCleanFile_hookAllows(self):
        path = makePy('x = "hello {}".format(name)\n')
        try:
            result = runHook({"tool_input": {"file_path": path}})
            self.assertEqual(result.returncode, 0)
            self.assertNotIn("block", result.stdout)
        finally:
            os.unlink(path)

    def testNonPyFile_ignored(self):
        f = tempfile.NamedTemporaryFile(suffix=".txt", mode="w", delete=False)
        f.write('x = f"hello"\n')
        f.close()
        try:
            result = runHook({"tool_input": {"file_path": f.name}})
            self.assertEqual(result.returncode, 0)
            self.assertEqual(result.stdout.strip(), "")
        finally:
            os.unlink(f.name)

    def testElseBlock_hookBlocks(self):
        path = makePy("if x:\n    pass\nelse:\n    pass\n")
        try:
            result = runHook({"tool_input": {"file_path": path}})
            self.assertIn("block", result.stdout)
        finally:
            os.unlink(path)

    def testSnakeCaseFunction_hookBlocks(self):
        path = makePy("def my_func():\n    pass\n")
        try:
            result = runHook({"tool_input": {"file_path": path}})
            self.assertIn("block", result.stdout)
            self.assertIn("camelCase", result.stdout)
        finally:
            os.unlink(path)


@skipUnless(HAS_JQ, "jq not installed")
class MultiEditTest(TestCase):

    def testMultiEdit_violationDetected(self):
        clean = makePy('x = "ok"\n')
        dirty = makePy('y = f"bad {x}"\n')
        try:
            result = runHook({"tool_input": {"edits": [
                {"file_path": clean},
                {"file_path": dirty},
            ]}})
            self.assertIn("block", result.stdout)
        finally:
            os.unlink(clean)
            os.unlink(dirty)

    def testMultiEdit_allClean_allows(self):
        a = makePy('x = "ok"\n')
        b = makePy('y = "also ok"\n')
        try:
            result = runHook({"tool_input": {"edits": [
                {"file_path": a},
                {"file_path": b},
            ]}})
            self.assertNotIn("block", result.stdout)
        finally:
            os.unlink(a)
            os.unlink(b)


if __name__ == "__main__":
    main()
