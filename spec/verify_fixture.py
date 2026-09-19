#!/usr/bin/env python3
"""Verifica, sobre a fixture local e sem rede, os fatos que sustentam o ADR 001
e o glossário corrigido em product.md §6.

Uso: python3 spec/verify_fixture.py
"""
import json
import pathlib
import sys

FIXTURE = pathlib.Path(__file__).parent / "fixtures" / "optcgjson-subset.json"

EXPECTED_RARITIES = {"C", "UC", "R", "SR", "SEC", "L", "P", "SP CARD", "TR"}
EXPECTED_CLASSES = {"LEADER", "CHARACTER", "EVENT", "STAGE"}
EXPECTED_COLORS = {"Red", "Green", "Blue", "Purple", "Black", "Yellow"}


def load_cards():
    payload = json.loads(FIXTURE.read_text())
    sets = payload["data"]
    return [(s["code"], c) for s in sets for c in s["cards"]]


def main():
    pairs = load_cards()
    cards = [c for _, c in pairs]
    failures = []

    def check(label, condition, detail=""):
        status = "ok  " if condition else "FALHA"
        print(f"  [{status}] {label}{(' — ' + detail) if detail else ''}")
        if not condition:
            failures.append(label)

    print(f"fixture: {FIXTURE.name} ({len(cards)} variantes)\n")

    print("Card != CardVariant (o critério de escolha da fonte):")
    numbers = {c["number"] for c in cards}
    ids = {c["id"] for c in cards}
    check("a fonte distingue impressões", len(ids) > len(numbers),
          f"{len(numbers)} cartas -> {len(ids)} variantes")
    check("variant_code vem pronto e é estável",
          any(c["id"] != c["number"] for c in cards),
          "ex.: OP01-001 / OP01-001_p1")

    print("\nVocabulário real (task 0.2):")
    check("raridades dentro da lista confirmada",
          {c["rarity"] for c in cards if c["rarity"]} <= EXPECTED_RARITIES)
    check("tipos de carta dentro da lista confirmada",
          {c["cardClass"] for c in cards if c["cardClass"]} <= EXPECTED_CLASSES)
    check("cores dentro das seis confirmadas",
          {x for c in cards for x in (c.get("color") or [])} <= EXPECTED_COLORS)

    print("\nInvariantes de modelagem:")
    check("counter NULL != 0 (nunca 0 como sentinela)",
          any(c.get("counter") is None for c in cards)
          and all(c.get("counter") != "0" for c in cards))
    check("Leader nunca tem cost",
          all(c.get("cost") is None for c in cards if c["cardClass"] == "LEADER"))
    check("life é exclusivo de Leader",
          not any(c.get("life") for c in cards if c["cardClass"] != "LEADER"))
    check("attribute pode ter mais de um valor",
          any(len(c.get("attribute") or []) > 1 for c in cards))
    check("existe carta multicolorida (filtro de cor deve incluí-la)",
          any(len(c.get("color") or []) > 1 for c in cards))

    print("\nCasos-limite que a ingestão precisa tolerar:")
    imu = [c for c in cards if "?" in (c.get("attribute") or [])]
    check("attribute '?' é valor real, não lixo -> rarity/attributes como texto",
          bool(imu), f"{len(imu)} ocorrência(s): OP13-079 (Imu)")
    sets_por_id = {}
    for code, c in pairs:
        sets_por_id.setdefault(c["id"], set()).add(code)
    multi = {k: v for k, v in sets_por_id.items() if len(v) > 1}
    check("a mesma variante aparece em mais de um set -> variante↔set não é 1:1",
          bool(multi), ", ".join(f"{k} em {sorted(v)}" for k, v in multi.items()))

    print()
    if failures:
        print(f"FALHOU: {len(failures)} verificação(ões) — {'; '.join(failures)}")
        return 1
    print("Todas as verificações passaram.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
