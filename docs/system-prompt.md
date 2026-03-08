# System Prompt for Local Model

When Claude Code runs with the local Qwen3:32b model (via `claude-local.sh` or the client `stocky` alias), it receives a system prompt that guides the model's behavior. This page explains why the prompt exists, what it does, and how to maintain it.

---

## Why is this needed?

Anthropic's Claude models are trained to use Claude Code's tools (Bash, Read, Write, etc.) effectively out of the box. The local Qwen3:32b model is not. Without guidance, Qwen3 will:

- Give manual instructions instead of executing code directly
- Try to use Jupyter notebooks or Docker containers instead of running Python via Bash
- Call `plt.show()` (which blocks or fails in a terminal)
- Not know which Python packages are available
- Use relative paths that break

The system prompt fixes this by providing explicit **task → action** mappings: "when the user asks to create an Excel file, use the Bash tool to run `python3` with `pandas + openpyxl`."

---

## Where is the prompt?

**Single source of truth:** [`scripts/stocky-prompt.txt`](../scripts/stocky-prompt.txt)

Used by:
- **Server:** `scripts/claude-local.sh` reads the file and passes it via `--append-system-prompt`
- **Clients:** The `stocky` shell alias reads from `~/.stocky/prompt.txt` (a copy of the same file)

---

## How it works

Claude Code's `--append-system-prompt` flag adds text to the model's system prompt. This means the model sees its normal Claude Code instructions **plus** our additions. The prompt counts against the 32K context window, so it's kept concise (~2 KB).

```
┌──────────────────────────────────┐
│  Claude Code default system      │
│  prompt (tools, rules, etc.)     │
├──────────────────────────────────┤
│  Our stocky-prompt.txt           │  ← appended
│  (task→action mapping)           │
├──────────────────────────────────┤
│  Conversation (user + model)     │
│  ...                             │
└──────────────────────────────────┘
         32K context window
```

---

## Prompt structure

The prompt has two sections:

### 1. Rules (behavioral constraints)

```
RULES:
1. Use Bash tool to run python3 for file/data/web tasks
2. Never use Jupyter or Docker containers
3. Write scripts to /tmp/ for complex tasks
4. Use absolute paths, save output where the user asks
5. Save charts as files, never plt.show()
6. Report errors clearly, don't guess
```

These override the model's default tendencies (especially the Jupyter habit).

### 2. Task → Action mapping

Each entry maps a user task to the exact Python import and pattern to use:

| User asks to... | Model should use... |
|----------------|---------------------|
| Read/create Excel | `pandas` + `openpyxl` or `xlsxwriter` |
| Read old .xls files | `pandas` + `xlrd` |
| Create Word document | `python-docx` (`from docx import Document`) |
| Create PowerPoint | `python-pptx` (`from pptx import Presentation`) |
| Create simple PDF | `fpdf2` (`from fpdf import FPDF`) |
| Create complex PDF | `reportlab` |
| HTML to PDF | `weasyprint` |
| Read/extract PDF text | `pymupdf` |
| Merge/split PDFs | `pypdf` |
| Static charts | `matplotlib` + `seaborn` |
| Interactive charts | `plotly` |
| Read a URL/article | `trafilatura` |
| Search the web | `duckduckgo-search` |
| Read RSS feeds | `feedparser` |
| Scrape HTML | `beautifulsoup4` + `lxml` |
| HTML to Markdown | `html2text` or `markdownify` |
| HTML templates | `Jinja2` |
| Resize/edit images | `Pillow` |
| SVG to PNG | `cairosvg` |
| Generate QR code | `qrcode` |
| YAML files | `pyyaml` |
| XML files | `xmltodict` or `lxml` |
| Detect encoding | `chardet` |
| Statistics | `scipy` |
| HTTP requests | `httpx` (preferred) or `requests` |
| Pretty tables | `tabulate` |
| Inline CSS for email | `premailer` |

---

## Python environment

### Server

Packages are installed in a dedicated venv at `/mnt/ai-models/claude-code-env/`. The wrapper script prepends it to `PATH`:

```bash
export PATH="/mnt/ai-models/claude-code-env/bin:$PATH"
```

### Clients

Packages are installed globally via `pip install`. The full install command is in [cli-tools.md](cli-tools.md).

---

## Maintaining the prompt

### Adding a new package

1. Install the package:
   ```bash
   # Server
   /mnt/ai-models/claude-code-env/bin/pip install <package>

   # Update client docs in cli-tools.md
   ```

2. Add a task→action entry in `scripts/stocky-prompt.txt`

3. Update the runbook maintenance section in `docs/runbook.md`

4. Tell clients to update their `~/.stocky/prompt.txt` and run `pip install <package>`

### Editing the prompt

- Keep it concise — every token counts against the 32K context window
- Use the `task → python3: import ...` format consistently
- Include the exact import statement — Qwen3 follows examples better than descriptions
- Test changes: `bash scripts/claude-local.sh -p "create a test Excel file at /tmp/test.xlsx"`

### What NOT to put in the prompt

- Long explanations or paragraphs (wastes context)
- Package version numbers (change too often)
- Niche packages used rarely (add only when needed)
- Instructions the model already follows (e.g., "respond in English")

---

## Context budget

| Component | Approximate tokens |
|-----------|-------------------|
| Claude Code system prompt | ~2,000 |
| Our stocky-prompt.txt | ~800 |
| Available for conversation | ~29,000 |

The prompt is ~2 KB of text which uses roughly 800 tokens. This leaves plenty of room for conversation. If the prompt grows beyond ~1,500 tokens, consider trimming less-used entries.
