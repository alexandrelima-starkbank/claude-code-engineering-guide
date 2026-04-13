import sys
import tempfile
from pathlib import Path
from unittest import TestCase

sys.path.insert(0, str(Path(__file__).parent.parent / "config"))
from sortImports import classifyImport, extractImportBlock, getTopLevelModule, readKnownFirstParty, sortImports, sortKey, sortLocalGroup


class SortImportsTest(TestCase):

    def testClassifyImport_Stdlib(self):
        # Arrange
        line = "import os"
        localPackages = set()

        # Act
        result = classifyImport(line, localPackages)

        # Assert
        self.assertEqual(result, "stdlib")

    def testClassifyImport_Local(self):
        # Arrange
        line = "from handlers.base import MsBaseHandler"
        localPackages = {"handlers"}

        # Act
        result = classifyImport(line, localPackages)

        # Assert
        self.assertEqual(result, "local")

    def testClassifyImport_External(self):
        # Arrange
        line = "from requests import get"
        localPackages = set()

        # Act
        result = classifyImport(line, localPackages)

        # Assert
        self.assertEqual(result, "external")

    def testClassifyImport_UnknownLine(self):
        # Arrange
        line = "# comment"
        localPackages = set()

        # Act
        result = classifyImport(line, localPackages)

        # Assert
        self.assertEqual(result, "other")

    def testExtractImportBlock_SimpleBlock(self):
        # Arrange
        lines = ["import os\n", "from pathlib import Path\n", "x = 1\n"]

        # Act
        startIndex, endIndex, block = extractImportBlock(lines)

        # Assert
        self.assertEqual(startIndex, 0)
        self.assertEqual(endIndex, 2)
        self.assertEqual(len(block), 2)

    def testExtractImportBlock_EmptyFile(self):
        # Arrange
        lines = ["x = 1\n", "y = 2\n"]

        # Act
        startIndex, endIndex, block = extractImportBlock(lines)

        # Assert
        self.assertIsNone(startIndex)
        self.assertIsNone(endIndex)
        self.assertEqual(block, [])

    def testExtractImportBlock_StopsAtNonImport(self):
        # Arrange
        lines = ["import os\n", "x = 1\n", "import sys\n"]

        # Act
        startIndex, endIndex, block = extractImportBlock(lines)

        # Assert
        self.assertEqual(startIndex, 0)
        self.assertEqual(endIndex, 1)

    def testExtractImportBlock_IgnoresBlankLines(self):
        # Arrange
        lines = ["import os\n", "\n", "from pathlib import Path\n", "x = 1\n"]

        # Act
        startIndex, endIndex, block = extractImportBlock(lines)

        # Assert
        self.assertEqual(startIndex, 0)
        self.assertEqual(endIndex, 3)

    def testGetTopLevelModule_FromImport(self):
        # Arrange
        line = "from models.card import CardStatus, CardType"

        # Act
        result = getTopLevelModule(line)

        # Assert
        self.assertEqual(result, "models")

    def testGetTopLevelModule_ImportStatement(self):
        # Arrange
        line = "import os"

        # Act
        result = getTopLevelModule(line)

        # Assert
        self.assertEqual(result, "os")

    def testGetTopLevelModule_NotAnImport(self):
        # Arrange
        line = "x = 1"

        # Act
        result = getTopLevelModule(line)

        # Assert
        self.assertIsNone(result)

    def testSortLocalGroup_GroupsByNamespaceMaxLength(self):
        # Arrange — handlers max=39, models max=44: handlers first
        lines = [
            "from models.cardLog import CardLogType",
            "from handlers.base import MsBaseHandler",
            "from models.card import CardStatus, CardType",
        ]

        # Act
        result = sortLocalGroup(lines)

        # Assert
        self.assertEqual(result[0], "from handlers.base import MsBaseHandler")
        self.assertEqual(result[1], "from models.cardLog import CardLogType")
        self.assertEqual(result[2], "from models.card import CardStatus, CardType")

    def testSortLocalGroup_WithinNamespaceByLength(self):
        # Arrange — within models: cardLog(38) before card(44)
        lines = [
            "from models.card import CardStatus, CardType",
            "from models.cardLog import CardLogType",
        ]

        # Act
        result = sortLocalGroup(lines)

        # Assert
        self.assertEqual(result[0], "from models.cardLog import CardLogType")
        self.assertEqual(result[1], "from models.card import CardStatus, CardType")

    def testSortLocalGroup_TiesBetweenGroupsPreserveOriginalOrder(self):
        # Arrange — utils max=51, gateways max=51: tie resolved by original order
        lines = [
            "from utils.holderPermission import getSafeHolderIds",
            "from gateways.issuingCard import IssuingCardGateway",
        ]

        # Act
        result = sortLocalGroup(lines)

        # Assert — utils comes first (original order preserved)
        self.assertEqual(result[0], "from utils.holderPermission import getSafeHolderIds")
        self.assertEqual(result[1], "from gateways.issuingCard import IssuingCardGateway")

    def testSortKey_ShorterFirst(self):
        # Arrange
        lines = ["from pathlib import Path", "import os"]

        # Act
        result = sorted(lines, key=sortKey)

        # Assert
        self.assertEqual(result[0], "import os")

    def testSortKey_SameLengthPreservesOrder(self):
        # Arrange
        lines = ["import sys", "import abc"]

        # Act
        result = sorted(lines, key=sortKey)

        # Assert
        self.assertEqual(result[0], "import sys")

    def testSortImports_ThreeGroupsNoBlankLines(self):
        # Arrange
        content = (
            "from utils.parser import parseInput\n"
            "from requests import get\n"
            "import os\n"
            "x = 1\n"
        )
        with tempfile.NamedTemporaryFile(mode='w', suffix='.py', delete=False) as f:
            f.write(content)
            filePath = f.name

        # Act
        sortImports(filePath, localPackages={"utils"})
        result = Path(filePath).read_text()
        Path(filePath).unlink()

        # Assert
        importLines = result.splitlines()[:3]
        self.assertEqual(importLines[0], "import os")
        self.assertEqual(importLines[1], "from requests import get")
        self.assertEqual(importLines[2], "from utils.parser import parseInput")

    def testSortImports_OrdersByLengthWithinGroup(self):
        # Arrange
        content = (
            "from models.cardLog import CardLogType\n"
            "from models.card import CardStatus, CardType\n"
            "x = 1\n"
        )
        with tempfile.NamedTemporaryFile(mode='w', suffix='.py', delete=False) as f:
            f.write(content)
            filePath = f.name

        # Act
        sortImports(filePath, localPackages={"models"})
        result = Path(filePath).read_text()
        Path(filePath).unlink()

        # Assert
        lines = result.splitlines()
        self.assertEqual(lines[0], "from models.cardLog import CardLogType")
        self.assertEqual(lines[1], "from models.card import CardStatus, CardType")

    def testSortImports_PreservesNonImportCode(self):
        # Arrange
        content = "import os\n\nx = 1\ny = 2\n"
        with tempfile.NamedTemporaryFile(mode='w', suffix='.py', delete=False) as f:
            f.write(content)
            filePath = f.name

        # Act
        sortImports(filePath, localPackages=set())
        result = Path(filePath).read_text()
        Path(filePath).unlink()

        # Assert
        self.assertIn("x = 1", result)
        self.assertIn("y = 2", result)

    def testSortImports_NoImports_LeavesFileUnchanged(self):
        # Arrange
        content = "x = 1\ny = 2\n"
        with tempfile.NamedTemporaryFile(mode='w', suffix='.py', delete=False) as f:
            f.write(content)
            filePath = f.name

        # Act
        sortImports(filePath, localPackages=set())
        result = Path(filePath).read_text()
        Path(filePath).unlink()

        # Assert
        self.assertEqual(result, content)

    def testReadKnownFirstParty_WithConfig(self):
        # Arrange
        tomlContent = '[tool.ruff.lint.isort]\nknown-first-party = ["handlers", "models"]\n'
        with tempfile.TemporaryDirectory() as tmpDir:
            configPath = Path(tmpDir) / "pyproject.toml"
            configPath.write_text(tomlContent)

            # Act
            result = readKnownFirstParty(Path(tmpDir))

        # Assert
        self.assertIn("handlers", result)
        self.assertIn("models", result)

    def testReadKnownFirstParty_NoConfig(self):
        # Arrange / Act
        with tempfile.TemporaryDirectory() as tmpDir:
            result = readKnownFirstParty(Path(tmpDir))

        # Assert
        self.assertEqual(result, [])
