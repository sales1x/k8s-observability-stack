CLUSTER      ?= obs-lab
IMAGE        ?= demo-api
TAG          ?= 0.1.0
NAMESPACE    ?= demo

.PHONY: help
help: ## Lista os alvos disponiveis
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-18s %s\n", $$1, $$2}'

.PHONY: up
up: cluster build load monitoring deploy dashboard ## Sobe o ambiente completo do zero
	@echo ""
	@echo "Ambiente pronto."
	@echo "  API:        http://localhost:8080/api/pedidos"
	@echo "  Grafana:    make grafana   (admin / admin)"
	@echo "  Prometheus: make prometheus"

.PHONY: cluster
cluster: ## Cria o cluster kind
	kind create cluster --config kind/cluster.yaml

.PHONY: build
build: ## Builda a imagem da aplicacao
	docker build -t $(IMAGE):$(TAG) ./app

.PHONY: load
load: ## Carrega a imagem local dentro do kind
	kind load docker-image $(IMAGE):$(TAG) --name $(CLUSTER)

.PHONY: monitoring
monitoring: ## Instala kube-prometheus-stack via Helm
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	helm repo update
	helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
		--namespace monitoring --create-namespace \
		-f monitoring/values-kube-prometheus-stack.yaml \
		--wait --timeout 10m
	kubectl apply -f monitoring/prometheus-rules-slo.yaml

.PHONY: deploy
deploy: ## Aplica os manifests da aplicacao
	kubectl apply -f k8s/namespace.yaml
	kubectl apply -f k8s/
	kubectl -n $(NAMESPACE) rollout status deployment/demo-api

.PHONY: dashboard
dashboard: ## Publica o dashboard de SLO no Grafana
	kubectl -n monitoring create configmap grafana-dashboard-slo \
		--from-file=slo.json=monitoring/grafana-dashboard-slo.json \
		--dry-run=client -o yaml | kubectl label -f - --local -o yaml --dry-run=client \
		grafana_dashboard=1 | kubectl apply -f -

.PHONY: carga
carga: ## Gera trafego sintetico contra a API
	./scripts/gerar-carga.sh http://localhost:8080/api/pedidos 15 600

.PHONY: incidente
incidente: ## Injeta 30% de erro por 10 minutos para validar os alertas
	./scripts/incidente-simulado.sh 0.30 600

.PHONY: grafana
grafana: ## Abre o Grafana em localhost:3000
	kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80

.PHONY: prometheus
prometheus: ## Abre o Prometheus em localhost:9090
	kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090

.PHONY: alertmanager
alertmanager: ## Abre o Alertmanager em localhost:9093
	kubectl -n monitoring port-forward svc/kube-prometheus-stack-alertmanager 9093:9093

.PHONY: lint
lint: ## Valida manifests e regras do Prometheus
	kubectl apply --dry-run=client -f k8s/ > /dev/null && echo "manifests ok"
	python3 scripts/extrai_regras.py monitoring/prometheus-rules-slo.yaml /tmp/regras.yaml
	docker run --rm -v /tmp:/tmp --entrypoint promtool prom/prometheus:v2.53.0 check rules /tmp/regras.yaml

.PHONY: down
down: ## Destroi o cluster
	kind delete cluster --name $(CLUSTER)
