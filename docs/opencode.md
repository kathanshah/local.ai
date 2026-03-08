# OpenCode CLI Setup

OpenCode is an open-source terminal AI assistant (similar to Claude Code) that works with **local models via Ollama**. It can read/write files, run commands, and manipulate code — all using the local Stocky/Qwen3 model with no cloud dependency.

> **This is the recommended CLI tool for file manipulation** since it uses the local Ollama model (free, private, no internet needed).

---

## Install

### Option A: Install script (recommended)
```bash
curl -fsSL https://opencode.ai/install | bash
```

### Option B: Go install (requires Go 1.22+)
```bash
# Install Go if not present
sudo apt install -y golang-go

# Install OpenCode
go install github.com/opencode-ai/opencode@latest

# Add Go bin to PATH if not already
echo 'export PATH=$PATH:$(go env GOPATH)/bin' >> ~/.bashrc
source ~/.bashrc
```

## Configure

Create config file at `~/.config/opencode/opencode.json`:
```json
{
  "provider": {
    "ollama": {
      "type": "ollama",
      "host": "http://localhost:11434"
    }
  },
  "agent": {
    "model": "ollama/qwen3:32b"
  }
}
```

You can also place a project-level `opencode.json` in the repo root.

## Usage

```bash
# Start interactive TUI session
opencode

# Non-interactive one-shot command
opencode run "create an Excel file with sample sales data at ~/sales.xlsx"
```

## What It Can Do

- Read, write, and edit files on the local filesystem
- Run shell commands (python, pip, git, etc.)
- Generate Excel/CSV/JSON files by writing and executing Python
- Navigate and search codebases
- Git operations (commit, diff, branch)
- All processing stays local via Ollama — no data leaves the server

## File Generation Example

```
> opencode run "create an Excel spreadsheet at ~/employees.xlsx with columns: Name, Department, Salary. Add 10 sample rows using openpyxl."
```

OpenCode writes a Python script, executes it via shell, and the file appears on disk.

## Comparison with Stocky (Open WebUI)

| Feature | Stocky (Open WebUI) | OpenCode CLI |
|---------|---------------------|--------------|
| Interface | Browser chat | Terminal |
| Model | Local (Qwen3-32B) | Local (Qwen3-32B) — same model |
| File creation | Via Jupyter code interpreter | Direct file system access |
| Cost | Free | Free |
| Internet | Not required | Not required |
| Privacy | Fully local | Fully local |
| Best for | Chat, documents, research | Code, file manipulation, automation |

## Dependencies on This Server

OpenCode uses the same Ollama instance that powers Stocky. When OpenCode is running a task, it shares the GPU with Open WebUI requests. If parallel mode is set to 1, requests will queue.

Consider switching to 2-parallel mode when using both:
```bash
bash scripts/toggle-parallel.sh
```

## Links

- GitHub: https://github.com/opencode-ai/opencode
- Docs: https://opencode.ai/docs/
- Config reference: https://opencode.ai/docs/config/
- CLI reference: https://opencode.ai/docs/cli/
