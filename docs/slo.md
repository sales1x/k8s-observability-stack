# SLIs, SLOs e politica de error budget - demo-api

## Jornada critica do usuario

O servico expoe o catalogo de pedidos consumido pelo app mobile. A experiencia quebra
quando a listagem falha ou demora o suficiente para o usuario perceber. Por isso os
indicadores foram definidos na borda do servico (request-based), e nao em metricas de
infraestrutura como CPU ou memoria.

## SLIs

| SLI | Definicao | Origem |
|-----|-----------|--------|
| Disponibilidade | requisicoes sem resposta 5xx / total de requisicoes | `http_requests_total` |
| Latencia | requisicoes servidas em ate 250ms / total de requisicoes | `http_request_duration_seconds_bucket` |

Erros 4xx nao entram no numerador: eles representam uso incorreto do cliente e nao falha
do servico. Essa decisao foi tomada para evitar que um bug de cliente consuma o budget do time.

## SLOs

| SLO | Alvo | Janela | Error budget |
|-----|------|--------|--------------|
| Disponibilidade | 99,9% | 30 dias corridos | 43min 12s de indisponibilidade |
| Latencia | 95% abaixo de 250ms | 30 dias corridos | 5% das requisicoes |

## Alertas por burn rate

Alertar em "taxa de erro maior que X" gera ruido. O modelo adotado usa duas janelas
simultaneas (uma longa para significancia estatistica, uma curta para reset rapido):

| Burn rate | Janela longa | Janela curta | Budget consumido | Acao |
|-----------|--------------|--------------|------------------|------|
| 14,4x | 1h | 5m | 2% em 1h | Aciona plantao imediatamente |
| 6x | 6h | 30m | 5% em 6h | Aciona plantao |
| 3x | 1d | 2h | 10% em 1 dia | Abre ticket, horario comercial |

## Politica de error budget

- **Budget acima de 50%**: time segue com o roadmap normalmente.
- **Budget entre 25% e 50%**: toda mudanca precisa de plano de rollback documentado no PR.
- **Budget abaixo de 25%**: congelamento de features. A prioridade passa a ser confiabilidade
  (testes, hardening, correcao das causas dos incidentes do periodo).
- **Budget esgotado**: apenas correcoes de bug e mudancas de seguranca ate a janela renovar.

A politica existe para transformar confiabilidade em uma conversa com dados, e nao em uma
disputa entre quem quer entregar rapido e quem quer manter o sistema de pe.
