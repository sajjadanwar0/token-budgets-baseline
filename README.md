# token-budgets-baseline

Fair-baseline candidate corpus for the *Token Budgets* paper.

## What this is

A separately-coded corpus of LLM agent failure incidents constructed under a deliberately *more permissive* triage rule than the main catalog. The goal is to provide an independent reviewer with a way to assess whether the main catalog's inclusion criteria (`codebook_v1.md` in `token-budgets-formals`) systematically under- or over-represent any framework, mechanism, or time window.

The main catalog (109 retained cases) was constructed by applying the codebook's evidence bars strictly. The fair-baseline corpus relaxes the evidence requirement: any GitHub issue or comment thread referencing "cost," "budget," "token," "loop," "retry," or related terms qualifies, regardless of whether the issue meets the inclusion criteria.

## Why this exists

A reviewer asking *"is your retention rate biased?"* can compare the main catalog's 109 retained rows against this corpus's larger candidate pool and verify that:

1. The exclusion criteria are applied consistently (not strategically against any one framework).
2. The retained subset's mechanism distribution matches the broader pool.
3. The temporal distribution of retentions tracks the temporal distribution of candidates.

The paper's §5.7 fair-baseline analysis uses this corpus.

## Contents

| File                          | Description                                                      |
|-------------------------------|------------------------------------------------------------------|
| `fair_baseline_candidates.csv`| Permissively-triaged candidate corpus (broader than main catalog)|
| `fair_baseline_results.csv`   | Per-framework retention rate against the main catalog            |
| `methodology.md`              | Inclusion / exclusion methodology for this corpus                |

## Reproduction

```bash
# Compare retention rates between this corpus and the main catalog
python3 - <<'PY'
import csv

# Load candidate corpus
with open("fair_baseline_candidates.csv") as f:
    candidates = list(csv.DictReader(f))

# Load main catalog's retained rows (clone token-budgets-formals first)
with open("../token-budgets-formals/irr/coding_sheet.csv") as f:
    retained = list(csv.DictReader(f))

cand_fw = {}
ret_fw  = {}
for r in candidates:
    cand_fw[r["framework"]] = cand_fw.get(r["framework"], 0) + 1
for r in retained:
    ret_fw[r["framework"]] = ret_fw.get(r["framework"], 0) + 1

for fw in sorted(set(cand_fw) | set(ret_fw)):
    c = cand_fw.get(fw, 0)
    r = ret_fw.get(fw, 0)
    rate = (100*r/c) if c else 0
    print(f"  {fw:20s}  retained: {r:3d}  candidate: {c:3d}  rate: {rate:5.1f}%")
PY
```

The retention rate should be roughly uniform across frameworks within the 30–50% band expected from the codebook's evidence-bar strictness.

## Companion repositories

- [token-budgets](https://github.com/sajjadanwar0/token-budgets) — main library
- [token-budgets-formals](https://github.com/sajjadanwar0/token-budgets-formals) — main catalog (109-row retained) lives in `irr/coding_sheet.csv`
- [token-budgets-experiments](https://github.com/sajjadanwar0/token-budgets-experiments) — fair-baseline analysis in `fair-baseline/`
