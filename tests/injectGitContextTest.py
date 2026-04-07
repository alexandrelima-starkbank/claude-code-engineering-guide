import json
import os
import shutil
import subprocess
import tempfile
from unittest import TestCase, main, skipUnless

PROJECT_ROOT = os.path.join(os.path.dirname(__file__), "..")
HOOK = os.path.join(PROJECT_ROOT, ".claude", "hooks", "inject-git-context.sh")

HAS_JQ = subprocess.run(["which", "jq"], capture_output=True).returncode == 0


def run(cwd):
    payload = json.dumps({"session_id": "test"})
    return subprocess.run(
        ["bash", HOOK],
        input=payload,
        capture_output=True,
        text=True,
        cwd=cwd,
        env={**os.environ, "HOME": os.environ.get("HOME", "/tmp")},
    )


def git(cwd, *args):
    subprocess.run(["git"] + list(args), cwd=cwd, capture_output=True)


@skipUnless(HAS_JQ, "jq not installed")
class GitContextTest(TestCase):

    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()
        git(self.tmpdir, "init")
        git(self.tmpdir, "config", "user.email", "test@test.com")
        git(self.tmpdir, "config", "user.name", "Test")
        readme = os.path.join(self.tmpdir, "README.md")
        with open(readme, "w") as f:
            f.write("# Test\n")
        git(self.tmpdir, "add", "README.md")
        git(self.tmpdir, "commit", "-m", "Initial commit")

    def tearDown(self):
        shutil.rmtree(self.tmpdir, ignore_errors=True)

    def testGitRepo_outputsValidJson(self):
        result = run(self.tmpdir)
        self.assertEqual(result.returncode, 0)
        output = json.loads(result.stdout)
        self.assertIn("additionalContext", output["hookSpecificOutput"])

    def testGitRepo_contextContainsBranch(self):
        result = run(self.tmpdir)
        output = json.loads(result.stdout)
        context = output["hookSpecificOutput"]["additionalContext"]
        self.assertIn("Branch:", context)

    def testGitRepo_contextContainsProjectName(self):
        result = run(self.tmpdir)
        output = json.loads(result.stdout)
        context = output["hookSpecificOutput"]["additionalContext"]
        self.assertIn("Projeto:", context)

    def testGitRepo_contextContainsRecentCommit(self):
        result = run(self.tmpdir)
        output = json.loads(result.stdout)
        context = output["hookSpecificOutput"]["additionalContext"]
        self.assertIn("Initial commit", context)

    def testModifiedFile_appearsInContext(self):
        path = os.path.join(self.tmpdir, "modified.py")
        with open(path, "w") as f:
            f.write("x = 1\n")
        result = run(self.tmpdir)
        output = json.loads(result.stdout)
        context = output["hookSpecificOutput"]["additionalContext"]
        self.assertIn("modified.py", context)

    def testManyModifiedFiles_truncationNoticeShown(self):
        for i in range(12):
            path = os.path.join(self.tmpdir, "file{}.py".format(i))
            with open(path, "w") as f:
                f.write("x = {}\n".format(i))
        result = run(self.tmpdir)
        output = json.loads(result.stdout)
        context = output["hookSpecificOutput"]["additionalContext"]
        self.assertIn("mostrando 10 de", context)


@skipUnless(HAS_JQ, "jq not installed")
class OutsideGitRepoTest(TestCase):

    def testOutsideGitRepo_outputsValidJson(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            result = run(tmpdir)
            self.assertEqual(result.returncode, 0)
            output = json.loads(result.stdout)
            self.assertIn("additionalContext", output["hookSpecificOutput"])

    def testOutsideGitRepo_fallbackBranchMessage(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            result = run(tmpdir)
            output = json.loads(result.stdout)
            context = output["hookSpecificOutput"]["additionalContext"]
            self.assertIn("fora de um repositório git", context)


if __name__ == "__main__":
    main()
