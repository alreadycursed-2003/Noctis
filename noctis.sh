#!/usr/bin/env bash
# =============================================================================
# pentest.sh — Main orchestrator for PentestAutomator v1.0
#
# USAGE:
#   ./pentest.sh -t <target> [options]
#
# LEGAL NOTICE:
#   This tool is for authorized security testing ONLY. You must have explicit
#   written permission to test any target. Unauthorized use is illegal under
#   the Computer Fraud and Abuse Act (CFAA) and equivalent laws worldwide.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/ai.sh"

# ── Load modules ──────────────────────────────────────────────────────────────
source "${SCRIPT_DIR}/modules/recon.sh"
source "${SCRIPT_DIR}/modules/portscan.sh"
source "${SCRIPT_DIR}/modules/vulnscan.sh"
source "${SCRIPT_DIR}/modules/report.sh"

# ── Defaults ──────────────────────────────────────────────────────────────────
TARGET=""
ENGAGEMENT_NAME="Pentest Engagement"
SCOPE_FILE=""
MODULES="all"          # all | recon | portscan | vulnscan | report
SCAN_TYPE="full"       # quick | full | stealth
OUTPUT_BASE="${SCRIPT_DIR}/reports"
SKIP_CONFIRM=false
TESTER="$(whoami)"
AI_CONFIG_FILE="${SCRIPT_DIR}/.ai_config"

# ── Help ──────────────────────────────────────────────────────────────────────
usage() {
    echo -e "${BOLD}${CYAN}PentestAutomator v1.0${RESET} — Authorized engagements only\n"
    echo -e "Usage: ${BOLD}$0 -t <target>${RESET} [options]\n"
    echo "Options:"
    printf "  %-30s %s\n" "-t, --target <host/IP>"       "Target hostname or IP (required)"
    printf "  %-30s %s\n" "-e, --engagement <name>"      "Engagement name (default: 'Pentest Engagement')"
    printf "  %-30s %s\n" "-s, --scope-file <file>"      "Path to authorized scope file (one entry per line)"
    printf "  %-30s %s\n" "-m, --modules <list>"         "Modules to run: all|recon|portscan|vulnscan|report"
    printf "  %-30s %s\n" "                              "  "  Comma-separate multiple: recon,portscan"
    printf "  %-30s %s\n" "--scan-type <type>"           "Scan depth: quick|full (default: full)"
    printf "  %-30s %s\n" "-o, --output <dir>"           "Output directory (default: ./reports/)"
    printf "  %-30s %s\n" "--tester <name>"              "Tester name for report (default: current user)"
    printf "  %-30s %s\n" "-y, --yes"                    "Skip confirmation prompt"
    printf "  %-30s %s\n" "-h, --help"                   "Show this help"
    echo ""
    echo -e "${BOLD}Examples:${RESET}"
    echo "  # Full assessment"
    echo "  $0 -t example.com -e 'Client Corp Q1 2025' -s scope.txt"
    echo ""
    echo "  # Quick recon only"
    echo "  $0 -t 192.168.1.1 -m recon --scan-type quick -y"
    echo ""
    echo "  # Port scan + vuln scan, skip recon"
    echo "  $0 -t 10.0.0.5 -m portscan,vulnscan"
    echo ""
    echo -e "${DIM}  Scope file format: one hostname, IP, or regex per line. Lines starting with # are comments.${RESET}"
    echo ""
}

# ── Argument parsing ──────────────────────────────────────────────────────────
parse_args() {
    [[ $# -eq 0 ]] && usage && exit 1

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -t|--target)         TARGET="$2";          shift 2 ;;
            -e|--engagement)     ENGAGEMENT_NAME="$2"; shift 2 ;;
            -s|--scope-file)     SCOPE_FILE="$2";      shift 2 ;;
            -m|--modules)        MODULES="$2";         shift 2 ;;
            --scan-type)         SCAN_TYPE="$2";       shift 2 ;;
            -o|--output)         OUTPUT_BASE="$2";     shift 2 ;;
            --tester)            TESTER="$2";          shift 2 ;;
            -y|--yes)            SKIP_CONFIRM=true;    shift   ;;
            --no-ai)             AI_PROVIDER="";       shift   ;;
            --ai-config)         AI_CONFIG_FILE="$2";  shift 2 ;;
            -h|--help)           usage; exit 0 ;;
            *) log_error "Unknown option: $1"; usage; exit 1 ;;
        esac
    done
}

# ── Module selector ───────────────────────────────────────────────────────────
should_run() {
    local module="$1"
    [[ "$MODULES" == "all" ]] && return 0
    echo "$MODULES" | tr ',' '\n' | grep -qx "$module"
}

# ── Authorization confirmation ────────────────────────────────────────────────
confirm_authorization() {
    echo ""
    echo -e "${RED}${BOLD}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${RED}${BOLD}║             ⚠️   LEGAL AUTHORIZATION REQUIRED   ⚠️             ║${RESET}"
    echo -e "${RED}${BOLD}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    echo -e "  Target    : ${BOLD}${CYAN}${TARGET}${RESET}"
    echo -e "  Engagement: ${BOLD}${ENGAGEMENT_NAME}${RESET}"
    echo -e "  Modules   : ${BOLD}${MODULES}${RESET}"
    echo -e "  Scan type : ${BOLD}${SCAN_TYPE}${RESET}"
    [[ -n "$SCOPE_FILE" ]] && echo -e "  Scope file: ${BOLD}${SCOPE_FILE}${RESET}"
    echo ""
    echo -e "  ${YELLOW}By proceeding, you confirm that:${RESET}"
    echo -e "  ${DIM}1. You have explicit written authorization to test this target.${RESET}"
    echo -e "  ${DIM}2. This assessment is within your defined scope of work.${RESET}"
    echo -e "  ${DIM}3. You understand and accept full legal responsibility.${RESET}"
    echo ""

    read -rp "  Type 'AUTHORIZED' to confirm and proceed: " confirmation
    if [[ "$confirmation" != "AUTHORIZED" ]]; then
        echo ""
        log_error "Authorization not confirmed. Aborting."
        exit 1
    fi
    echo ""
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
    parse_args "$@"
    print_banner

    # Validate required args
    if [[ -z "$TARGET" ]]; then
        log_error "Target is required. Use -t <hostname/IP>"
        usage
        exit 1
    fi

    # Validate scan type
    if [[ "$SCAN_TYPE" != "quick" && "$SCAN_TYPE" != "full" ]]; then
        log_error "Invalid scan type: $SCAN_TYPE. Use quick or full."
        exit 1
    fi

    # Check nmap is available before anything else
    require_tool nmap || exit 1

    # Scope check
    if [[ -n "$SCOPE_FILE" ]]; then
        validate_scope "$TARGET" "$SCOPE_FILE" || exit 1
    fi

    # Initialize AI (load config if exists)
    if [[ -f "$AI_CONFIG_FILE" && -n "${AI_PROVIDER+x}" ]]; then
        load_ai_config "$AI_CONFIG_FILE"
    fi
    if init_ai 2>/dev/null; then
        echo -e "  ${MAGENTA}${BOLD}🤖 AI:${RESET} ${AI_PROVIDER} / ${AI_MODEL}"
    else
        echo -e "  ${DIM}🤖 AI: disabled (run ./setup-ai.sh to enable)${RESET}"
    fi

    # Confirmation
    if [[ "$SKIP_CONFIRM" != true ]]; then
        confirm_authorization
    fi

    # Create output directory
    local OUTDIR
    OUTDIR=$(make_output_dir "$OUTPUT_BASE" "$TARGET")
    LOG_FILE="${OUTDIR}/pentest.log"
    touch "$LOG_FILE"

    echo -e "  ${GREEN}${BOLD}Output directory:${RESET} ${CYAN}${OUTDIR}${RESET}"
    echo -e "  ${GREEN}${BOLD}Log file:${RESET} ${CYAN}${LOG_FILE}${RESET}"
    echo ""

    log_info "Starting engagement: ${BOLD}${ENGAGEMENT_NAME}${RESET}"
    log_info "Target: ${BOLD}${TARGET}${RESET} | Scan type: ${BOLD}${SCAN_TYPE}${RESET}"

    local total_start; total_start=$(timer_start)

    # ── Run modules ────────────────────────────────────────────────────────────
    if should_run "recon"; then
        run_recon "$TARGET" "$OUTDIR"
        ai_analyze_recon "$OUTDIR" "$TARGET"
    fi

    if should_run "portscan"; then
        run_portscan "$TARGET" "$OUTDIR" "$SCAN_TYPE"
        ai_analyze_ports "$OUTDIR" "$TARGET"
    fi

    if should_run "vulnscan"; then
        run_vulnscan "$TARGET" "$OUTDIR"
        ai_analyze_vulns "$OUTDIR" "$TARGET"
    fi

    # AI executive summary (if multiple modules ran)
    ai_executive_summary "$OUTDIR" "$TARGET" "$ENGAGEMENT_NAME"

    if should_run "report"; then
        run_report "$TARGET" "$OUTDIR" "$ENGAGEMENT_NAME" "$TESTER"
    fi

    # ── Final summary ──────────────────────────────────────────────────────────
    local total_elapsed; total_elapsed=$(timer_end "$total_start")

    echo ""
    echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${BOLD}${GREEN}  ✅  Assessment Complete${RESET}"
    echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
    echo -e "  Total time  : ${BOLD}${total_elapsed}${RESET}"
    echo -e "  Output dir  : ${CYAN}${OUTDIR}${RESET}"
    echo -e "  Log         : ${CYAN}${LOG_FILE}${RESET}"
    [[ -f "${OUTDIR}/report.md" ]]              && echo -e "  MD Report       : ${CYAN}${OUTDIR}/report.md${RESET}"
    [[ -f "${OUTDIR}/report.html" ]]            && echo -e "  HTML Report     : ${CYAN}${OUTDIR}/report.html${RESET}"
    [[ -f "${OUTDIR}/ai_executive_summary.md" ]] && echo -e "  ${MAGENTA}🤖 AI Summary   : ${OUTDIR}/ai_executive_summary.md${RESET}"
    [[ -f "${OUTDIR}/ai_vuln_triage.md" ]]      && echo -e "  ${MAGENTA}🤖 AI Triage    : ${OUTDIR}/ai_vuln_triage.md${RESET}"
    [[ -f "${OUTDIR}/ai_port_analysis.md" ]]    && echo -e "  ${MAGENTA}🤖 AI Playbook  : ${OUTDIR}/ai_port_analysis.md${RESET}"
    [[ -f "${OUTDIR}/ai_recon_analysis.md" ]]   && echo -e "  ${MAGENTA}🤖 AI Recon     : ${OUTDIR}/ai_recon_analysis.md${RESET}"
    echo ""
    echo -e "  ${DIM}Reminder: Handle all findings in accordance with your engagement's${RESET}"
    echo -e "  ${DIM}data handling and disclosure agreements.${RESET}"
    echo ""
}

main "$@"
