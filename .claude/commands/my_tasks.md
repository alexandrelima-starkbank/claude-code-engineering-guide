---
description: Lista tarefas da pipeline com filtros opcionais de status, limite e ordem.
allowed-tools: Bash
---
# My Tasks

Argumentos (todos opcionais): `$ARGUMENTS`

```bash
pipeline task list --format json | python3 -c "
import sys, json, re

args = '$ARGUMENTS'.strip()

# parse args
status_filter = None
limit = None
order = 'asc'

for token in args.split():
    if token in ('asc', 'desc'):
        order = token
    elif token.lstrip('-').isdigit():
        limit = int(token.lstrip('-'))
    else:
        status_filter = token.lower()

tasks = json.load(sys.stdin)

if status_filter:
    tasks = [t for t in tasks if status_filter in t.get('status','').lower()]

phase_order = ['requirements','spec','tests','implementation','mutation','done']

def sort_key(t):
    phase = t.get('phase','')
    idx = phase_order.index(phase) if phase in phase_order else 99
    return (idx, t.get('id',''))

tasks.sort(key=sort_key, reverse=(order == 'desc'))

if limit:
    tasks = tasks[:limit]

print(json.dumps(tasks, ensure_ascii=False, indent=2))
"
```

Para cada tarefa no JSON, gere **exatamente um bullet** na forma:

```
• [T<N>] <título> | <projeto> | <fase> | <status>
```

- Sem cabeçalho, sem seções, sem texto adicional — apenas os bullets
- Se JSON vazio: `Nenhuma tarefa encontrada.`
