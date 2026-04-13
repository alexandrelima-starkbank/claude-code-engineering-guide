---
description: Resumo diário — tarefas ativas e concluídas nas últimas 24h, agrupadas por data, sem canceladas.
allowed-tools: Bash
---
# Daily Report

```bash
pipeline task list --format json | python3 -c "
import sys, json
from datetime import date, timedelta

today_dt = date.today()
weekday = today_dt.weekday()
prev_dt = today_dt - timedelta(days=3) if weekday == 0 else today_dt - timedelta(days=1)
today = str(today_dt)
yesterday = str(prev_dt)
tasks = json.load(sys.stdin)

TOOLING_PROJECTS = {'projects', 'claude-code-engineering-guide'}
active = [t for t in tasks if t['status'] in ('em andamento', 'pendente')
          and t.get('projectId') not in TOOLING_PROJECTS]
done = [t for t in tasks if t['status'] in ('concluido', 'concluído')
        and t.get('updatedAt', '')[:10] in (today, yesterday)
        and t.get('projectId') not in TOOLING_PROJECTS]

def sort_key(t):
    order = {'em andamento': 0, 'pendente': 1}
    return (order.get(t['status'], 9), t['id'])

active.sort(key=sort_key)
done.sort(key=lambda t: t.get('updatedAt', ''), reverse=True)

prev_label = 'sexta-feira' if weekday == 0 else 'ontem'
result = {'today': today, 'yesterday': yesterday, 'prev_label': prev_label, 'active': active, 'done': done}
print(json.dumps(result, ensure_ascii=False, indent=2))
"
```

Com o JSON resultante, gere o relatório no seguinte formato:

```
{today} -> hoje
[ ] <resumo da tarefa>
[ ] <resumo da tarefa>

{yesterday} -> {prev_label}
[X] <resumo da tarefa>
```

Regras:
- `[ ]` para `em andamento` e `pendente`
- `[X]` para `concluído`
- Tarefas ativas (`active`) listadas primeiro sob a data de hoje
- Tarefas concluídas (`done`) agrupadas pela data de `updatedAt[:10]`
- Resumo = título da tarefa, sem ID, sem projeto, sem fase
- Se `active` e `done` ambos vazios: `Nenhuma atividade registrada.`
- Sem texto adicional além do formato acima
