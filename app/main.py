import os
import random
import time

from fastapi import FastAPI, HTTPException, Request, Response
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Gauge, Histogram, generate_latest

APP_VERSION = os.getenv("APP_VERSION", "0.1.0")
FAILURE_RATE = float(os.getenv("FAILURE_RATE", "0.02"))
LATENCY_BASE_MS = float(os.getenv("LATENCY_BASE_MS", "30"))

app = FastAPI(title="demo-api", version=APP_VERSION)

REQUESTS = Counter(
    "http_requests_total",
    "Total de requisicoes HTTP recebidas",
    ["method", "path", "status"],
)
LATENCY = Histogram(
    "http_request_duration_seconds",
    "Duracao das requisicoes HTTP em segundos",
    ["method", "path"],
    buckets=(0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0),
)
BUILD_INFO = Gauge("app_build_info", "Informacoes de build da aplicacao", ["version"])
BUILD_INFO.labels(version=APP_VERSION).set(1)

READY = {"status": True}


def normaliza_rota(request: Request) -> str:
    """Usa o template da rota para nao explodir a cardinalidade das metricas."""
    route = request.scope.get("route")
    if route and getattr(route, "path", None):
        return route.path
    return "unmatched"


@app.middleware("http")
async def metricas_middleware(request: Request, call_next):
    inicio = time.perf_counter()
    status = 500
    try:
        response = await call_next(request)
        status = response.status_code
        return response
    finally:
        duracao = time.perf_counter() - inicio
        path = normaliza_rota(request)
        if path != "/metrics":
            LATENCY.labels(request.method, path).observe(duracao)
            REQUESTS.labels(request.method, path, str(status)).inc()


@app.get("/")
def raiz():
    return {"servico": "demo-api", "versao": APP_VERSION}


@app.get("/healthz")
def healthz():
    """Liveness: responde enquanto o processo estiver vivo."""
    return {"status": "ok"}


@app.get("/readyz")
def readyz():
    """Readiness: pode ser derrubada manualmente para testar rollout e alertas."""
    if not READY["status"]:
        raise HTTPException(status_code=503, detail="fora de rotacao")
    return {"status": "ready"}


@app.post("/admin/readiness/{estado}")
def alterna_readiness(estado: str):
    READY["status"] = estado == "on"
    return {"ready": READY["status"]}


@app.get("/api/pedidos")
def listar_pedidos():
    """Endpoint principal usado como base do SLO de disponibilidade e latencia."""
    time.sleep(random.expovariate(1 / (LATENCY_BASE_MS / 1000)))
    if random.random() < FAILURE_RATE:
        raise HTTPException(status_code=500, detail="falha simulada no backend")
    return {"pedidos": [{"id": 1, "total": 99.9}, {"id": 2, "total": 149.5}]}


@app.get("/api/pedidos/lento")
def pedido_lento():
    """Usado nos testes de carga para provocar queima de error budget de latencia."""
    time.sleep(random.uniform(0.8, 2.0))
    return {"status": "processado com atraso"}


@app.get("/metrics")
def metrics():
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)
