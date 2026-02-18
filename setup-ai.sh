#!/usr/bin/env bash
# =============================================================================
# setup-ai.sh — Interactive AI provider configuration wizard
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

CONFIG_FILE="${SCRIPT_DIR}/.ai_config"

print_banner
echo -e "${BOLD}${CYAN}AI Provider Setup Wizard${RESET}"
echo -e "${DIM}Configure your LLM backend for intelligent analysis${RESET}"
echo ""

# ── Provider selection ────────────────────────────────────────────────────────
echo -e "${BOLD}Select your AI provider:${RESET}"
echo "  1) Ollama        (local, free, private — recommended)"
echo "  2) OpenAI        (GPT-4o, GPT-4, etc.)"
echo "  3) Anthropic     (Claude)"
echo "  4) OpenAI-compat (LM Studio, Together AI, Groq, Mistral, etc.)"
echo "  5) Disable AI"
echo ""
read -rp "Choice [1-5]: " provider_choice

case "$provider_choice" in
    1) PROVIDER="ollama" ;;
    2) PROVIDER="openai" ;;
    3) PROVIDER="claude" ;;
    4) PROVIDER="openai_compat" ;;
    5)
        echo "" > "$CONFIG_FILE"
        log_success "AI disabled. Config saved."
        exit 0
        ;;
    *)
        log_error "Invalid choice."
        exit 1
        ;;
esac

echo ""

# ── Provider-specific config ──────────────────────────────────────────────────
case "$PROVIDER" in
    ollama)
        read -rp "Ollama base URL [http://localhost:11434]: " base_url
        base_url="${base_url:-http://localhost:11434}"

        echo ""
        echo "Fetching available models..."
        available=$(curl -sf "${base_url}/api/tags" 2>/dev/null | \
            grep -oP '"name":"[^"]*"' | cut -d'"' -f4 | head -20)

        if [[ -n "$available" ]]; then
            echo -e "\n${BOLD}Available models:${RESET}"
            echo "$available" | nl -ba
            echo ""
        fi

        read -rp "Model name [llama3]: " model
        model="${model:-llama3}"
        API_KEY=""
        BASE_URL="$base_url"
        ;;

    openai)
        read -rsp "OpenAI API key: " api_key; echo ""
        [[ -z "$api_key" ]] && log_error "API key required." && exit 1

        echo ""
        echo "Common models: gpt-4o, gpt-4-turbo, gpt-4, gpt-3.5-turbo"
        read -rp "Model [gpt-4o]: " model
        model="${model:-gpt-4o}"
        API_KEY="$api_key"
        BASE_URL="https://api.openai.com/v1"
        ;;

    claude)
        read -rsp "Anthropic API key: " api_key; echo ""
        [[ -z "$api_key" ]] && log_error "API key required." && exit 1

        echo ""
        echo "Models: claude-opus-4-6, claude-sonnet-4-6, claude-haiku-4-5-20251001"
        read -rp "Model [claude-opus-4-6]: " model
        model="${model:-claude-opus-4-6}"
        API_KEY="$api_key"
        BASE_URL="https://api.anthropic.com"
        ;;

    openai_compat)
        echo "Examples:"
        echo "  LM Studio  : http://localhost:1234/v1"
        echo "  Groq       : https://api.groq.com/openai/v1"
        echo "  Together AI: https://api.together.xyz/v1"
        echo "  Mistral    : https://api.mistral.ai/v1"
        echo "  Perplexity : https://api.perplexity.ai"
        echo ""
        read -rp "Base URL: " base_url
        [[ -z "$base_url" ]] && log_error "Base URL required." && exit 1

        read -rsp "API key (leave blank if not required): " api_key; echo ""
        read -rp "Model name: " model
        [[ -z "$model" ]] && log_error "Model name required." && exit 1

        API_KEY="$api_key"
        BASE_URL="$base_url"
        ;;
esac

# ── Timeout ───────────────────────────────────────────────────────────────────
echo ""
read -rp "Request timeout in seconds [120]: " timeout
timeout="${timeout:-120}"

# ── Write config ──────────────────────────────────────────────────────────────
cat > "$CONFIG_FILE" << CONFIG
# PentestAutomator AI Configuration
# Generated: $(date)
AI_PROVIDER=${PROVIDER}
AI_API_KEY=${API_KEY}
AI_MODEL=${model}
AI_BASE_URL=${BASE_URL}
AI_TIMEOUT=${timeout}
CONFIG

chmod 600 "$CONFIG_FILE"
log_success "Config saved to ${CONFIG_FILE} (chmod 600)"

# ── Connection test ───────────────────────────────────────────────────────────
echo ""
log_info "Testing AI connection..."

source "${SCRIPT_DIR}/lib/ai.sh"
load_ai_config "$CONFIG_FILE"

if init_ai; then
    start_spinner "Sending test query..."
    response=$(ai_query \
        "You are a helpful assistant." \
        "Reply with exactly: 'PentestAutomator AI connection successful.' and nothing else.")
    stop_spinner

    if [[ -n "$response" ]]; then
        log_success "Connection test passed!"
        echo -e "  Response: ${DIM}${response}${RESET}"
    else
        log_warn "Connected but got empty response. Check model name."
    fi
else
    log_error "Connection test failed. Check your config and try again."
    exit 1
fi

echo ""
echo -e "${BOLD}${GREEN}✅ AI is configured and ready!${RESET}"
echo ""
echo -e "  Run your assessment normally — AI analysis will activate automatically:"
echo -e "  ${CYAN}./pentest.sh -t example.com -e 'Engagement Name'${RESET}"
echo ""
echo -e "  To reconfigure: ${DIM}./setup-ai.sh${RESET}"
echo -e "  To disable AI:  ${DIM}rm ${CONFIG_FILE}${RESET}"
echo ""
