---
description: Resumo diário — tarefas ativas e concluídas nas últimas 24h, agrupadas por data, sem canceladas.
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
done = [t for t in tasks if t['status'] in ('concluido', 'concluído')
        and t.get('updatedAt', '')[:10] in (today, yesterday)]

def sort_key(t):
    order = {'em andamento': 0, 'pendente': 1}
    return (order.get(t['status'], 9), t['id'])

active.sort(key=sort_key)
done.sort(key=lambda t: t.get('updatedAt', ''), reverse=True)

result = {'today': today, 'yesterday': yesterday, 'active': active, 'done': done}
print(json.dumps(result, ensure_ascii=False, indent=2))
"
```

Com o JSON resultante, gere o relatório no seguinte formato:

```
{today} -> hoje
[ ] <resumo da tarefa>
[ ] <resumo da tarefa>

{yesterday} -> ontem
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
