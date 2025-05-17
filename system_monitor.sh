#!/bin/bash

# Configuration and data directories
CONFIG_DIR="$HOME/.config/system_monitor"
CONFIG_FILE="$CONFIG_DIR/config.conf"
SUMMARIES_DIR="$HOME/.local/share/system_monitor/summaries"

# Ensure directories exist
mkdir -p "$CONFIG_DIR" "$SUMMARIES_DIR"

# Check if dialog is installed
if ! command -v dialog >/dev/null 2>&1; then
    echo "Error: dialog is not installed. Please install it to use this tool (e.g., sudo apt install dialog)."
    exit 1
fi

# Check if user can read auth.log
if [ ! -r "/var/log/auth.log" ]; then
    echo "Warning: Cannot read /var/log/auth.log. Please ensure you have permission (e.g., be in the adm group)."
fi

# Function to read config values
get_config() {
    local key="$1"
    if [ -f "$CONFIG_FILE" ]; then
        grep "^$key=" "$CONFIG_FILE" | cut -d'=' -f2
    else
        echo "true"  # Default to true if config file doesn't exist
    fi
}

# Function to generate system report
get_system_report() {
    local report=""
    
    if [ "$(get_config show_uptime)" = "true" ]; then
        report+="Uptime: $(uptime -p)\n\n"
    fi
    
    if [ "$(get_config show_disk_space)" = "true" ]; then
        report+="Disk Space:\n$(df -h / | awk 'NR==2 {print $0}')\n\n"
    fi
    
    if [ "$(get_config show_memory_usage)" = "true" ]; then
        report+="Memory Usage: $(free -h | awk '/Mem:/ {print $3 "/" $2}')\n\n"
    fi
    
    if [ "$(get_config show_logged_in_users)" = "true" ]; then
        report+="Logged-in Users: $(who | wc -l)\n\n"
    fi
    
    if [ "$(get_config show_cpu_load)" = "true" ]; then
        report+="CPU Load: $(uptime | awk -F'load average:' '{print $2}')\n\n"
    fi
    
    if [ "$(get_config show_motivational_quote)" = "true" ]; then
        if command -v fortune >/dev/null 2>&1; then
            report+="Motivational Quote:\n$(fortune)\n"
        else
            report+="Motivational Quote:\nKeep shining, you're doing great!\n"
        fi
    fi
    
    echo -e "$report"
}

# Function to generate sudo summary for a given date
generate_sudo_summary() {
    local date="$1"  # Expected format: YYYY-MM-DD
    local pattern=$(date -d "$date" +"%b %e")
    local output_file="$SUMMARIES_DIR/$date.txt"
    
    if [ -r "/var/log/auth.log" ]; then
        grep "^$pattern" /var/log/auth.log | grep "sudo:" | awk -F' ' '/sudo:/ {
            time=$3; user=$6; cmd_index=match($0, "COMMAND="); cmd=substr($0, cmd_index+8);
            print time " " user " " cmd
        }' > "$output_file"
    else
        dialog --msgbox "Cannot read /var/log/auth.log. Please ensure you have permission." 10 50
        return 1
    fi
}

# Function to view sudo activity log
view_sudo_log() {
    dialog --calendar "Select date for sudo log (use arrow keys, Enter to select):" 0 0 2>/tmp/date.txt
    if [ $? -ne 0 ]; then return; fi
    
    local date=$(awk -F'/' '{print $3"-"$2"-"$1}' /tmp/date.txt)
    rm -f /tmp/date.txt
    
    local summary_file="$SUMMARIES_DIR/$date.txt"
    if [ ! -f "$summary_file" ]; then
        dialog --yesno "No summary exists for $date. Generate it now?" 7 50
        if [ $? -eq 0 ]; then
            generate_sudo_summary "$date"
        else
            return
        fi
    fi
    
    if [ -s "$summary_file" ]; then
        dialog --textbox "$summary_file" 20 80
    else
        dialog --msgbox "No sudo activity recorded for $date." 7 50
    fi
}

# Function to export sudo logs
export_sudo_log() {
    dialog --calendar "Select date to export sudo logs:" 0 0 2>/tmp/date.txt
    if [ $? -ne 0 ]; then return; fi
    
    local date=$(awk -F'/' '{print $3"-"$2"-"$1}' /tmp/date.txt)
    rm -f /tmp/date.txt
    
    local summary_file="$SUMMARIES_DIR/$date.txt"
    if [ ! -f "$summary_file" ]; then
        dialog --yesno "No summary exists for $date. Generate it now?" 7 50
        if [ $? -eq 0 ]; then
            generate_sudo_summary "$date"
        else
            return
        fi
    fi
    
    if [ ! -s "$summary_file" ]; then
        dialog --msgbox "No sudo activity to export for $date." 7 50
        return
    fi
    
    dialog --menu "Choose export format:" 10 40 2 \
        1 "CSV" \
        2 "JSON" 2>/tmp/format.txt
    if [ $? -ne 0 ]; then return; fi
    
    local format=$( [ "$(cat /tmp/format.txt)" = "1" ] && echo "CSV" || echo "JSON" )
    rm -f /tmp/format.txt
    
    dialog --inputbox "Enter filename to save (e.g., sudo_log_$date.$format):" 8 50 "sudo_log_$date.$format" 2>/tmp/filename.txt
    if [ $? -ne 0 ]; then return; fi
    
    local output_file=$(cat /tmp/filename.txt)
    rm -f /tmp/filename.txt
    
    if [ "$format" = "CSV" ]; then
        echo "time,user,command" > "$output_file"
        while read -r time user cmd; do
            echo "$time,$user,\"$cmd\"" >> "$output_file"
        done < "$summary_file"
    elif [ "$format" = "JSON" ]; then
        echo "[" > "$output_file"
        first=true
        while read -r time user cmd; do
            if [ "$first" = true ]; then
                first=false
            else
                echo "," >> "$output_file"
            fi
            echo "{\"time\": \"$time\", \"user\": \"$user\", \"command\": \"$cmd\"}" >> "$output_file"
        done < "$summary_file"
        echo "]" >> "$output_file"
    fi
    
    dialog --msgbox "Sudo log exported to $output_file" 7 50
}

# Function to setup cron for daily sudo summary
setup_cron() {
    local script_path="$HOME/bin/generate_daily_summary.sh"
    local cron_entry="0 0 * * * $script_path"
    
    dialog --yesno "This will add a cron job to run daily sudo summary at midnight.\nEnsure $script_path exists.\nProceed?" 10 50
    if [ $? -ne 0 ]; then return; fi
    
    if [ -f "$script_path" ]; then
        (crontab -l 2>/dev/null; echo "$cron_entry") | crontab -
        dialog --msgbox "Cron job added successfully!\nDaily sudo summaries will be generated at midnight." 8 50
    else
        dialog --msgbox "Error: $script_path not found. Please create the script first." 8 50
    fi
}

# Function to manage settings
settings() {
    local current_uptime=$(get_config show_uptime)
    local current_disk=$(get_config show_disk_space)
    local current_memory=$(get_config show_memory_usage)
    local current_users=$(get_config show_logged_in_users)
    local current_cpu=$(get_config show_cpu_load)
    local current_quote=$(get_config show_motivational_quote)
    local current_notification=$(get_config daily_notification)
    
    dialog --checklist "Customize System Report and Notifications (use Space to select):" 15 50 7 \
        1 "Uptime" "$( [ "$current_uptime" = "true" ] && echo "on" || echo "off")" \
        2 "Disk Space" "$( [ "$current_disk" = "true" ] && echo "on" || echo "off")" \
        3 "Memory Usage" "$( [ "$current_memory" = "true" ] && echo "on" || echo "off")" \
        4 "Logged-in Users" "$( [ "$current_users" = "true" ] && echo "on" || echo "off")" \
        5 "CPU Load" "$( [ "$current_cpu" = "true" ] && echo "on" || echo "off")" \
        6 "Motivational Quote" "$( [ "$current_quote" = "true" ] && echo "on" || echo "off")" \
        7 "Daily Notification at Login" "$( [ "$current_notification" = "true" ] && echo "on" || echo "off")" 2>/tmp/settings.txt
    if [ $? -ne 0 ]; then return; fi
    
    local selections=$(cat /tmp/settings.txt | tr -d '"')
    rm -f /tmp/settings.txt
    
    # Update config file
    cat > "$CONFIG_FILE" <<EOF
show_uptime=$(echo "$selections" | grep -q "1" && echo "true" || echo "false")
show_disk_space=$(echo "$selections" | grep -q "2" && echo "true" || echo "false")
show_memory_usage=$(echo "$selections" | grep -q "3" && echo "true" || echo "false")
show_logged_in_users=$(echo "$selections" | grep -q "4" && echo "true" || echo "false")
show_cpu_load=$(echo "$selections" | grep -q "5" && echo "true" || echo "false")
show_motivational_quote=$(echo "$selections" | grep -q "6" && echo "true" || echo "false")
daily_notification=$(echo "$selections" | grep -q "7" && echo "true" || echo "false")
EOF
    
    # Handle daily notification autostart
    local autostart_dir="$HOME/.config/autostart"
    local desktop_file="$autostart_dir/system_monitor.desktop"
    if echo "$selections" | grep -q "7"; then
        mkdir -p "$autostart_dir"
        cat > "$desktop_file" <<EOF
[Desktop Entry]
Type=Application
Exec=$(realpath "$0") --daily-notification
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=System Monitor Daily Notification
Comment=Show daily system report at login
EOF
    else
        rm -f "$desktop_file"
    fi
    
    dialog --msgbox "Settings saved successfully!" 7 40
}

# Function to show daily notification
show_daily_notification() {
    if [ "$(get_config daily_notification)" = "true" ]; then
        local report=$(get_system_report)
        echo -e "$report" >/tmp/report.txt
        dialog --textbox /tmp/report.txt 20 60
        rm -f /tmp/report.txt
    fi
}

# Welcome screen
dialog --title "Welcome to System Monitor" --msgbox "\ZbWelcome to System Monitor!\Zb\n\nThis tool helps you monitor system health and track sudo activity.\nUse arrow keys to navigate, Enter to select, and Esc to cancel." 10 60

# Main menu
main_menu() {
    dialog --colors --menu "\ZbSystem Monitor Main Menu\Zb\nSelect an option:" 15 50 6 \
        1 "View Today's System Report" \
        2 "View Sudo Activity Log" \
        3 "Export Sudo Logs" \
        4 "Settings" \
        5 "Setup Daily Sudo Summary (Cron)" \
        6 "Exit" 2>/tmp/menu.txt
    if [ $? -ne 0 ]; then exit 0; fi
    
    local choice=$(cat /tmp/menu.txt)
    rm -f /tmp/menu.txt
    
    case "$choice" in
        1)
            local report=$(get_system_report)
            echo -e "$report" >/tmp/report.txt
            dialog --textbox /tmp/report.txt 20 60
            rm -f /tmp/report.txt
            ;;
        2)
            view_sudo_log
            ;;
        3)
            export_sudo_log
            ;;
        4)
            settings
            ;;
        5)
            setup_cron
            ;;
        6)
            dialog --msgbox "Thank you for using System Monitor!" 7 40
            exit 0
            ;;
    esac
}

# Check for daily notification flag
if [ "$1" = "--daily-notification" ]; then
    show_daily_notification
    exit 0
fi

# Run main menu in a loop
while true; do
    main_menu
done
