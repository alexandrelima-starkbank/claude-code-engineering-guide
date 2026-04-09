---
description: Atualiza o ecossistema Claude Code para a versão mais recente sem sair do ambiente.
allowed-tools: Bash
---
# Update

```bash
rm -rf /tmp/cce-guide \
  && git clone --depth 1 https://github.com/alexandrelima-starkbank/claude-code-engineering-guide.git /tmp/cce-guide 2>&1 \
  && bash /tmp/cce-guide/install.sh "$(pwd)"
```

Após a execução, exiba o output do script e informe:
- Versão/commit instalado (`git -C /tmp/cce-guide rev-parse --short HEAD`)
- Se houve algum erro ou aviso relevante
