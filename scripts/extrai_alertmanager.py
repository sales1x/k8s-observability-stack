"""Extrai alertmanager.config do values do kube-prometheus-stack para validar com amtool.

Mesmo papel do extrai_regras.py: a configuracao vive dentro do values do Helm, mas o
amtool so entende o arquivo nativo do Alertmanager. Usado no Makefile e no CI.
"""

import sys

import yaml


def main() -> int:
    if len(sys.argv) != 3:
        print("uso: extrai_alertmanager.py <values.yaml> <arquivo-saida>")
        return 2

    origem, destino = sys.argv[1], sys.argv[2]
    with open(origem, encoding="utf-8") as arquivo:
        values = yaml.safe_load(arquivo)

    config = (values.get("alertmanager") or {}).get("config")
    if not config:
        print(f"{origem} nao tem alertmanager.config")
        return 1

    with open(destino, "w", encoding="utf-8") as arquivo:
        yaml.safe_dump(config, arquivo, sort_keys=False, allow_unicode=True)

    print(f"{len(config.get('receivers', []))} receivers e "
          f"{len(config.get('route', {}).get('routes', []))} rotas extraidos para {destino}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
