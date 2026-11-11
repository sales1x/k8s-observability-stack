# Runbook: poucas réplicas prontas na demo-api

**Alerta:** `DemoApiPoucasReplicasProntas`
**Severidade:** crítica
**Impacto:** o serviço está rodando com menos de 2 réplicas disponíveis. Ainda pode estar
respondendo, mas sem margem: mais uma falha (ou um drain de nó) derruba o tráfego, e o
PodDisruptionBudget (`minAvailable: 2`) passa a bloquear manutenções.

## 1. Confirmar o estado (2 min)

```bash
kubectl -n demo get deployment demo-api
kubectl -n demo get pods -l app.kubernetes.io/name=demo-api -o wide
kubectl -n demo get pdb demo-api
```

No Grafana, dashboard `demo-api | SLO 99.9%`, verificar se o burn rate também subiu.
Se subiu, seguir em paralelo o [runbook de alta taxa de erro](runbook-alta-taxa-de-erro.md).

## 2. Hipóteses mais comuns

| Sintoma | Hipótese | Verificação |
|---------|----------|-------------|
| Pods em `Pending` | Falta de recurso no cluster ou nó indisponível | `kubectl -n demo describe pod <pod>` (eventos `FailedScheduling`), `kubectl get nodes` |
| Pods em `CrashLoopBackOff` | Falha na aplicação ou na configuração | seguir o [runbook de CrashLoop](runbook-crashloop.md) |
| Pods `Running` mas não `Ready` | Readiness falhando | `kubectl -n demo describe pod <pod>` (eventos `Unhealthy`) |
| Rollout parado no meio | Versão nova não fica pronta | `kubectl -n demo rollout status deployment/demo-api` |
| Nó em `NotReady` ou cordonado | Problema de infraestrutura | `kubectl get nodes`, `kubectl describe node <node>` |

## 3. Mitigar

Se a causa for o deploy atual, voltar para a revisão anterior:

```bash
kubectl -n demo rollout undo deployment/demo-api
kubectl -n demo rollout status deployment/demo-api
```

Se a causa for capacidade, liberar espaço ou trazer o nó de volta:

```bash
kubectl uncordon <node>
kubectl -n demo scale deployment/demo-api --replicas=3
```

Evite remover o PodDisruptionBudget para "destravar" uma manutenção: ele está fazendo
exatamente o trabalho dele, que é impedir que a manutenção derrube o serviço.

## 4. Depois do incidente

Registrar a causa e, se o problema foi falta de capacidade, revisar requests do Deployment
e a quantidade de nós no próximo ciclo de capacidade.
