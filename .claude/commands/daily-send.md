---
description: Gera o relatório diário e envia para o Google Chat configurado em ~/.claude/pipeline/gchat_webhook.
allowed-tools: Bash
---
# Daily Send

```bash
WEBHOOK_FILE="$HOME/.claude/pipeline/gchat_webhook"

if [ ! -f "$WEBHOOK_FILE" ]; then
    echo "Webhook não configurado. Execute:"
    echo "  echo 'https://chat.googleapis.com/v1/spaces/...' > ~/.claude/pipeline/gchat_webhook"
    exit 1
fi

WEBHOOK_URL=$(cat "$WEBHOOK_FILE" | tr -d '[:space:]')

if [ -z "$WEBHOOK_URL" ]; then
    echo "Arquivo gchat_webhook está vazio."
    exit 1
fi

NAME=$(git config user.name 2>/dev/null || echo "Engenheiro")

pipeline task list --format json | python3 -c "
import sys, json
from datetime import date, timedelta

name = sys.argv[1]
today = date.today()
weekday = today.weekday()  # 0=segunda, 4=sexta, 5=sábado, 6=domingo

# Na segunda-feira, "ontem" é sexta-feira
if weekday == 0:
    prev = today - timedelta(days=3)
else:
    prev = today - timedelta(days=1)

today_str = str(today)
prev_str = str(prev)
tasks = json.load(sys.stdin)

TOOLING_PROJECTS = {'projects', 'claude-code-engineering-guide'}
active = [t for t in tasks if t['status'] in ('em andamento', 'pendente')
          and t.get('projectId') not in TOOLING_PROJECTS]
done = [t for t in tasks if t['status'] in ('concluido', 'concluído')
        and t.get('updatedAt', '')[:10] in (today_str, prev_str)
        and t.get('projectId') not in TOOLING_PROJECTS]

def sort_key(t):
    return ({'em andamento': 0, 'pendente': 1}.get(t['status'], 9), t['id'])

active.sort(key=sort_key)
done.sort(key=lambda t: t.get('updatedAt', ''), reverse=True)

if not active and not done:
    print('EMPTY')
    sys.exit(0)

prev_label = 'sexta-feira' if weekday == 0 else 'ontem'

lines = ['*Daily Report — {}*'.format(name), '']

if active:
    lines.append('{} -> hoje'.format(today_str))
    for t in active:
        tag = '[ZENDESK] ' if t.get('type') == 'incident' else ''
        lines.append('[ ] {}{}'.format(tag, t['title']))

done_by_date = {}
for t in done:
    d = t.get('updatedAt', '')[:10]
    done_by_date.setdefault(d, []).append(t)

for d in sorted(done_by_date.keys(), reverse=True):
    label = 'hoje' if d == today_str else prev_label if d == prev_str else d
    if lines:
        lines.append('')
    lines.append('{} -> {}'.format(d, label))
    for t in done_by_date[d]:
        tag = '[ZENDESK] ' if t.get('type') == 'incident' else ''
        lines.append('[X] {}{}'.format(tag, t['title']))

print('\n'.join(lines))
" "$NAME" | {
    read -r -d '' MESSAGE || true
    if [ "$MESSAGE" = "EMPTY" ]; then
        exit 0
    fi
    PAYLOAD=$(python3 -c "import json, sys; print(json.dumps({'text': sys.argv[1]}))" "$MESSAGE")
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
        -X POST "$WEBHOOK_URL" \
        -H "Content-Type: application/json" \
        -d "$PAYLOAD")
    if [ "$RESPONSE" = "200" ]; then
        echo "Relatório enviado para o Google Chat."
    else
        echo "Erro ao enviar (HTTP $RESPONSE). Verifique a URL do webhook."
    fi
}
```

Se o webhook não estiver configurado, exiba as instruções acima e encerre sem erro.
