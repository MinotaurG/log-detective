#!/bin/bash
# Log Detective - Analysis Toolkit
# Usage: ./analyze.sh [command]

LOG_FILE="logs/app.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Check if log file exists
check_log() {
    if [ ! -f "$LOG_FILE" ]; then
        echo -e "${RED}Error: $LOG_FILE not found!${NC}"
        echo "Run ./generate_logs.sh first"
        exit 1
    fi
}

# Show help menu
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
    echo -e "  ${GREEN}report${NC}       Generate full incident report"
    echo ""
    echo -e "${BOLD}Examples:${NC}"
    echo "  ./analyze.sh summary"
    echo "  ./analyze.sh errors"
    echo "  ./analyze.sh investigate 172.16.0.200"
}

# Summary command
cmd_summary() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                    📊 ${BOLD}LOG SUMMARY${NC}                           ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    total=$(wc -l < "$LOG_FILE")
    errors_5xx=$(grep -cE " 5[0-9]{2} " "$LOG_FILE")
    errors_4xx=$(grep -cE " 4[0-9]{2} " "$LOG_FILE")
    success=$(grep -cE " 2[0-9]{2} " "$LOG_FILE")
    
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
    echo ""
    
    echo -e "  ${BOLD}Top 5 Endpoints:${NC}"
    awk -F'"' '{print $2}' "$LOG_FILE" | awk '{print $2}' | sort | uniq -c | sort -rn | head -5 | while read count endpoint; do
        printf "    %-20s %s requests\n" "$endpoint" "$count"
    done
}

# Errors command
cmd_errors() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                    🚨 ${BOLD}ERROR ANALYSIS${NC}                        ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    total=$(wc -l < "$LOG_FILE")
    total_errors=$(grep -cE " 5[0-9]{2} " "$LOG_FILE")
    
    echo -e "  ${BOLD}Error Breakdown:${NC}"
    echo -e "  ─────────────────────────────────"
    grep -oE " 5[0-9]{2} " "$LOG_FILE" | sort | uniq -c | sort -rn | while read count code; do
        code=$(echo $code | xargs)
        printf "    Status %s: %s occurrences\n" "$code" "$count"
    done
    echo ""
    
    echo -e "  ${BOLD}Top 5 IPs Causing Errors:${NC}"
    echo -e "  ─────────────────────────────────"
    grep -E " 5[0-9]{2} " "$LOG_FILE" | awk '{print $1}' | sort | uniq -c | sort -rn | head -5 | while read count ip; do
        ip_total=$(grep -c "^$ip " "$LOG_FILE")
        rate=$(awk "BEGIN {printf \"%.1f\", ($count/$ip_total)*100}")
        printf "    %-18s %3s errors (%s%% of their requests)\n" "$ip" "$count" "$rate"
    done
    echo ""
    
    echo -e "  ${BOLD}Top 5 Endpoints with Errors:${NC}"
    echo -e "  ─────────────────────────────────"
    grep -E " 5[0-9]{2} " "$LOG_FILE" | awk -F'"' '{print $2}' | awk '{print $2}' | sort | uniq -c | sort -rn | head -5 | while read count endpoint; do
        printf "    %-20s %s errors\n" "$endpoint" "$count"
    done
    echo ""
    
    echo -e "  ${BOLD}Recent Errors (last 5):${NC}"
    echo -e "  ─────────────────────────────────"
    grep -E " 5[0-9]{2} " "$LOG_FILE" | tail -5 | while read line; do
        echo -e "    ${RED}$line${NC}"
    done
}

# Slow requests command
cmd_slow() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                    🐢 ${BOLD}SLOW REQUESTS${NC}                         ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    threshold=${1:-1.0}
    echo -e "  ${BOLD}Threshold:${NC} > ${threshold} seconds"
    echo ""
    
    echo -e "  ${BOLD}Average Response Time by Endpoint:${NC}"
    echo -e "  ─────────────────────────────────────"
    for endpoint in "/api/payments" "/api/orders" "/api/users" "/api/search" "/health" "/api/reports"; do
        count=$(grep "$endpoint" "$LOG_FILE" | wc -l)
        if [ $count -gt 0 ]; then
            avg=$(grep "$endpoint" "$LOG_FILE" | awk '{sum += $NF; count++} END {printf "%.3f", sum/count}')
            if (( $(echo "$avg > $threshold" | bc -l) )); then
                printf "    ${RED}%-20s %s sec (avg) - %s requests${NC}\n" "$endpoint" "$avg" "$count"
            else
                printf "    %-20s %s sec (avg) - %s requests\n" "$endpoint" "$avg" "$count"
            fi
        fi
    done
    echo ""
    
    echo -e "  ${BOLD}Top 10 Slowest Requests:${NC}"
    echo -e "  ─────────────────────────────────────"
    sort -t' ' -k11 -rn "$LOG_FILE" | head -10 | while read line; do
        time=$(echo "$line" | awk '{print $NF}')
        ip=$(echo "$line" | awk '{print $1}')
        endpoint=$(echo "$line" | awk -F'"' '{print $2}' | awk '{print $2}')
        status=$(echo "$line" | awk '{print $9}')
        printf "    %6s sec | %-15s | %-20s | %s\n" "$time" "$ip" "$endpoint" "$status"
    done
}

# IPs command
cmd_ips() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                    🌐 ${BOLD}IP ANALYSIS${NC}                           ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "  ${BOLD}All IPs by Request Count:${NC}"
    echo -e "  ─────────────────────────────────────────────────────────"
    printf "    ${BOLD}%-18s %8s %8s %8s${NC}\n" "IP Address" "Requests" "Errors" "Err Rate"
    echo -e "  ─────────────────────────────────────────────────────────"
    
    awk '{print $1}' "$LOG_FILE" | sort | uniq -c | sort -rn | while read count ip; do
        errors=$(grep "^$ip " "$LOG_FILE" | grep -cE " 5[0-9]{2} ")
        rate=$(awk "BEGIN {printf \"%.1f\", ($errors/$count)*100}")
        
        if (( $(echo "$rate > 20" | bc -l) )); then
            printf "    ${RED}%-18s %8s %8s %7s%%${NC}\n" "$ip" "$count" "$errors" "$rate"
        elif (( $(echo "$rate > 10" | bc -l) )); then
            printf "    ${YELLOW}%-18s %8s %8s %7s%%${NC}\n" "$ip" "$count" "$errors" "$rate"
        else
            printf "    %-18s %8s %8s %7s%%\n" "$ip" "$count" "$errors" "$rate"
        fi
    done
}

# Users command
cmd_users() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                    👤 ${BOLD}USER ANALYSIS${NC}                         ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    total=$(wc -l < "$LOG_FILE")
    
    echo -e "  ${BOLD}All Users by Request Count:${NC}"
    echo -e "  ─────────────────────────────────────────────────────────"
    printf "    ${BOLD}%-15s %8s %8s %8s %8s${NC}\n" "User" "Requests" "%" "Errors" "Err Rate"
    echo -e "  ─────────────────────────────────────────────────────────"
    
    awk '{print $3}' "$LOG_FILE" | sort | uniq -c | sort -rn | while read count user; do
        percent=$(awk "BEGIN {printf \"%.1f\", ($count/$total)*100}")
        errors=$(awk -v u="$user" '$3 == u' "$LOG_FILE" | grep -cE " 5[0-9]{2} ")
        err_rate=$(awk "BEGIN {printf \"%.1f\", ($errors/$count)*100}")
        
        # Flag suspicious users (>20% of traffic OR >20% error rate)
        if (( $(echo "$percent > 20" | bc -l) )) || (( $(echo "$err_rate > 20" | bc -l) )); then
            printf "    ${YELLOW}%-15s %8s %7s%% %8s %7s%%${NC} ⚠️\n" "$user" "$count" "$percent" "$errors" "$err_rate"
        else
            printf "    %-15s %8s %7s%% %8s %7s%%\n" "$user" "$count" "$percent" "$errors" "$err_rate"
        fi
    done
}

# Hourly command
cmd_hourly() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                    ⏰ ${BOLD}HOURLY ANALYSIS${NC}                       ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "  ${BOLD}Error Rate by Hour:${NC}"
    echo -e "  ─────────────────────────────────────────────────────────"
    printf "    ${BOLD}%5s %10s %8s %10s${NC}\n" "Hour" "Requests" "Errors" "Error Rate"
    echo -e "  ─────────────────────────────────────────────────────────"
    
    for hour in $(seq 0 23); do
        total=$(grep ":${hour}:" "$LOG_FILE" | wc -l)
        if [ $total -gt 0 ]; then
            errors=$(grep ":${hour}:" "$LOG_FILE" | grep -cE " 5[0-9]{2} ")
            rate=$(awk "BEGIN {printf \"%.1f\", ($errors/$total)*100}")
            
            # Visual bar
            bar_length=$(awk "BEGIN {printf \"%.0f\", $rate/2}")
            bar=$(printf '%*s' "$bar_length" | tr ' ' '█')
            
            if (( $(echo "$rate > 20" | bc -l) )); then
                printf "    ${RED}%5s %10s %8s %9s%% %s${NC}\n" "$hour:00" "$total" "$errors" "$rate" "$bar"
            elif (( $(echo "$rate > 10" | bc -l) )); then
                printf "    ${YELLOW}%5s %10s %8s %9s%% %s${NC}\n" "$hour:00" "$total" "$errors" "$rate" "$bar"
            else
                printf "    %5s %10s %8s %9s%% %s\n" "$hour:00" "$total" "$errors" "$rate" "$bar"
            fi
        fi
    done
}

# Main script logic
check_log

case "${1:-help}" in
    summary)
        cmd_summary
        ;;
    errors)
        cmd_errors
        ;;
    slow)
        cmd_slow "$2"
        ;;
    ips)
        cmd_ips
        ;;
    users)
        cmd_users
        ;;
    hourly)
        cmd_hourly
        ;;
    help|--help|-h|"")
        show_help
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        echo "Run './analyze.sh help' for usage"
        exit 1
        ;;
esac
