CLUSTER      ?= obs-lab
IMAGE        ?= demo-api
TAG          ?= 0.1.0
NAMESPACE    ?= demo

# Versoes fixadas para o ambiente ser reproduzivel.
KPS_VERSION            ?= 93.2.0
METRICS_SERVER_VERSION ?= 3.14.0
PROM_IMAGE             ?= prom/prometheus:v3.16.0
AM_IMAGE               ?= prom/alertmanager:v0.27.0

# Trafego sintetico: dura mais que o make incidente (10 min + rollouts) para dar
# tempo de ver o alerta disparar e depois resolver.
CARGA_RPS      ?= 15
CARGA_DURACAO  ?= 1800

.PHONY: help
help: ## Lista os alvos disponiveis
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-18s %s\n", $$1, $$2}'

.PHONY: up
up: cluster build load metrics-server monitoring deploy dashboard ## Sobe o ambiente completo do zero
	@echo ""
	@echo "Ambiente pronto."
	@echo "  API:        http://localhost:8080/api/pedidos"
	@echo "  Grafana:    make grafana   (admin / admin)"
	@echo "  Prometheus: make prometheus"
	@echo "  Plantao:    make plantao"

.PHONY: cluster
cluster: ## Cria o cluster kind
	kind create cluster --config kind/cluster.yaml

.PHONY: build
build: ## Builda a imagem da aplicacao
	docker build -t $(IMAGE):$(TAG) ./app

.PHONY: load
load: ## Carrega a imagem local dentro do kind
	kind load docker-image $(IMAGE):$(TAG) --name $(CLUSTER)

.PHONY: metrics-server
metrics-server: ## Instala o metrics-server (o kind nao traz, e sem ele o HPA fica <unknown>)
	helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
	helm repo update metrics-server
	helm upgrade --install metrics-server metrics-server/metrics-server \
		--version $(METRICS_SERVER_VERSION) --namespace kube-system \
		--set 'args={--kubelet-insecure-tls}' \
		--wait --timeout 5m

.PHONY: monitoring
monitoring: ## Instala kube-prometheus-stack via Helm, as regras de SLO e o receptor de alertas
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	helm repo update prometheus-community
	helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
		--version $(KPS_VERSION) \
		--namespace monitoring --create-namespace \
		-f monitoring/values-kube-prometheus-stack.yaml \
		--wait --timeout 10m
	kubectl apply -f monitoring/prometheus-rules-slo.yaml
	kubectl apply -f monitoring/webhook-logger.yaml
	kubectl -n monitoring rollout status deployment/webhook-logger

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
carga: ## Gera trafego sintetico contra a API (deixe rodando durante o make incidente)
	./scripts/gerar-carga.sh http://localhost:8080/api/pedidos $(CARGA_RPS) $(CARGA_DURACAO)

.PHONY: incidente
incidente: ## Injeta 30% de erro por 10 minutos para validar os alertas
	./scripts/incidente-simulado.sh 0.30 600

.PHONY: plantao
plantao: ## Acompanha as notificacoes que o Alertmanager enviou ao plantao
	kubectl -n monitoring logs -f deployment/webhook-logger

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
lint: ## Valida manifests, scripts, regras (sintaxe e testes) e config do Alertmanager
	kubectl apply --dry-run=client -f k8s/ -f monitoring/webhook-logger.yaml > /dev/null && echo "manifests ok"
	@for s in scripts/*.sh; do test -x "$$s" || { echo "$$s sem permissao de execucao"; exit 1; }; done; echo "scripts ok"
	python3 scripts/extrai_regras.py monitoring/prometheus-rules-slo.yaml /tmp/regras.yaml
	docker run --rm -v /tmp:/tmp --entrypoint promtool $(PROM_IMAGE) check rules /tmp/regras.yaml
	docker run --rm -v /tmp:/tmp -v $(CURDIR)/monitoring/tests:/tests:ro --entrypoint promtool $(PROM_IMAGE) \
		test rules /tests/slo-alertas_test.yaml
	python3 scripts/extrai_alertmanager.py monitoring/values-kube-prometheus-stack.yaml /tmp/alertmanager.yml
	docker run --rm -v /tmp:/tmp --entrypoint amtool $(AM_IMAGE) check-config /tmp/alertmanager.yml

.PHONY: down
down: ## Destroi o cluster
	kind delete cluster --name $(CLUSTER)
