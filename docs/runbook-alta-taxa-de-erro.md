# Runbook: alta taxa de erro na demo-api

**Alerta:** `DemoApiQueimaRapidaErrorBudget` / `DemoApiQueimaModeradaErrorBudget`
**Severidade:** crítica
**Impacto:** clientes recebem 5xx ao listar pedidos.

## 1. Confirmar o impacto (2 min)

```bash
kubectl -n demo get pods -l app.kubernetes.io/name=demo-api
kubectl -n demo top pods
```

No Grafana, dashboard `demo-api | SLO 99.9%`, verificar:

- o painel de burn rate está acima de 14,4x?
- os erros estão concentrados em um pod ou distribuídos?

## 2. Hipóteses mais comuns

| Sintoma | Hipótese | Verificação |
|---------|----------|-------------|
| Erros começaram junto com um deploy | Regressão na versão nova | `kubectl -n demo rollout history deployment/demo-api` |
| Erros em um único pod | Pod degradado | `kubectl -n demo logs <pod> --tail=100` |
| Latência subiu junto | Saturação de recursos | painel de CPU/memória, eventos de throttling |
| `up{job="demo-api"} == 0` | Problema de coleta, não do serviço | checar ServiceMonitor e endpoints |

## 3. Mitigar primeiro, investigar depois

Rollback para a revisão anterior:

```bash
kubectl -n demo rollout undo deployment/demo-api
kubectl -n demo rollout status deployment/demo-api
```

Se o problema for um pod isolado, remover da rotação sem perder o estado para análise:

```bash
kubectl -n demo label pod <pod> app.kubernetes.io/name-
```

Se a origem for saturação, escalar manualmente enquanto se investiga:

```bash
kubectl -n demo scale deployment/demo-api --replicas=6
```

## 4. Comunicação

- Abrir o canal do incidente e nomear um comandante.
- Atualização a cada 15 minutos enquanto o alerta estiver ativo.
- Registrar na linha do tempo: horário da detecção, primeira ação, momento da mitigação.

## 5. Depois do incidente

Abrir postmortem blameless em até 48h contendo: linha do tempo, impacto medido em
error budget consumido, causa raiz e ações com responsável e prazo.
