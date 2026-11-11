#!/usr/bin/env bash
# Gera trafego continuo contra a demo-api para popular as metricas.
# Uso: ./scripts/gerar-carga.sh [url] [requisicoes-por-segundo] [duracao-segundos]
set -euo pipefail

URL="${1:-http://localhost:8080/api/pedidos}"
RPS="${2:-10}"
DURACAO="${3:-300}"

intervalo=$(awk -v r="$RPS" 'BEGIN { printf "%.4f", 1 / r }')
fim=$(( $(date +%s) + DURACAO ))

echo "Enviando ~${RPS} req/s para ${URL} durante ${DURACAO}s"
while [ "$(date +%s)" -lt "$fim" ]; do
  # --max-time evita acumular processos curl se a API parar de responder.
  curl -s --max-time 5 -o /dev/null -w "%{http_code} " "$URL" &
  sleep "$intervalo"
done
wait
echo
echo "Carga finalizada."
