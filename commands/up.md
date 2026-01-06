---
description: Launch or reuse an Autodock staging environment, sync code, and expose ports
argument-hint: "[--fresh]"
---

# Autodock Up

Invoke the `staging` agent to orchestrate the Autodock staging environment setup.

Pass the following context to the agent:
- Arguments: $ARGUMENTS
- Working directory: The current project directory

The staging agent will:
1. Check for existing environments and handle reuse
2. Launch a new environment if needed
3. Detect technologies (Next.js, Vite, Supabase, etc.)
4. Sync code to the remote environment
5. Patch .env files for remote development
6. Install dependencies and start services
7. Expose ports and verify URLs
8. Report final URLs to the user

Run this as a subagent to avoid polluting the main conversation.
