#!/usr/bin/env bash
# Injeta uma falha controlada para validar os alertas de queima de error budget.
# Sobe a taxa de erro da aplicacao para 30%, espera e reverte.
set -euo pipefail

TAXA="${1:-0.30}"
DURACAO="${2:-600}"

echo "Elevando FAILURE_RATE para ${TAXA} no deployment demo-api"
kubectl -n demo set env deployment/demo-api "FAILURE_RATE=${TAXA}"
kubectl -n demo rollout status deployment/demo-api

echo "Aguardando ${DURACAO}s. Acompanhe o alerta DemoApiQueimaRapidaErrorBudget no Alertmanager."
sleep "$DURACAO"

echo "Revertendo para 0.02"
kubectl -n demo set env deployment/demo-api FAILURE_RATE=0.02
kubectl -n demo rollout status deployment/demo-api
