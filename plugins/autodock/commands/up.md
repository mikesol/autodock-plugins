---
description: Launch or reuse an Autodock staging environment, sync code, and expose ports
argument-hint: "[--fresh]"
---

# Autodock Up

## Step 1: Check Authentication

**IMPORTANT: Do not search for tools or grep for MCP availability. Directly call the tool.**

Call the `mcp__autodock__account_info` tool now. This is the only way to check authentication status.

**If the tool returns user info (email, name):**
- Authentication successful - proceed to Step 2

**If the tool call fails, errors, or the tool doesn't exist:**
- Tell the user: "The Autodock MCP server needs authentication. Please run `/mcp`, select the `autodock` server, and press Enter to log in. Then try `/autodock:up` again."
- STOP here - do not proceed to Step 2

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
