#!/usr/bin/env bash
# cleanup-custodian.sh
# Deletes all custodian-* Lambda functions and their associated EventBridge
# rules + targets in a given region. Run ONCE before terraform apply when
# migrating from an old policy set to a new one.
# After cleanup, re-deploys the c7n-mailer Lambda from the rendered config.
#
# Usage:
#   chmod +x scripts/cleanup-custodian.sh
#   ./scripts/cleanup-custodian.sh                        # default: us-east-1
#   ./scripts/cleanup-custodian.sh --region eu-west-1
#   ./scripts/cleanup-custodian.sh --region us-east-1 --dry-run
#
# Requirements: aws CLI, python3, c7n-mailer

set -euo pipefail

REGION="us-east-1"
DRY_RUN=false
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAILER_CONFIG="$SCRIPT_DIR/../modules/lambda/rendered_mailer.yml"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --region)   REGION="$2";   shift 2 ;;
    --dry-run)  DRY_RUN=true;  shift   ;;
    *)          echo "Unknown arg: $1"; exit 1 ;;
  esac
done

echo "==> Region   : $REGION"
echo "==> Dry-run  : $DRY_RUN"
echo ""

PY='import json,sys; [print(x) for x in json.load(sys.stdin)]'
PY_IDS='import json,sys; [print(x["Id"]) for x in json.load(sys.stdin)["Targets"]]'

# ── 1. Collect all custodian-* Lambda names ───────────────────────────────────
LAMBDAS=$(aws lambda list-functions \
  --region "$REGION" \
  --query 'Functions[?starts_with(FunctionName, `custodian-`)].FunctionName' \
  --output json | python3 -c "$PY")

LAMBDA_COUNT=$(echo "$LAMBDAS" | grep -c . || true)
echo "==> Found $LAMBDA_COUNT Lambda(s) with prefix 'custodian-'"

# ── 2. Collect all custodian-* EventBridge rules ──────────────────────────────
RULES=$(aws events list-rules \
  --region "$REGION" \
  --query 'Rules[?starts_with(Name, `custodian-`)].Name' \
  --output json | python3 -c "$PY")

RULE_COUNT=$(echo "$RULES" | grep -c . || true)
echo "==> Found $RULE_COUNT EventBridge rule(s) with prefix 'custodian-'"
echo ""

if [[ "$DRY_RUN" == "true" ]]; then
  echo "--- DRY RUN: would delete Lambdas ---"
  echo "$LAMBDAS"
  echo ""
  echo "--- DRY RUN: would delete EventBridge rules ---"
  echo "$RULES"
  echo ""
  echo "==> Dry-run complete. No resources deleted."
  exit 0
fi

# ── 3. Delete EventBridge targets + rules first ───────────────────────────────
echo "==> Deleting EventBridge rules..."
while IFS= read -r rule; do
  [[ -z "$rule" ]] && continue
  echo "    Removing targets from rule: $rule"
  TARGET_IDS=$(aws events list-targets-by-rule \
    --rule "$rule" \
    --region "$REGION" \
    --output json | python3 -c "$PY_IDS" | tr '\n' ' ' || true)
  if [[ -n "$TARGET_IDS" ]]; then
    aws events remove-targets \
      --rule "$rule" \
      --region "$REGION" \
      --ids $TARGET_IDS
  fi
  echo "    Deleting rule: $rule"
  aws events delete-rule \
    --name "$rule" \
    --region "$REGION"
done <<< "$RULES"

echo ""

# ── 4. Delete Lambda functions ────────────────────────────────────────────────
echo "==> Deleting Lambda functions..."
while IFS= read -r fn; do
  [[ -z "$fn" ]] && continue
  echo "    Deleting Lambda: $fn"
  aws lambda delete-function \
    --function-name "$fn" \
    --region "$REGION"
done <<< "$LAMBDAS"

echo ""
echo "==> Done. Deleted $RULE_COUNT rule(s) and $LAMBDA_COUNT Lambda(s)."

# ── 5. Re-deploy c7n-mailer Lambda ───────────────────────────────────────────
echo ""
echo "==> Deploying c7n-mailer Lambda..."
if [[ ! -f "$MAILER_CONFIG" ]]; then
  echo "    [WARN] rendered_mailer.yml not found at: $MAILER_CONFIG"
  echo "    Run 'terraform apply' first to render the mailer config, then re-run this script."
  exit 1
fi
c7n-mailer \
  --config "$MAILER_CONFIG" \
  --update-lambda
echo "==> c7n-mailer deployed."
