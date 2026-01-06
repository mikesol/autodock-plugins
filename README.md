# Autodock Claude Code Plugin

One command to provision, sync, and expose a complete staging environment.

## Features

- **One-command setup**: `/autodock:up` provisions a complete staging environment
- **Low friction**: Works in the background until your app's URLs are ready
- **Auto-sync**: Changes are automatically synced after file edits (with debouncing)
- **Smart .env handling**: Automatically patches URLs for remote development
- **Environment reuse**: Reuse existing environments or create fresh ones

## Quickstart

```bash
claude plugin marketplace add mikesol/autodock-plugins
claude plugin install autodock
```

Then launch Claude Code and run:

```
/autodock:up
```

## Commands

- `/autodock:up` - Launch or reuse a staging environment
- `/autodock:down` - Stop the environment
- `/autodock:status` - Check environment status
- `/autodock:sync` - Re-sync code after local changes

## Local Development

```bash
claude plugin marketplace add ./path/to/autodock-plugins
claude plugin install autodock
```

## License

MIT
