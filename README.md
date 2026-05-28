# token-budgets-baseline

Independent baseline cohort for the *Token Budgets* paper (preprint, 2026).

> **Repository note.** This cohort is the paper's §2.3 external-validity check.
> The `reproduce.sh` artifact bundle ships **five** components
> (`token-budgets`, `-formals`, `-experiments`, `-python`, `-extensions`); this
> baseline cohort is an **additional** standalone repository referenced from
> §2.3 and is not required by `reproduce.sh`. If you prefer a single artifact,
> fold this directory in as a sixth component (see the repo-strategy note in the
> main repository).

## What this is

A separately-coded cohort of LLM-agent failure incidents constructed under a
**keyword-neutral** selection rule (top-starred "LLM agent" projects), to test
whether the main catalogue's failure-keyword sampling frame distorts the
mechanism taxonomy. This is the §2.3 baseline-replication cohort, **not** a
prevalence estimate.

## Headline finding (paper §2.3)

- 20 GitHub projects ranked by stars under the keyword-neutral "LLM agent" term;
  3,461 issues pulled, 186 body-read under the same codebook.
- Qualifying budget-overrun rows surfaced in **12 of 20 projects (60% coverage,
  95% Wilson CI [40%, 77%])**.
- The four primary mechanism clusters recur, plus one new cluster
  (M-rate-limit-amplification in VoltAgent #1276).
- The original budget-keyword filter would have caught 61/63 qualifying rows
  (97% within-screen catch rate).

**Limitations (exploratory):** all 186 codings are single-coder (no IRR for this
cohort, in contrast to the main catalogue's κ = 0.837 on N = 113); ~25 of 63
rows have full-thread evidence, the balance title-plus-first-comment. 60% is a
project-level coverage statistic, not an incidence rate.

## Contents

| File                           | Description                                          |
|--------------------------------|------------------------------------------------------|
| `fair_baseline_candidates.csv` | Keyword-neutral candidate cohort                     |
| `fair_baseline_results.csv`    | Per-project coverage against the main catalogue      |
| `methodology.md`               | Inclusion / exclusion methodology and exclusions log |

## Reproduction

```bash
# Per-project coverage. The main catalogue (110 retained rows) lives in
# token-budgets-formals/irr/ ; adjust the path to your checkout.
python3 - <<'PY'
import csv
with open("fair_baseline_candidates.csv") as f:
    cand = list(csv.DictReader(f))
fw = {}
for r in cand:
    fw[r["framework"]] = fw.get(r["framework"], 0) + 1
for k in sorted(fw):
    print(f"  {k:24s} candidates: {fw[k]:3d}")
PY
```

## Companion components

- [token-budgets](https://github.com/sajjadanwar0/token-budgets) — main library + 110-row catalogue
- token-budgets-formals — mechanised cross-checks + IRR (κ = 0.837, N = 113)
- token-budgets-experiments — multi-runtime evaluation + fair-baseline analysis (§2.3)

## License

Dual MIT/Apache-2.0.