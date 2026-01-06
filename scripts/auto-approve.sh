#!/bin/bash
# auto-approve.sh - PreToolUse hook to auto-approve Autodock-related bash commands
#
# This hook receives tool input via stdin and outputs JSON to approve/deny.
# It auto-approves commands that are clearly Autodock-related to avoid approval fatigue.

set -e

# Read input from stdin
INPUT=$(cat)

# Extract tool name and command from input
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Only process Bash tool calls
if [[ "$TOOL_NAME" != "Bash" ]]; then
    exit 0
fi

# Check if command is Autodock-related
is_autodock_command() {
    local cmd="$1"

    # SSH to autodock.io hosts
    if [[ "$cmd" =~ ssh.*autodock\.io ]]; then
        return 0
    fi

    # SSH using autodock SSH keys
    if [[ "$cmd" =~ ssh.*\.autodock/ssh/ ]]; then
        return 0
    fi

    # rsync to autodock.io hosts
    if [[ "$cmd" =~ rsync.*autodock\.io ]]; then
        return 0
    fi

    # curl to autodock.io
    if [[ "$cmd" =~ curl.*autodock\.io ]]; then
        return 0
    fi

    # Reading .autodock-state
    if [[ "$cmd" =~ \.autodock-state ]]; then
        return 0
    fi

    # mkdir for .autodock directories
    if [[ "$cmd" =~ mkdir.*\.autodock ]]; then
        return 0
    fi

    # chmod for autodock SSH keys
    if [[ "$cmd" =~ chmod.*\.autodock ]]; then
        return 0
    fi

    # Downloading autodock SSH keys
    if [[ "$cmd" =~ curl.*\.autodock/ssh ]]; then
        return 0
    fi

    # Safe read-only commands often used in autodock setup
    if [[ "$cmd" =~ ^(cat|ls|basename|find|head|tail|grep|echo|test|true)( |\") ]]; then
        return 0
    fi

    # Package manager installs (needed for setup)
    if [[ "$cmd" =~ ^(npm|pnpm|yarn|pip)\ (install|ci) ]]; then
        return 0
    fi

    # Copying .env files for backup
    if [[ "$cmd" =~ cp.*\.env.*\.autodock-original ]]; then
        return 0
    fi

    return 1
}

# Check if this is an autodock-related command
if is_autodock_command "$COMMAND"; then
    # Output JSON to auto-approve
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
fi

# For non-autodock commands, don't interfere (let normal permission flow happen)
exit 0
