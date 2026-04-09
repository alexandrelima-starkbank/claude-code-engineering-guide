---
description: Auditoria completa da pipeline de uma tarefa — gates, rastreabilidade, métricas e histórico de fases.
allowed-tools: Bash
---
# Pipeline Audit: $ARGUMENTS

```bash
pipeline audit $ARGUMENTS
```

Reporta para cada gate (`requirements`, `spec`, `traceability`, `tests`, `mutation`):
- **PASS ✓** ou **FAIL ✗** com detalhe mensurável
- Histórico de transições de fase com timestamps
- Resultado final: **READY** ou **NOT READY**

Se `$ARGUMENTS` for omitido, audita todas as tarefas do projeto atual.

Para ver a view completa com matriz de rastreabilidade:
```bash
pipeline task show $ARGUMENTS
```
