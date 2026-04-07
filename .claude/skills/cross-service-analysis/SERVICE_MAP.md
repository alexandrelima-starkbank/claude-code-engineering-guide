# Service Dependency Map

<!-- Preencha este arquivo com os serviços da sua plataforma antes de usar
     /cross-service-analysis, /blast-radius ou /investigate. -->

---

## Serviços

<!-- Liste os serviços da plataforma e o que cada um faz.
     Exemplo:
     - payments   — processa transações e autorizações
     - accounts   — gerencia saldo e limites
     - ledger     — registra mutações financeiras (maior risco)
     - notify     — envia notificações ao usuário final
-->

- service-a — <descrição>
- service-b — <descrição>
- service-c — <descrição>

---

## Pipeline de Autorização / Fluxo Principal

<!-- Descreva a sequência de chamadas no caminho crítico.
     Exemplo: gateway -> processor -> issuer -> accounts -> ledger
-->

service-a -> service-b -> service-c

---

## Contratos Compartilhados

<!-- O que é compartilhado entre serviços e pode quebrar em cascata se mudar. -->

**Enums compartilhados:**
- `<NomeDoEnum>` — usado em: service-a, service-b

**Mensagens de fila (async):**
- `<TipoMensagem>` — producer: service-a, consumer: service-b

**Schemas de API entre serviços:**
- `GET /internal/<recurso>` — chamado por: service-b

---

## Regras de Deploy

1. **Campo novo (aditivo):** consumers fazem deploy antes do producer começar a enviar
2. **Remoção de campo:** producer para de enviar antes dos consumers removerem a leitura
3. **Enum novo:** todos os consumers devem suportar o novo valor antes do producer enviar
4. **Mudança de schema de fila:** coordenar janela de deploy ou usar versionamento
5. **Serviço de ledger / financeiro:** maior risco — sempre coordenar e testar em staging

---

## Diretórios dos Serviços

<!-- Caminhos reais no sistema de arquivos.
     Exemplo: ~/projects/api-ms-payments
-->

- service-a: ~/projects/<diretório-do-service-a>
- service-b: ~/projects/<diretório-do-service-b>
- service-c: ~/projects/<diretório-do-service-c>
