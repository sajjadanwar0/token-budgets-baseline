# Token Capabilities catalog: codebook v1.0

This codebook formalizes the inclusion, classification, and exclusion
rules used to construct the failure catalog reported in the Token
Capabilities paper. It is derived from the implicit rules used to
build the v19/v20 catalog of 29 retained rows, and is intended to
govern future expansion to 100+ rows in the journal extension.

Versioning: codebook v1.0 corresponds to paper v20 (the 29-row
version). Future versions are tagged with the paper version they
correspond to (e.g. v1.1 -> paper v21).

## 1. Scope

A row in the catalog corresponds to a single GitHub issue or pull
request that documents either (a) an unbounded-spend incident in a
production LLM agent framework, or (b) a feature request for a
budget-bounding mechanism, or (c) a maintainer statement that
characterizes such failures as inherent to the framework.

Out of scope: bugs that are budget-adjacent but mechanistically
distinct (e.g. streaming-correctness, tool-calling-correctness,
authentication, rate-limit-as-network-error without a documented
amplification of cost), and rate-limit issues that don't surface a
cost overrun.

## 2. Inclusion criteria

A row is **retained** if and only if it satisfies BOTH:

- **(A) At least one evidence bar is met.** The three evidence bars are:
  - **(A.1) Cost evidence.** A specific dollar amount, token count,
    API-call count, or time-bounded loss is documented in the issue
    body, comments, or activity log. Approximate numbers (e.g. "$235
    in 4 days") count; vague language (e.g. "a lot of money") does
    not.
  - **(A.2) Mechanism evidence.** A specific failure mechanism is
    described: a reproducible loop, a documented error trace, a
    code-path identification, or an explicit description of the
    amplification dynamic (e.g. "input grows by 60 tokens per step").
    A bare bug-report ("the agent loops forever") without mechanism
    detail does NOT clear this bar.
  - **(A.3) Maintainer-quote evidence.** The project maintainer (or
    a clearly-identified core contributor) issues a quotable
    response that classifies, explains, or contextualizes the
    failure. The quote must be at least one full sentence and
    available verbatim from the issue thread.

- **(B) None of the exclusion criteria apply.** The seven exclusion
  criteria are listed in Section 4.

## 3. Classification: the four-tag taxonomy

Every retained row receives exactly one tag from the following set:

| Tag | Name | Definition |
|---|---|---|
| `bf` | bug_fixed_by_framework | Issue closed with a real maintainer-authored patch in the framework's repository. The fix must be merged, not just proposed. |
| `bu` | bug_unfixed | Issue acknowledged by maintainers OR community as a real failure but not patched in the framework. Includes: stale-closed by bot, closed-as-not-planned, explicitly declined, user-found-workaround-only. |
| `mf` | maintainer_framing | Maintainer (or core contributor) responds by characterizing the failure as inherent, expected, by-design, or out-of-scope, regardless of issue-close status. The maintainer's framing is the primary evidence. |
| `fr` | feature_request | The issue is a request for a missing capability rather than a report of an incident. The request may anticipate the failure mode without having experienced it. |

**Tie-breaking rules.** When more than one tag could apply:
- Prefer `mf` over `bu` when a maintainer's classification statement
  is the most quotable evidence in the issue.
- Prefer `bu` over `mf` when the maintainer engagement is procedural
  (closing as stale) without a substantive classification statement.
- Prefer `bf` over `fr` when a feature request was filed and then
  fulfilled.
- A single issue can spawn multiple rows ONLY if the rows reflect
  genuinely distinct failure mechanisms documented in distinct
  comments. In practice this is rare; default is one row per issue.

## 4. Exclusion criteria (the SKIPPED taxonomy)

A candidate is **skipped** if any of the following apply. Skips must
be documented in the CSV `notes` column with the prefix
`SKIPPED for paper:` and the specific reason cited.

| Code | Name | Definition |
|---|---|---|
| `S1` | wrong-failure-class | The issue is mechanistically about something other than budget overrun, even if budget words appear in the title. Example: streaming-correctness bug (LLMI-002), authentication failure (AGPT-004 was rate-limit-auth-not-budget). |
| `S2` | duplicate-of-existing | The issue shares a root cause with an already-retained row, OR has the same closing commit. Example: AIDR-002 had the same root commit as AIDR-001. |
| `S3` | weak-evidence-stub | A bare bug report (typically one or two sentences) with no mechanism detail, no maintainer engagement, and no cost evidence. Example: CRAI-003. |
| `S4` | qa-not-incident | A question-and-answer thread where the reporter misunderstood mechanics; community correctly explained; not a failure incident. Example: LANG-003. |
| `S5` | user-found-existing-feature | The reporter resolved their issue same-day after another user pointed to an existing feature or workaround. Example: CRAI-005. |
| `S6` | rate-limit-not-budget | A pure rate-limit issue without a documented cost-amplification mechanism. (Rate-limit issues WITH amplification, like AIDR-003, are retained.) |
| `S7` | roadmap-doc-not-incident | A maintainer-authored roadmap, SWOT, or planning document that mentions cost overruns but does not document a specific incident. Example: AGPT-003. |

## 5. CSV schema (three-state)

The catalog file `budget-archaeology.csv` has the following columns
and uses a three-state convention in the `notes` column:

| Column | Type | Description |
|---|---|---|
| `issue_id` | string | Catalog identifier, e.g. `LANG-001`. Stable across paper versions. |
| `framework` | string | Framework name in lowercase, e.g. `langgraph`. |
| `date` | YYYY-MM | Issue filing date. |
| `short_url` | string | GitHub short-ref, e.g. `#6731`. |
| `title` | string | Verbatim issue title at filing time. |
| `prevented_at_compile_time` | bool | Whether the failure would have been prevented by Token Capabilities. Default true for all retained `bu` and `mf` rows; varies for `bf` and `fr`. |
| `user_dollar_loss` | string | Documented dollar loss, blank if not reported. |
| `notes` | string | Three-state convention as below. |

**Three-state notes convention.** The first token of the `notes`
column determines a row's status:

| Prefix | Meaning |
|---|---|
| `paper:<tag>;` | Retained for the paper. `<tag>` is one of `bf`, `bu`, `mf`, `fr`. Example: `paper:bf; fixed same day in commit f2e1e17`. |
| `SKIPPED for paper:` | Triaged out, exclusion code in subsequent prose. Example: `SKIPPED for paper. <S4 description>` |
| (empty or non-prefix prose) | Not yet triaged. Candidates pre-staged for future archaeology. |

This three-state schema is the audit trail. Reviewers can verify
every retained row's evidence and every skip's rationale; they can
also see the candidate pool from which retentions were drawn.

## 6. Failure-mechanism categories

Retained rows additionally receive one of the following
failure-mechanism tags. These tags emerged from the v19/v20 work and
should be treated as a starting taxonomy, not a closed set: new
categories may be added as the catalog grows, with prior rows
back-coded.

| Mechanism code | Description | Example row |
|---|---|---|
| `M-retry-loop` | Agent calls a tool, receives an error, retries without modifying input. Conversation history grows monotonically. | LANG-001, CCDE-001 |
| `M-delegation-fanout` | Parent agent spawns sub-agents that recurse or fan out without bounded delegation. | CRAI-001, CDXL-001 |
| `M-context-amplification` | Each step's input grows superlinearly with prior context (often via repo-map, RAG retrieval, or compaction artifacts). | AIDR-004, CCDE-001 |
| `M-reasoning-token-leak` | Reasoning models (DeepSeek-R1, OpenAI o-series) generate hidden thinking tokens not predictable by caller. | AIDR-006, LANG-004, LANG-005 |
| `M-cost-observability` | Framework's cost ledger silently fails to count tokens, leaving operators with $0.00 attribution for real spend. | LANG-006 |
| `M-rate-limit-amplification` | Rate-limit retry logic re-sends increasing context, amplifying cost beyond what a single call would consume. | AIDR-003 |
| `M-feature-gap` | No incident; request for an unimplemented capability. | AGPT-001, AGPT-002, NANO-001 |
| `M-other` | Documented mechanism that doesn't fit above. Adding rows here should trigger consideration of a new category. | (none currently) |

## 7. Search protocol

The protocol below codifies how the original 60-row archaeology was
done and how journal-extension search should proceed.

**Sources to canvass:**
1. GitHub issue trackers of LLM agent frameworks (primary).
2. GitHub PRs that close issues fitting the evidence bars (primary).
3. Reddit (r/LocalLLaMA, r/MachineLearning, r/rust, r/OpenAI) for
   incident reports referencing public issues (secondary).
4. Hacker News submissions referencing such issues (secondary).
5. Provider status pages and incident reports (tertiary, low yield).

**Keyword set:**
- "budget", "cost", "token limit", "recursion", "infinite loop"
- "max_tokens", "max_cost", "price", "spend", "burn"
- "$", "USD", "dollars", "credit"
- "stuck", "loop", "retry"

A match is triaged when ANY of the keywords appears in title or
issue body within proximity to budget-overrun semantics.

**Triage protocol per match:**
1. Open the URL. Read the issue body in full.
2. Read the comment thread in full.
3. Apply Section 2 inclusion criteria.
4. If inclusion: assign tag (Section 3), mechanism (Section 6), and
   write a `paper:<tag>;` notes-column entry quoting at least one
   verbatim sentence from the issue.
5. If exclusion: write a `SKIPPED for paper:` entry citing the
   relevant exclusion code (Section 4) and a one-sentence reason.

**Productivity expectations from the v19/v20 work:**
- Initial archaeology: ~60 candidates yielded ~29 retained rows
  (~48% retention rate).
- Subsequent thinner-territory work expected to retain 30-40%.
- Each batch should target a documented theme (a specific framework,
  a specific mechanism category, a specific time window) rather than
  random pick-from-CSV.

## 8. Coding workflow

For each batch of new candidates, the workflow is:

1. **You search.** Pick a theme. Apply Section 7 search protocol.
   Collect 5-15 candidate URLs in one sitting.
2. **You collect raw material.** For each candidate, paste: GitHub
   URL, issue title, the most cost-relevant 3-5 sentences of issue
   body, maintainer's response if any, closure status, any dollar
   number mentioned.
3. **Coding.** Apply Sections 2-6 to each candidate. Produce the
   CSV row in the schema of Section 5.
4. **Sanity check at row-count milestones.** At each multiple of 25
   retained rows, audit categorical distributions, framework
   coverage, mechanism coverage, and time-window coverage. Update
   the codebook (and bump version) if patterns require new
   categories.

## 9. Inter-rater reliability (planned for v21+)

Solo coding is documented as a methodology limitation in the v20
paper. The journal extension targets:

- A second coder recoding a stratified random sample of 20-30 rows
  against this codebook independently.
- Reporting Cohen's kappa per categorical field (tag, mechanism,
  inclusion-decision).
- Disagreement-resolution protocol: discuss, then re-code by
  consensus; document any codebook revisions that arise from
  disagreements.

This section is a placeholder for v21; the IRR work is not yet done.

## 10. Codebook revision policy

Codebook revisions happen at row-count milestones (25, 50, 75, 100)
and follow this protocol:

1. Identify any retained rows where the v1.0 rules feel ambiguous or
   produced a forced-fit decision.
2. Identify any new mechanism patterns that have emerged from at
   least 3 cases (the "n=3 minimum for a new category" rule).
3. Draft revised codebook section(s) with examples from the new
   data.
4. Bump version: v1.1 for minor (added mechanism category, new
   exclusion code), v2.0 for major (changed inclusion criteria,
   restructured tag taxonomy).
5. Back-code any rows whose v1.0 classification differs from the
   revised codebook; document changed rows in a changelog.

The codebook is a living document. The journal submission should
include the most recent stable version as a supplementary artifact.
