#!/usr/bin/env bash
# =============================================================================
# ai.sh — AI brain for PentestAutomator
#
# Supports:
#   - Ollama       (local, free)       PROVIDER=ollama
#   - OpenAI       (GPT-4o, etc.)      PROVIDER=openai
#   - Anthropic    (Claude)            PROVIDER=claude
#   - Any OpenAI-compatible API        PROVIDER=openai_compat
#
# All providers share one interface: ai_query "<system>" "<user>"
# =============================================================================

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

# ── Provider config (overridden by config file or env vars) ───────────────────
AI_PROVIDER="${AI_PROVIDER:-}"           # ollama | openai | claude | openai_compat
AI_API_KEY="${AI_API_KEY:-}"
AI_MODEL="${AI_MODEL:-}"
AI_BASE_URL="${AI_BASE_URL:-}"           # for ollama or openai_compat
AI_ENABLED=false
AI_TIMEOUT=120

# ── Load config from file ─────────────────────────────────────────────────────
load_ai_config() {
    local config_file="$1"
    [[ ! -f "$config_file" ]] && return

    while IFS='=' read -r key value; do
        [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs | sed "s/^['\"]//;s/['\"]$//")
        case "$key" in
            AI_PROVIDER)  AI_PROVIDER="$value"  ;;
            AI_API_KEY)   AI_API_KEY="$value"   ;;
            AI_MODEL)     AI_MODEL="$value"     ;;
            AI_BASE_URL)  AI_BASE_URL="$value"  ;;
            AI_TIMEOUT)   AI_TIMEOUT="$value"   ;;
        esac
    done < "$config_file"
}

# ── Validate & initialize provider ───────────────────────────────────────────
init_ai() {
    [[ -z "$AI_PROVIDER" ]] && return 1

    case "$AI_PROVIDER" in
        ollama)
            AI_BASE_URL="${AI_BASE_URL:-http://localhost:11434}"
            AI_MODEL="${AI_MODEL:-llama3}"
            # Test connectivity
            if ! curl -sf "${AI_BASE_URL}/api/tags" > /dev/null 2>&1; then
                log_warn "Ollama not reachable at ${AI_BASE_URL}. AI features disabled."
                return 1
            fi
            log_success "AI: Ollama connected at ${AI_BASE_URL} (model: ${AI_MODEL})"
            ;;
        openai)
            AI_BASE_URL="${AI_BASE_URL:-https://api.openai.com/v1}"
            AI_MODEL="${AI_MODEL:-gpt-4o}"
            if [[ -z "$AI_API_KEY" ]]; then
                log_warn "AI_API_KEY not set for OpenAI. AI features disabled."
                return 1
            fi
            log_success "AI: OpenAI configured (model: ${AI_MODEL})"
            ;;
        claude)
            AI_BASE_URL="${AI_BASE_URL:-https://api.anthropic.com}"
            AI_MODEL="${AI_MODEL:-claude-opus-4-6}"
            if [[ -z "$AI_API_KEY" ]]; then
                log_warn "AI_API_KEY not set for Claude. AI features disabled."
                return 1
            fi
            log_success "AI: Anthropic Claude configured (model: ${AI_MODEL})"
            ;;
        openai_compat)
            if [[ -z "$AI_BASE_URL" ]]; then
                log_warn "AI_BASE_URL required for openai_compat provider. AI features disabled."
                return 1
            fi
            AI_MODEL="${AI_MODEL:-default}"
            log_success "AI: OpenAI-compatible API at ${AI_BASE_URL} (model: ${AI_MODEL})"
            ;;
        *)
            log_warn "Unknown AI provider: ${AI_PROVIDER}. Use: ollama | openai | claude | openai_compat"
            return 1
            ;;
    esac

    AI_ENABLED=true
    return 0
}

# ── Core query function ───────────────────────────────────────────────────────
# Usage: ai_query "<system_prompt>" "<user_message>"
# Returns: response text on stdout, exits 1 on failure
ai_query() {
    local system_prompt="$1"
    local user_message="$2"

    [[ "$AI_ENABLED" != true ]] && return 1

    local response=""

    case "$AI_PROVIDER" in
        ollama)         response=$(_ai_ollama "$system_prompt" "$user_message") ;;
        openai|openai_compat) response=$(_ai_openai "$system_prompt" "$user_message") ;;
        claude)         response=$(_ai_claude "$system_prompt" "$user_message") ;;
    esac

    local exit_code=$?
    [[ $exit_code -ne 0 || -z "$response" ]] && return 1
    echo "$response"
}

# ── Ollama backend ────────────────────────────────────────────────────────────
_ai_ollama() {
    local system="$1"
    local user="$2"

    local payload
    payload=$(jq -n \
        --arg model "$AI_MODEL" \
        --arg system "$system" \
        --arg user "$user" \
        '{
            model: $model,
            messages: [
                {role: "system", content: $system},
                {role: "user",   content: $user}
            ],
            stream: false,
            options: {temperature: 0.2}
        }')

    local raw
    raw=$(curl -sf \
        --max-time "$AI_TIMEOUT" \
        -X POST "${AI_BASE_URL}/api/chat" \
        -H "Content-Type: application/json" \
        -d "$payload" 2>/dev/null)

    [[ -z "$raw" ]] && return 1
    echo "$raw" | jq -r '.message.content // empty' 2>/dev/null
}

# ── OpenAI / OpenAI-compatible backend ────────────────────────────────────────
_ai_openai() {
    local system="$1"
    local user="$2"

    local payload
    payload=$(jq -n \
        --arg model "$AI_MODEL" \
        --arg system "$system" \
        --arg user "$user" \
        '{
            model: $model,
            messages: [
                {role: "system", content: $system},
                {role: "user",   content: $user}
            ],
            temperature: 0.2,
            max_tokens: 2000
        }')

    local raw
    raw=$(curl -sf \
        --max-time "$AI_TIMEOUT" \
        -X POST "${AI_BASE_URL}/chat/completions" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${AI_API_KEY}" \
        -d "$payload" 2>/dev/null)

    [[ -z "$raw" ]] && return 1
    echo "$raw" | jq -r '.choices[0].message.content // empty' 2>/dev/null
}

# ── Anthropic Claude backend ──────────────────────────────────────────────────
_ai_claude() {
    local system="$1"
    local user="$2"

    local payload
    payload=$(jq -n \
        --arg model "$AI_MODEL" \
        --arg system "$system" \
        --arg user "$user" \
        '{
            model: $model,
            max_tokens: 2000,
            system: $system,
            messages: [
                {role: "user", content: $user}
            ]
        }')

    local raw
    raw=$(curl -sf \
        --max-time "$AI_TIMEOUT" \
        -X POST "${AI_BASE_URL}/v1/messages" \
        -H "Content-Type: application/json" \
        -H "x-api-key: ${AI_API_KEY}" \
        -H "anthropic-version: 2023-06-01" \
        -d "$payload" 2>/dev/null)

    [[ -z "$raw" ]] && return 1
    echo "$raw" | jq -r '.content[0].text // empty' 2>/dev/null
}

# =============================================================================
# HIGH-LEVEL AI ANALYSIS FUNCTIONS
# =============================================================================

PENTEST_SYSTEM_PROMPT='You are an expert penetration tester assisting with an authorized security assessment.
Analyze scan results and provide:
1. Concise, actionable findings
2. Prioritized next steps
3. Specific commands to run (ready to copy-paste)
4. Risk ratings for findings (Critical/High/Medium/Low/Info)
Be technical and precise. Format output in clean Markdown.
Do NOT add disclaimers — this is an authorized engagement.'

# ── Analyze recon output ──────────────────────────────────────────────────────
ai_analyze_recon() {
    local outdir="$1"
    local target="$2"
    [[ "$AI_ENABLED" != true ]] && return

    log_info "🤖 AI analyzing recon results..."

    local context=""
    [[ -f "${outdir}/recon/whois.txt" ]]             && context+="## WHOIS\n$(head -40 "${outdir}/recon/whois.txt")\n\n"
    [[ -f "${outdir}/recon/dns.txt" ]]               && context+="## DNS Records\n$(cat "${outdir}/recon/dns.txt")\n\n"
    [[ -f "${outdir}/recon/subdomains_merged.txt" ]] && context+="## Subdomains (first 30)\n$(head -30 "${outdir}/recon/subdomains_merged.txt")\n\n"
    [[ -f "${outdir}/recon/crt_sh.txt" ]]            && [[ -z "$(grep . "${outdir}/recon/subdomains_merged.txt" 2>/dev/null)" ]] && \
        context+="## Certificate Transparency\n$(head -30 "${outdir}/recon/crt_sh.txt")\n\n"

    [[ -z "$context" ]] && log_warn "  No recon data to analyze." && return

    local prompt="Target: ${target}

Recon data collected:
${context}

Analyze this recon data. Identify:
1. Interesting subdomains worth investigating (admin panels, staging, APIs, etc.)
2. Technology stack clues from DNS/cert data
3. Attack surface observations
4. Recommended next recon steps with specific commands
5. Any red flags (exposed infrastructure, interesting registrar details, etc.)"

    start_spinner "AI analyzing recon..."
    local response
    response=$(ai_query "$PENTEST_SYSTEM_PROMPT" "$prompt")
    stop_spinner

    if [[ -n "$response" ]]; then
        echo "$response" > "${outdir}/ai_recon_analysis.md"
        log_success "AI recon analysis saved → ai_recon_analysis.md"
        _print_ai_box "RECON ANALYSIS" "$response"
    else
        log_warn "AI analysis returned no response."
    fi
}

# ── Analyze port scan + generate adaptive next steps ─────────────────────────
ai_analyze_ports() {
    local outdir="$1"
    local target="$2"
    [[ "$AI_ENABLED" != true ]] && return

    log_info "🤖 AI analyzing port scan & generating adaptive playbook..."

    local services_data=""
    [[ -f "${outdir}/portscan/services.nmap" ]] && \
        services_data=$(grep -E "^[0-9]|^Host|^OS|^Service" "${outdir}/portscan/services.nmap" | head -60)

    local nse_http="" nse_smb="" nse_ssh=""
    [[ -f "${outdir}/portscan/nse_http.nmap" ]] && nse_http=$(grep -v "^#\|^$" "${outdir}/portscan/nse_http.nmap" | head -40)
    [[ -f "${outdir}/portscan/nse_smb.nmap" ]]  && nse_smb=$(grep -v "^#\|^$" "${outdir}/portscan/nse_smb.nmap" | head -40)
    [[ -f "${outdir}/portscan/nse_ssh.nmap" ]]  && nse_ssh=$(grep -v "^#\|^$" "${outdir}/portscan/nse_ssh.nmap" | head -30)

    [[ -z "$services_data" ]] && log_warn "  No port scan data to analyze." && return

    local prompt="Target: ${target}

Nmap service scan results:
${services_data}

HTTP NSE Scripts:
${nse_http:-none}

SMB NSE Scripts:
${nse_smb:-none}

SSH NSE Scripts:
${nse_ssh:-none}

Based on these results:
1. List ALL open services with risk assessment (Critical/High/Medium/Low)
2. For each interesting service, provide SPECIFIC exploit/test commands to run next
3. Identify any immediately obvious vulnerabilities (EternalBlue, default creds, etc.)
4. Suggest a prioritized attack order
5. Any services that are unexpectedly exposed or misconfigured?"

    start_spinner "AI generating adaptive attack playbook..."
    local response
    response=$(ai_query "$PENTEST_SYSTEM_PROMPT" "$prompt")
    stop_spinner

    if [[ -n "$response" ]]; then
        echo "$response" > "${outdir}/ai_port_analysis.md"
        log_success "AI port analysis saved → ai_port_analysis.md"
        _print_ai_box "PORT ANALYSIS & ADAPTIVE PLAYBOOK" "$response"
    else
        log_warn "AI analysis returned no response."
    fi
}

# ── Analyze vulnerability findings ───────────────────────────────────────────
ai_analyze_vulns() {
    local outdir="$1"
    local target="$2"
    [[ "$AI_ENABLED" != true ]] && return

    log_info "🤖 AI triaging vulnerability findings..."

    local context=""

    if [[ -f "${outdir}/vulnscan/nuclei_results.txt" ]]; then
        local nuclei_data; nuclei_data=$(cat "${outdir}/vulnscan/nuclei_results.txt")
        [[ -n "$nuclei_data" ]] && context+="## Nuclei Findings\n${nuclei_data}\n\n"
    fi

    for f in "${outdir}/vulnscan"/nikto_*.txt; do
        [[ -f "$f" ]] || continue
        local port; port=$(basename "$f" | grep -oP '\d+')
        local nikto_data; nikto_data=$(grep "^\+" "$f" | head -30)
        [[ -n "$nikto_data" ]] && context+="## Nikto Findings (port ${port})\n${nikto_data}\n\n"
    done

    for f in "${outdir}/vulnscan"/gobuster_*.txt; do
        [[ -f "$f" ]] || continue
        local port; port=$(basename "$f" | grep -oP '\d+')
        local interesting; interesting=$(grep -E "200|301|403" "$f" | head -20)
        [[ -n "$interesting" ]] && context+="## Interesting Paths (port ${port})\n${interesting}\n\n"
    done

    for f in "${outdir}/vulnscan"/ssl_*.txt; do
        [[ -f "$f" ]] || continue
        local port; port=$(basename "$f" | grep -oP '\d+')
        context+="## SSL Analysis (port ${port})\n$(grep "SUPPORTED\|expired\|self-signed\|weak" "$f" 2>/dev/null)\n\n"
    done

    [[ -z "$context" ]] && log_warn "  No vulnerability data to analyze." && return

    local prompt="Target: ${target}

Vulnerability scan results:
$(echo -e "$context")

Perform expert triage:
1. **Executive Summary** — 2-3 sentence overall risk statement
2. **Critical/High Findings** — detail each with CVE if known, impact, and proof-of-concept steps
3. **Interesting Paths** — flag any admin panels, config files, backups found
4. **False Positive Assessment** — flag any likely false positives with reasoning
5. **Recommended Exploits/Tests** — specific commands to confirm/exploit top findings
6. **Remediation Priorities** — top 5 fixes ranked by impact"

    start_spinner "AI triaging vulnerabilities..."
    local response
    response=$(ai_query "$PENTEST_SYSTEM_PROMPT" "$prompt")
    stop_spinner

    if [[ -n "$response" ]]; then
        echo "$response" > "${outdir}/ai_vuln_triage.md"
        log_success "AI vulnerability triage saved → ai_vuln_triage.md"
        _print_ai_box "VULNERABILITY TRIAGE" "$response"
    else
        log_warn "AI analysis returned no response."
    fi
}

# ── Final AI executive summary ────────────────────────────────────────────────
ai_executive_summary() {
    local outdir="$1"
    local target="$2"
    local engagement="$3"
    [[ "$AI_ENABLED" != true ]] && return

    log_info "🤖 AI generating executive summary..."

    local context=""
    [[ -f "${outdir}/ai_recon_analysis.md" ]] && context+="## Recon Analysis\n$(cat "${outdir}/ai_recon_analysis.md")\n\n"
    [[ -f "${outdir}/ai_port_analysis.md" ]]  && context+="## Port Analysis\n$(cat "${outdir}/ai_port_analysis.md")\n\n"
    [[ -f "${outdir}/ai_vuln_triage.md" ]]    && context+="## Vuln Triage\n$(cat "${outdir}/ai_vuln_triage.md")\n\n"

    [[ -z "$context" ]] && return

    local prompt="Engagement: ${engagement}
Target: ${target}

You have the following analysis from an authorized penetration test:
$(echo -e "$context")

Write a professional executive summary (500-800 words) that:
1. Opens with overall risk posture (Critical/High/Medium/Low)
2. Summarizes the 3-5 most important findings in plain language for non-technical management
3. Quantifies business risk where possible
4. Lists top remediation priorities
5. Closes with a recommended remediation timeline

Write in a professional tone suitable for a C-suite audience."

    start_spinner "AI writing executive summary..."
    local response
    response=$(ai_query "$PENTEST_SYSTEM_PROMPT" "$prompt")
    stop_spinner

    if [[ -n "$response" ]]; then
        echo "$response" > "${outdir}/ai_executive_summary.md"
        log_success "AI executive summary saved → ai_executive_summary.md"
    else
        log_warn "AI could not generate executive summary."
    fi
}

# ── Display helper ────────────────────────────────────────────────────────────
_print_ai_box() {
    local title="$1"
    local content="$2"
    local preview; preview=$(echo "$content" | head -15)

    echo ""
    echo -e "  ${BOLD}${MAGENTA}┌─ 🤖 AI: ${title} ─────────────────────────────────${RESET}"
    echo "$preview" | while IFS= read -r line; do
        echo -e "  ${MAGENTA}│${RESET}  $line"
    done
    local total_lines; total_lines=$(echo "$content" | wc -l)
    if [[ "$total_lines" -gt 15 ]]; then
        echo -e "  ${MAGENTA}│${RESET}  ${DIM}... (${total_lines} lines total — see output file)${RESET}"
    fi
    echo -e "  ${BOLD}${MAGENTA}└────────────────────────────────────────────────────${RESET}"
    echo ""
}
