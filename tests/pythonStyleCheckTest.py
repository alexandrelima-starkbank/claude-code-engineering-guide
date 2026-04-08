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

    def testElse_forElse_notFlagged(self):
        out = run("for i in items:\n    pass\nelse:\n    pass\n")
        self.assertEqual("", out)

    def testElse_whileElse_notFlagged(self):
        out = run("while condition:\n    pass\nelse:\n    pass\n")
        self.assertEqual("", out)


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

    def testTypeHint_asyncReturnType_detected(self):
        out = run("async def foo() -> int:\n    return 1\n")
        self.assertIn("[type hint]", out)

    def testTypeHint_asyncParamType_detected(self):
        out = run("async def foo(x: str):\n    pass\n")
        self.assertIn("[type hint]", out)


class DocstringTest(TestCase):

    def testDocstring_inFunction_detected(self):
        out = run('def foo():\n    """docstring"""\n    pass\n')
        self.assertIn("[docstring]", out)

    def testDocstring_inClass_detected(self):
        out = run('class Foo:\n    """docstring"""\n    pass\n')
        self.assertIn("[docstring]", out)

    def testDocstring_asyncFunction_detected(self):
        out = run('async def foo():\n    """docstring"""\n    pass\n')
        self.assertIn("[docstring]", out)

    def testDocstring_multilineStringAsValue_notFlagged(self):
        out = run('def foo():\n    query = """\n    SELECT *\n    """\n    return query\n')
        self.assertEqual("", out)


class CamelCaseTest(TestCase):

    def testCamelCase_snakeFunctionName_detected(self):
        out = run("def my_func():\n    pass\n")
        self.assertIn("[camelCase]", out)

    def testCamelCase_camelFunctionName_notFlagged(self):
        out = run("def myFunc():\n    pass\n")
        self.assertEqual("", out)

    def testCamelCase_snakeParameter_detected(self):
        out = run("def foo(my_param):\n    pass\n")
        self.assertIn("[camelCase]", out)

    def testCamelCase_camelParameter_notFlagged(self):
        out = run("def foo(myParam):\n    pass\n")
        self.assertEqual("", out)

    def testCamelCase_testMethod_notFlagged(self):
        out = run("def testFoo_BarScenario():\n    pass\n")
        self.assertEqual("", out)

    def testCamelCase_dunder_notFlagged(self):
        out = run("class Foo:\n    def __init__(self):\n        pass\n")
        self.assertEqual("", out)

    def testCamelCase_privateSnakeFunction_detected(self):
        out = run("def _my_helper():\n    pass\n")
        self.assertIn("[camelCase]", out)

    def testCamelCase_privateCamelFunction_notFlagged(self):
        out = run("def _myHelper():\n    pass\n")
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
