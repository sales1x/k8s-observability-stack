# Runbook: latência acima do alvo

**Alerta:** `DemoApiLatenciaForaDoAlvo`
**Severidade:** warning
**Impacto:** menos de 95% das requisições respondem em até 250ms.

## Diagnóstico

1. Comparar p50, p95 e p99 no dashboard. p99 alto com p50 estável indica cauda longa
   (poucas requisições lentas), normalmente dependência externa ou lock.
   p50 alto indica degradação geral, normalmente saturação.
2. Checar se o HPA escalou:

```bash
kubectl -n demo get hpa demo-api
kubectl -n demo describe hpa demo-api | tail -20
```

3. Checar throttling de CPU:

```bash
kubectl -n demo top pods
```

Throttling frequente com uso abaixo do limite indica limit de CPU muito apertado.

## Mitigação

- Aumentar `maxReplicas` do HPA se o teto foi atingido.
- Revisar `resources.limits.cpu` (limits baixos causam throttling mesmo com nó ocioso).
- Se a origem for uma dependência externa, aplicar timeout e circuit breaker no cliente.

## Prevenção

Registrar o resultado no próximo ciclo de revisão de capacidade e comparar com o teste
de carga baseline do repositório de confiabilidade.
