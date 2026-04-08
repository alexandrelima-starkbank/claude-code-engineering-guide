import os
import shutil
import subprocess
import tempfile
from unittest import TestCase, main

PROJECT_ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
CONFIGURE = os.path.join(PROJECT_ROOT, "configure.sh")

PYPROJECT_PLACEHOLDER = """\
[tool.ruff.lint.isort]
known-first-party = []
"""

PYPROJECT_CONFIGURED = """\
[tool.ruff.lint.isort]
known-first-party = ["myapp"]
"""

MUTMUT_PLACEHOLDER = """\
[mutmut]
paths_to_mutate = "src/"
tests_dir = "tests/"
"""

MUTMUT_CONFIGURED = """\
[mutmut]
paths_to_mutate = "myapp/"
tests_dir = "myapp_tests/"
"""

SERVICE_MAP_TEMPLATE = """\
# Service Dependency Map

---

## Diretórios dos Serviços

- service-a: ~/projects/<diretório-do-service-a>
- service-b: ~/projects/<diretório-do-service-b>
"""


def makeWorkdir(pyproject=PYPROJECT_PLACEHOLDER, mutmut=MUTMUT_PLACEHOLDER, serviceMap=SERVICE_MAP_TEMPLATE):
    d = tempfile.mkdtemp()
    with open(os.path.join(d, "pyproject.toml"), "w") as f:
        f.write(pyproject)
    with open(os.path.join(d, "mutmut.toml"), "w") as f:
        f.write(mutmut)
    svc_dir = os.path.join(d, ".claude", "skills", "cross-service-analysis")
    os.makedirs(svc_dir)
    with open(os.path.join(svc_dir, "SERVICE_MAP.md"), "w") as f:
        f.write(serviceMap)
    # Stub setup.sh — evita execução real de dependências
    stub = os.path.join(d, "setup.sh")
    with open(stub, "w") as f:
        f.write("#!/bin/bash\necho '[ok] stub setup'\nexit 0\n")
    os.chmod(stub, 0o755)
    return d


def runConfigure(answers, workdir):
    stub = os.path.join(workdir, "setup.sh")
    return subprocess.run(
        ["bash", CONFIGURE],
        input="\n".join(answers) + "\n",
        capture_output=True,
        text=True,
        cwd=workdir,
        env={**os.environ, "CONFIGURE_SETUP_SH": stub},
    )


def readFile(workdir, path):
    with open(os.path.join(workdir, path)) as f:
        return f.read()


class FirstTimeConfigTest(TestCase):

    def setUp(self):
        self.workdir = makeWorkdir()
        os.makedirs(os.path.join(self.workdir, "myapp"), exist_ok=True)
        os.makedirs(os.path.join(self.workdir, "myapp_tests"), exist_ok=True)

    def tearDown(self):
        shutil.rmtree(self.workdir, ignore_errors=True)

    def testFirstTime_knownFirstPartyWritten(self):
        # Seção 1: placeholder → digita "myapp"
        # Seção 2: placeholder → digita "myapp/"
        # Seção 3: placeholder → digita "myapp_tests/"
        # Seção 4: sem marcador → N (single-service)
        result = runConfigure(["myapp", "myapp/", "myapp_tests/", "N"], self.workdir)
        self.assertEqual(result.returncode, 0)
        content = readFile(self.workdir, "pyproject.toml")
        self.assertIn('known-first-party = ["myapp"]', content)

    def testFirstTime_pathsToMutateWritten(self):
        runConfigure(["myapp", "myapp/", "myapp_tests/", "N"], self.workdir)
        content = readFile(self.workdir, "mutmut.toml")
        self.assertIn('paths_to_mutate = "myapp/"', content)

    def testFirstTime_testsDirWritten(self):
        runConfigure(["myapp", "myapp/", "myapp_tests/", "N"], self.workdir)
        content = readFile(self.workdir, "mutmut.toml")
        self.assertIn('tests_dir = "myapp_tests/"', content)

    def testFirstTime_singleServiceMarkerWritten(self):
        runConfigure(["myapp", "myapp/", "myapp_tests/", "N"], self.workdir)
        svc_map = readFile(self.workdir, ".claude/skills/cross-service-analysis/SERVICE_MAP.md")
        self.assertIn("configure.sh", svc_map)
        self.assertIn("single-service", svc_map)


class AlreadyConfiguredTest(TestCase):

    def setUp(self):
        self.workdir = makeWorkdir(
            pyproject=PYPROJECT_CONFIGURED,
            mutmut=MUTMUT_CONFIGURED,
        )

    def tearDown(self):
        shutil.rmtree(self.workdir, ignore_errors=True)

    def testAlreadyConfigured_keepAll_noChanges(self):
        # Seção 1: configurado → N (manter)
        # Seção 2: configurado → N (manter)
        # Seção 3: configurado → N (manter)
        # Seção 4: sem marcador → N (single-service)
        runConfigure(["N", "N", "N", "N"], self.workdir)
        self.assertIn('known-first-party = ["myapp"]', readFile(self.workdir, "pyproject.toml"))
        self.assertIn('paths_to_mutate = "myapp/"', readFile(self.workdir, "mutmut.toml"))
        self.assertIn('tests_dir = "myapp_tests/"', readFile(self.workdir, "mutmut.toml"))

    def testAlreadyConfigured_updateKfp(self):
        # Seção 1: configurado → s → novo valor "myapp,utils"
        # Demais: manter
        runConfigure(["s", "myapp,utils", "N", "N", "N"], self.workdir)
        content = readFile(self.workdir, "pyproject.toml")
        self.assertIn('"myapp"', content)
        self.assertIn('"utils"', content)


class SingleServiceIdempotencyTest(TestCase):

    def setUp(self):
        self.workdir = makeWorkdir()
        os.makedirs(os.path.join(self.workdir, "myapp"), exist_ok=True)
        os.makedirs(os.path.join(self.workdir, "myapp_tests"), exist_ok=True)
        # Primeira execução — grava marcador
        runConfigure(["myapp", "myapp/", "myapp_tests/", "N"], self.workdir)

    def tearDown(self):
        shutil.rmtree(self.workdir, ignore_errors=True)

    def testSingleService_secondRun_section4Skipped(self):
        # Segunda execução: seções 1–3 marcadas como configuradas (N), seção 4 deve pular
        # Seção 1: configurado → N; Seção 2: configurado → N; Seção 3: configurado → N
        # Seção 4: marcador presente → N (manter)
        result = runConfigure(["N", "N", "N", "N"], self.workdir)
        self.assertEqual(result.returncode, 0)
        self.assertIn("single-service", result.stdout)
        self.assertIn("mantido sem alteração", result.stdout)


class MultiServiceConfigTest(TestCase):

    def setUp(self):
        self.workdir = makeWorkdir()
        os.makedirs(os.path.join(self.workdir, "myapp"), exist_ok=True)
        os.makedirs(os.path.join(self.workdir, "myapp_tests"), exist_ok=True)

    def tearDown(self):
        shutil.rmtree(self.workdir, ignore_errors=True)

    def testMultiService_serviceMapGenerated(self):
        # Seção 1–3: primeiro uso
        # Seção 4: s → "payments,accounts" → dirs → S (confirmar)
        result = runConfigure([
            "myapp", "myapp/", "myapp_tests/",  # seções 1-3
            "s",                                  # multi-service? sim
            "payments,accounts",                  # nomes dos serviços
            "~/projects/payments",                # dir do payments
            "~/projects/accounts",                # dir do accounts
            "S",                                  # confirmar geração
        ], self.workdir)
        self.assertEqual(result.returncode, 0)
        svc_map = readFile(self.workdir, ".claude/skills/cross-service-analysis/SERVICE_MAP.md")
        self.assertIn("payments", svc_map)
        self.assertIn("accounts", svc_map)
        self.assertIn("~/projects/payments", svc_map)
        self.assertIn("Gerado por configure.sh", svc_map)

    def testMultiService_pipelineGenerated(self):
        runConfigure([
            "myapp", "myapp/", "myapp_tests/",
            "s", "alpha,beta",
            "~/projects/alpha", "~/projects/beta",
            "S",
        ], self.workdir)
        svc_map = readFile(self.workdir, ".claude/skills/cross-service-analysis/SERVICE_MAP.md")
        self.assertIn("alpha -> beta", svc_map)


class SedVerificationTest(TestCase):

    def setUp(self):
        # pyproject.toml sem a chave known-first-party — sed não encontra o padrão
        self.workdir = makeWorkdir(pyproject="[tool.ruff]\nselect = []\n")
        os.makedirs(os.path.join(self.workdir, "myapp"), exist_ok=True)

    def tearDown(self):
        shutil.rmtree(self.workdir, ignore_errors=True)

    def testSedFailure_warnDisplayed(self):
        # Seção 1: placeholder vazio → digita "myapp", sed não encontra padrão → deve avisar
        # Seções 2–4: valores padrão
        result = runConfigure(["myapp", "myapp/", "myapp_tests/", "N"], self.workdir)
        self.assertIn("substituição pode ter falhado", result.stdout)


if __name__ == "__main__":
    main()
