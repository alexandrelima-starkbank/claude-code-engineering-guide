---
description: Resumo diário — todas as tarefas ativas + concluídas/canceladas nas últimas 24h, independente de projeto.
allowed-tools: Bash
---
# Daily Report

```bash
pipeline task list --format json | python3 -c "
import sys, json
from datetime import date, timedelta

today = str(date.today())
yesterday = str(date.today() - timedelta(days=1))
tasks = json.load(sys.stdin)

active = [t for t in tasks if t['status'] in ('em andamento', 'pendente')]
recent = [t for t in tasks if t['status'] in ('concluido', 'concluído', 'cancelado')
          and t.get('updatedAt', '')[:10] in (today, yesterday)]

order = {'em andamento': 0, 'pendente': 1}
active.sort(key=lambda t: (order.get(t['status'], 9), t['id']))
recent.sort(key=lambda t: t.get('updatedAt', ''), reverse=True)

print(json.dumps(active + recent, ensure_ascii=False, indent=2))
"
```

Para cada tarefa no JSON resultante, gere **exatamente um bullet**:

```
• [T<N>] <título> (<projeto>) | <fase> | <status> — <próximo passo em ≤8 palavras>
```

- `em andamento` / `pendente`: próximo passo concreto (ex: "aprovar EARS", "escrever testes C01", "rodar mutmut")
- `concluído` / `cancelado`: próximo passo = "—"
- Sem cabeçalho, sem seções, sem texto adicional — apenas os bullets
- Se JSON vazio: `Nenhuma atividade registrada.`
