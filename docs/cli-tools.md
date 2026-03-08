# CLI Coding Assistants

Terminal-based AI agents that can read/write files, run commands, and generate documents. This page covers which tools work with our setup and how to use them.

---

## Recommendation

**Claude Code** is the best CLI for this server. It natively connects to the local Ollama instance (free, private, offline) and has the most reliable tool calling of any CLI tested. It also works from client machines on the network.

| Tool | Works with Ollama | Works offline | Tool calling | Cost (local) |
|------|-------------------|---------------|-------------|--------------|
| **Claude Code** | Yes (native Anthropic API compat) | Yes | Reliable | Free |
| OpenCode | Yes (but unreliable) | Yes | Frequently fails silently | Free |
| CodeBuff | No (cloud only) | No | N/A | Pay-per-use |

---

## Claude Code + Local Ollama (Recommended)

### On the server

Already installed (v2.1.71). No Anthropic account or login needed — the wrapper script handles all auth. Just run:
```bash
bash scripts/claude-local.sh
```

Or with a one-shot command:
```bash
bash scripts/claude-local.sh -p "create an Excel file at ~/report.xlsx with Q1 sales data"
```

The wrapper sets these environment variables:
```bash
export ANTHROPIC_BASE_URL="http://localhost:11434"
export ANTHROPIC_API_KEY="ollama"
unset ANTHROPIC_AUTH_TOKEN   # Prevent conflict with stored claude.ai login
unset CLAUDECODE             # Prevent nested-session detection
```

### On client machines (any computer on the network)

1. Install Claude Code:
   ```bash
   # Linux / macOS / WSL
   curl -fsSL https://claude.ai/install.sh | bash

   # Windows PowerShell
   irm https://claude.ai/install.ps1 | iex
   ```

2. Set environment variables (add to shell profile for persistence):
   ```bash
   export ANTHROPIC_BASE_URL="http://ai.local:11434"
   export ANTHROPIC_API_KEY="ollama"
   ```

3. Run:
   ```bash
   claude --model qwen3:32b
   ```

No Anthropic account or login needed. All processing runs on the AI server GPU.

> **Note:** If you've previously logged into claude.ai on the same machine, you may see a warning about "Both a token and an API key are set." This is cosmetic — the local connection works correctly. To silence it, run `claude /logout` first.

### Using Anthropic's cloud instead

To use Anthropic's cloud models (paid, more capable), just run `claude` without the env vars. It authenticates via browser on first run.

```bash
# Cloud mode (default, requires Anthropic account)
claude

# Switch models
claude --model opus     # Most capable
claude --model sonnet   # Default for most plans
claude --model haiku    # Fastest / cheapest
```

### Context requirements

Claude Code needs **32K+ context** for reliable agentic work (tool calls, file edits). Keep the server in **1x32K mode** when using Claude Code:
```bash
# Check current mode
grep OLLAMA_NUM_PARALLEL /etc/systemd/system/ollama.service.d/override.conf

# If it shows 2 (parallel mode), switch to single:
bash scripts/toggle-parallel.sh
```

2x16K parallel mode will cause Claude Code to truncate context and miss tool calls.

### Common commands

```bash
# Interactive session
bash scripts/claude-local.sh

# One-shot (print mode) — runs and exits
bash scripts/claude-local.sh -p "summarize all .md files in docs/"

# Pipe input
cat data.csv | bash scripts/claude-local.sh -p "analyze this CSV and find outliers"

# Continue most recent conversation
bash scripts/claude-local.sh --continue

# Resume a specific session
bash scripts/claude-local.sh --resume <session-id>
```

### File generation examples

```bash
# Excel file
bash scripts/claude-local.sh -p "create ~/report.xlsx with employee data: Name, Department, Salary, Start Date. Add 20 sample rows."

# CSV from existing data
cat raw-data.txt | bash scripts/claude-local.sh -p "parse this into a clean CSV at ~/output.csv"

# Python script
bash scripts/claude-local.sh -p "write a Python script at ~/backup.py that backs up /mnt/ai-models/open-webui/ to a timestamped tar.gz"
```

---

## Why Not the Others?

### OpenCode (not recommended for this server)

OpenCode (https://github.com/anomalyco/opencode, 118K stars) supports Ollama but has **known issues with tool calling on local models**. The maintainer stated: "local LLMs are not yet ready for this kind of workload." Qwen3 specifically was tested and required workarounds (`num_ctx` fix), with tool calls still failing silently in many cases.

If you want to try it anyway:
```bash
curl -fsSL https://opencode.ai/install | bash
```

Config at `~/.config/opencode/opencode.json`:
```json
{
  "provider": {
    "ollama": {
      "npm": "@ai-sdk/openai-compatible",
      "options": { "baseURL": "http://localhost:11434/v1" },
      "models": { "qwen3:32b": { "name": "Qwen3 32B" } }
    }
  }
}
```

### CodeBuff (incompatible)

CodeBuff (https://github.com/CodebuffAI/codebuff) cannot connect to local Ollama. It routes all requests through its own cloud backend via OpenRouter. Not usable in our setup.

---

## Links

| Tool | Docs | GitHub |
|------|------|--------|
| Claude Code | https://code.claude.com/docs/en/ | https://github.com/anthropics/claude-code |
| OpenCode | https://opencode.ai/docs/ | https://github.com/anomalyco/opencode |
| CodeBuff | https://www.codebuff.com/docs | https://github.com/CodebuffAI/codebuff |
