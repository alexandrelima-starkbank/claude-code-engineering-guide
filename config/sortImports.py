import re
import sys
from pathlib import Path

_STDLIB = getattr(sys, 'stdlib_module_names', frozenset())


def classifyImport(line, localPackages):
    topLevel = getTopLevelModule(line)
    if not topLevel:
        return 'other'
    if topLevel in _STDLIB:
        return 'stdlib'
    if topLevel in localPackages:
        return 'local'
    return 'external'


def detectLocalPackages(projectRoot):
    packages = []
    for item in sorted(projectRoot.iterdir()):
        if item.is_dir() and (item / "__init__.py").exists():
            packages.append(item.name)
    return packages


def extractImportBlock(lines):
    startIndex = None
    endIndex = None
    for i, line in enumerate(lines):
        stripped = line.strip()
        if stripped.startswith('from ') or stripped.startswith('import '):
            if startIndex is None:
                startIndex = i
            endIndex = i
            continue
        if startIndex is not None and stripped and not stripped.startswith('#'):
            break
    if startIndex is None:
        return None, None, []
    return startIndex, endIndex + 1, lines[startIndex:endIndex + 1]


def findProjectRoot(filePath):
    current = Path(filePath).resolve().parent
    while current != current.parent:
        if (current / "pyproject.toml").exists():
            return current
        current = current.parent
    return Path(filePath).resolve().parent


def getTopLevelModule(line):
    match = re.match(r'from\s+(\S+)\s+import', line)
    if match:
        return match.group(1).split('.')[0]
    match = re.match(r'import\s+(\S+)', line)
    if match:
        return match.group(1).split('.')[0]
    return None


def readKnownFirstParty(projectRoot):
    configPath = projectRoot / "pyproject.toml"
    if not configPath.exists():
        return []
    content = configPath.read_text()
    match = re.search(r'known-first-party\s*=\s*\[([^\]]*)\]', content)
    if not match:
        return []
    return re.findall(r'"([^"]+)"', match.group(1))


def sortImports(filePath, localPackages=None):
    path = Path(filePath)
    content = path.read_text()
    lines = content.splitlines(keepends=True)
    if localPackages is None:
        projectRoot = findProjectRoot(filePath)
        configPackages = readKnownFirstParty(projectRoot)
        detectedPackages = detectLocalPackages(projectRoot)
        localPackages = set(configPackages) | set(detectedPackages)
    startIndex, endIndex, importLines = extractImportBlock(lines)
    if startIndex is None:
        return
    stdlibLines = []
    externalLines = []
    localLines = []
    for line in importLines:
        stripped = line.rstrip('\n').rstrip('\r')
        if not stripped.strip():
            continue
        category = classifyImport(stripped, localPackages)
        if category == 'stdlib':
            stdlibLines.append(stripped)
            continue
        if category == 'local':
            localLines.append(stripped)
            continue
        externalLines.append(stripped)
    stdlibLines.sort(key=sortKey)
    externalLines.sort(key=sortKey)
    localLines.sort(key=sortKey)
    sortedLines = stdlibLines + externalLines + localLines
    if not sortedLines:
        path.write_text(''.join(lines[:startIndex] + lines[endIndex:]))
        return
    newImportBlock = '\n'.join(sortedLines) + '\n'
    newLines = lines[:startIndex] + [newImportBlock] + lines[endIndex:]
    path.write_text(''.join(newLines))


def sortKey(line):
    return len(line)


if __name__ == '__main__':
    if len(sys.argv) < 2:
        sys.exit(1)
    sortImports(sys.argv[1])
