#!/usr/bin/env python3
"""
screen_candidates.py — Filter pulled issue JSONs by keyword title-screen
into a per-project candidate CSV. Reduces 10,000+ raw issues to a few
hundred candidates worth body-reading.

Usage:
    python3 screen_candidates.py

Reads:  baseline_issues/<project>.json   (from gh issue list output)
Writes: baseline_candidates/<project>.csv (one row per candidate issue)
        baseline_candidates/_summary.csv  (one row per project)

The CSV schema is designed to be opened in your editor / a spreadsheet:
you eyeball the title, click the URL, body-read, then fill in the
'codebook_decision' column with one of:
    paper:bf | paper:bu | paper:mf | paper:fr | SKIPPED-S1..S7 | (blank)

After body-reading all candidates for one project, run
aggregate_baseline.py (see Step 5) to produce baseline_coding.csv.
"""
import csv
import json
import os
import re
import sys
from collections import Counter

# Title-screen keyword set. Case-insensitive. Hit any one and the issue
# becomes a candidate for body-reading. This is intentionally broad to
# minimise false-negatives; the body-read pass is where you apply the
# codebook's evidence bars.
KEYWORDS = [
    # Cost/budget direct
    "budget", "cost", "expensive", "dollar", "spend", "burn",
    "credit", "billing", "bill", "charge", "quota",
    # Token-related
    "token", "max_token", "max-token", "max_tokens", "context length",
    "context window", "context limit",
    # Loop / runaway / amplification
    "loop", "infinite", "runaway", "exceeded", "exhausted",
    "recursion", "recursive", "recursionerror", "recursion_limit",
    "max_iter", "max-iter", "iteration limit",
    # Retry / rate-limit (will need careful coding for S6 exclusion)
    "retry", "retries", "rate limit", "rate-limit", "429",
    # Reasoning model specific
    "reasoning_content", "thinking", "deepseek-r1", "o1-",
    # Cost-observability
    "usage_metadata", "cost track", "cost report", "cost attribution",
    "token usage", "token count",
]

KEYWORD_RE = re.compile("|".join(re.escape(k) for k in KEYWORDS), re.IGNORECASE)


def screen_project(project_safe_name: str, issues_path: str, out_csv: str):
    """Process one project's pulled JSON and write its candidate CSV."""
    with open(issues_path) as f:
        try:
            issues = json.load(f)
        except json.JSONDecodeError:
            print(f"  WARN: {issues_path} is not valid JSON; skipping")
            return None
    total = len(issues)
    candidates = []
    for issue in issues:
        title = issue.get("title", "") or ""
        body = (issue.get("body", "") or "")[:500]  # first 500 chars only
        # Title hit (primary signal)
        title_hit = bool(KEYWORD_RE.search(title))
        # Body hit (weaker; catches issues with bland titles)
        body_hit = bool(KEYWORD_RE.search(body))
        if title_hit or body_hit:
            candidates.append({
                "number": issue.get("number", ""),
                "title": title,
                "url": issue.get("url", ""),
                "state": issue.get("state", ""),
                "createdAt": (issue.get("createdAt") or "")[:10],
                "title_hit": title_hit,
                "body_hit": body_hit,
                "codebook_decision": "",  # YOU FILL THIS IN
                "cluster": "",            # YOU FILL THIS IN if retained
                "would_filter_have_caught": "",  # YOU FILL THIS IN if retained
                "notes": "",              # YOU FILL THIS IN
            })
    with open(out_csv, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=[
            "number", "title", "url", "state", "createdAt",
            "title_hit", "body_hit",
            "codebook_decision", "cluster", "would_filter_have_caught", "notes",
        ])
        w.writeheader()
        for c in candidates:
            w.writerow(c)
    return total, len(candidates)


def main():
    issues_dir = "baseline_issues"
    candidates_dir = "baseline_candidates"
    if not os.path.isdir(issues_dir):
        sys.exit(f"ERROR: {issues_dir}/ not found. Run gh issue list loop first.")
    os.makedirs(candidates_dir, exist_ok=True)

    summary_rows = []
    for fname in sorted(os.listdir(issues_dir)):
        if not fname.endswith(".json"):
            continue
        project_safe = fname[:-5]
        in_path = os.path.join(issues_dir, fname)
        out_path = os.path.join(candidates_dir, f"{project_safe}.csv")
        result = screen_project(project_safe, in_path, out_path)
        if result is None:
            continue
        total, n_candidates = result
        ratio = (100 * n_candidates / total) if total else 0
        print(f"  {project_safe:<55s}  {total:5d} issues  ->  "
              f"{n_candidates:4d} candidates  ({ratio:4.1f}%)")
        summary_rows.append({
            "project": project_safe.replace("_", "/", 1),
            "total_issues_pulled": total,
            "n_candidates": n_candidates,
            "screen_pct": f"{ratio:.1f}",
        })

    # Summary
    with open(os.path.join(candidates_dir, "_summary.csv"), "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(summary_rows[0].keys()))
        w.writeheader()
        for r in summary_rows:
            w.writerow(r)
    total_issues = sum(r["total_issues_pulled"] for r in summary_rows)
    total_candidates = sum(r["n_candidates"] for r in summary_rows)
    print(f"\n  Total: {total_issues} issues across "
          f"{len(summary_rows)} projects, "
          f"{total_candidates} candidates ({100*total_candidates/total_issues:.1f}%)")
    print(f"  Per-project candidate CSVs: {candidates_dir}/<project>.csv")
    print(f"  Summary:                    {candidates_dir}/_summary.csv")


if __name__ == "__main__":
    main()
