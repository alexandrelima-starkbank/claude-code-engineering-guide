import os
import sys
from unittest import TestCase
from unittest.mock import patch

PROJECT_ROOT = os.path.join(os.path.dirname(__file__), "..")
sys.path.insert(0, os.path.join(PROJECT_ROOT, "pipeline-cli"))

from pipeline.cli import cli
from click.testing import CliRunner


class SearchOutputTest(TestCase):

    def testSearch_AlwaysShowsProjectPrefix(self):
        # Critério: cada linha exibe [projectId] como prefixo
        fakeResults = [{
            "document": "function doSomething  [src/module.py:10]\ndef doSomething(): pass",
            "metadata": {"projectId": "my-project", "file": "src/module.py", "line": 10, "qualifiedName": "doSomething", "type": "function"},
            "distance": 0.1,
        }]
        with patch("pipeline.vector.searchCode", return_value=fakeResults):
            with patch("pipeline.llm.expandQuery", return_value="query"):
                runner = CliRunner()
                result = runner.invoke(cli, ["search", "query"])

        self.assertEqual(result.exit_code, 0)
        self.assertIn("[my-project]", result.output)

    def testContextSearch_RequirementShowsProject(self):
        # Critério: linha de requirement exibe [projectId] como prefixo
        fakeReqs = [{
            "text": "System SHALL do X",
            "id": "T1:R01",
            "metadata": {"taskId": "T1", "reqId": "R01", "projectId": "proj-alpha"},
            "distance": 0.1,
        }]
        with patch("pipeline.vector.searchRequirements", return_value=fakeReqs):
            with patch("pipeline.vector.searchContext", return_value=[]):
                with patch("pipeline.llm.expandQuery", return_value="query"):
                    runner = CliRunner()
                    result = runner.invoke(cli, ["context", "search", "query"])

        self.assertEqual(result.exit_code, 0)
        self.assertIn("[proj-alpha]", result.output)

    def testContextSearch_ContextItemShowsProject(self):
        # Critério: linha de context item exibe [projectId] como prefixo
        fakeCtx = [{
            "text": "Decided to use X approach",
            "id": "decision:2026-01-01",
            "metadata": {"type": "decision", "projectId": "proj-beta", "taskId": ""},
            "distance": 0.1,
            "collection": "decisions",
        }]
        with patch("pipeline.vector.searchRequirements", return_value=[]):
            with patch("pipeline.vector.searchContext", return_value=fakeCtx):
                with patch("pipeline.llm.expandQuery", return_value="query"):
                    runner = CliRunner()
                    result = runner.invoke(cli, ["context", "search", "query"])

        self.assertEqual(result.exit_code, 0)
        self.assertIn("[proj-beta]", result.output)
