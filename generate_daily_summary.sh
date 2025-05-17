#!/bin/bash

# Directory for summaries
SUMMARIES_DIR="$HOME/.local/share/system_monitor/summaries"
mkdir -p "$SUMMARIES_DIR"

# Generate summary for yesterday
yesterday=$(date -d "yesterday" +"%Y-%m-%d")
pattern=$(date -d "$yesterday" +"%b %e")

if [ -r "/var/log/auth.log" ]; then
    grep "^$pattern" /var/log/auth.log | grep "sudo:" | awk -F' ' '/sudo:/ {
        time=$3; user=$6; cmd_index=match($0, "COMMAND="); cmd=substr($0, cmd_index+8);
        print time " " user " " cmd
    }' > "$SUMMARIES_DIR/$yesterday.txt"
else
    echo "Error: Cannot read /var/log/auth.log. Please ensure you have permission."
    exit 1
fi
