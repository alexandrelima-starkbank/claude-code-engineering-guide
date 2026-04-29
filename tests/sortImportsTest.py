import os
import json
import tempfile
import subprocess
import importlib.util
from unittest import TestCase, main

PROJECT_ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
SCRIPT = os.path.join(PROJECT_ROOT, ".claude", "hooks", "sortImports.py")
HOOK = os.path.join(PROJECT_ROOT, ".claude", "hooks", "sort-imports-on-edit.sh")

HAS_JQ = subprocess.run(["which", "jq"], capture_output=True).returncode == 0


def loadSortImports():
    spec = importlib.util.spec_from_file_location("sortImports", SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def makePyFile(content):
    f = tempfile.NamedTemporaryFile(mode="w", suffix=".py", delete=False)
    f.write(content)
    f.close()
    return f.name


class SortImportsScriptTest(TestCase):

    def setUp(self):
        self.mod = loadSortImports()

    def testSortImports_classifiesThreeGroups(self):
        fname = makePyFile(
            "import os\n"
            "from requests import get\n"
            "from myapp.models import User\n"
        )
        try:
            self.mod.sortImports(fname, localPackages={"myapp"})
            lines = [l for l in open(fname).read().splitlines() if l.strip()]
            os_idx = next(i for i, l in enumerate(lines) if l.strip() == "import os")
            req_idx = next(i for i, l in enumerate(lines) if "requests" in l)
            myapp_idx = next(i for i, l in enumerate(lines) if "myapp" in l)
            self.assertLess(os_idx, req_idx)
            self.assertLess(req_idx, myapp_idx)
        finally:
            os.unlink(fname)

    def testSortImports_ascendingByLength(self):
        fname = makePyFile(
            "from datetime import datetime\n"
            "import re\n"
        )
        try:
            self.mod.sortImports(fname, localPackages=set())
            lines = [l for l in open(fname).read().splitlines() if l.strip()]
            re_idx = next(i for i, l in enumerate(lines) if l.strip() == "import re")
            dt_idx = next(i for i, l in enumerate(lines) if "datetime" in l)
            self.assertLess(re_idx, dt_idx)
        finally:
            os.unlink(fname)

    def testSortImports_localGroupComesAfterExternal(self):
        fname = makePyFile(
            "import myapp\n"
            "from requests import get\n"
            "import os\n"
        )
        try:
            self.mod.sortImports(fname, localPackages={"myapp"})
            lines = [l for l in open(fname).read().splitlines() if l.strip()]
            req_idx = next(i for i, l in enumerate(lines) if "requests" in l)
            myapp_idx = next(i for i, l in enumerate(lines) if "myapp" in l)
            self.assertLess(req_idx, myapp_idx)
        finally:
            os.unlink(fname)

    def testSortImports_localGroupDescendingByMaxLen(self):
        fname = makePyFile(
            "from utils.parse import parse\n"
            "from models.order import OrderStatus, PaymentMethod\n"
            "from models.user import User\n"
        )
        try:
            self.mod.sortImports(fname, localPackages={"utils", "models"})
            lines = [l for l in open(fname).read().splitlines() if l.strip()]
            first_models = next(i for i, l in enumerate(lines) if "models" in l)
            utils_idx = next(i for i, l in enumerate(lines) if "utils" in l)
            self.assertLess(first_models, utils_idx)
        finally:
            os.unlink(fname)

    def testSortImports_groupOrder(self):
        fname = makePyFile(
            "from myapp.models import User\n"
            "from requests import get\n"
            "import os\n"
        )
        try:
            self.mod.sortImports(fname, localPackages={"myapp"})
            lines = [l for l in open(fname).read().splitlines() if l.strip()]
            os_idx = next(i for i, l in enumerate(lines) if l.strip() == "import os")
            req_idx = next(i for i, l in enumerate(lines) if "requests" in l)
            myapp_idx = next(i for i, l in enumerate(lines) if "myapp" in l)
            self.assertLess(os_idx, req_idx)
            self.assertLess(req_idx, myapp_idx)
        finally:
            os.unlink(fname)


class SortImportsUnitsTest(TestCase):

    def setUp(self):
        self.mod = loadSortImports()

    def testClassifyImport_stdlib(self):
        result = self.mod.classifyImport("import os", set())
        self.assertEqual(result, "stdlib")

    def testClassifyImport_external(self):
        result = self.mod.classifyImport("from requests import get", set())
        self.assertEqual(result, "external")

    def testClassifyImport_local(self):
        result = self.mod.classifyImport("from myapp.models import User", {"myapp"})
        self.assertEqual(result, "local")

    def testClassifyImport_noTopLevel_returnsOther(self):
        result = self.mod.classifyImport("x = 1", set())
        self.assertEqual(result, "other")

    def testGetTopLevelModule_fromImport(self):
        result = self.mod.getTopLevelModule("from re import compile")
        self.assertEqual(result, "re")

    def testGetTopLevelModule_simpleImport(self):
        result = self.mod.getTopLevelModule("import os")
        self.assertEqual(result, "os")

    def testGetTopLevelModule_dottedModule(self):
        result = self.mod.getTopLevelModule("from models.order import OrderStatus")
        self.assertEqual(result, "models")

    def testGetTopLevelModule_dottedImportStatement(self):
        result = self.mod.getTopLevelModule("import os.path")
        self.assertEqual(result, "os")

    def testGetTopLevelModule_notAnImport_returnsNone(self):
        result = self.mod.getTopLevelModule("x = 1")
        self.assertIsNone(result)

    def testSortKey_returnsLineLength(self):
        self.assertEqual(self.mod.sortKey("import os"), 9)
        self.assertEqual(self.mod.sortKey("from datetime import datetime"), 29)

    def testExtractImportBlock_multipleImports(self):
        lines = ["import os\n", "import re\n", "\n", "x = 1\n"]
        start, end, block = self.mod.extractImportBlock(lines)
        self.assertEqual(start, 0)
        self.assertEqual(end, 2)
        self.assertEqual(len(block), 2)

    def testExtractImportBlock_noImports_returnsNone(self):
        lines = ["x = 1\n", "y = 2\n"]
        start, end, block = self.mod.extractImportBlock(lines)
        self.assertIsNone(start)

    def testExtractImportBlock_stopsAtNonImportNonBlank(self):
        lines = ["import os\n", "import re\n", "x = 1\n", "import sys\n"]
        start, end, block = self.mod.extractImportBlock(lines)
        self.assertEqual(start, 0)
        self.assertEqual(end, 2)
        self.assertEqual(len(block), 2)

    def testExtractImportBlock_commentBetweenImports_doesNotBreakBlock(self):
        lines = ["import os\n", "# a comment\n", "import re\n"]
        start, end, block = self.mod.extractImportBlock(lines)
        self.assertEqual(start, 0)
        self.assertEqual(end, 3)
        self.assertEqual(len(block), 3)

    def testExtractImportBlock_singleImport(self):
        lines = ["import os\n", "\n", "x = 1\n"]
        start, end, block = self.mod.extractImportBlock(lines)
        self.assertEqual(start, 0)
        self.assertEqual(end, 1)
        self.assertEqual(block[0].strip(), "import os")

    def testDetectLocalPackages_requiresInitPy(self):
        with tempfile.TemporaryDirectory() as projdir:
            emptyDir = os.path.join(projdir, "notapackage")
            os.makedirs(emptyDir)
            pkgDir = os.path.join(projdir, "realpackage")
            os.makedirs(pkgDir)
            with open(os.path.join(pkgDir, "__init__.py"), "w") as f:
                f.write("")
            from pathlib import Path
            detected = self.mod.detectLocalPackages(Path(projdir))
            self.assertIn("realpackage", detected)
            self.assertNotIn("notapackage", detected)

    def testSortLocalGroup_sameNamespaceGrouped(self):
        lines = [
            "from models.user import User",
            "from utils.parse import parse",
            "from models.order import OrderStatus, PaymentMethod",
        ]
        result = self.mod.sortLocalGroup(lines)
        first_models = next(i for i, l in enumerate(result) if "models" in l)
        utils_idx = next(i for i, l in enumerate(result) if "utils" in l)
        last_models = max(i for i, l in enumerate(result) if "models" in l)
        self.assertLess(first_models, utils_idx)
        self.assertLess(last_models, utils_idx)


class SortImportsIntegrationTest(TestCase):

    def setUp(self):
        self.mod = loadSortImports()

    def testSortImports_stdlibBeforeExternalEvenWhenLonger(self):
        fname = makePyFile(
            "import jwt\n"
            "from collections import OrderedDict\n"
        )
        try:
            self.mod.sortImports(fname, localPackages=set())
            lines = [l for l in open(fname).read().splitlines() if l.strip()]
            collections_idx = next(i for i, l in enumerate(lines) if "collections" in l)
            jwt_idx = next(i for i, l in enumerate(lines) if "jwt" in l)
            self.assertLess(collections_idx, jwt_idx)
        finally:
            os.unlink(fname)

    def testSortImports_preservesBlankLineAndCode(self):
        fname = makePyFile(
            "from datetime import datetime\n"
            "import re\n"
            "\n"
            "x = 1\n"
        )
        try:
            self.mod.sortImports(fname, localPackages=set())
            content = open(fname).read()
            self.assertIn("import re\nfrom datetime import datetime\n", content)
            self.assertIn("\n\nx = 1", content)
            self.assertNotIn("XX", content)
        finally:
            os.unlink(fname)

    def testSortImports_noImports_fileUnchanged(self):
        original = "x = 1\ny = 2\n"
        fname = makePyFile(original)
        try:
            self.mod.sortImports(fname, localPackages=set())
            content = open(fname).read()
            self.assertEqual(content, original)
        finally:
            os.unlink(fname)

    def testSortImports_autoDetectsLocalViaKnownFirstParty(self):
        with tempfile.TemporaryDirectory() as projdir:
            with open(os.path.join(projdir, "pyproject.toml"), "w") as f:
                f.write('[tool.ruff.lint]\nknown-first-party = ["myapp"]\n')
            fname = os.path.join(projdir, "main.py")
            with open(fname, "w") as f:
                f.write(
                    "from myapp.models import User\n"
                    "from requests import get\n"
                    "import os\n"
                )
            self.mod.sortImports(fname)
            lines = [l for l in open(fname).read().splitlines() if l.strip()]
            os_idx = next(i for i, l in enumerate(lines) if l.strip() == "import os")
            req_idx = next(i for i, l in enumerate(lines) if "requests" in l)
            myapp_idx = next(i for i, l in enumerate(lines) if "myapp" in l)
            self.assertLess(os_idx, req_idx)
            self.assertLess(req_idx, myapp_idx)

    def testSortImports_outputJoinsWithNewline(self):
        fname = makePyFile(
            "import sys\n"
            "import os\n"
            "\n"
            "x = 1\n"
        )
        try:
            self.mod.sortImports(fname, localPackages=set())
            raw = open(fname, "rb").read()
            self.assertIn(b"import os\nimport sys\n", raw)
            self.assertNotIn(b"XX", raw)
        finally:
            os.unlink(fname)

    def testSortImports_blankLineInImportBlock(self):
        fname = makePyFile("import sys\n\nimport os\n\nx = 1\n")
        try:
            self.mod.sortImports(fname, localPackages=set())
            lines = [l for l in open(fname).read().splitlines() if l.strip()]
            self.assertTrue(any("import os" in l for l in lines))
            self.assertTrue(any("import sys" in l for l in lines))
            os_idx = next(i for i, l in enumerate(lines) if l.strip() == "import os")
            sys_idx = next(i for i, l in enumerate(lines) if l.strip() == "import sys")
            self.assertLess(os_idx, sys_idx)
        finally:
            os.unlink(fname)

    def testSortImports_detectsLocalViaInit(self):
        with tempfile.TemporaryDirectory() as projdir:
            with open(os.path.join(projdir, "pyproject.toml"), "w") as f:
                f.write("[tool.ruff.lint]\n")
            pkgDir = os.path.join(projdir, "mylocal")
            os.makedirs(pkgDir)
            with open(os.path.join(pkgDir, "__init__.py"), "w") as f:
                f.write("")
            fname = os.path.join(projdir, "main.py")
            with open(fname, "w") as f:
                f.write(
                    "import mylocal\n"
                    "from very_long_external_library.module import SomeName\n"
                    "import os\n"
                )
            self.mod.sortImports(fname)
            lines = [l for l in open(fname).read().splitlines() if l.strip()]
            longlib_idx = next(i for i, l in enumerate(lines) if "very_long" in l)
            mylocal_idx = next(i for i, l in enumerate(lines) if "mylocal" in l)
            self.assertLess(longlib_idx, mylocal_idx)

    def testSortImports_findProjectRootInParent(self):
        with tempfile.TemporaryDirectory() as projdir:
            with open(os.path.join(projdir, "pyproject.toml"), "w") as f:
                f.write('[tool.ruff.lint]\nknown-first-party = ["parentapp"]\n')
            subdir = os.path.join(projdir, "subdir")
            os.makedirs(subdir)
            fname = os.path.join(subdir, "main.py")
            with open(fname, "w") as f:
                f.write(
                    "from parentapp.models import User\n"
                    "from very_long_external_library.module import SomeName\n"
                    "import os\n"
                )
            self.mod.sortImports(fname)
            lines = [l for l in open(fname).read().splitlines() if l.strip()]
            longlib_idx = next(i for i, l in enumerate(lines) if "very_long" in l)
            parentapp_idx = next(i for i, l in enumerate(lines) if "parentapp" in l)
            self.assertLess(longlib_idx, parentapp_idx)

    def testSortImports_codeBeforeImports_importsStillSorted(self):
        fname = makePyFile(
            "x = 1\n"
            "import sys\n"
            "import os\n"
        )
        try:
            self.mod.sortImports(fname, localPackages=set())
            content = open(fname).read()
            self.assertIn("x = 1", content)
        finally:
            os.unlink(fname)

    def testSortImports_cliNoArgs_exits1(self):
        result = subprocess.run(
            ["python3", SCRIPT],
            capture_output=True,
        )
        self.assertEqual(result.returncode, 1)


class SortImportsHookTest(TestCase):

    def runHook(self, toolInput, home=None):
        env = dict(os.environ)
        if home:
            env["HOME"] = home
        payload = json.dumps({"tool_input": toolInput})
        return subprocess.run(
            ["bash", HOOK],
            input=payload,
            capture_output=True,
            text=True,
            env=env,
            cwd=PROJECT_ROOT,
        )

    def testHook_invokesOnPyEdit(self):
        fname = makePyFile(
            "from datetime import datetime\n"
            "import re\n"
            "\n"
            "x = 1\n"
        )
        try:
            result = self.runHook({"file_path": fname})
            self.assertEqual(result.returncode, 0)
            lines = [l for l in open(fname).read().splitlines() if l.startswith(("import", "from"))]
            re_idx = next(i for i, l in enumerate(lines) if l.strip() == "import re")
            dt_idx = next(i for i, l in enumerate(lines) if "datetime" in l)
            self.assertLess(re_idx, dt_idx)
        finally:
            os.unlink(fname)

    def testHook_fallbackToLocalScript(self):
        with tempfile.TemporaryDirectory() as fakeHome:
            fname = makePyFile(
                "from datetime import datetime\n"
                "import re\n"
                "\n"
                "x = 1\n"
            )
            try:
                result = self.runHook({"file_path": fname}, home=fakeHome)
                self.assertEqual(result.returncode, 0)
                lines = [l for l in open(fname).read().splitlines() if l.startswith(("import", "from"))]
                re_idx = next(i for i, l in enumerate(lines) if l.strip() == "import re")
                dt_idx = next(i for i, l in enumerate(lines) if "datetime" in l)
                self.assertLess(re_idx, dt_idx)
            finally:
                os.unlink(fname)

    def testHook_silentWhenUnavailable(self):
        with tempfile.TemporaryDirectory() as fakeHome:
            result = subprocess.run(
                ["bash", HOOK],
                input=json.dumps({"tool_input": {"file_path": "/tmp/test.py"}}),
                capture_output=True,
                text=True,
                env={**os.environ, "HOME": fakeHome},
                cwd=fakeHome,
            )
            self.assertEqual(result.returncode, 0)
            self.assertEqual(result.stderr, "")

    def testHook_nonPyFile_skipped(self):
        fname = makePyFile("from datetime import datetime\nimport re\n")
        fname_sh = fname.replace(".py", ".sh")
        os.rename(fname, fname_sh)
        try:
            result = self.runHook({"file_path": fname_sh})
            self.assertEqual(result.returncode, 0)
            content = open(fname_sh).read()
            self.assertIn("from datetime import datetime", content.splitlines()[0])
        finally:
            os.unlink(fname_sh)


class SortImportsSettingsTest(TestCase):

    def testSettings_hookRegisteredInMatcher(self):
        settings_path = os.path.join(PROJECT_ROOT, ".claude", "settings.json")
        data = json.loads(open(settings_path).read())
        post_tool = data.get("hooks", {}).get("PostToolUse", [])
        edit_matcher = next(
            (h for h in post_tool if h.get("matcher") == "Edit|Write|MultiEdit"),
            None,
        )
        self.assertIsNotNone(edit_matcher)
        hook_commands = [h["command"] for h in edit_matcher.get("hooks", [])]
        self.assertTrue(any("sort-imports-on-edit" in cmd for cmd in hook_commands))


class ImportSortingConfigTest(TestCase):

    def testPyproject_noRuffI(self):
        content = open(os.path.join(PROJECT_ROOT, "pyproject.toml")).read()
        import re
        match = re.search(r'select\s*=\s*\[([^\]]*)\]', content)
        self.assertIsNotNone(match)
        select = match.group(1)
        self.assertNotIn('"I"', select)
        self.assertNotIn("'I'", select)

    def testPyproject_noIsortSection(self):
        content = open(os.path.join(PROJECT_ROOT, "pyproject.toml")).read()
        self.assertNotIn("[tool.ruff.lint.isort]", content)

    def testConventions_referenceSortImports(self):
        content = open(os.path.join(PROJECT_ROOT, "CONVENTIONS.starkbank.md")).read()
        self.assertIn("sortImports", content)

    def testClaudeMd_noRuffI(self):
        content = open(os.path.join(PROJECT_ROOT, "CLAUDE.md")).read()
        self.assertIn("sortImports", content)


if __name__ == "__main__":
    main()
