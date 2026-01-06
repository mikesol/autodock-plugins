---
description: Show current Autodock environment status and URLs
---

# Autodock Status - Environment Status

Display the status of the current Autodock staging environment, including exposed URLs and resource usage.

---

## Step 1: Read State

Check for `.autodock-state` in the project root:

```bash
cat .autodock-state 2>/dev/null || echo "NO_STATE"
```

**If no state file exists:**
1. Call `mcp__autodock__env_list` to list all environments
2. If environments exist, show summary of all
3. If no environments: "No Autodock environment configured for this project. Run `/autodock up` to create one."

---

## Step 2: Get Environment Status

Call `mcp__autodock__env_status` with the `environmentId` from state.

---

## Step 3: Get Exposed Ports

Call `mcp__autodock__env_listExposed` with the `environmentId`.

---

## Step 4: Format Output

```
Autodock Environment Status
===========================

**Name:** <name>
**Status:** <ready|stopped|provisioning|failed>
**ID:** <environmentId>

**Exposed URLs:**
- https://3000--<slug>.autodock.io (port 3000) - frontend
- https://8080--<slug>.autodock.io (port 8080) - api

**Auto-stop:** <minutes> minutes remaining
**Created:** <timestamp>
**Last sync:** <timestamp>

**Detected Technologies:** nextjs, vite

**Commands:**
- `/autodock sync` - Re-sync code changes
- `/autodock down` - Stop environment
- `/autodock up --fresh` - Create new environment
```

---

## Additional Information

If environment is `stopped`:
```
**Status:** stopped

This environment is currently stopped. Run `/autodock up` to restart it.
All data and configuration is preserved.
```

If environment is `provisioning`:
```
**Status:** provisioning

This environment is still being set up. Please wait...
```

If environment is `failed`:
```
**Status:** failed

This environment failed to provision. Run `/autodock up --fresh` to try again.
```
