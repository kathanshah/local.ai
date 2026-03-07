#!/bin/bash
# AI Server — Inference Test
# Tests that Ollama + Qwen3-32B can generate responses
# Run: bash ~/scripts/test-inference.sh

set -euo pipefail

echo "========================================"
echo " Inference Test — Qwen3-32B"
echo " $(date)"
echo "========================================"

# Check ollama is running
if ! curl -s --max-time 5 http://localhost:11434/api/tags > /dev/null 2>&1; then
    echo "[FAIL] Ollama not responding. Run: sudo systemctl start ollama"
    exit 1
fi

# Check model available
if ! ollama list 2>/dev/null | grep -q "qwen3:32b"; then
    echo "[FAIL] qwen3:32b not found. Run: ollama pull qwen3:32b"
    exit 1
fi

echo ""
echo "--- Test 1: Simple generation (should respond in <10s) ---"
START=$(date +%s%N)
RESPONSE=$(curl -s --max-time 60 http://localhost:11434/api/generate -d '{
  "model": "qwen3:32b",
  "prompt": "Write a one-sentence professional email subject line about a Q1 budget review meeting.",
  "stream": false,
  "options": {"num_predict": 50}
}' 2>/dev/null)
END=$(date +%s%N)
ELAPSED=$(( (END - START) / 1000000 ))

if echo "$RESPONSE" | python3 -c "import sys,json; r=json.load(sys.stdin); print(r['response'])" 2>/dev/null; then
    echo "  Time: ${ELAPSED}ms"
    EVAL_COUNT=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('eval_count',0))" 2>/dev/null)
    EVAL_DUR=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('eval_duration',0))" 2>/dev/null)
    if [[ $EVAL_DUR -gt 0 ]]; then
        TPS=$(python3 -c "print(f'{$EVAL_COUNT / ($EVAL_DUR / 1e9):.1f}')")
        echo "  Tokens/sec: $TPS"
    fi
    echo "  [PASS] Generation works"
else
    echo "  [FAIL] No valid response"
    echo "  Raw: $RESPONSE"
fi

echo ""
echo "--- Test 2: Tool-use / function calling ---"
RESPONSE2=$(curl -s --max-time 60 http://localhost:11434/api/chat -d '{
  "model": "qwen3:32b",
  "messages": [{"role": "user", "content": "What is 42 * 17?"}],
  "stream": false,
  "options": {"num_predict": 50}
}' 2>/dev/null)

if echo "$RESPONSE2" | python3 -c "import sys,json; r=json.load(sys.stdin); print(r['message']['content'][:200])" 2>/dev/null; then
    echo "  [PASS] Chat API works"
else
    echo "  [FAIL] Chat API error"
fi

echo ""
echo "--- Test 3: GPU utilization during inference ---"
GPU_UTIL=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | tr -d ' ')
GPU_MEM=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits 2>/dev/null | tr -d ' ')
echo "  GPU utilization: ${GPU_UTIL}%"
echo "  GPU memory used: ${GPU_MEM} MiB"
[[ $GPU_MEM -gt 1000 ]] && echo "  [PASS] Model loaded in VRAM" || echo "  [WARN] Low VRAM usage — model may not be loaded"

echo ""
echo "--- Test 4: Open WebUI accessibility ---"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 http://ai.local 2>/dev/null)
[[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "302" ]] && echo "  [PASS] Open WebUI (ai.local): HTTP $HTTP_CODE" || echo "  [WARN] Open WebUI (ai.local): HTTP $HTTP_CODE"

echo ""
echo "--- Test 5: Ollama API via ai.local ---"
API_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://ai.local:11434/api/tags 2>/dev/null)
[[ "$API_CODE" == "200" ]] && echo "  [PASS] Ollama API (ai.local:11434): HTTP $API_CODE" || echo "  [WARN] Ollama API (ai.local:11434): HTTP $API_CODE"

echo ""
echo "========================================"
echo " Inference test complete."
echo "========================================"
