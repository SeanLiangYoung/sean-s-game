"""Audit frozen real-progression runs; never infer causality from held relic frequency."""
import collections
import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "artifacts"


def key(r):
    return r["captain"], r["profile"], r["strategy"], r["seed"]


def load(label):
    paths = [ART / f"longline-{label}-{c}.json" for c in ("shen", "wen", "lu")]
    if label in ("support", "supply", "training"):
        paths = [ART / f"longline-{label}.json"]
    if label in ("lu-broad-holdout", "lu-control-holdout"):
        paths = [ART / f"longline-{label}-lu.json"]
    docs = [json.loads(p.read_text()) for p in paths]
    for d in docs:
        assert not d["changed_sources"]
        assert d["source_hashes"] == docs[0]["source_hashes"]
        assert d["cases_sha256"] == docs[0]["cases_sha256"]
    rows = [r for d in docs for r in d["results"]]
    for r in rows:
        assert not r["errors"] and r["failure"] in ("", "defeat", "gameover")
        assert r["whole_campaign"]
        i = r["initial"]
        assert (i["silver"], i["supplies"], i["relics"], i["collection"]) == (40, 3, 0, 0)
        assert len(i["equipment"]) == 8 and len(i["ranks"]) == 6 and not i["achievements"]
        assert all(u["xp"] == 0 and list(u["skills"].values()) == [1] for u in i["ranks"])
        assert all(t["xp_before"] - t["xp_after"] == t["cost"] and t["xp_after"] >= 0
                   for t in r["training"])
        earned = collections.Counter()
        spent = collections.Counter()
        for b in r["battles"]:
            earned.update(b["earned_xp"])
        for t in r["training"]:
            spent[t["actor"]] += t["cost"]
        # A visited study event can pay every living roster member 20 XP, including
        # reserves. Legacy traces omit its subtype: audit a conservative upper bound.
        event_budget = 20 * sum(s["kind"] == "event" for s in r["stages"])
        assert all(spent[a] <= earned[a] + event_budget for a in spent), (label, key(r), spent, earned)
        assert all(p["silver_before"] - p["silver_after"] == p["net_cost"]
                   and p["net_cost"] == p["price"] - p["acquisition_bonus"]
                   and p["silver_after"] >= 0 for p in r["purchases"])
        assert all(not set(r["denied"]).intersection(s["relics"]) for s in r["stages"])
        assert r["final"]["supplies"] >= 0 and r["final"]["silver"] >= 0
        assert all(t["used"] == 1 and t["remaining"] >= 0 for t in r["supplies"])
        assert r["cleared"] == r["campaign_completed"]
        assert len(r["diagnostics"]) == len(r["battles"])
    return docs[0]["source_hashes"], rows


def stats(rows):
    success = [r for r in rows if r["cleared"]]
    losses = [r for r in rows if not r["cleared"]]
    result = {"runs": len(rows), "clears": len(success),
              "initial_seed_blocks": len({r["seed"] for r in rows}),
              "failures_with_supplies": sum(r["final"]["supplies"] > 0 for r in losses),
              "failure_regions": dict(collections.Counter(r["battles"][-1]["region"] for r in losses)),
              "battles": sum(len(r["battles"]) for r in rows)}
    for field in ("captain", "profile", "strategy"):
        result[field] = {}
        for value in sorted({r[field] for r in rows}):
            group = [r for r in rows if r[field] == value]
            result[field][value] = {"runs": len(group), "clears": sum(r["cleared"] for r in group)}
    result["captain_profile"] = {
        f"{c}/{p}": {"runs": len(group), "clears": sum(r["cleared"] for r in group)}
        for c in ("shen", "wen", "lu") for p in ("balanced", "guard", "support", "assault")
        if (group := [r for r in rows if r["captain"] == c and r["profile"] == p])}
    bosses = [b for r in rows for b in r["before_boss"]]
    result["boss_entries"] = len(bosses)
    result["boss_two_piece"] = sum(b["build"]["count"] >= 2 for b in bosses)
    result["boss_mixed_two_two"] = sum(b["build"]["mixed_two_two"] for b in bosses)
    result["boss_theme_counts"] = dict(collections.Counter(b["build"]["family"] for b in bosses))
    first_deaths = []
    for r in rows:
        for b in r["diagnostics"]:
            dead = [u for u in b["final"] if u["side"] == 0 and u["hp"] <= 0]
            if dead:
                first_deaths.append({"dead": dead, "battle": b})
                break
    result["runs_with_casualty"] = len(first_deaths)
    result["first_casualty_with_supplies"] = sum(d["battle"]["final_supplies"] > 0 for d in first_deaths)
    result["first_casualty_actors"] = sum(len(d["dead"]) for d in first_deaths)
    result["first_casualty_high_mana_actors"] = sum(u["mp"] * 10 >= u["max_mp"] * 9
                                                    for d in first_deaths for u in d["dead"])
    # Presence is descriptive: frequency is not a causal estimate of item strength.
    acquired = []
    for r in success:
        ids = set()
        for b in r["before_boss"]:
            ids.update(b["relics"])
        acquired.append(ids)
    result["successful_preboss_relic_intersection"] = sorted(set.intersection(*acquired)) if acquired else []
    return result


def paired(old, new):
    a, b = ({key(r): r for r in rows} for rows in (old, new))
    assert a.keys() == b.keys()
    return {"gains": sum(not a[k]["cleared"] and b[k]["cleared"] for k in a),
            "losses": sum(a[k]["cleared"] and not b[k]["cleared"] for k in a)}


def main():
    labels = ("diagnostic", "support", "supply", "training", "new-baseline", "new-final", "holdout-final", "refusal")
    data = {label: load(label) for label in labels}
    out = {label: stats(rows) for label, (_, rows) in data.items()}
    for previous, current in (("diagnostic", "support"), ("support", "supply"),
                              ("supply", "training"), ("new-baseline", "new-final")):
        out[current]["paired"] = paired(data[previous][1], data[current][1])
    original = {key(r): r for r in data["new-final"][1]}
    denied = data["refusal"][1]
    out["refusal"]["paired"] = paired([original[key(r)] for r in denied], denied)
    out["refusal"]["paired_original_clears"] = sum(original[key(r)]["cleared"] for r in denied)
    out["refusal"]["original_real_acquisition_cases"] = sum(
        any(set(r["denied"]).intersection(b["relics"]) for b in original[key(r)]["before_boss"])
        for r in denied)
    exposed = [r for r in denied if any(set(r["denied"]).intersection(b["relics"])
                                       for b in original[key(r)]["before_boss"])]
    out["refusal"]["original_acquisition_subset"] = stats(exposed)
    out["refusal"]["original_acquisition_subset"]["paired_original_clears"] = sum(original[key(r)]["cleared"] for r in exposed)
    base, final = (data[label][0] for label in ("new-baseline", "new-final"))
    changes = sorted(k for k in base if base[k] != final[k])
    assert changes == ["game/rules.gd", "tools/relic_mix_simulation.gd"], changes
    assert not {r["seed"] for r in data["new-final"][1]}.intersection(
        r["seed"] for r in data["holdout-final"][1])
    plan = json.loads((ART / "longline-plan.json").read_text())
    for name, expected in plan["cases_hashes"].items():
        assert hashlib.sha256((ART / name).read_bytes()).hexdigest() == expected
    out["audit"] = {"changed_sources": changes, "new_seed_blocks": out["new-final"]["initial_seed_blocks"],
                    "holdout_disjoint": True, "initial_states_costs_earned_XP_denied_items_checked": True,
                    "frozen_case_hashes_checked": True,
                    "note": "production support AI plus legal policy corrections; not a stat-only balance experiment"}
    (ART / "longline-v2-summary.json").write_text(json.dumps(out, ensure_ascii=False, indent=2) + "\n")
    for label in labels:
        s = out[label]
        print(label, s["clears"], "/", s["runs"], "Lu support", s["captain_profile"].get("lu/support"), s.get("paired"))


def prospective():
    labels = ("prospective-baseline", "prospective-final", "prospective-refusal",
              "prospective-alternative", "prospective-holdout", "targeted",
              "lu-broad-holdout", "lu-control-holdout")
    data = {label: load(label) for label in labels}
    summary = {label: stats(rows) for label, (_, rows) in data.items()}
    summary["prospective-final"]["paired"] = paired(data["prospective-baseline"][1], data["prospective-final"][1])
    main_rows = {key(r): r for r in data["prospective-final"][1]}
    for label in ("prospective-refusal", "prospective-alternative"):
        rows = data[label][1]
        summary[label]["paired"] = paired([main_rows[key(r)] for r in rows], rows)
        summary[label]["paired_original_clears"] = sum(main_rows[key(r)]["cleared"] for r in rows)
    denied = data["prospective-refusal"][1]
    exposed = [r for r in denied if any(set(r["denied"]).intersection(b["relics"])
                                       for b in main_rows[key(r)]["before_boss"])]
    summary["prospective-refusal"]["original_acquisition_subset"] = stats(exposed)
    summary["prospective-refusal"]["original_acquisition_subset"]["paired_original_clears"] = sum(main_rows[key(r)]["cleared"] for r in exposed)
    base, final = (data[label][0] for label in ("prospective-baseline", "prospective-final"))
    changes = sorted(k for k in base if base[k] != final[k])
    assert changes == ["game/rules.gd", "tools/relic_mix_simulation.gd"], changes
    assert not {r["seed"] for r in data["prospective-final"][1]}.intersection(r["seed"] for r in data["prospective-holdout"][1])
    for label in ("prospective-refusal", "prospective-alternative", "prospective-holdout", "targeted",
                  "lu-broad-holdout", "lu-control-holdout"):
        assert data[label][0] == final
    plan = json.loads((ART / "longline-prospective-plan.json").read_text())
    for name, expected in plan["case_hashes"].items():
        assert hashlib.sha256((ART / name).read_bytes()).hexdigest() == expected
    extra_plan = json.loads((ART / "longline-lu-holdout-plan.json").read_text())
    for name, expected in extra_plan["case_hashes"].items():
        assert hashlib.sha256((ART / name).read_bytes()).hexdigest() == expected
    observed = {r["seed"] for label in ("prospective-final", "prospective-holdout") for r in data[label][1]}
    assert not observed.intersection(r["seed"] for r in data["lu-broad-holdout"][1])
    summary["lu-control-holdout"]["paired"] = paired(data["lu-broad-holdout"][1], data["lu-control-holdout"][1])
    summary["audit"] = {"changed_sources": changes, "frozen_case_hashes_checked": True,
                        "initial_states_costs_earned_XP_denied_items_checked": True,
                        "main_seed_blocks": summary["prospective-final"]["initial_seed_blocks"],
                        "holdout_seed_blocks": summary["prospective-holdout"]["initial_seed_blocks"],
                        "additional_Lu_seed_blocks": summary["lu-broad-holdout"]["initial_seed_blocks"],
                        "holdout_disjoint": True, "revision": "v3 captain exposure; v2 retained as diagnostic iteration"}
    (ART / "longline-prospective-summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n")
    previous = json.loads((ART / "longline-v2-summary.json").read_text())
    (ART / "longline-summary.json").write_text(json.dumps({"previous_iterations": previous, "final": summary}, ensure_ascii=False, indent=2) + "\n")
    for label in labels:
        s = summary[label]
        print(label, s["clears"], "/", s["runs"], "Lu support", s["captain_profile"].get("lu/support"), s.get("paired"))


if __name__ == "__main__":
    prospective() if "--prospective" in sys.argv else main()
