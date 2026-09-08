# SLIs, SLOs e política de error budget - demo-api

## Jornada crítica do usuário

O serviço expõe o catálogo de pedidos consumido pelo app mobile. A experiência quebra
quando a listagem falha ou demora o suficiente para o usuário perceber. Por isso os
indicadores foram definidos na borda do serviço (request-based), e não em métricas de
infraestrutura como CPU ou memória.

## SLIs

| SLI | Definição | Origem |
|-----|-----------|--------|
| Disponibilidade | requisições sem resposta 5xx / total de requisições | `http_requests_total` |
| Latência | requisições servidas em até 250ms / total de requisições | `http_request_duration_seconds_bucket` |

Erros 4xx não entram no numerador: eles representam uso incorreto do cliente e não falha
do serviço. Essa decisão foi tomada para evitar que um bug de cliente consuma o budget do time.

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
