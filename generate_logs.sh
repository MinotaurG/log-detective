#!/bin/bash
# Log Generator - Creates realistic fake web server logs
# with hidden patterns for analysis practice

# Configuration
LOG_FILE="logs/app.log"
NUM_ENTRIES=1000

# Arrays of possible values
IPS=(
    "192.168.1.100"
    "192.168.1.101"
    "192.168.1.102"
    "10.0.0.50"
    "10.0.0.51"
    "172.16.0.200"    # This will be our "bad" IP
    "203.0.113.42"
    "198.51.100.73"
)

USERS=(
    "john"
    "jane"
    "admin"
    "bot_user"        # This one will be suspicious
    "alice"
    "bob"
    "guest"
    "-"               # Anonymous user
)

ENDPOINTS=(
    "/api/users"
    "/api/products"
    "/api/orders"
    "/api/payments"   # This one will be slow
    "/api/search"
    "/api/auth/login"
    "/api/auth/logout"
    "/health"
    "/api/reports"
    "/"
)

METHODS=("GET" "POST" "PUT" "DELETE")

# Function to generate random number in range
random_range() {
    local min=$1
    local max=$2
    echo $(( RANDOM % (max - min + 1) + min ))
}

# Function to pick random element from array
random_element() {
    local arr=("$@")
    local index=$(( RANDOM % ${#arr[@]} ))
    echo "${arr[$index]}"
}

# Function to generate timestamp within last 24 hours
generate_timestamp() {
    local hours_ago=$(random_range 0 23)
    local mins=$(random_range 0 59)
    local secs=$(random_range 0 59)
    
    # Calculate timestamp
    local timestamp=$(date -d "$hours_ago hours ago" "+%d/%b/%Y:${hours_ago}:${mins}:${secs} +0000" 2>/dev/null)
    
    # Fallback for systems where date -d doesn't work well
    if [ -z "$timestamp" ]; then
        timestamp=$(date "+%d/%b/%Y:%H:%M:%S +0000")
    fi
    
    echo "$timestamp"
}

# Function to determine status code with patterns
generate_status() {
    local ip=$1
    local endpoint=$2
    local hour=$3
    
    local rand=$(random_range 1 100)
    
    # Pattern 1: Bad IP (172.16.0.200) has 40% error rate
    if [ "$ip" == "172.16.0.200" ]; then
        if [ $rand -le 40 ]; then
            echo "500"
            return
        fi
    fi
    
    # Pattern 2: Lunch hour (12:xx) has more errors
    if [ "$hour" == "12" ]; then
        if [ $rand -le 25 ]; then
            echo "500"
            return
        fi
    fi
    
    # Normal distribution of status codes
    if [ $rand -le 85 ]; then
        echo "200"
    elif [ $rand -le 90 ]; then
        echo "201"
    elif [ $rand -le 93 ]; then
        echo "304"
    elif [ $rand -le 95 ]; then
        echo "400"
    elif [ $rand -le 97 ]; then
        echo "401"
    elif [ $rand -le 98 ]; then
        echo "404"
    elif [ $rand -le 99 ]; then
        echo "500"
    else
        echo "503"
    fi
}

# Function to generate response time with patterns
generate_response_time() {
    local endpoint=$1
    local status=$2
    
    # Pattern: /api/payments is slow (0.5-2.0 seconds)
    if [ "$endpoint" == "/api/payments" ]; then
        local ms=$(random_range 500 2000)
        awk "BEGIN {printf \"%.3f\", $ms/1000}"
        return
    fi
    
    # Errors are often slow
    if [ "$status" == "500" ] || [ "$status" == "503" ]; then
        local ms=$(random_range 1000 5000)
        awk "BEGIN {printf \"%.3f\", $ms/1000}"
        return
    fi
    
    # Normal requests: 10-200ms
    local ms=$(random_range 10 200)
    awk "BEGIN {printf \"%.3f\", $ms/1000}"
}

# Function to generate bytes
generate_bytes() {
    local status=$1
    local endpoint=$2
    
    # Errors return small responses
    if [[ "$status" =~ ^5 ]]; then
        echo $(random_range 100 500)
        return
    fi
    
    # Different endpoints return different sizes
    case $endpoint in
        "/health")
            echo $(random_range 20 50)
            ;;
        "/api/reports")
            echo $(random_range 5000 50000)
            ;;
        *)
            echo $(random_range 500 5000)
            ;;
    esac
}

# Main generation logic
echo "🔧 Generating $NUM_ENTRIES log entries..."
echo ""

# Clear existing log file
> "$LOG_FILE"

# Progress tracking
progress_interval=$((NUM_ENTRIES / 10))

for i in $(seq 1 $NUM_ENTRIES); do
    # Select values with patterns
    
    # Pattern: bot_user makes 20% of all requests
    if [ $(random_range 1 100) -le 20 ]; then
        user="bot_user"
    else
        user=$(random_element "${USERS[@]}")
    fi
    
    # Pattern: bad IP makes 15% of requests
    if [ $(random_range 1 100) -le 15 ]; then
        ip="172.16.0.200"
    else
        ip=$(random_element "${IPS[@]}")
    fi
    
    endpoint=$(random_element "${ENDPOINTS[@]}")
    method=$(random_element "${METHODS[@]}")
    
    # Generate timestamp and extract hour
    timestamp=$(generate_timestamp)
    hour=$(echo "$timestamp" | cut -d':' -f2)
    
    # Generate status based on patterns
    status=$(generate_status "$ip" "$endpoint" "$hour")
    
    # Generate response time based on patterns
    response_time=$(generate_response_time "$endpoint" "$status")
    
    # Generate bytes
    bytes=$(generate_bytes "$status" "$endpoint")
    
    # Write log entry
    echo "$ip - $user [$timestamp] \"$method $endpoint HTTP/1.1\" $status $bytes $response_time" >> "$LOG_FILE"
    
    # Show progress
    if [ $((i % progress_interval)) -eq 0 ]; then
        percent=$((i * 100 / NUM_ENTRIES))
        echo -ne "\r  Progress: $percent% ($i/$NUM_ENTRIES entries)"
    fi
done

echo -e "\n"
echo "✅ Log generation complete!"
echo ""
echo "📊 Summary:"
echo "   File: $LOG_FILE"
echo "   Entries: $NUM_ENTRIES"
echo "   Size: $(du -h $LOG_FILE | cut -f1)"
echo ""
echo "📋 Sample entries:"
echo "   First: $(head -1 $LOG_FILE)"
echo "   Last:  $(tail -1 $LOG_FILE)"
echo ""
echo "🔍 Hidden patterns to discover:"
echo "   - Which IP causes the most errors?"
echo "   - Which endpoint is slowest?"
echo "   - What time has the most errors?"
echo "   - Which user makes the most requests?"
