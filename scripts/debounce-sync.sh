#!/bin/bash
# debounce-sync.sh - Debounced auto-sync trigger for Autodock
#
# Called by PostToolUse hook on Write|Edit operations.
# Implements 5-second debounce by tracking last-trigger time.
#
# Output is shown to Claude as a hint to run /autodock sync.

set -e

STATE_DIR="${HOME}/.autodock-plugin"
STATE_FILE="${STATE_DIR}/sync-state.json"
DEBOUNCE_SECONDS=5

# Ensure state directory exists
mkdir -p "$STATE_DIR"

# Check if project has an active autodock environment
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
if [[ ! -f "$PROJECT_ROOT/.autodock-state" ]]; then
  # No active environment, skip sync suggestion
  exit 0
fi

# Get current timestamp
NOW=$(date +%s)

# Read existing state or initialize
if [[ -f "$STATE_FILE" ]]; then
  LAST_TRIGGER=$(cat "$STATE_FILE" | grep -o '"lastTrigger":[0-9]*' | grep -o '[0-9]*' || echo "0")
  if [[ -z "$LAST_TRIGGER" ]]; then
    LAST_TRIGGER=0
  fi
else
  LAST_TRIGGER=0
fi

# Calculate time since last trigger
ELAPSED=$((NOW - LAST_TRIGGER))

# If within debounce window, mark pending and exit silently
if [[ $ELAPSED -lt $DEBOUNCE_SECONDS ]]; then
  cat > "$STATE_FILE" << EOF
{
  "lastTrigger": $LAST_TRIGGER,
  "pending": true,
  "pendingSince": $NOW
}
EOF
  exit 0
fi

# Outside debounce window - update state and suggest sync
cat > "$STATE_FILE" << EOF
{
  "lastTrigger": $NOW,
  "pending": false,
  "triggeredAt": $NOW
}
EOF

# Create marker file for sync request
touch "${STATE_DIR}/sync-requested"

# Output hint for Claude (this appears in the conversation)
echo "Files changed. Consider running /autodock sync to update the staging environment."
