#!/bin/bash
# Log Detective - Analysis Toolkit
# Usage: ./analyze.sh [command]

LOG_FILE="logs/app.log"
DB_FILE="data/insights.db"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

check_log() {
    if [ ! -f "$LOG_FILE" ]; then
        echo -e "${RED}Error: $LOG_FILE not found!${NC}"
        echo "Run ./generate_logs.sh first"
        exit 1
    fi
}

check_db() {
    if [ ! -f "$DB_FILE" ]; then
        echo -e "${RED}Error: Database not found!${NC}"
        echo "Run ./import_logs.sh first"
        exit 1
    fi
}

show_help() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}            🔍 ${BOLD}LOG DETECTIVE - Analysis Toolkit${NC}              ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BOLD}Usage:${NC} ./analyze.sh [command]"
    echo ""
    echo -e "${BOLD}Commands:${NC}"
    echo -e "  ${GREEN}summary${NC}      Overview of log file stats"
    echo -e "  ${GREEN}errors${NC}       Analyze error patterns"
    echo -e "  ${GREEN}slow${NC}         Find slow requests"
    echo -e "  ${GREEN}ips${NC}          Analyze traffic by IP"
    echo -e "  ${GREEN}users${NC}        Analyze traffic by user"
    echo -e "  ${GREEN}hourly${NC}       Error rate by hour"
    echo -e "  ${GREEN}investigate${NC}  Deep dive on specific IP or user"
    echo -e "  ${GREEN}report${NC}       Generate full incident report (SQL)"
    echo ""
    echo -e "${BOLD}Examples:${NC}"
    echo "  ./analyze.sh summary"
    echo "  ./analyze.sh investigate 172.16.0.200"
    echo "  ./analyze.sh report"
}

cmd_summary() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                    📊 ${BOLD}LOG SUMMARY${NC}                           ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    total=$(wc -l < "$LOG_FILE")
    errors_5xx=$(awk '$9 ~ /^5[0-9][0-9]$/' "$LOG_FILE" | wc -l)
    errors_4xx=$(awk '$9 ~ /^4[0-9][0-9]$/' "$LOG_FILE" | wc -l)
    success=$(awk '$9 ~ /^2[0-9][0-9]$/' "$LOG_FILE" | wc -l)
    error_rate=$(awk "BEGIN {printf \"%.1f\", ($errors_5xx/$total)*100}")
    
    echo -e "  ${BOLD}Total Requests:${NC}  $total"
    echo -e "  ${GREEN}Success (2xx):${NC}   $success"
    echo -e "  ${YELLOW}Client Err (4xx):${NC} $errors_4xx"
    echo -e "  ${RED}Server Err (5xx):${NC} $errors_5xx (${error_rate}%)"
    echo ""
    
    echo -e "  ${BOLD}Top 5 IPs:${NC}"
    awk '{print $1}' "$LOG_FILE" | sort | uniq -c | sort -rn | head -5 | while read count ip; do
        printf "    %-18s %s requests\n" "$ip" "$count"
    done
}

cmd_errors() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                    🚨 ${BOLD}ERROR ANALYSIS${NC}                        ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "  ${BOLD}Top 5 IPs Causing Errors:${NC}"
    awk '$9 ~ /^5[0-9][0-9]$/ {print $1}' "$LOG_FILE" | sort | uniq -c | sort -rn | head -5 | while read count ip; do
        ip_total=$(grep -c "^$ip " "$LOG_FILE")
        rate=$(awk "BEGIN {printf \"%.1f\", ($count/$ip_total)*100}")
        printf "    %-18s %3s errors (%s%% error rate)\n" "$ip" "$count" "$rate"
    done
}

cmd_slow() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                    🐢 ${BOLD}SLOW REQUESTS${NC}                         ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "  ${BOLD}Average Response Time by Endpoint:${NC}"
    for endpoint in "/api/payments" "/api/orders" "/api/users" "/health"; do
        avg=$(grep "$endpoint" "$LOG_FILE" | awk '{sum += $NF; count++} END {printf "%.3f", sum/count}')
        count=$(grep -c "$endpoint" "$LOG_FILE")
        printf "    %-20s %s sec (%s requests)\n" "$endpoint" "$avg" "$count"
    done
}

cmd_ips() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                    🌐 ${BOLD}IP ANALYSIS${NC}                           ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    printf "    ${BOLD}%-18s %8s %8s %8s${NC}\n" "IP Address" "Requests" "Errors" "Err Rate"
    echo "    ─────────────────────────────────────────────────────"
    
    awk '{print $1}' "$LOG_FILE" | sort | uniq -c | sort -rn | while read count ip; do
        errors=$(awk -v ip="$ip" '$1 == ip && $9 ~ /^5[0-9][0-9]$/' "$LOG_FILE" | wc -l)
        rate=$(awk "BEGIN {printf \"%.1f\", ($errors/$count)*100}")
        printf "    %-18s %8s %8s %7s%%\n" "$ip" "$count" "$errors" "$rate"
    done
}

cmd_users() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                    👤 ${BOLD}USER ANALYSIS${NC}                         ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    total=$(wc -l < "$LOG_FILE")
    printf "    ${BOLD}%-15s %8s %8s${NC}\n" "User" "Requests" "% Traffic"
    echo "    ─────────────────────────────────────────"
    
    awk '{print $3}' "$LOG_FILE" | sort | uniq -c | sort -rn | while read count user; do
        pct=$(awk "BEGIN {printf \"%.1f\", ($count/$total)*100}")
        printf "    %-15s %8s %7s%%\n" "$user" "$count" "$pct"
    done
}

cmd_hourly() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                    ⏰ ${BOLD}HOURLY ANALYSIS${NC}                       ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    printf "    ${BOLD}%5s %8s %8s %10s${NC}\n" "Hour" "Requests" "Errors" "Error Rate"
    echo "    ─────────────────────────────────────────"
    
    for hour in $(seq 0 23); do
        total=$(grep ":${hour}:" "$LOG_FILE" | wc -l)
        if [ $total -gt 0 ]; then
            errors=$(grep ":${hour}:" "$LOG_FILE" | awk '$9 ~ /^5[0-9][0-9]$/' | wc -l)
            rate=$(awk "BEGIN {printf \"%.1f\", ($errors/$total)*100}")
            printf "    %5s %8s %8s %9s%%\n" "$hour:00" "$total" "$errors" "$rate"
        fi
    done
}

cmd_investigate() {
    local target="$1"
    
    if [ -z "$target" ]; then
        echo -e "${RED}Error: Specify an IP or username${NC}"
        echo "Usage: ./analyze.sh investigate <IP or username>"
        exit 1
    fi
    
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}              🔍 ${BOLD}INVESTIGATING: $target${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    if [[ "$target" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        matches=$(grep "^$target " "$LOG_FILE")
    else
        matches=$(awk -v user="$target" '$3 == user' "$LOG_FILE")
    fi
    
    total=$(echo "$matches" | grep -c .)
    errors=$(echo "$matches" | awk '$9 ~ /^5[0-9][0-9]$/' | wc -l)
    rate=$(awk "BEGIN {printf \"%.1f\", ($errors/$total)*100}")
    
    echo "  Total Requests: $total"
    echo "  Errors: $errors (${rate}%)"
}

cmd_report() {
    check_db
    
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}              📝 ${BOLD}INCIDENT REPORT${NC}                              ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}              $(date '+%Y-%m-%d %H:%M:%S')                           ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${BOLD}📊 EXECUTIVE SUMMARY${NC}"
    echo "────────────────────────────────────────────────────────────────"
    sqlite3 "$DB_FILE" -header -column "
    SELECT 
        COUNT(*) as total_requests,
        SUM(CASE WHEN status >= 500 THEN 1 ELSE 0 END) as server_errors,
        ROUND(100.0 * SUM(CASE WHEN status >= 500 THEN 1 ELSE 0 END) / COUNT(*), 2) as error_rate_pct,
        ROUND(AVG(response_time), 3) as avg_response_sec
    FROM requests;"
    echo ""
    
    echo -e "${BOLD}🚨 TOP OFFENDING IPs${NC}"
    echo "────────────────────────────────────────────────────────────────"
    sqlite3 "$DB_FILE" -header -column "
    SELECT ip, COUNT(*) as requests,
        SUM(CASE WHEN status >= 500 THEN 1 ELSE 0 END) as errors,
        ROUND(100.0 * SUM(CASE WHEN status >= 500 THEN 1 ELSE 0 END) / COUNT(*), 1) as error_rate
    FROM requests GROUP BY ip HAVING errors > 0 ORDER BY errors DESC LIMIT 5;"
    echo ""
    
    echo -e "${BOLD}🐢 SLOWEST ENDPOINTS${NC}"
    echo "────────────────────────────────────────────────────────────────"
    sqlite3 "$DB_FILE" -header -column "
    SELECT endpoint, COUNT(*) as requests,
        ROUND(AVG(response_time), 3) as avg_time,
        ROUND(MAX(response_time), 3) as max_time
    FROM requests GROUP BY endpoint ORDER BY avg_time DESC LIMIT 5;"
    echo ""
    
    echo -e "${BOLD}👤 USER ACTIVITY${NC}"
    echo "────────────────────────────────────────────────────────────────"
    sqlite3 "$DB_FILE" -header -column "
    SELECT user, COUNT(*) as requests,
        ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM requests), 1) as pct_traffic
    FROM requests GROUP BY user ORDER BY requests DESC;"
    echo ""
    
    echo -e "${BOLD}💡 RECOMMENDATIONS${NC}"
    echo "────────────────────────────────────────────────────────────────"
    
    bad_ip=$(sqlite3 "$DB_FILE" "SELECT ip FROM requests GROUP BY ip 
        HAVING ROUND(100.0 * SUM(CASE WHEN status >= 500 THEN 1 ELSE 0 END) / COUNT(*), 1) > 20
        ORDER BY SUM(CASE WHEN status >= 500 THEN 1 ELSE 0 END) DESC LIMIT 1;")
    [ -n "$bad_ip" ] && echo -e "  ${RED}⚠️  BLOCK/INVESTIGATE: $bad_ip (>20% error rate)${NC}"
    
    slow_ep=$(sqlite3 "$DB_FILE" "SELECT endpoint FROM requests GROUP BY endpoint 
        HAVING AVG(response_time) > 1.0 ORDER BY AVG(response_time) DESC LIMIT 1;")
    [ -n "$slow_ep" ] && echo -e "  ${YELLOW}⚠️  OPTIMIZE: $slow_ep (>1s avg response)${NC}"
    
    bot=$(sqlite3 "$DB_FILE" "SELECT user FROM requests GROUP BY user 
        HAVING ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM requests), 1) > 25 LIMIT 1;")
    [ -n "$bot" ] && echo -e "  ${YELLOW}⚠️  RATE LIMIT: $bot (>25% of traffic)${NC}"
    
    echo ""
    echo "────────────────────────────────────────────────────────────────"
    echo "Analyzed: $(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM requests;") log entries"
}

# Main
case "${1:-help}" in
    summary)     check_log; cmd_summary ;;
    errors)      check_log; cmd_errors ;;
    slow)        check_log; cmd_slow ;;
    ips)         check_log; cmd_ips ;;
    users)       check_log; cmd_users ;;
    hourly)      check_log; cmd_hourly ;;
    investigate) check_log; cmd_investigate "$2" ;;
    report)      cmd_report ;;
    help|--help|-h|"") show_help ;;
    *) echo -e "${RED}Unknown command: $1${NC}"; exit 1 ;;
esac
