import subprocess
import sys
import tempfile
import os
from unittest import TestCase, main

CHECKER = os.path.join(os.path.dirname(__file__), "..", ".claude", "hooks", "python_style_check.py")


def run(source):
    with tempfile.NamedTemporaryFile(suffix=".py", mode="w", delete=False, encoding="utf-8") as f:
        f.write(source)
        path = f.name
    try:
        result = subprocess.run(
            [sys.executable, CHECKER, path],
            capture_output=True, text=True
        )
        return result.stdout.strip()
    finally:
        os.unlink(path)


class FStringTest(TestCase):

    def testFString_detected(self):
        out = run('x = f"hello {name}"\n')
        self.assertIn("[f-string]", out)

    def testFString_formatNotFlagged(self):
        out = run('x = "hello {}".format(name)\n')
        self.assertEqual("", out)

    def testFString_stringContainingF_notFlagged(self):
        out = run('x = "staff"\n')
        self.assertEqual("", out)


class ElseBlockTest(TestCase):

    def testElse_afterIf_detected(self):
        out = run("if x:\n    pass\nelse:\n    pass\n")
        self.assertIn("[else]", out)

    def testElse_elif_notFlagged(self):
        out = run("if x:\n    pass\nelif y:\n    pass\n")
        self.assertEqual("", out)

    def testElse_forElse_detected(self):
        out = run("for i in items:\n    pass\nelse:\n    pass\n")
        self.assertIn("[else]", out)

    def testElse_whileElse_detected(self):
        out = run("while condition:\n    pass\nelse:\n    pass\n")
        self.assertIn("[else]", out)


class TypeHintTest(TestCase):

    def testTypeHint_returnType_detected(self):
        out = run("def foo() -> int:\n    return 1\n")
        self.assertIn("[type hint]", out)

    def testTypeHint_paramType_detected(self):
        out = run("def foo(x: str):\n    pass\n")
        self.assertIn("[type hint]", out)

    def testTypeHint_noAnnotation_notFlagged(self):
        out = run("def foo(x):\n    return x\n")
        self.assertEqual("", out)


class DocstringTest(TestCase):

    def testDocstring_inFunction_detected(self):
        out = run('def foo():\n    """docstring"""\n    pass\n')
        self.assertIn("[docstring]", out)

    def testDocstring_inClass_detected(self):
        out = run('class Foo:\n    """docstring"""\n    pass\n')
        self.assertIn("[docstring]", out)

    def testDocstring_multilineStringAsValue_notFlagged(self):
        out = run('def foo():\n    query = """\n    SELECT *\n    """\n    return query\n')
        self.assertEqual("", out)


class CleanCodeTest(TestCase):

    def testCleanCode_noViolations(self):
        source = (
            "from datetime import datetime\n\n"
            "class ItemHandler:\n\n"
            "    def getById(self, itemId):\n"
            "        item = self.gateway.findById(itemId)\n"
            "        if item is None:\n"
            "            return None\n"
            "        return item.json()\n"
        )
        out = run(source)
        self.assertEqual("", out)


if __name__ == "__main__":
    main()
