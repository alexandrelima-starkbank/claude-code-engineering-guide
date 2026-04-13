import ast
import hashlib
from pathlib import Path

from . import vector
from .db import ensureProject
from .vector import getSourceCodeCollection

# ─── Padrões de exclusão ──────────────────────────────────────────────────────

SKIP_DIRS = {
    "__pycache__", ".git", ".venv", "venv", "env",
    "migrations", "node_modules", ".mypy_cache", ".pytest_cache",
    "dist", "build", "eggs", ".eggs",
}

SKIP_FILE_SUFFIXES = {"_pb2.py", "_pb2_grpc.py"}  # protobuf gerado

MAX_BODY_LINES = 60  # limite por unidade para não sobrecarregar o embedding


# ─── AST extraction ───────────────────────────────────────────────────────────

def _sourceSlice(lines, node):
    start = node.lineno - 1
    end = min(getattr(node, "end_lineno", start + MAX_BODY_LINES), start + MAX_BODY_LINES)
    return "\n".join(lines[start:end])


def _classHeader(lines, classNode):
    """Primeiras linhas da classe — suficiente para capturar bases e atributos."""
    start = classNode.lineno - 1
    end = min(start + 8, getattr(classNode, "end_lineno", start + 8))
    return "\n".join(lines[start:end])


def extractUnits(filePath, projectRoot=None):
    """
    Extrai unidades semânticas de um arquivo Python via AST.
    Retorna lista de dicts com: id, qualifiedName, type, file, line, document, metadata.
    """
    path = Path(filePath)

    # Exclusão por nome de arquivo
    if any(path.name.endswith(sfx) for sfx in SKIP_FILE_SUFFIXES):
        return []

    try:
        source = path.read_text(encoding="utf-8", errors="ignore")
        tree = ast.parse(source, filename=str(path))
    except SyntaxError:
        return []
    except Exception:
        return []

    relPath = str(path.relative_to(projectRoot)) if projectRoot else str(path)
    lines = source.splitlines()
    units = []

    for node in ast.iter_child_nodes(tree):

        # ── Função de módulo ──────────────────────────────────────────────────
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
            body = _sourceSlice(lines, node)
            units.append(_makeUnit(
                unitId="{0}:{1}".format(relPath, node.lineno),
                qualifiedName=node.name,
                unitType="function",
                relPath=relPath,
                line=node.lineno,
                document="function {0}  [{1}:{2}]\n{3}".format(
                    node.name, relPath, node.lineno, body
                ),
                extra={},
            ))

        # ── Classe + seus métodos ─────────────────────────────────────────────
        elif isinstance(node, ast.ClassDef):
            classHeader = _classHeader(lines, node)
            units.append(_makeUnit(
                unitId="{0}:{1}".format(relPath, node.lineno),
                qualifiedName=node.name,
                unitType="class",
                relPath=relPath,
                line=node.lineno,
                document="class {0}  [{1}:{2}]\n{3}".format(
                    node.name, relPath, node.lineno, classHeader
                ),
                extra={},
            ))

            for child in ast.iter_child_nodes(node):
                if isinstance(child, (ast.FunctionDef, ast.AsyncFunctionDef)):
                    body = _sourceSlice(lines, child)
                    qualifiedName = "{0}.{1}".format(node.name, child.name)
                    units.append(_makeUnit(
                        unitId="{0}:{1}".format(relPath, child.lineno),
                        qualifiedName=qualifiedName,
                        unitType="method",
                        relPath=relPath,
                        line=child.lineno,
                        document="class {0} > method {1}  [{2}:{3}]\n{4}".format(
                            node.name, child.name, relPath, child.lineno, body
                        ),
                        extra={"className": node.name},
                    ))

    return units


def _makeUnit(unitId, qualifiedName, unitType, relPath, line, document, extra):
    meta = {
        "qualifiedName": qualifiedName,
        "type": unitType,
        "file": relPath,
        "line": line,
    }
    meta.update(extra)
    return {
        "id": unitId,
        "qualifiedName": qualifiedName,
        "type": unitType,
        "file": relPath,
        "line": line,
        "document": document,
        "metadata": meta,
    }


# ─── Indexação ────────────────────────────────────────────────────────────────

def _fileHash(filePath):
    return hashlib.md5(Path(filePath).read_bytes()).hexdigest()


def indexFile(filePath, projectId, projectRoot=None, force=False):
    """Indexa um único arquivo Python. Retorna número de unidades indexadas.

    Pula o arquivo se o hash do conteúdo não mudou desde a última indexação,
    a menos que force=True (usado pelo post-commit hook).
    """
    if not vector.isAvailable():
        return 0

    path = Path(filePath)
    currentHash = _fileHash(path)
    relPath = str(path.relative_to(projectRoot)) if projectRoot else str(path)
    filePrefix = "{0}:{1}:".format(projectId, relPath)

    if not force:
        client = vector.getClient()
        col = getSourceCodeCollection(client, create=True)
        # Verifica se já existe alguma unidade desse arquivo com o mesmo hash
        try:
            existing = col.get(
                where={"$and": [{"projectId": projectId}, {"file": relPath}]},
                limit=1,
                include=["metadatas"],
            )
            if existing["metadatas"] and existing["metadatas"][0].get("fileHash") == currentHash:
                return -1  # sem mudança — pulado
        except Exception:
            pass

    units = extractUnits(filePath, projectRoot)
    if not units:
        return 0

    client = vector.getClient()
    col = getSourceCodeCollection(client, create=True)

    ids = ["{0}:{1}".format(projectId, u["id"]) for u in units]
    docs = [u["document"] for u in units]
    metas = [{**u["metadata"], "projectId": projectId, "fileHash": currentHash} for u in units]

    col.upsert(documents=docs, ids=ids, metadatas=metas)
    return len(units)


def indexProject(projectPath, projectId, verbose=False, force=False):
    """Indexa todos os arquivos Python de um projeto. Retorna total de unidades."""
    root = Path(projectPath).resolve()
    total = 0
    skipped = 0

    for pyFile in sorted(root.rglob("*.py")):
        if any(part in SKIP_DIRS for part in pyFile.parts):
            continue
        n = indexFile(pyFile, projectId, projectRoot=root, force=force)
        if n == -1:
            skipped += 1
        elif n > 0:
            total += n
            if verbose:
                rel = pyFile.relative_to(root)
                print("  {0} ({1} unidades)".format(rel, n))

    if verbose and skipped > 0:
        print("  ({0} arquivo(s) sem mudança — pulados)".format(skipped))

    return total


# ─── Descoberta de projetos ───────────────────────────────────────────────────

PROJECT_SIGNALS = [
    ".git", "pyproject.toml", "setup.py", "setup.cfg",
    "package.json", "Makefile", "requirements.txt",
]

CONTEXT_FILES = ["README.md", "GUIDE.md", "CLAUDE.md", "ARCHITECTURE.md"]


def _isProject(path):
    return any((path / signal).exists() for signal in PROJECT_SIGNALS)


def _extractDocs(projectPath):
    """Extrai documentação textual do projeto (README, CLAUDE.md, etc.)."""
    parts = []
    for filename in CONTEXT_FILES:
        f = projectPath / filename
        if f.exists():
            try:
                content = f.read_text(encoding="utf-8", errors="ignore")[:2000]
                parts.append("[{0}]\n{1}".format(filename, content.strip()))
            except Exception:
                pass
    return "\n\n".join(parts) if parts else None


def indexDirectory(targetDir, verbose=False):
    """
    Descobre projetos em targetDir, indexa docs no ChromaDB (coleção context)
    e código-fonte (coleção source_code). Retorna lista de resultados.
    """
    targetPath = Path(targetDir).resolve()
    candidates = [p for p in targetPath.iterdir() if p.is_dir() and not p.name.startswith(".")]
    projects = [p for p in candidates if _isProject(p)]

    results = []
    for projectPath in sorted(projects, key=lambda p: p.name):
        name = projectPath.name
        projectId = ensureProject(name, str(projectPath))

        # Docs (README, CLAUDE.md) → coleção context
        docs = _extractDocs(projectPath)
        if docs and vector.isAvailable():
            vector.addContext(
                text=docs,
                contextType="context",
                projectId=projectId,
            )

        # Código-fonte Python → coleção source_code
        codeUnits = indexProject(projectPath, projectId, verbose=verbose)

        # Instala post-commit hook no projeto
        _installPostCommitHook(projectPath)

        results.append({
            "name": name,
            "projectId": projectId,
            "codeUnits": codeUnits,
            "hasDocs": docs is not None,
            "indexed": vector.isAvailable(),
        })

        if verbose:
            status = "✓" if vector.isAvailable() else "~"
            print("[{0}] {1} — {2} unidades de código".format(status, name, codeUnits))

    return results


def _installPostCommitHook(projectPath):
    """Instala o hook post-commit no .git/hooks/ do projeto."""
    import shutil
    gitHooks = Path(projectPath) / ".git" / "hooks"
    if not gitHooks.exists():
        return
    hookSource = Path(__file__).parent.parent.parent / ".claude" / "hooks" / "post-commit.sh"
    if not hookSource.exists():
        # Fallback: gera o hook inline
        hookContent = (
            "#!/bin/bash\n"
            "if ! command -v pipeline &>/dev/null; then exit 0; fi\n"
            "ROOT=$(git rev-parse --show-toplevel 2>/dev/null)\n"
            "[ -z \"$ROOT\" ] && exit 0\n"
            "MODIFIED=$(git diff --name-only HEAD~1 HEAD 2>/dev/null | grep '\\.py$')\n"
            "[ -z \"$MODIFIED\" ] && exit 0\n"
            "for file in $MODIFIED; do\n"
            "    ABS=\"${ROOT}/${file}\"\n"
            "    [ -f \"$ABS\" ] && pipeline index-file \"$ABS\" 2>/dev/null || true\n"
            "done\n"
        )
        hookDest = gitHooks / "post-commit"
        hookDest.write_text(hookContent)
        hookDest.chmod(0o755)
    else:
        hookDest = gitHooks / "post-commit"
        shutil.copy2(str(hookSource), str(hookDest))
        hookDest.chmod(0o755)


def generateContextSection(results):
    if not results:
        return "<!-- Nenhum projeto detectado. Descreva aqui o contexto do workspace. -->"
    lines = [
        "Workspace com {0} projeto(s) indexado(s) no ChromaDB:".format(len(results)),
        "",
    ]
    for r in results:
        lines.append("- **{0}** — {1} unidades de código indexadas".format(
            r["name"], r["codeUnits"]
        ))
    lines += [
        "",
        "Use `pipeline search \"<termo>\"` para busca semântica no código.",
        "Use `pipeline context search \"<termo>\"` para decisões e requisitos anteriores.",
    ]
    return "\n".join(lines)
