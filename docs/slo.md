# SLIs, SLOs e política de error budget - demo-api

## Jornada crítica do usuário

O serviço expõe o catálogo de pedidos consumido pelo app mobile. A experiência quebra
quando a listagem falha ou demora o suficiente para o usuário perceber. Por isso os
indicadores foram definidos na borda do serviço (request-based), e não em métricas de
infraestrutura como CPU ou memória.

## SLIs

| SLI | Definição | Origem |
|-----|-----------|--------|
| Disponibilidade | requisições às rotas `/api/...` sem resposta 5xx / total de requisições às rotas `/api/...` | `http_requests_total` |
| Latência | requisições às rotas `/api/...` servidas em até 250ms / total de requisições às rotas `/api/...` | `http_request_duration_seconds_bucket` |

Erros 4xx não entram no numerador: eles representam uso incorreto do cliente e não falha
do serviço. Essa decisão foi tomada para evitar que um bug de cliente consuma o budget do time.

Só as rotas de API entram no SLI. As probes do kubelet (`/healthz` e `/readyz`) e as rotas
internas não são tráfego de usuário: com 3 réplicas, as probes somam cerca de 0,9 req/s,
sempre com 200, e diluiriam a taxa de erro (em horário sem tráfego, o SLI mostraria 100%
medindo só as probes). Um período sem nenhum 5xx conta como 0% de erro, e não como
"sem dados".

## SLOs

| SLO | Alvo | Janela | Error budget |
|-----|------|--------|--------------|
| Disponibilidade | 99,9% | 30 dias corridos | 43min 12s de indisponibilidade |
| Latência | 95% abaixo de 250ms | 30 dias corridos | 5% das requisições |

## Alertas por burn rate

Alertar em "taxa de erro maior que X" gera ruído. O modelo adotado usa duas janelas
simultâneas: uma longa, para significância estatística, e uma curta, para reset rápido.

| Burn rate | Janela longa | Janela curta | Budget consumido | Ação |
|-----------|--------------|--------------|------------------|------|
| 14,4x | 1h | 5m | 2% em 1h | Aciona o plantão imediatamente |
| 6x | 6h | 30m | 5% em 6h | Aciona o plantão |
| 3x | 1d | 2h | 10% em 1 dia | Abre ticket, horário comercial |

## Política de error budget

- **Budget acima de 50%**: o time segue com o roadmap normalmente.
- **Budget entre 25% e 50%**: toda mudança precisa de plano de rollback documentado no PR.
- **Budget abaixo de 25%**: congelamento de features. A prioridade passa a ser confiabilidade
  (testes, hardening, correção das causas dos incidentes do período).
- **Budget esgotado**: apenas correções de bug e mudanças de segurança até a janela renovar.

A política existe para transformar confiabilidade em uma conversa com dados, e não em uma
disputa entre quem quer entregar rápido e quem quer manter o sistema de pé.
