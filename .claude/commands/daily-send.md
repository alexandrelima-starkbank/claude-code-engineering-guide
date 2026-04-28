---
description: Gera o relatório diário e envia para o Google Chat configurado em ~/.claude/pipeline/gchat_webhook.
allowed-tools: Bash
---
# Daily Send

Primeiro, verifique se o webhook está configurado:

```bash
WEBHOOK_FILE="$HOME/.claude/pipeline/gchat_webhook"
if [ ! -f "$WEBHOOK_FILE" ]; then
    echo "Webhook não configurado. Execute:"
    echo "  echo 'https://chat.googleapis.com/v1/spaces/...' > ~/.claude/pipeline/gchat_webhook"
    exit 1
fi
cat "$WEBHOOK_FILE" | tr -d '[:space:]'
```

Se o webhook estiver vazio ou ausente, exiba as instruções e encerre.

Caso contrário, gere o relatório diário exatamente como o skill `/daily --reportable` faz. Em seguida, envie o texto gerado para o webhook usando o comando abaixo, substituindo `WEBHOOK_URL` pela URL lida acima e `REPORT_TEXT` pelo relatório gerado:

```bash
PAYLOAD=$(python3 -c "import json, sys; print(json.dumps({'text': sys.argv[1]}))" "$REPORT_TEXT")
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST "$WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD")
if [ "$RESPONSE" = "200" ]; then
    echo "Relatório enviado para o Google Chat."
else
    echo "Erro ao enviar (HTTP $RESPONSE). Verifique a URL do webhook."
fi
```

Se não houver tarefas concluídas (`Nenhuma atividade registrada.`), encerre sem enviar.
