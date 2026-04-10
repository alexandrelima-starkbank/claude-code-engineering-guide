from pathlib import Path
from . import vector
from .db import ensureProject

# Arquivos que indicam que um subdiretório é um projeto
PROJECT_SIGNALS = [
    ".git", "pyproject.toml", "setup.py", "setup.cfg",
    "package.json", "Makefile", "requirements.txt",
]

# Arquivos de contexto a extrair (em ordem de prioridade)
CONTEXT_FILES = ["README.md", "CLAUDE.md", "ARCHITECTURE.md", "docs/architecture.md"]

# Extensões de código para inferir linguagem
LANG_EXTENSIONS = {
    ".py": "Python", ".js": "JavaScript", ".ts": "TypeScript",
    ".go": "Go", ".java": "Java", ".rb": "Ruby", ".rs": "Rust",
}


def _isProject(path):
    return any((path / signal).exists() for signal in PROJECT_SIGNALS)


def _extractContext(projectPath):
    lines = []
    for filename in CONTEXT_FILES:
        f = projectPath / filename
        if f.exists():
            try:
                content = f.read_text(encoding="utf-8", errors="ignore")[:2000]
                lines.append("[{0}]\n{1}".format(filename, content.strip()))
            except Exception:
                pass
    return "\n\n".join(lines) if lines else None


def _inferLanguage(projectPath):
    counts = {}
    for ext, lang in LANG_EXTENSIONS.items():
        count = len(list(projectPath.rglob("*" + ext)))
        if count:
            counts[lang] = count
    if not counts:
        return None
    return max(counts, key=counts.get)


def _gitRemote(projectPath):
    try:
        import subprocess
        result = subprocess.run(
            ["git", "-C", str(projectPath), "remote", "get-url", "origin"],
            capture_output=True, text=True,
        )
        if result.returncode == 0:
            return result.stdout.strip()
    except Exception:
        pass
    return None


def indexDirectory(targetDir, verbose=False):
    targetPath = Path(targetDir).resolve()
    results = []

    candidates = [p for p in targetPath.iterdir() if p.is_dir() and not p.name.startswith(".")]
    projects = [p for p in candidates if _isProject(p)]

    if not projects:
        return results

    for projectPath in sorted(projects, key=lambda p: p.name):
        name = projectPath.name
        projectId = ensureProject(name, str(projectPath))

        context = _extractContext(projectPath)
        lang = _inferLanguage(projectPath)
        remote = _gitRemote(projectPath)

        parts = ["Projeto: {0}".format(name)]
        if lang:
            parts.append("Linguagem principal: {0}".format(lang))
        if remote:
            parts.append("Repositório: {0}".format(remote))
        if context:
            parts.append(context)

        fullContext = "\n".join(parts)

        if vector.isAvailable():
            vector.addContext(
                text=fullContext,
                contextType="context",
                projectId=projectId,
            )

        results.append({
            "name": name,
            "projectId": projectId,
            "lang": lang,
            "hasReadme": (projectPath / "README.md").exists(),
            "hasClaudeMd": (projectPath / "CLAUDE.md").exists(),
            "indexed": vector.isAvailable(),
        })

        if verbose:
            print("  [{0}] {1}{2}".format(
                "✓" if vector.isAvailable() else "~",
                name,
                " ({0})".format(lang) if lang else "",
            ))

    return results


def generateContextSection(results):
    if not results:
        return "<!-- Nenhum projeto detectado. Descreva aqui o contexto do workspace. -->"

    lines = ["Workspace com {0} projeto(s) indexado(s) no ChromaDB:".format(len(results)), ""]
    for r in results:
        lang = " ({0})".format(r["lang"]) if r["lang"] else ""
        lines.append("- **{0}**{1}".format(r["name"], lang))

    lines += [
        "",
        "Use `pipeline context search \"<termo>\"` para buscar contexto relevante.",
    ]
    return "\n".join(lines)
