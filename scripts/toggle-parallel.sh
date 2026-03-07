#!/bin/bash
# Toggle Ollama between 1 and 2 parallel request modes
# Run: bash scripts/toggle-parallel.sh
#
# Mode 1 (default): 1 parallel, 32K context (~50 pages) — best for long documents
# Mode 2:           2 parallel, 16K context (~25 pages) — best for multiple users

set -euo pipefail

OVERRIDE="/etc/systemd/system/ollama.service.d/override.conf"
CURRENT=$(grep -oP 'OLLAMA_NUM_PARALLEL=\K\d+' "$OVERRIDE" 2>/dev/null || echo "1")

WEBUI_EMAIL="${WEBUI_EMAIL:-hello@kathanshah.com}"
WEBUI_PASS="${WEBUI_PASS:-PopPop123\$%\`}"

update_model_context() {
    local CTX=$1
    local TOKEN
    TOKEN=$(curl -s --max-time 10 http://localhost:3000/api/v1/auths/signin \
      -H "Content-Type: application/json" \
      -d "{\"email\":\"${WEBUI_EMAIL}\",\"password\":\"${WEBUI_PASS}\"}" 2>/dev/null \
      | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))" 2>/dev/null)

    if [[ -z "$TOKEN" ]]; then
        echo "  [WARN] Could not authenticate with Open WebUI — update context manually"
        return
    fi

    curl -s --max-time 10 -X POST "http://localhost:3000/api/v1/models/model/update" \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" \
      -d "{
        \"id\": \"qwen3:32b\",
        \"name\": \"Stocky\",
        \"params\": {
          \"system\": \"You are Stocky, an AI assistant built for business productivity. You are helpful, sharp, and professional — but you have a dry sense of humor and are not afraid to crack a clever joke when the moment is right.\n\nKeep responses clear, concise, and actionable. Use bullet points and headings to structure longer answers. When drafting emails, documents, or proposals, match the appropriate tone for the context — formal for clients, relaxed for internal comms.\n\nYou are great with spreadsheets, data analysis, writing, research, and reviewing contracts. If something is ambiguous, ask a quick clarifying question rather than guessing.\n\nNever mention that you are an AI model, what model you are, or technical details about how you work. You are simply Stocky — the office assistant who actually gets things done (and occasionally gets a laugh).\",
          \"temperature\": 0.7,
          \"top_p\": 0.9,
          \"num_ctx\": $CTX
        }
      }" > /dev/null 2>&1

    echo "  Context window: $CTX tokens"
}

echo ""
echo "Current mode: $CURRENT parallel"
echo ""

if [[ "$CURRENT" == "1" ]]; then
    echo "Switching to: 2 parallel, 16K context"
    echo ""
    sudo sed -i 's/OLLAMA_NUM_PARALLEL=1/OLLAMA_NUM_PARALLEL=2/' "$OVERRIDE"
    sudo systemctl daemon-reload
    sudo systemctl restart ollama
    sleep 3
    update_model_context 16384
    echo ""
    echo "Done. Now running: 2 parallel, 16K context (~25 pages)"
    echo "Two users can chat simultaneously."
else
    echo "Switching to: 1 parallel, 32K context"
    echo ""
    sudo sed -i 's/OLLAMA_NUM_PARALLEL=2/OLLAMA_NUM_PARALLEL=1/' "$OVERRIDE"
    sudo systemctl daemon-reload
    sudo systemctl restart ollama
    sleep 3
    update_model_context 32768
    echo ""
    echo "Done. Now running: 1 parallel, 32K context (~50 pages)"
    echo "One user at a time, maximum document length."
fi
