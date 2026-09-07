# Runbook: latencia acima do alvo

**Alerta:** `DemoApiLatenciaForaDoAlvo`
**Severidade:** warning
**Impacto:** menos de 95% das requisicoes respondem em ate 250ms.

## Diagnostico

1. Comparar p50, p95 e p99 no dashboard. p99 alto com p50 estavel indica cauda longa
   (poucas requisicoes lentas), normalmente dependencia externa ou lock.
   p50 alto indica degradacao geral, normalmente saturacao.
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

## Mitigacao

- Aumentar `maxReplicas` do HPA se o teto foi atingido.
- Revisar `resources.limits.cpu` (limits baixos causam throttling mesmo com no ocioso).
- Se a origem for uma dependencia externa, aplicar timeout e circuit breaker no cliente.

## Prevencao

Registrar o resultado no proximo ciclo de revisao de capacidade e comparar com o teste
de carga baseline do repositorio de confiabilidade.
