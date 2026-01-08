#!/bin/bash
# auto-approve-skill.sh - PreToolUse hook to auto-approve Autodock skill calls
#
# This hook receives tool input via stdin and outputs JSON to approve/deny.
# It auto-approves Skill calls that invoke specific autodock skills.

set -e

# Read input from stdin
INPUT=$(cat)

# Extract skill name from input
SKILL=$(echo "$INPUT" | jq -r '.tool_input.skill // empty')

# Only approve specific autodock skills
case "$SKILL" in
    autodock:up|autodock:down|autodock:status|autodock:sync|autodock:test)
        cat << 'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow",
    "permissionDecisionReason": "Auto-approved by Autodock plugin"
  }
}
EOF
        exit 0
        ;;
esac

# For non-autodock skills, don't interfere
exit 0
