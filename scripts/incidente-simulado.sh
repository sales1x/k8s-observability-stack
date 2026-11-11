#!/usr/bin/env bash
# Injeta uma falha controlada para validar os alertas de queima de error budget.
# Sobe a taxa de erro da aplicacao, espera e restaura o valor que estava antes,
# inclusive se o script for interrompido (Ctrl+C) ou falhar no meio.
# Uso: ./scripts/incidente-simulado.sh [taxa-de-erro] [duracao-segundos]
# Deixe o make carga rodando em outro terminal: sem trafego nao ha erro para medir.
set -euo pipefail

TAXA="${1:-0.30}"
DURACAO="${2:-600}"
NAMESPACE="${NAMESPACE:-demo}"
DEPLOY="deployment/demo-api"

ANTERIOR=$(kubectl -n "$NAMESPACE" get "$DEPLOY" \
  -o jsonpath='{.spec.template.spec.containers[?(@.name=="api")].env[?(@.name=="FAILURE_RATE")].value}')
ANTERIOR="${ANTERIOR:-0.0005}"

RESTAURADO=0
restaurar() {
  if [ "$RESTAURADO" = 1 ]; then
    return
  fi
  RESTAURADO=1
  echo "Restaurando FAILURE_RATE para ${ANTERIOR}"
  kubectl -n "$NAMESPACE" set env "$DEPLOY" "FAILURE_RATE=${ANTERIOR}"
  kubectl -n "$NAMESPACE" rollout status "$DEPLOY"
}
trap restaurar EXIT
trap 'exit 130' INT TERM

echo "Elevando FAILURE_RATE de ${ANTERIOR} para ${TAXA} no deployment demo-api"
kubectl -n "$NAMESPACE" set env "$DEPLOY" "FAILURE_RATE=${TAXA}"
kubectl -n "$NAMESPACE" rollout status "$DEPLOY"

echo "Aguardando ${DURACAO}s. Acompanhe o alerta DemoApiQueimaRapidaErrorBudget no"
echo "Alertmanager (make alertmanager) e as paginas do plantao (make plantao)."
sleep "$DURACAO"
