import os
import json
import tempfile
import subprocess
from unittest import TestCase, main, skipUnless

PROJECT_ROOT = os.path.join(os.path.dirname(__file__), "..")
HOOK = os.path.join(PROJECT_ROOT, ".claude", "hooks", "inject-tasks-context.sh")

HAS_JQ = subprocess.run(["which", "jq"], capture_output=True).returncode == 0

TASKS_EMPTY = """\
# TASKS.md

## Tarefas Ativas

_Nenhuma tarefa ativa no momento._

## Histórico

_Nenhuma tarefa concluída ainda._
"""

TASKS_WITH_ACTIVE = """\
# TASKS.md

## Tarefas Ativas

### T1 — Implementar parser

- **Projeto:** core
- **Status:** em andamento
- **Descrição:** Implementar parser de JSON

## Histórico

_Nenhuma tarefa concluída ainda._
"""

TASKS_WITH_STALE = """\
# TASKS.md

## Tarefas Ativas

### T1 — Fix linter

- **Projeto:** core
- **Status:** concluído
- **Descrição:** Corrigir linter

## Histórico

_Nenhuma tarefa concluída ainda._
"""

TASKS_WITH_CANCELLED = """\
# TASKS.md

## Tarefas Ativas

### T2 — Spike de migração

- **Projeto:** core
- **Status:** cancelado
- **Descrição:** Avaliar migração

## Histórico

_Nenhuma tarefa concluída ainda._
"""


def makeFakePipeline(tmpdir):
    fakeBin = os.path.join(tmpdir, "_bin")
    os.makedirs(fakeBin, exist_ok=True)
    fakePipeline = os.path.join(fakeBin, "pipeline")
    with open(fakePipeline, "w") as f:
        f.write("#!/bin/bash\nexit 1\n")
    os.chmod(fakePipeline, 0o755)
    return fakeBin


def run(tasksContent):
    with tempfile.TemporaryDirectory() as tmpdir:
        subprocess.run(["git", "init"], cwd=tmpdir, capture_output=True)
        fakeBin = makeFakePipeline(tmpdir)
        tasks_path = os.path.join(tmpdir, "TASKS.md")
        with open(tasks_path, "w", encoding="utf-8") as f:
            f.write(tasksContent)

        env = {**os.environ, "HOME": os.environ.get("HOME", "/tmp")}
        env["PATH"] = fakeBin + ":" + env.get("PATH", "")
        payload = json.dumps({"prompt": "test"})
        result = subprocess.run(
            ["bash", HOOK],
            input=payload,
            capture_output=True,
            text=True,
            cwd=tmpdir,
            env=env,
        )
        return result


@skipUnless(HAS_JQ, "jq not installed")
class TasksContextTest(TestCase):

    def testNoTasksFile_silentExit(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            subprocess.run(["git", "init"], cwd=tmpdir, capture_output=True)
            fakeBin = makeFakePipeline(tmpdir)
            env = {**os.environ}
            env["PATH"] = fakeBin + ":" + env.get("PATH", "")
            payload = json.dumps({"prompt": "test"})
            result = subprocess.run(
                ["bash", HOOK],
                input=payload,
                capture_output=True,
                text=True,
                cwd=tmpdir,
                env=env,
            )
            self.assertEqual(result.returncode, 0)
            self.assertEqual(result.stdout.strip(), "")

    def testEmptyActiveTasks_silentExit(self):
        result = run(TASKS_EMPTY)
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout.strip(), "")

    def testActiveTasks_contextInjected(self):
        result = run(TASKS_WITH_ACTIVE)
        self.assertEqual(result.returncode, 0)
        output = json.loads(result.stdout)
        context = output["hookSpecificOutput"]["additionalContext"]
        self.assertIn("T1", context)
        self.assertIn("em andamento", context)

    def testStaleConcluido_urgentAlertInjected(self):
        result = run(TASKS_WITH_STALE)
        self.assertEqual(result.returncode, 0)
        output = json.loads(result.stdout)
        context = output["hookSpecificOutput"]["additionalContext"]
        self.assertIn("ACAO OBRIGATORIA", context)
        self.assertIn("T1", context)

    def testStaleCancelado_urgentAlertInjected(self):
        result = run(TASKS_WITH_CANCELLED)
        self.assertEqual(result.returncode, 0)
        output = json.loads(result.stdout)
        context = output["hookSpecificOutput"]["additionalContext"]
        self.assertIn("ACAO OBRIGATORIA", context)


if __name__ == "__main__":
    main()
