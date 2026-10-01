#!/usr/bin/env python3
"""Verifica spec/fixtures/apitcg-subset.json contra SRC-29 (offline, sem Docker nem Ruby).

Uso: python3 spec/verify_fixture.py

A fixture é um recorte do snapshot real da apitcg (T10), no mesmo formato do
snapshot: {"fetched_at", "sets": [...], "cards": [...]}. Cada check é nomeado
e imprime OK/FAIL; qualquer FAIL sai com código 1.
"""
import json
import pathlib
import re
import sys

FIXTURE = pathlib.Path(__file__).parent / "fixtures" / "apitcg-subset.json"
TRIGGER_SEPARATOR = "\r\n<br>\r\n[Trigger]"


def attrs(card):
    return card.get("attributes") or {}


def suffixes(card):
    return re.findall(r"\(([^)]*)\)", card.get("name", ""))


def set_prefix(set_code):
    return re.sub(r"[\s-]+", "", set_code or "")


def card_prefix(card):
    return (attrs(card).get("Number") or card.get("code") or "").split("-")[0]


def is_reprint_set(set_doc, cards):
    """SRC-24/35: o prefixo do próprio set não é maioria estrita dos números distintos."""
    numbers = {attrs(c).get("Number") or c.get("code") for c in cards if c["set"]["_id"] == set_doc["_id"]}
    numbers.discard(None)
    own = {n for n in numbers if n.split("-")[0] == set_prefix(set_doc.get("code"))}
    return bool(set_doc.get("code")) and bool(numbers) and len(own) * 2 <= len(numbers)


def build_checks(cards, sets):
    don = [c for c in cards if attrs(c).get("CardType") == "DON!!"]
    leaders = [c for c in cards if attrs(c).get("CardType") == "Leader"]
    by_set = {}
    for c in cards:
        by_set.setdefault((c["set"]["_id"], c.get("code")), []).append(c)

    base_and_parallel = any(
        "(Parallel)" in c["name"]
        and any(o is not c and o.get("code") == c.get("code") and o["set"]["_id"] == c["set"]["_id"]
                and not suffixes(o) for o in cards)
        for c in cards if c.get("code")
    )
    own_numbers = {attrs(c).get("Number") for c in cards}

    return [
        ("sanidade: ids únicos", len({c["_id"] for c in cards}) == len(cards)),
        ("sanidade: todo set de carta está em sets",
         {c["set"]["_id"] for c in cards} <= {s["_id"] for s in sets}),
        ("sanidade: sem x-api-key nem APITCG", not re.search(r"x-api-key|APITCG", FIXTURE.read_text(), re.I)),
        ("SRC-29 (a) carta com impressão base e parallel", base_and_parallel),
        ("SRC-29 (b) sufixo Alternate Art", any("Alternate Art" in suffixes(c) for c in cards)),
        ("SRC-29 (c) sufixo Manga", any("Manga" in suffixes(c) for c in cards)),
        ("SRC-29 (d) sufixo Reprint", any("Reprint" in suffixes(c) for c in cards)),
        ("SRC-29 (e) sufixo numérico", any(re.fullmatch(r"\d+", s) for c in cards for s in suffixes(c))),
        ("SRC-29 (e) sufixo numérico igual a um card_number", any(
            re.fullmatch(r"\d+", s) and any(n and n.endswith("-" + s) for n in own_numbers)
            for c in cards for s in suffixes(c))),
        ("SRC-29 (f) [Trigger] na Description com o separador real",
         any(TRIGGER_SEPARATOR in attrs(c).get("Description", "") for c in cards)),
        ("SRC-29 (g) DON!!", bool(don)),
        ("SRC-29 (h) produto de carta sem code (fora o DON!!)",
         any(not c.get("code") and attrs(c).get("CardType") != "DON!!" for c in cards)),
        ("SRC-29 (i) set com code nulo", any(not s.get("code") for s in sets)),
        ("SRC-29 (j) set de reimpressão", any(is_reprint_set(s, cards) for s in sets)),
        ("counter: há carta sem Counterplus (nulo), com \"0\" e com valor positivo",
         any(attrs(c).get("Counterplus") in (None, "") for c in cards)
         and any(attrs(c).get("Counterplus") == "0" for c in cards)
         and any((attrs(c).get("Counterplus") or "0").isdigit() and int(attrs(c).get("Counterplus") or 0) > 0 for c in cards)),
        ("só líder tem Life", bool(leaders) and all(("Life" in attrs(c)) == (attrs(c).get("CardType") == "Leader")
                                                    for c in cards if attrs(c).get("CardType") != "DON!!")),
        ("líder sem custo", any(attrs(c).get("Cost") in (None, "") for c in leaders)),
        ("carta multicor", any(";" in (attrs(c).get("Color") or "") for c in cards)),
        ("carta com mais de um atributo", any(";" in (attrs(c).get("Attribute") or "") for c in cards)),
    ]


def main():
    try:
        data = json.loads(FIXTURE.read_text())
        cards, sets = data["cards"], data["sets"]
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(f"FAIL fixture ilegível ou sem as chaves 'sets' e 'cards': {error}")
        return 1

    print(f"fixture: {FIXTURE.name} ({len(cards)} cartas, {len(sets)} sets)")
    failed = []
    for name, ok in build_checks(cards, sets):
        print(f"{'OK  ' if ok else 'FAIL'} {name}")
        if not ok:
            failed.append(name)
    if failed:
        print(f"\n{len(failed)} verificação(ões) falharam")
        return 1
    print("\ntodas as verificações passaram")
    return 0


if __name__ == "__main__":
    sys.exit(main())
