"""Audit and summarize the frozen, paired fresh-progression experiments."""
import collections
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "artifacts"
CAPTAINS = ("shen", "wen", "lu")


def key(r):
    return tuple(r[k] for k in ("captain", "profile", "strategy", "region", "seed"))


def load(phase):
    paths = [ART / f"fresh-runs-{phase}-{c}.json" for c in CAPTAINS]
    if phase == "campaign-refusal":
        paths = [ART / "fresh-runs-campaign-refusal.json"]
    docs = [json.loads(p.read_text()) for p in paths]
    for d in docs:
        assert not d["changed_sources"]
        assert d["source_hashes"] == docs[0]["source_hashes"]
        assert d["policy_hashes"] == docs[0]["policy_hashes"]
    rows = [r for d in docs for r in d["results"]]
    for r in rows:
        assert not r["errors"] and r["failure"] in ("", "defeat", "gameover")
        i = r["initial"]
        assert (i["silver"], i["supplies"], i["relics"], i["collection"]) == (40, 3, 0, 0)
        assert not i["achievements"] and len(i["equipment"]) == 8
        assert len(i["ranks"]) == 6
        assert all(u["xp"] == 0 and list(u["skills"].values()) == [1] for u in i["ranks"])
        assert all(t["xp_before"] - t["xp_after"] == t["cost"] and t["xp_after"] >= 0
                   for t in r["training"])
        assert all(p["silver_before"] - p["silver_after"] == p["net_cost"]
                   and p["net_cost"] == p["price"] - p["acquisition_bonus"]
                   and p["silver_after"] >= 0 for p in r["purchases"])
        denied = set(r["denied"])
        assert all(x["chosen"] not in denied for x in r["rewards"])
        assert all(x.get("id") not in denied for x in r["purchases"])
        assert all(not denied.intersection(s["relics"]) for s in r["stages"])
    return docs[0], rows


def stats(rows):
    bosses = [b for r in rows for b in r["before_boss"]]
    result = {"runs": len(rows), "clears": sum(r["cleared"] for r in rows),
              "initial_seed_blocks": len({r["seed"] for r in rows}),
              "boss_entries": len(bosses),
              "boss_two_piece": sum(b["build"]["count"] >= 2 for b in bosses),
              "boss_four_piece": sum(b["build"]["count"] >= 4 for b in bosses),
              "boss_mixed_two_two": sum(b["build"]["mixed_two_two"] for b in bosses)}
    for field in ("captain", "profile", "strategy"):
        result[field] = {v: {"runs": len(group), "clears": sum(r["cleared"] for r in group)}
                         for v in sorted({r[field] for r in rows})
                         if (group := [r for r in rows if r[field] == v])}
    result["failure_regions"] = dict(collections.Counter(
        r["battles"][-1]["region"] for r in rows if not r["cleared"] and r["battles"]))
    return result


def main():
    phases = ("baseline", "final", "campaign-baseline", "campaign-final", "holdout", "refusal", "campaign-refusal")
    loaded = {p: load(p) for p in phases}
    policy = loaded["baseline"][0]["policy_hashes"]
    assert all(d["policy_hashes"] == policy for d, _ in loaded.values())
    before, after = (loaded[p][0]["source_hashes"] for p in ("baseline", "final"))
    changed = sorted(k for k in before if before[k] != after[k])
    assert changed == ["campaign.gd", "relics.gd"], changed
    summary = {p: stats(rows) for p, (_, rows) in loaded.items()}
    for a, b in (("baseline", "final"), ("campaign-baseline", "campaign-final")):
        old = {key(r): r for r in loaded[a][1]}
        new = {key(r): r for r in loaded[b][1]}
        assert old.keys() == new.keys()
        summary[b]["paired_gains"] = sum(not old[k]["cleared"] and new[k]["cleared"] for k in old)
        summary[b]["paired_losses"] = sum(old[k]["cleared"] and not new[k]["cleared"] for k in old)
    for phase, base in (("refusal", "final"), ("campaign-refusal", "campaign-final")):
        originals = {key(r): r for r in loaded[base][1]}
        groups = collections.defaultdict(list)
        for r in loaded[phase][1]:
            original = originals[key(r)]
            if phase == "campaign-refusal":
                assert original["cleared"]
            denied = set(r["denied"])
            # A boss-entry snapshot precedes that boss's reward, avoiding post-clear evidence.
            assert any(denied.intersection(b["relics"]) for b in original["before_boss"])
            groups[",".join(r["denied"])].append(r)
        summary[phase]["groups"] = {g: stats(rows) for g, rows in groups.items()}
        summary[phase]["paired_baseline_clears"] = sum(originals[key(r)]["cleared"] for r in loaded[phase][1])
        summary[phase]["paired_gains"] = sum(not originals[key(r)]["cleared"] and r["cleared"] for r in loaded[phase][1])
        summary[phase]["paired_losses"] = sum(originals[key(r)]["cleared"] and not r["cleared"] for r in loaded[phase][1])
        summary[phase]["reward_exposure_cases"] = sum(
            any(set(r["denied"]).intersection(x["offered"]) for x in r["rewards"])
            for r in loaded[phase][1])
        summary[phase]["shop_exposure_cases"] = sum(
            any(set(r["denied"]).intersection(x.get("stock", [])) for x in r["shop_offers"])
            for r in loaded[phase][1])
    summary["audit"] = {"same_policy_hashes": policy, "changed_game_files": changed,
                        "all_initial_states_and_denied_acquisitions_checked": True,
                        "input_hashes": {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                                         for p in ART.glob("fresh*cases.json")}}
    out = ART / "fresh-progression-summary.json"
    out.write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(summary, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
