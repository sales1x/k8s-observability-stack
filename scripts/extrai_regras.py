"""Extrai o campo spec de um PrometheusRule para validar com promtool.

O promtool nao entende o CRD do Prometheus Operator, apenas o formato nativo de
rule files. Este script faz a ponte e e usado tanto no Makefile quanto no CI.
"""

import sys

import yaml


def main() -> int:
    if len(sys.argv) != 3:
        print("uso: extrai_regras.py <arquivo-prometheusrule> <arquivo-saida>")
        return 2

    origem, destino = sys.argv[1], sys.argv[2]
    with open(origem, encoding="utf-8") as arquivo:
        documento = yaml.safe_load(arquivo)

    if documento.get("kind") != "PrometheusRule":
        print(f"{origem} nao e um PrometheusRule")
        return 1

    with open(destino, "w", encoding="utf-8") as arquivo:
        yaml.safe_dump(documento["spec"], arquivo, sort_keys=False)

    grupos = documento["spec"].get("groups", [])
    regras = sum(len(g.get("rules", [])) for g in grupos)
    print(f"{len(grupos)} grupos e {regras} regras extraidos para {destino}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
