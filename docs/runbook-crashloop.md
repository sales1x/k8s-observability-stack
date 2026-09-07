# Runbook: pod em CrashLoopBackOff

**Alerta:** `DemoApiPodEmCrashLoop`

## Passos

```bash
kubectl -n demo get pods
kubectl -n demo describe pod <pod>
kubectl -n demo logs <pod> --previous --tail=200
```

Causas mais comuns e o que olhar:

- **OOMKilled**: campo `Last State` no describe. Corrigir `resources.limits.memory`.
- **Falha na readiness/liveness**: probe apontando para path ou porta errada, ou
  `initialDelaySeconds` menor que o tempo de boot da aplicacao.
- **Erro de configuracao**: variavel de ambiente ou secret ausente aparece no log da
  primeira linha do container.
- **Imagem invalida**: `ImagePullBackOff` no lugar de CrashLoop, checar tag e registry.

## Mitigacao

Se o deploy atual e a causa, `kubectl -n demo rollout undo deployment/demo-api`.
Se apenas um no esta afetado, cordonar o no e deixar o scheduler realocar:

```bash
kubectl cordon <node>
kubectl -n demo delete pod <pod>
```
