---
name: bugfix
description: Ciclo N4 completo para correção de bugs — do root cause ao código testado. Reproduz o bug antes de corrigir. Use após /support escalar para N4 ou quando o root cause já for conhecido.
---

# Bugfix: $ARGUMENTS

Ciclo N4 — correção segura e rastreável a partir do root cause.

A ordem importa: **reproduzir antes de corrigir**.
Um fix sem teste de regressão que falha antes da correção não tem garantia de estar corrigindo o bug certo.

---

## Fase 0 — Root Cause

Identificar o input desta sessão:

**Se vier de `/support`:** ler `TASKS.md` para encontrar a tarefa de incidente correspondente.
Extrair: root cause, nível de confiança, Requisitos EARS gerados na escalação N4.

**Se for direto:** coletar o root cause agora:
- Qual é o comportamento incorreto (o que o código faz)?
- Qual é o comportamento esperado (o que deveria fazer)?
- Em qual arquivo/função/serviço o bug está localizado?
- Qual é a condição de ativação?

**GATE:** editar `TASKS.md` agora com o formato de incidente (`**Tipo:** incidente`, `**Nível:** N4`, `**Comportamento atual:**`, `**Comportamento esperado:**`, `**Root cause:**`). Não avançar sem ter escrito no arquivo.

---

## Fase 1 — Teste de Regressão que Falha

Escrever o teste que reproduz o bug **antes de qualquer mudança no código de produção**.

```python
def test<Cenário>_<Condição>(self):
    # Root cause: <causa raiz do incidente>
    # Regresso: este teste deveria ter existido antes do bug

    # Arrange
    <configurar as condições que ativam o bug>

    # Act
    <chamar o código que exibe o comportamento incorreto>

    # Assert
    <verificar o comportamento CORRETO esperado — que ainda não existe>
```

**Executar o teste — DEVE falhar.**
```bash
python3 -m pytest tests/ -v -k "test<NomeDoTeste>"
```

Se o teste passar antes da correção: ele não está testando o bug correto — revisar arrange/act/assert.
Só avançar quando o teste falhar pelo motivo certo.

---

## Fase 2 — Requisitos EARS

Se os Requisitos EARS já existem (vindo do `/support`): ler de `TASKS.md` e confirmar que cobrem o root cause.

Se não existem: derivar agora a partir do root cause:
- Focar nos padrões `IF/THEN` (o que deve acontecer quando o bug se manifesta)
- Focar nos padrões `WHEN` (comportamento correto esperado no caminho feliz)
- Cada requisito deve ser testável pelo teste de regressão escrito na Fase 1

**GATE:** se não existir, editar `TASKS.md` agora e escrever os requisitos na seção `**Requisitos EARS:**`. Não avançar sem confirmar a edição.

---

## Fase 3 — Spec

Derivar cenários Given/When/Then dos Requisitos EARS:
- O cenário principal DEVE mapear para o teste de regressão da Fase 1
- Adicionar cenários para edge cases e paths adjacentes ao bug

Cada "Então" mapeia para exatamente um método de teste: `test<Cenário>_<Condição>`.

**GATE:** editar `TASKS.md` agora e escrever os cenários na seção `**Critério de aceitação:**`. Não avançar sem confirmar a edição.

---

## Fase 4 — Implementação

Implementar o mínimo de código para fazer o teste de regressão passar:
- Nenhuma funcionalidade além do que os testes exigem
- Seguir todas as convenções do `CLAUDE.md` (camelCase, sem else, `.format()`, sem type hints, sem docstrings)
- Executar os testes após cada mudança significativa

```bash
python3 -m pytest tests/ -v
```

Parar quando todos os testes passarem — sem over-engineering.

---

## Fase 5 — Verificação por Mutação

Confirmar que `mutmut.toml` aponta para diretórios reais antes de executar.

```bash
mutmut run --paths-to-mutate <arquivo-corrigido>
mutmut results
```

Para cada mutante sobrevivente (`mutmut show <id>`):
- **Lacuna no teste**: adicionar assertion que mata o mutante — priorizar mutantes que representam variações do bug
- **Equivalente**: adicionar `# pragma: no mutate — <justificativa>`

**Não concluir antes que o mutation score seja 100%** (exceto equivalentes justificados).

---

## Fase 6 — Blast Radius

Antes de fazer merge, verificar o impacto da mudança:

```
/blast-radius <o que foi alterado>
```

Para cada serviço afetado: confirmar que a mudança é backward-compatible ou que os serviços dependentes serão atualizados coordenadamente.

---

## Fase 7 — Checklist Final

Confirmar todos os gates antes de commitar:

- [ ] Teste de regressão existe e falhou antes da correção
- [ ] Todos os testes passam após a correção
- [ ] Mutation score: 100% (exceto equivalentes justificados)
- [ ] Blast radius verificado — deploy coordenado se necessário
- [ ] Convenções seguidas — executar `/review` para confirmar
- [ ] `TASKS.md` atualizado: `**Root cause:**` preenchido, status `concluído`
- [ ] Mensagem de commit referencia o incidente: `Fix <comportamento incorreto> em <componente>`
