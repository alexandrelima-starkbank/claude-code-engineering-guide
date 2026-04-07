import json
import os
import subprocess
from unittest import TestCase, main, skipUnless

PROJECT_ROOT = os.path.join(os.path.dirname(__file__), "..")
HOOK = os.path.join(PROJECT_ROOT, ".claude", "hooks", "validate-destructive.sh")

HAS_JQ = subprocess.run(["which", "jq"], capture_output=True).returncode == 0


def run(command):
    payload = json.dumps({"tool_input": {"command": command}})
    return subprocess.run(
        ["bash", HOOK],
        input=payload,
        capture_output=True,
        text=True,
        cwd=PROJECT_ROOT,
    )


def blocked(result):
    return result.returncode == 2 and "BLOQUEADO" in result.stderr


def allowed(result):
    return result.returncode == 0


@skipUnless(HAS_JQ, "jq not installed")
class RmRfTest(TestCase):

    def testRmRf_basic_blocked(self):
        self.assertTrue(blocked(run("rm -rf /tmp/test")))

    def testRmRf_fr_variant_blocked(self):
        self.assertTrue(blocked(run("rm -fr /tmp/test")))

    def testRmRf_separatedFlags_blocked(self):
        self.assertTrue(blocked(run("rm -r -f /tmp/test")))

    def testRmRf_sudo_blocked(self):
        self.assertTrue(blocked(run("sudo rm -rf /tmp/test")))

    def testRm_singleFile_allowed(self):
        self.assertTrue(allowed(run("rm /tmp/file.txt")))

    def testRm_dashR_only_allowed(self):
        self.assertTrue(allowed(run("rm -r /tmp/dir")))


@skipUnless(HAS_JQ, "jq not installed")
class GitPushTest(TestCase):

    def testGitPush_force_blocked(self):
        self.assertTrue(blocked(run("git push --force")))

    def testGitPush_shortFlag_blocked(self):
        self.assertTrue(blocked(run("git push -f origin main")))

    def testGitPush_forceAtEnd_blocked(self):
        self.assertTrue(blocked(run("git push origin main --force")))

    def testGitPush_forceWithLease_blocked(self):
        self.assertTrue(blocked(run("git push origin main --force-with-lease")))

    def testGitPush_normal_allowed(self):
        self.assertTrue(allowed(run("git push origin main")))


@skipUnless(HAS_JQ, "jq not installed")
class GitResetTest(TestCase):

    def testGitReset_hard_blocked(self):
        self.assertTrue(blocked(run("git reset --hard")))

    def testGitReset_hard_withRef_blocked(self):
        self.assertTrue(blocked(run("git reset --hard HEAD~1")))

    def testGitReset_soft_allowed(self):
        self.assertTrue(allowed(run("git reset --soft HEAD~1")))

    def testGitReset_mixed_allowed(self):
        self.assertTrue(allowed(run("git reset HEAD file.py")))


@skipUnless(HAS_JQ, "jq not installed")
class GitRestoreTest(TestCase):

    def testGitRestore_worktree_blocked(self):
        self.assertTrue(blocked(run("git restore .")))

    def testGitRestore_file_blocked(self):
        self.assertTrue(blocked(run("git restore file.py")))

    def testGitRestore_staged_allowed(self):
        self.assertTrue(allowed(run("git restore --staged file.py")))

    def testGitRestore_stagedAndWorktree_blocked(self):
        self.assertTrue(blocked(run("git restore --staged --worktree file.py")))


@skipUnless(HAS_JQ, "jq not installed")
class GitCleanTest(TestCase):

    def testGitClean_force_blocked(self):
        self.assertTrue(blocked(run("git clean -f")))

    def testGitClean_fd_blocked(self):
        self.assertTrue(blocked(run("git clean -fd")))

    def testGitClean_dryRun_allowed(self):
        self.assertTrue(allowed(run("git clean -n")))


@skipUnless(HAS_JQ, "jq not installed")
class GitStashTest(TestCase):

    def testGitStash_drop_blocked(self):
        self.assertTrue(blocked(run("git stash drop")))

    def testGitStash_clear_blocked(self):
        self.assertTrue(blocked(run("git stash clear")))

    def testGitStash_push_allowed(self):
        self.assertTrue(allowed(run("git stash")))

    def testGitStash_pop_allowed(self):
        self.assertTrue(allowed(run("git stash pop")))


@skipUnless(HAS_JQ, "jq not installed")
class GitBranchTest(TestCase):

    def testGitBranch_forceDelete_blocked(self):
        self.assertTrue(blocked(run("git branch -D feature/old")))

    def testGitBranch_safeDelete_allowed(self):
        self.assertTrue(allowed(run("git branch -d feature/merged")))

    def testGitBranch_list_allowed(self):
        self.assertTrue(allowed(run("git branch -a")))


@skipUnless(HAS_JQ, "jq not installed")
class GitCheckoutTest(TestCase):

    def testGitCheckout_discardAll_blocked(self):
        self.assertTrue(blocked(run("git checkout -- .")))

    def testGitCheckout_discardFile_blocked(self):
        self.assertTrue(blocked(run("git checkout -- file.py")))

    def testGitCheckout_switchBranch_allowed(self):
        self.assertTrue(allowed(run("git checkout main")))


@skipUnless(HAS_JQ, "jq not installed")
class DdlTest(TestCase):

    def testDdl_dropTable_blocked(self):
        self.assertTrue(blocked(run("psql -c 'DROP TABLE users'")))

    def testDdl_truncateTable_blocked(self):
        self.assertTrue(blocked(run("psql -c 'TRUNCATE TABLE events'")))

    def testDdl_select_allowed(self):
        self.assertTrue(allowed(run("psql -c 'SELECT * FROM users'")))


@skipUnless(HAS_JQ, "jq not installed")
class GitCommitTest(TestCase):

    def testGitCommit_coAuthoredBy_blocked(self):
        self.assertTrue(blocked(run(
            "git commit -m 'Fix bug\n\nCo-Authored-By: Claude <noreply@anthropic.com>'"
        )))

    def testGitCommit_coAuthoredByLowercase_blocked(self):
        self.assertTrue(blocked(run(
            "git commit -m 'Fix\n\nco-authored-by: test <t@t.com>'"
        )))

    def testGitCommit_normal_allowed(self):
        self.assertTrue(allowed(run("git commit -m 'Fix linter hook'")))

    def testGitCommit_withoutCoAuthored_allowed(self):
        self.assertTrue(allowed(run('git commit -m "Add feature"')))


@skipUnless(HAS_JQ, "jq not installed")
class SafeCommandsTest(TestCase):

    def testSafeCommand_gitStatus_allowed(self):
        self.assertTrue(allowed(run("git status")))

    def testSafeCommand_gitLog_allowed(self):
        self.assertTrue(allowed(run("git log --oneline -5")))

    def testSafeCommand_ls_allowed(self):
        self.assertTrue(allowed(run("ls -la")))

    def testSafeCommand_python_allowed(self):
        self.assertTrue(allowed(run("python3 -m pytest tests/ -v")))


if __name__ == "__main__":
    main()
