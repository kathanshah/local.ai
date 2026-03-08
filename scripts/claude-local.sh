#!/bin/bash
# Run Claude Code using the local Ollama server instead of Anthropic's cloud.
# Usage: bash scripts/claude-local.sh [claude args...]
#
# Examples:
#   bash scripts/claude-local.sh                          # Interactive session
#   bash scripts/claude-local.sh -p "list all .py files"  # One-shot print mode
#
# From client machines on the network:
#   ANTHROPIC_BASE_URL=http://ai.local:11434 ANTHROPIC_API_KEY=ollama claude --model qwen3:32b
#
# Note: If you've previously logged into claude.ai on this machine, you may see
# a harmless warning about "Both a token and an API key are set." This is cosmetic
# — the local Ollama connection works correctly regardless.

export ANTHROPIC_BASE_URL="http://localhost:11434"
export ANTHROPIC_API_KEY="ollama"
unset ANTHROPIC_AUTH_TOKEN
unset CLAUDECODE

# Activate Python venv so Bash tool can run pandas/matplotlib/openpyxl
export PATH="/mnt/ai-models/claude-code-env/bin:$PATH"

# System prompt guides local model behavior (task→package mapping).
# Single source of truth: scripts/stocky-prompt.txt (shared with client alias).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_PROMPT="$(cat "$SCRIPT_DIR/stocky-prompt.txt")"

exec claude --model qwen3:32b --append-system-prompt "$LOCAL_PROMPT" "$@"
