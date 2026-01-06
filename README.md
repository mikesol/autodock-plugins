# Autodock Claude Code Plugin

Automatic staging environment management for [Autodock](https://autodock.io). One command to provision, sync, and expose a complete staging environment.

## Features

- **One-command setup**: `/autodock up` provisions a complete staging environment
- **Zero interaction**: No prompts until your URLs are ready
- **Auto-sync**: Changes are automatically synced after file edits (with debouncing)
- **Smart .env handling**: Automatically patches URLs for remote development
- **Environment reuse**: Reuse existing environments or create fresh ones

## Prerequisites

1. [Claude Code](https://claude.ai/code) installed
2. [Autodock MCP server](https://autodock.io) configured in Claude Code:
   ```bash
   claude mcp add --transport http autodock https://autodock.io/api/mcp/streamable-http
   ```

## Installation

### From Local Path (Development)

```bash
/plugin marketplace add ./path/to/autodock-plugin
/plugin install autodock
```

### From GitHub (Production)

```bash
/plugin marketplace add autodock/autodock-plugin
/plugin install autodock
```

## Usage

### `/autodock up`

Launch or reuse a staging environment:

```
/autodock up          # Launch new or reuse existing
/autodock up --fresh  # Always create new environment
```

This command:
1. Checks for existing environments (prompts to reuse if found)
2. Launches a new environment if needed
3. Detects your project's technologies (Next.js, Vite, Supabase, etc.)
4. Syncs your code to the remote environment
5. Patches .env files for remote URLs
6. Installs dependencies and starts services
7. Exposes ports and verifies connectivity
8. Reports your staging URLs

### `/autodock down`

Stop the current environment:

```
/autodock down
```

The environment can be restarted later with `/autodock up`.

### `/autodock status`

Show environment status and URLs:

```
/autodock status
```

### `/autodock sync`

Manually sync code changes:

```
/autodock sync
```

## Auto-Sync

The plugin includes a hook that triggers after file edits (Write/Edit operations). Changes are debounced (5 seconds) to avoid excessive syncing.

When files change, you'll see a suggestion to run `/autodock sync`.

## .env Handling

The plugin intelligently handles environment variables:

### External Variables (patched to Autodock URLs)
- `NEXT_PUBLIC_*`, `VITE_*`, `REACT_APP_*`
- `API_URL`, `BACKEND_URL`, `FRONTEND_URL`
- `NEXTAUTH_URL`, `CORS_*`, `CALLBACK_URL`

### Internal Variables (kept as localhost)
- `DATABASE_URL`, `POSTGRES_*`, `MYSQL_*`
- `REDIS_*`, `MONGODB_*`, `CACHE_URL`

Example transformation:
```
# Local .env
NEXT_PUBLIC_API_URL=http://localhost:8080
DATABASE_URL=postgresql://localhost:5432/mydb

# Remote .env (patched)
NEXT_PUBLIC_API_URL=https://8080--my-project-abc123.autodock.io
DATABASE_URL=postgresql://localhost:5432/mydb  # unchanged
```

## State Files

### `.autodock-state` (project root)

Tracks the active environment for this project. Add to `.gitignore`:

```gitignore
.autodock-state
.env.autodock-original
```

### `~/.autodock-plugin/` (global)

Plugin state directory for debounce timing.

## Technology Detection

The plugin automatically detects:
- **Next.js**: `next` in package.json, `next.config.*`
- **Vite**: `vite` in package.json, `vite.config.*`
- **Supabase**: `@supabase/*` in package.json, `supabase/` directory
- **Kubernetes**: `k8s/` or `kubernetes/` directory
- **ArgoCD**: `argocd/` directory

Detection enables framework-specific guidance during setup.

## Troubleshooting

### "No Autodock MCP server found"

Ensure the Autodock MCP server is configured:
```bash
claude mcp add --transport http autodock https://autodock.io/api/mcp/streamable-http
```

### "Environment launch failed"

Check your Autodock quota:
```
mcp__autodock__account_info
```

### "Port exposure failed"

Verify the service is running and bound to `0.0.0.0`:
```bash
ssh ... "ss -tlnp | grep <port>"
```

### "Service won't start"

Check logs:
```bash
ssh ... "tail -100 /workspace/logs/<project>.log"
```

## License

MIT
