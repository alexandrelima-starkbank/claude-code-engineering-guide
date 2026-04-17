import os
import sys
from unittest import TestCase
from unittest.mock import MagicMock, call, patch

def _findProjectRoot():
    current = os.path.dirname(os.path.abspath(__file__))
    while True:
        if os.path.exists(os.path.join(current, "pipeline-cli", "pyproject.toml")):
            return current
        parent = os.path.dirname(current)
        if parent == current:
            raise FileNotFoundError("Could not find project root")
        current = parent

PROJECT_ROOT = _findProjectRoot()
if not os.environ.get("MUTANT_UNDER_TEST"):
    sys.path.insert(0, os.path.join(PROJECT_ROOT, "pipeline-cli"))


class ExpandQueryTest(TestCase):

    def testExpandQuery_WithApiKey(self):
        # Critério: a query retornada é diferente da original e não vazia

        # Arrange
        mockContent = MagicMock()
        mockContent.text = "create card issue new card"
        mockMessage = MagicMock()
        mockMessage.content = [mockContent]
        mockClient = MagicMock()
        mockClient.messages.create.return_value = mockMessage

        # Act
        with patch.dict(os.environ, {"ANTHROPIC_API_KEY": "test-key"}):
            with patch("anthropic.Anthropic", return_value=mockClient):
                from pipeline import llm
                result = llm.expandQuery("criar cartão")

        # Assert
        self.assertNotEqual(result, "criar cartão")
        self.assertTrue(len(result) > 0)

    def testExpandQuery_UsedInContextSearch(self):
        # Critério: contextSearch passa a query expandida ao vector, não a original

        # Arrange
        expandedQuery = "create card issue new card"

        # Act
        with patch.dict(os.environ, {"ANTHROPIC_API_KEY": "test-key"}):
            with patch("pipeline.llm.expandQuery", return_value=expandedQuery) as mockExpand:
                with patch("pipeline.vector.isAvailable", return_value=True):
                    with patch("pipeline.vector.searchRequirements", return_value=[]):
                        with patch("pipeline.vector.searchContext", return_value=[]) as mockSearch:
                            with patch("pipeline.db.ensureProject", return_value=None):
                                from click.testing import CliRunner
                                from pipeline.cli import cli
                                runner = CliRunner()
                                runner.invoke(cli, ["context", "search", "criar cartão"])

        # Assert
        mockExpand.assert_called_once_with("criar cartão")
        mockSearch.assert_called_once()
        self.assertEqual(mockSearch.call_args[0][0], expandedQuery)

    def testExpandQuery_WithoutApiKey_ReturnsOriginal(self):
        # Critério: sem ANTHROPIC_API_KEY retorna a query original sem exceção

        # Arrange
        env = {k: v for k, v in os.environ.items() if k != "ANTHROPIC_API_KEY"}

        # Act
        with patch.dict(os.environ, env, clear=True):
            from pipeline import llm
            result = llm.expandQuery("criar cartão")

        # Assert
        self.assertEqual(result, "criar cartão")

    def testExpandQuery_OnApiError_ReturnsOriginal(self):
        # Critério: quando a API falha, retorna a query original sem propagar exceção

        # Arrange
        mockClient = MagicMock()
        mockClient.messages.create.side_effect = Exception("API error")

        # Act
        with patch.dict(os.environ, {"ANTHROPIC_API_KEY": "test-key"}):
            with patch("anthropic.Anthropic", return_value=mockClient):
                from pipeline import llm
                result = llm.expandQuery("criar cartão")

        # Assert
        self.assertEqual(result, "criar cartão")

    def testExpandQuery_UsesHaikuModel(self):
        # Critério: exatamente uma chamada à API usando claude-haiku-4-5-20251001

        # Arrange
        mockContent = MagicMock()
        mockContent.text = "create card"
        mockMessage = MagicMock()
        mockMessage.content = [mockContent]
        mockClient = MagicMock()
        mockClient.messages.create.return_value = mockMessage

        # Act
        with patch.dict(os.environ, {"ANTHROPIC_API_KEY": "test-key"}):
            with patch("anthropic.Anthropic", return_value=mockClient):
                from pipeline import llm
                llm.expandQuery("criar cartão")

        # Assert
        self.assertEqual(mockClient.messages.create.call_count, 1)
        self.assertEqual(
            mockClient.messages.create.call_args.kwargs["model"],
            "claude-haiku-4-5-20251001",
        )

    def testExpandQuery_CallsApiWithCorrectParams(self):
        # Critério: API chamada com api_key, max_tokens=64, mensagem role=user com query no conteúdo

        # Arrange
        mockContent = MagicMock()
        mockContent.text = "create card issue new card"
        mockMessage = MagicMock()
        mockMessage.content = [mockContent]
        mockClient = MagicMock()
        mockClient.messages.create.return_value = mockMessage

        # Act
        with patch.dict(os.environ, {"ANTHROPIC_API_KEY": "test-key"}):
            with patch("anthropic.Anthropic", return_value=mockClient) as mockAnthropicCls:
                from pipeline import llm
                llm.expandQuery("criar cartão")

        # Assert
        mockAnthropicCls.assert_called_once_with(api_key="test-key")
        createCall = mockClient.messages.create.call_args
        self.assertEqual(createCall.kwargs["max_tokens"], 64)
        actualMessages = createCall.kwargs["messages"]
        self.assertIsNotNone(actualMessages)
        self.assertEqual(len(actualMessages), 1)
        self.assertEqual(actualMessages[0]["role"], "user")
        self.assertIn("criar cartão", actualMessages[0]["content"])


class PyprojectTomlTest(TestCase):

    def testPyprojectToml_HasAnthropicOptionalDep(self):
        # Critério: anthropic em [project.optional-dependencies] sob chave llm

        # Arrange
        pyprojectPath = os.path.join(PROJECT_ROOT, "pipeline-cli", "pyproject.toml")

        # Act
        with open(pyprojectPath) as f:
            content = f.read()

        # Assert
        self.assertIn("[project.optional-dependencies]", content)
        llmSectionStart = content.find("llm")
        self.assertGreater(llmSectionStart, -1)
        llmSection = content[llmSectionStart:llmSectionStart + 200]
        self.assertIn("anthropic", llmSection)
