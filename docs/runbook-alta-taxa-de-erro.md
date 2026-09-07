# Runbook: alta taxa de erro na demo-api

**Alerta:** `DemoApiQueimaRapidaErrorBudget` / `DemoApiQueimaModeradaErrorBudget`
**Severidade:** critica
**Impacto:** clientes recebem 5xx ao listar pedidos.

## 1. Confirmar o impacto (2 min)

```bash
kubectl -n demo get pods -l app.kubernetes.io/name=demo-api
kubectl -n demo top pods
```

No Grafana, dashboard `demo-api | SLO 99.9%`, verificar:
- o painel de burn rate esta acima de 14,4x?
- os erros estao concentrados em um pod ou distribuidos?

## 2. Hipoteses mais comuns

| Sintoma | Hipotese | Verificacao |
|---------|----------|-------------|
| Erros comecaram junto com um deploy | Regressao na versao nova | `kubectl -n demo rollout history deployment/demo-api` |
| Erros em um unico pod | Pod degradado | `kubectl -n demo logs <pod> --tail=100` |
| Latencia subiu junto | Saturacao de recursos | painel de CPU/memoria, eventos de throttling |
| `up{job="demo-api"} == 0` | Problema de coleta, nao do servico | checar ServiceMonitor e endpoints |

## 3. Mitigar primeiro, investigar depois

Rollback para a revisao anterior:

```bash
kubectl -n demo rollout undo deployment/demo-api
kubectl -n demo rollout status deployment/demo-api
```

Se o problema for um pod isolado, remover da rotacao sem perder o estado para analise:

```bash
kubectl -n demo label pod <pod> app.kubernetes.io/name-
```

Se a origem for saturacao, escalar manualmente enquanto se investiga:

```bash
kubectl -n demo scale deployment/demo-api --replicas=6
```

## 4. Comunicacao

- Abrir canal do incidente e nomear um comandante.
- Atualizacao a cada 15 minutos enquanto o alerta estiver ativo.
- Registrar no timeline: horario da deteccao, primeira acao, momento da mitigacao.

## 5. Depois do incidente

Abrir postmortem blameless em ate 48h contendo: linha do tempo, impacto medido em
error budget consumido, causa raiz e acoes com responsavel e prazo.
