import os
import subprocess
import tempfile
import shutil
from unittest import TestCase, main

PROJECT_ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
SETUP = os.path.join(PROJECT_ROOT, "setup.sh")


def makeWorkdir(pyproject="", mutmut=""):
    d = tempfile.mkdtemp()
    if pyproject:
        with open(os.path.join(d, "pyproject.toml"), "w") as f:
            f.write(pyproject)
    if mutmut:
        with open(os.path.join(d, "mutmut.toml"), "w") as f:
            f.write(mutmut)
    hooks_dir = os.path.join(d, ".claude", "hooks")
    os.makedirs(hooks_dir)
    # chmod +x .claude/hooks/*.sh requer ao menos um arquivo .sh
    stub = os.path.join(hooks_dir, "stub.sh")
    with open(stub, "w") as f:
        f.write("#!/bin/bash\n")
    return d


def runSetup(workdir):
    return subprocess.run(
        ["bash", SETUP],
        capture_output=True,
        text=True,
        cwd=workdir,
    )


class PlaceholderValidationTest(TestCase):

    def setUp(self):
        self.workdir = makeWorkdir(
            pyproject="[tool.ruff.lint.isort]\nknown-first-party = [\"myapp\"]\n",
            mutmut="[mutmut]\npaths_to_mutate = \"myapp/\"\n",
        )

    def tearDown(self):
        shutil.rmtree(self.workdir, ignore_errors=True)

    def testValidConfig_exits0(self):
        result = runSetup(self.workdir)
        self.assertEqual(result.returncode, 0)

    def testKnownFirstPartyPlaceholder_exits1(self):
        with open(os.path.join(self.workdir, "pyproject.toml"), "w") as f:
            f.write("[tool.ruff.lint.isort]\nknown-first-party = []\n")
        result = runSetup(self.workdir)
        self.assertEqual(result.returncode, 1)
        self.assertIn("known-first-party", result.stdout)

    def testKnownFirstPartyPlaceholder_suggestsConfigureSh(self):
        with open(os.path.join(self.workdir, "pyproject.toml"), "w") as f:
            f.write("[tool.ruff.lint.isort]\nknown-first-party = []\n")
        result = runSetup(self.workdir)
        self.assertIn("configure.sh", result.stdout)

    def testPathsToMutatePlaceholder_exits1(self):
        with open(os.path.join(self.workdir, "mutmut.toml"), "w") as f:
            f.write('[mutmut]\npaths_to_mutate = "src/"\n')
        result = runSetup(self.workdir)
        self.assertEqual(result.returncode, 1)
        self.assertIn("paths_to_mutate", result.stdout)

    def testPathsToMutatePlaceholder_suggestsConfigureSh(self):
        with open(os.path.join(self.workdir, "mutmut.toml"), "w") as f:
            f.write('[mutmut]\npaths_to_mutate = "src/"\n')
        result = runSetup(self.workdir)
        self.assertIn("configure.sh", result.stdout)


class NoPyprojectTest(TestCase):

    def setUp(self):
        self.workdir = makeWorkdir()

    def tearDown(self):
        shutil.rmtree(self.workdir, ignore_errors=True)

    def testNoPyproject_exits0(self):
        result = runSetup(self.workdir)
        self.assertEqual(result.returncode, 0)

    def testNoMutmut_exits0(self):
        result = runSetup(self.workdir)
        self.assertEqual(result.returncode, 0)


class PermissionsTest(TestCase):

    def setUp(self):
        self.workdir = makeWorkdir()
        stub = os.path.join(self.workdir, ".claude", "hooks", "stub.sh")
        os.chmod(stub, 0o644)

    def tearDown(self):
        shutil.rmtree(self.workdir, ignore_errors=True)

    def testHooks_madeExecutable(self):
        runSetup(self.workdir)
        stub = os.path.join(self.workdir, ".claude", "hooks", "stub.sh")
        self.assertTrue(os.access(stub, os.X_OK))


if __name__ == "__main__":
    main()
