#!/usr/bin/env bash
# pull_baseline_issues.sh
#
# Pulls GitHub issues for all 20 baseline cohort projects via gh CLI.
# Output: one JSON file per project at baseline_issues/<safe_name>.json
#
# Idempotent: re-running skips projects already pulled. Safe to interrupt
# and resume.
#
# Usage:
#   cd ~/RustroverProjects/token-budgets-baseline
#   bash pull_baseline_issues.sh
#
# Cost: gh API calls only, no $ cost. Total elapsed time ~10-30 min
# (rate-limited politely with sleep between projects).

set -uo pipefail   # NOT -e: we want to continue past individual project failures

# ---- Config ----
PROJECTS_FILE="baseline_projects.txt"
OUTPUT_DIR="baseline_issues"
ISSUES_PER_PROJECT=500
SLEEP_BETWEEN=2     # seconds between gh calls (politeness)
MIN_FILE_KB=5       # warn if pulled file is suspiciously small

# ---- Pretty-print helpers ----
if [ -t 1 ]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
    BLUE='\033[0;34m'; NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; BLUE=''; NC=''
fi

# ---- Prerequisite checks ----
echo -e "${BLUE}=== Prerequisite checks ===${NC}"

if ! command -v gh >/dev/null 2>&1; then
    echo -e "${RED}ERROR: gh (GitHub CLI) not installed.${NC}"
    echo "Install via: https://cli.github.com/  (e.g., 'sudo apt install gh' on Ubuntu)"
    exit 1
fi
echo "  ✓ gh CLI installed: $(gh --version | head -1)"

if ! gh auth status >/dev/null 2>&1; then
    echo -e "${RED}ERROR: gh not authenticated.${NC}"
    echo "Run: gh auth login"
    exit 1
fi
echo "  ✓ gh authenticated: $(gh auth status 2>&1 | grep 'Logged in' | head -1 | sed 's/^[[:space:]]*//')"

if [ ! -f "$PROJECTS_FILE" ]; then
    echo -e "${RED}ERROR: $PROJECTS_FILE not found in current directory.${NC}"
    echo "Make sure you're in ~/RustroverProjects/token-budgets-baseline/"
    exit 1
fi

TOTAL_PROJECTS=$(grep -cv '^[[:space:]]*\(#\|$\)' "$PROJECTS_FILE")
echo "  ✓ $PROJECTS_FILE found: $TOTAL_PROJECTS projects to pull"

mkdir -p "$OUTPUT_DIR"
echo "  ✓ Output dir: $OUTPUT_DIR/"

# Check rate limit status
RATE_REMAINING=$(gh api rate_limit --jq '.resources.core.remaining' 2>/dev/null || echo "?")
RATE_LIMIT=$(gh api rate_limit --jq '.resources.core.limit' 2>/dev/null || echo "?")
echo "  ✓ gh API rate limit: ${RATE_REMAINING}/${RATE_LIMIT} remaining"
if [ "$RATE_REMAINING" != "?" ] && [ "$RATE_REMAINING" -lt 100 ]; then
    echo -e "${YELLOW}  WARN: low rate limit; may hit limit during run. Continue? (Ctrl-C to abort)${NC}"
    sleep 5
fi

# ---- Pull loop ----
echo ""
echo -e "${BLUE}=== Pulling issues (${ISSUES_PER_PROJECT} per project, ${SLEEP_BETWEEN}s between) ===${NC}"

CURRENT=0
SUCCEEDED=0
SKIPPED=0
FAILED=0
SMALL=0
FAILED_PROJECTS=()
SMALL_PROJECTS=()

while IFS= read -r repo || [ -n "$repo" ]; do
    # Skip blank lines and comments
    repo="$(echo "$repo" | sed 's/[[:space:]]*$//')"
    if [ -z "$repo" ] || [[ "$repo" =~ ^# ]]; then
        continue
    fi
    CURRENT=$((CURRENT + 1))

    # Convert "owner/repo" -> "owner_repo" for filename
    safe="${repo//\//_}"
    out="${OUTPUT_DIR}/${safe}.json"

    # Cached check
    if [ -f "$out" ] && [ -s "$out" ]; then
        size_kb=$(du -k "$out" | cut -f1)
        echo -e "  [${CURRENT}/${TOTAL_PROJECTS}] ${YELLOW}SKIP cached${NC}: $repo (${size_kb} KB)"
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    echo -n "  [${CURRENT}/${TOTAL_PROJECTS}] Pulling $repo ... "

    # Run gh issue list. Capture stderr separately for diagnostic.
    err_log=$(mktemp)
    if gh issue list --repo "$repo" --state all --limit "$ISSUES_PER_PROJECT" \
            --json number,title,body,state,createdAt,closedAt,url,labels \
            > "$out" 2> "$err_log"; then
        size_kb=$(du -k "$out" | cut -f1)
        issue_count=$(jq 'length' "$out" 2>/dev/null || echo "?")
        if [ "$size_kb" -lt "$MIN_FILE_KB" ]; then
            echo -e "${YELLOW}small${NC} (${size_kb} KB, ${issue_count} issues)"
            SMALL=$((SMALL + 1))
            SMALL_PROJECTS+=("$repo (${issue_count} issues, ${size_kb} KB)")
        else
            echo -e "${GREEN}OK${NC} (${size_kb} KB, ${issue_count} issues)"
        fi
        SUCCEEDED=$((SUCCEEDED + 1))
    else
        err_msg=$(head -3 "$err_log" | tr '\n' ' ')
        echo -e "${RED}FAILED${NC}: ${err_msg}"
        FAILED=$((FAILED + 1))
        FAILED_PROJECTS+=("$repo: ${err_msg}")
        rm -f "$out"   # don't leave empty/partial file behind
    fi
    rm -f "$err_log"

    sleep "$SLEEP_BETWEEN"
done < "$PROJECTS_FILE"

# ---- Summary ----
echo ""
echo -e "${BLUE}=== Summary ===${NC}"
echo "  Total projects:    $TOTAL_PROJECTS"
echo -e "  ${GREEN}Succeeded${NC}:         $SUCCEEDED"
echo -e "  ${YELLOW}Skipped (cached)${NC}:  $SKIPPED"
echo -e "  ${YELLOW}Small files (<${MIN_FILE_KB} KB)${NC}: $SMALL"
echo -e "  ${RED}Failed${NC}:            $FAILED"
echo ""

if [ "$FAILED" -gt 0 ]; then
    echo -e "${RED}Failed projects:${NC}"
    for f in "${FAILED_PROJECTS[@]}"; do
        echo "  - $f"
    done
    echo ""
    echo "Common causes: archived repo, issues disabled, 404, rate limit."
    echo "Replace these in baseline_projects.txt with candidates from"
    echo "baseline_exclusion_log.md (e.g., AIGNE-io/aigne-framework,"
    echo "microsoft/project-oagents, ldclabs/anda), then re-run this script."
    echo ""
fi

if [ "$SMALL" -gt 0 ]; then
    echo -e "${YELLOW}Small-file projects (may have insufficient issues for coding):${NC}"
    for s in "${SMALL_PROJECTS[@]}"; do
        echo "  - $s"
    done
    echo ""
    echo "Projects with <50 issues are usually too thin for coding."
    echo "Consider replacing them with candidates from baseline_exclusion_log.md."
    echo ""
fi

# Total disk used
total_size=$(du -sh "$OUTPUT_DIR" 2>/dev/null | cut -f1)
total_issues=$(find "$OUTPUT_DIR" -name "*.json" -exec jq 'length' {} \; 2>/dev/null | awk '{s+=$1} END {print s}')
file_count=$(find "$OUTPUT_DIR" -name "*.json" | wc -l)
echo "Output: $file_count JSON files, $total_issues total issues, ${total_size} total"
echo ""

if [ "$SUCCEEDED" -ge 18 ] && [ "$FAILED" -le 2 ]; then
    echo -e "${GREEN}Ready for Step 3 — run the title-screen:${NC}"
    echo "  python3 screen_candidates.py"
elif [ "$FAILED" -gt 2 ]; then
    echo -e "${YELLOW}Replace the failed projects in baseline_projects.txt and re-run this script.${NC}"
else
    echo -e "${YELLOW}Pull incomplete; investigate failures before running screen_candidates.py.${NC}"
fi
