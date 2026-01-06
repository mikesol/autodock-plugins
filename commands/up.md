---
description: Launch or reuse an Autodock staging environment, sync code, and expose ports
argument-hint: "[--fresh]"
---

# Autodock Up - Staging Environment Orchestration

You are orchestrating an Autodock staging environment. Your goal is to get the user's project running remotely with **zero interaction** until URLs are ready.

**IMPORTANT**: Do not ask the user questions during setup unless absolutely necessary (like environment reuse decisions). Execute all steps autonomously.

---

## Phase 1: Environment Check & Reuse

### Step 1.1: Check for existing state

First, check if `.autodock-state` exists in the project root:

```bash
cat .autodock-state 2>/dev/null || echo "NO_STATE"
```

### Step 1.2: List existing environments

Call `mcp__autodock__env_list` to see all user environments.

### Step 1.3: Decide on reuse

**If `--fresh` argument was provided**: Skip to Phase 2 (launch new).

**If `.autodock-state` exists with an environmentId**:
1. Call `mcp__autodock__env_status` with that environmentId
2. If status is `ready`: Ask user "Found running environment [name]. Reuse it? (y/n)"
3. If status is `stopped`: Ask user "Found stopped environment [name]. Restart it? (y/n)"
4. If user says yes to restart: Call `mcp__autodock__env_restart`, then skip to Phase 3
5. If user says yes to reuse ready env: Skip to Phase 3
6. If environment not found: Delete `.autodock-state` and proceed to Phase 2

**If no `.autodock-state` exists**:
1. Check `mcp__autodock__env_list` results
2. If 0 environments: Proceed to Phase 2 (launch new) - NO prompt needed
3. If 1+ environments with matching project name: Ask user which to use or launch new

---

## Phase 2: Launch New Environment

### Step 2.1: Determine project name

Get the project directory name:
```bash
basename "$PWD"
```

### Step 2.2: Launch environment

Call `mcp__autodock__env_launch` with:
- `name`: Project directory name
- `autoStopMinutes`: 120 (2 hours default)

### Step 2.3: Wait for ready

The launch returns immediately. Call `mcp__autodock__env_status` periodically until status is `ready`. This typically takes 1-2 minutes.

---

## Phase 3: Technology Detection

Before syncing, detect technologies to enable framework-specific guidance.

### Step 3.1: Read package.json

```bash
cat package.json 2>/dev/null || echo "{}"
```

Look for dependencies:
- `next`, `@next/*` → `nextjs`
- `vite`, `@vitejs/*` → `vite`
- `@supabase/*` → `supabase`

### Step 3.2: Check for config files and directories

```bash
ls -la next.config.* vite.config.* supabase/ k8s/ kubernetes/ argocd/ 2>/dev/null || true
```

- `next.config.*` → `nextjs`
- `vite.config.*` → `vite`
- `supabase/` or `supabase/config.toml` → `supabase`
- `k8s/` or `kubernetes/` → `k3s`
- `argocd/` → `argocd`

Build array: `["nextjs", "vite", "supabase"]` (as applicable)

---

## Phase 4: Sync Code

### Step 4.1: Get sync instructions

Call `mcp__autodock__env_sync` with:
- `projectName`: basename of current directory
- `detectedTechnologies`: array from Phase 3

### Step 4.2: Execute rsync

Run the rsync command template returned. **Exclude .env files** from rsync - we handle them separately:

```bash
rsync -avz --exclude='.env*' --exclude='node_modules' --exclude='.git' \
  -e "ssh -i ~/.autodock/ssh/<slug>.pem -p <port>" \
  ./ ubuntu@<host>:/workspace/<projectName>/
```

### Step 4.3: Handle .env files

This is **critical** for remote development. Read all .env files:

```bash
cat .env .env.local .env.development .env.production 2>/dev/null || true
```

**Classify each variable with a localhost URL:**

#### EXTERNAL vars (MUST patch to autodock URL):
- `NEXT_PUBLIC_*`, `VITE_*`, `REACT_APP_*` (browser-facing)
- `API_URL`, `BACKEND_URL`, `FRONTEND_URL`, `APP_URL`, `BASE_URL`
- `NEXTAUTH_URL`
- `CORS_*`, `CSRF_TRUSTED_ORIGINS`, `ALLOWED_HOSTS`
- `WS_URL`, `WEBSOCKET_URL` (use `wss://` prefix)
- `OAUTH_REDIRECT_URI`, `CALLBACK_URL`

#### INTERNAL vars (keep as localhost):
- `DATABASE_URL`, `DB_HOST`, `POSTGRES_*`, `MYSQL_*`
- `REDIS_*`, `MONGODB_*`, `CACHE_URL`
- `ELASTICSEARCH_URL`, `RABBITMQ_URL`, `KAFKA_*`, `*_SERVICE_HOST`

**Patching rules:**
- `http://localhost:3000` → `https://3000--<slug>.autodock.io`
- `ws://localhost:3000` → `wss://3000--<slug>.autodock.io`
- Keep INTERNAL vars as `localhost`

**Create patched .env on remote:**

```bash
ssh -i ~/.autodock/ssh/<slug>.pem -p <port> ubuntu@<host> "cat > /workspace/<projectName>/.env" << 'EOF'
# Patched for Autodock remote development
NEXT_PUBLIC_API_URL=https://8080--<slug>.autodock.io
DATABASE_URL=postgresql://localhost:5432/mydb
# ... rest of patched content
EOF
```

**Save original locally for re-sync detection:**
```bash
cp .env .env.autodock-original 2>/dev/null || true
```

---

## Phase 5: Install Dependencies & Start Services

### Step 5.1: Get run templates

Call `mcp__autodock__env_run` with:
- `projectName`: basename of current directory

### Step 5.2: Install dependencies

SSH into environment and run install command. Use `bash -li -c` wrapper for mise-managed tools:

```bash
ssh -i ~/.autodock/ssh/<slug>.pem -p <port> ubuntu@<host> \
  "cd /workspace/<projectName> && bash -li -c 'npm install'"
```

### Step 5.3: Start services in background

**CRITICAL**: Use proper backgrounding to prevent SSH hangs:

```bash
ssh -i ~/.autodock/ssh/<slug>.pem -p <port> ubuntu@<host> << 'EOF'
cd /workspace/<projectName>
# For Vite projects, add host validation
export __VITE_ADDITIONAL_SERVER_ALLOWED_HOSTS=.autodock.io
# Start in background with nohup
nohup bash -li -c 'npm run dev' > /workspace/logs/<projectName>.log 2>&1 </dev/null &
echo "Started with PID: $!"
EOF
```

Wait a few seconds for the service to start, then verify:
```bash
ssh -i ~/.autodock/ssh/<slug>.pem -p <port> ubuntu@<host> \
  "tail -20 /workspace/logs/<projectName>.log"
```

---

## Phase 6: Port Detection & Exposure

### Step 6.1: Detect ports

Check for common ports in:
- `package.json` scripts (look for `--port`, `-p`, `:PORT`)
- Framework defaults: Next.js (3000), Vite (5173), Express (3000, 8080)
- Docker compose port mappings

Common ports to check: 3000, 3001, 5173, 8000, 8080

### Step 6.2: Expose each port

For each detected port, call `mcp__autodock__env_expose` with:
- `environmentId`: from state
- `port`: the port number
- `name`: optional friendly name (e.g., "frontend", "api")

### Step 6.3: Verify URLs

For each exposed URL, verify connectivity from local machine:

```bash
curl -sI https://3000--<slug>.autodock.io | head -5
```

If verification fails:
1. Check if service is running: `ssh ... "ss -tlnp | grep <port>"`
2. Check if bound to 0.0.0.0 (not just 127.0.0.1)
3. Check service logs for errors

---

## Phase 7: Save State & Report

### Step 7.1: Save state

Write `.autodock-state` to project root:

```json
{
  "environmentId": "<uuid>",
  "environmentName": "<name>",
  "slug": "<slug>",
  "createdAt": "<timestamp>",
  "lastSync": "<timestamp>",
  "exposedPorts": [3000, 8080],
  "detectedTechnologies": ["nextjs"]
}
```

### Step 7.2: Final output

Report to user:

```
Your Autodock staging environment is ready!

**URLs:**
- Frontend: https://3000--<slug>.autodock.io
- API: https://8080--<slug>.autodock.io

**Environment:** <name>
**Auto-stop:** 2 hours of inactivity

Run `/autodock status` to check state.
Run `/autodock sync` to re-sync after changes.
```

---

## Error Handling

- **Launch fails**: Report error, suggest checking quota with `mcp__autodock__account_info`
- **Sync fails**: Report which step failed, suggest manual retry
- **Port exposure fails**: Check if service is running, bound to correct interface
- **Service won't start**: Check logs, report specific error

---

## Quick Reference: MCP Tools

- `mcp__autodock__env_list` - List all environments
- `mcp__autodock__env_launch` - Launch new environment
- `mcp__autodock__env_status` - Get environment status
- `mcp__autodock__env_restart` - Restart stopped environment
- `mcp__autodock__env_sync` - Get sync instructions
- `mcp__autodock__env_run` - Get run command templates
- `mcp__autodock__env_expose` - Expose port with HTTPS URL
- `mcp__autodock__env_listExposed` - List exposed ports
