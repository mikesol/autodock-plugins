---
description: Stop the current Autodock staging environment
---

# Autodock Down - Stop Environment

Stop the current Autodock staging environment. The environment can be restarted later with `/autodock up`.

---

## Step 1: Read State

Check for `.autodock-state` in the project root:

```bash
cat .autodock-state 2>/dev/null || echo "NO_STATE"
```

**If no state file exists:**
1. Call `mcp__autodock__env_list` to list all environments
2. If exactly 1 environment is running, use that
3. If multiple environments, ask user which to stop
4. If no environments, report: "No active Autodock environment found."

---

## Step 2: Stop Environment

Call `mcp__autodock__env_stop` with the `environmentId` from state.

---

## Step 3: Update State

Update `.autodock-state` to reflect stopped status (keep the file for potential restart):

```json
{
  "environmentId": "<uuid>",
  "environmentName": "<name>",
  "slug": "<slug>",
  "status": "stopped",
  "stoppedAt": "<timestamp>"
}
```

---

## Step 4: Report

```
Environment [name] has been stopped.

Run `/autodock up` to restart it.
Run `/autodock up --fresh` to create a new environment instead.
```

---

## Error Handling

- **Environment not found**: Clear `.autodock-state` and report
- **Stop fails**: Report error and suggest retrying
