#!/usr/bin/env bash
set -euo pipefail

REPO="davyuonggd/uwhichcard-catalog"
OWNER_ID=11054157

if ! command -v gh >/dev/null; then echo "Install GitHub CLI: brew install gh" >&2; exit 1; fi
if ! gh auth status >/dev/null 2>&1; then
  if [[ -n "${GH_TOKEN:-}" || -n "${GITHUB_TOKEN:-}" ]]; then
    export GH_TOKEN="${GH_TOKEN:-${GITHUB_TOKEN}}"
  else
    echo "Run: gh auth login (or set GH_TOKEN / GITHUB_TOKEN)" >&2
    exit 1
  fi
fi

existing_ruleset_id="$(gh api "repos/${REPO}/rulesets" --jq '.[] | select(.name == "Protect main and develop") | .id' 2>/dev/null || true)"

payload="$(cat <<EOF
{
  "name": "Protect main and develop",
  "target": "branch",
  "enforcement": "active",
  "bypass_actors": [],
  "conditions": {
    "ref_name": {
      "include": ["refs/heads/main", "refs/heads/develop"],
      "exclude": []
    }
  },
  "rules": [
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 1,
        "dismiss_stale_reviews_on_push": false,
        "require_code_owner_review": true,
        "require_last_push_approval": false,
        "required_review_thread_resolution": false,
        "allowed_merge_methods": ["merge", "squash", "rebase"],
        "required_reviewers": [
          {
            "reviewer": { "id": ${OWNER_ID}, "type": "User" },
            "minimum_approvals": 1,
            "file_patterns": ["*"]
          }
        ]
      }
    },
    {
      "type": "restrict_pushes",
      "parameters": {
        "restrictions": [
          { "id": ${OWNER_ID}, "type": "User" }
        ]
      }
    },
    { "type": "deletion", "parameters": {} },
    { "type": "non_fast_forward", "parameters": {} }
  ]
}
EOF
)"

if [[ -n "${existing_ruleset_id}" ]]; then
  gh api --method PUT "repos/${REPO}/rulesets/${existing_ruleset_id}" --input - <<<"${payload}"
else
  gh api --method POST "repos/${REPO}/rulesets" --input - <<<"${payload}"
fi

echo "Ruleset applied. Only @davyuonggd can push to or approve changes on main/develop."

echo "Hardening repository settings..."
gh api --method PUT "repos/${REPO}/actions/permissions" \
  -f enabled=true \
  -f allowed_actions=all

gh api --method PUT "repos/${REPO}/actions/permissions/workflow" \
  -f default_workflow_permissions=read \
  -F can_approve_pull_request_reviews=false

echo "Done."
