#!/bin/bash
# Import log file into SQLite database

LOG_FILE="logs/app.log"
DB_FILE="data/insights.db"

echo "🗄️  Log Importer"
echo "================"
echo ""

# Check if log file exists
if [ ! -f "$LOG_FILE" ]; then
    echo "❌ Error: $LOG_FILE not found!"
    echo "   Run ./generate_logs.sh first"
    exit 1
fi

# Remove old database
rm -f "$DB_FILE"

echo "📋 Creating database schema..."

# Create the database and table
sqlite3 "$DB_FILE" << 'SCHEMA'
CREATE TABLE requests (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ip TEXT NOT NULL,
    user TEXT,
    timestamp TEXT,
    method TEXT,
    endpoint TEXT,
    protocol TEXT,
    status INTEGER,
    bytes INTEGER,
    response_time REAL
);

CREATE INDEX idx_ip ON requests(ip);
CREATE INDEX idx_status ON requests(status);
CREATE INDEX idx_endpoint ON requests(endpoint);
CREATE INDEX idx_user ON requests(user);
SCHEMA

echo "✅ Schema created"
echo ""
echo "📥 Importing log entries..."

# Count total lines
total=$(wc -l < "$LOG_FILE")
count=0
batch_size=100
sql_batch=""

# Read and parse each line
while IFS= read -r line; do
    # Parse the log line
    # Format: IP - USER [TIMESTAMP] "METHOD ENDPOINT PROTOCOL" STATUS BYTES RESPONSE_TIME
    
    ip=$(echo "$line" | awk '{print $1}')
    user=$(echo "$line" | awk '{print $3}')
    timestamp=$(echo "$line" | awk -F'[][]' '{print $2}')
    method=$(echo "$line" | awk -F'"' '{print $2}' | awk '{print $1}')
    endpoint=$(echo "$line" | awk -F'"' '{print $2}' | awk '{print $2}')
    protocol=$(echo "$line" | awk -F'"' '{print $2}' | awk '{print $3}')
    status=$(echo "$line" | awk '{print $9}')
    bytes=$(echo "$line" | awk '{print $10}')
    response_time=$(echo "$line" | awk '{print $11}')
    
    # Handle empty user
    [ "$user" = "-" ] && user="anonymous"
    
    # Build SQL insert
    sql_batch+="INSERT INTO requests (ip, user, timestamp, method, endpoint, protocol, status, bytes, response_time) VALUES ('$ip', '$user', '$timestamp', '$method', '$endpoint', '$protocol', $status, $bytes, $response_time);"
    
    count=$((count + 1))
    
    # Execute batch
    if [ $((count % batch_size)) -eq 0 ]; then
        echo "$sql_batch" | sqlite3 "$DB_FILE"
        sql_batch=""
        printf "\r   Progress: %d/%d entries (%.0f%%)" "$count" "$total" "$((count * 100 / total))"
    fi
    
done < "$LOG_FILE"

# Insert remaining
if [ -n "$sql_batch" ]; then
    echo "$sql_batch" | sqlite3 "$DB_FILE"
fi

echo ""
echo ""
echo "✅ Import complete!"
echo ""
echo "📊 Database Stats:"
sqlite3 "$DB_FILE" -header -column "
SELECT 
    COUNT(*) as total_requests,
    SUM(CASE WHEN status >= 500 THEN 1 ELSE 0 END) as errors,
    COUNT(DISTINCT ip) as unique_ips,
    COUNT(DISTINCT user) as unique_users,
    COUNT(DISTINCT endpoint) as unique_endpoints
FROM requests;"
echo ""
echo "🔍 Try these queries:"
echo "   sqlite3 data/insights.db -header -column \"SELECT * FROM requests LIMIT 5;\""
echo "   sqlite3 data/insights.db -header -column \"SELECT ip, COUNT(*) as cnt FROM requests GROUP BY ip ORDER BY cnt DESC;\""
