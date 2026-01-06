---
description: Launch or reuse an Autodock staging environment, sync code, and expose ports
argument-hint: "[--fresh]"
---

# Autodock Up

## Step 1: Check Authentication

Call `mcp__autodock__account_info` to verify the user is authenticated.

**If the call fails or returns an auth error:**
- Tell the user: "The Autodock MCP server needs authentication. Please run `/mcp`, select the `autodock` server, and press Enter to log in. Then try `/autodock:up` again."
- STOP here - do not proceed to Step 2

**If auth succeeds (returns user info):**
- Proceed to Step 2

## Step 2: Launch Background Agent

1. Invoke the `staging` agent with `run_in_background: true`
2. Never use blocking TaskOutput - always use `block: false`

Tell the user:
- Setup is running in the background
- They can continue working
- Ask anytime to check progress

Pass to agent:
- Arguments: $ARGUMENTS
- Working directory context
