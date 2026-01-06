---
description: Manually sync code changes to the Autodock staging environment
---

# Autodock Sync - Manual Code Sync

Manually trigger a code sync to the staging environment. Use this after making changes that weren't automatically synced.

---

## Step 1: Verify Environment

Check for `.autodock-state` in the project root:

```bash
cat .autodock-state 2>/dev/null || echo "NO_STATE"
```

**If no state file exists:**
Report: "No Autodock environment found. Run `/autodock up` first."
Exit.

### Verify environment is running

Call `mcp__autodock__env_status` with the `environmentId`.

If status is `stopped`:
```
Environment is stopped. Run `/autodock up` to restart it first.
```

---

## Step 2: Detect Technologies

Same as `/autodock up`:
- Check `package.json` for framework dependencies
- Check for config files: `next.config.*`, `vite.config.*`, etc.
- Check for directories: `supabase/`, `k8s/`, etc.

Build array: `["nextjs", "vite"]` etc.

---

## Step 3: Get Sync Instructions

Call `mcp__autodock__env_sync` with:
- `projectName`: basename of current directory
- `detectedTechnologies`: array from Step 2

---

## Step 4: Execute Sync

Run the rsync command from the sync instructions, excluding .env files:

```bash
rsync -avz --exclude='.env*' --exclude='node_modules' --exclude='.git' \
  -e "ssh -i ~/.autodock/ssh/<slug>.pem -p <port>" \
  ./ ubuntu@<host>:/workspace/<projectName>/
```

---

## Step 5: Handle .env Changes

Check if local .env has changed since last sync:

```bash
diff .env .env.autodock-original 2>/dev/null || echo "CHANGED"
```

**If .env changed:**
1. Re-classify variables (EXTERNAL vs INTERNAL)
2. Patch EXTERNAL vars with autodock URLs
3. Upload patched version to remote
4. Update `.env.autodock-original`

**Classification rules:**

EXTERNAL (patch to autodock URL):
- `NEXT_PUBLIC_*`, `VITE_*`, `REACT_APP_*`
- `API_URL`, `BACKEND_URL`, `FRONTEND_URL`, `APP_URL`, `BASE_URL`, `NEXTAUTH_URL`
- `CORS_*`, `CSRF_TRUSTED_ORIGINS`, `ALLOWED_HOSTS`
- `WS_URL`, `WEBSOCKET_URL` (use `wss://`)
- `OAUTH_REDIRECT_URI`, `CALLBACK_URL`

INTERNAL (keep localhost):
- `DATABASE_URL`, `DB_HOST`, `POSTGRES_*`, `MYSQL_*`
- `REDIS_*`, `MONGODB_*`, `CACHE_URL`
- `ELASTICSEARCH_URL`, `RABBITMQ_URL`, `KAFKA_*`

---

## Step 6: Check for Dependency Changes

```bash
git diff HEAD~1 --name-only 2>/dev/null | grep -E 'package.json|package-lock.json|yarn.lock|pnpm-lock.yaml'
```

**If dependencies changed:**
```bash
ssh -i ~/.autodock/ssh/<slug>.pem -p <port> ubuntu@<host> \
  "cd /workspace/<projectName> && bash -li -c 'npm install'"
```

---

## Step 7: Restart Services If Needed

Check if services support hot reload (HMR):
- Next.js, Vite, Create React App: Usually auto-reload
- Express, Fastify: May need restart

For non-HMR changes or if service crashed:
```bash
ssh -i ~/.autodock/ssh/<slug>.pem -p <port> ubuntu@<host> << 'EOF'
cd /workspace/<projectName>
# Kill existing process
pkill -f "npm run dev" || true
# Restart
export __VITE_ADDITIONAL_SERVER_ALLOWED_HOSTS=.autodock.io
nohup bash -li -c 'npm run dev' > /workspace/logs/<projectName>.log 2>&1 </dev/null &
EOF
```

---

## Step 8: Update State & Report

Update `lastSync` in `.autodock-state`:

```json
{
  "lastSync": "<timestamp>"
}
```

Report:
```
Sync complete!

**Changes synced to:** https://3000--<slug>.autodock.io

Run `/autodock status` to see all URLs.
```

---

## Error Handling

- **Rsync fails**: Report error, check SSH connectivity
- **Dependencies fail**: Report npm/yarn error
- **Service restart fails**: Check logs, report error
