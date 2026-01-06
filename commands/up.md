---
description: Launch or reuse an Autodock staging environment, sync code, and expose ports
argument-hint: "[--fresh]"
---

# Autodock Up

**CRITICAL INSTRUCTIONS - FOLLOW EXACTLY:**

1. **Invoke the `staging` agent AS A BACKGROUND TASK** - use `run_in_background: true`
2. **DO NOT block waiting for the agent** - never use blocking TaskOutput
3. **When checking status, ALWAYS use non-blocking TaskOutput** - `block: false`

After starting the background agent, tell the user:
- The staging environment setup is running in the background
- They can continue working while it runs
- Ask anytime to check progress (you'll use non-blocking TaskOutput)
- You'll let them know when it completes

Pass to the agent:
- Arguments: $ARGUMENTS (includes --fresh flag if provided)
- Working directory context

The staging agent handles everything autonomously:
- Environment reuse/launch
- Technology detection
- Code sync and .env patching
- Dependency installation
- Service startup
- Port exposure
- Final URL reporting
