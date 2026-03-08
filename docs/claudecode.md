# Claude Code CLI Setup

Claude Code is Anthropic's official CLI agent for software engineering tasks. It can read, write, and edit files, run shell commands, search codebases, and manage git — all from the terminal.

> **Note:** Claude Code requires an Anthropic account (cloud-based). It does NOT use the local Ollama/Stocky model. Each request is sent to Anthropic's API and billed per token.

---

## Install

```bash
# Linux / WSL (recommended)
curl -fsSL https://claude.ai/install.sh | bash

# Or via npm (requires Node.js 18+, deprecated)
npm install -g @anthropic-ai/claude-code
```

## Authenticate

Claude Code uses browser-based login (not an API key):
```bash
claude
# First run opens a browser to authenticate with your Anthropic account
```

## Usage

```bash
# Start interactive session in current directory
claude

# Start with an initial prompt
claude "create an Excel file with sample employee data"

# Non-interactive (print mode) — runs, outputs, then exits
claude -p "list all Python files in this directory"

# Pipe input
cat data.csv | claude -p "summarize this CSV data"

# Continue most recent conversation
claude --continue

# Resume a specific session
claude --resume <session-id>

# Add extra working directories
claude --add-dir ../other-project
```

## What It Can Do

- Read, write, create, and edit files directly on the server
- Run shell commands (pip, python, git, etc.)
- Generate Excel/CSV files using Python scripts it writes and executes
- Refactor codebases, fix bugs, write tests
- Search and navigate large codebases
- Manage git (commit, branch, diff)

## File Generation Example

```
> claude "create an Excel spreadsheet at ~/employees.xlsx with columns: Name, Department, Salary. Add 10 sample rows."
```

Claude Code will write a Python script using openpyxl, execute it, and the file appears on disk.

## Cost Considerations

- Uses Anthropic's cloud — requires internet and an Anthropic account
- Billed per token (input + output)
- Typical session: $0.01 - $0.50 depending on complexity
- Default model depends on your plan tier (Opus 4.6 for Max/Team Premium, Sonnet 4.6 for Pro/Team Standard)
- Switch models with `--model`: `claude --model opus`, `claude --model sonnet`, `claude --model haiku`

## Comparison with Stocky (Open WebUI)

| Feature | Stocky (Open WebUI) | Claude Code CLI |
|---------|---------------------|-----------------|
| Interface | Browser chat | Terminal |
| Model | Local (Qwen3-32B) | Cloud (Claude) |
| File creation | Via Jupyter code interpreter | Direct file system access |
| Cost | Free (runs locally) | Pay per token |
| Internet | Not required | Required |
| Privacy | Fully local | Data sent to Anthropic |
| Best for | Chat, documents, research | Code, file manipulation, automation |

## Links

- Docs: https://code.claude.com/docs/en/
- GitHub: https://github.com/anthropics/claude-code
