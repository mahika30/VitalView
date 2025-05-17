# VitalView

**VitalView** is a lightweight system monitoring tool designed to track and log vital system metrics on Unix-like operating systems. It provides real-time insights into system performance, helping users to monitor resource utilization effectively.

## Features

* **Real-Time Monitoring**: Continuously tracks CPU usage, memory consumption, disk usage, and network activity.
* **Daily Summaries**: Generates daily summary reports of system metrics for performance analysis.
* **Shell Script Implementation**: Built entirely using shell scripts, ensuring minimal dependencies and ease of customization.
* **Modular Design**: Comprises separate scripts for monitoring and summary generation, allowing flexibility in usage.

## Getting Started

### Prerequisites

* Unix-like operating system (e.g., Linux, macOS)
* Bash shell
* Standard Unix utilities: `top`, `df`, `free`, `ifconfig`/`ip`, `awk`, `grep`, `sed`

### Installation

1. **Clone the Repository**:

   ```bash
   git clone https://github.com/mahika30/VitalView.git
   cd VitalView
   ```

2. **Make Scripts Executable**:

   ```bash
   chmod +x system_monitor.sh
   chmod +x generate_daily_summary.sh
   ```

## Usage

### Real-Time Monitoring

Run the `system_monitor.sh` script to start monitoring system metrics:

```bash
./system_monitor.sh
```

This script will display real-time statistics of CPU, memory, disk, and network usage.

### Generate Daily Summary

To generate a summary report of the day's system performance:

```bash
./generate_daily_summary.sh
```

The summary will be saved to a file (e.g., `daily_summary_YYYYMMDD.txt`) in the current directory.

## Customization

* **Monitoring Interval**: Modify the sleep duration in `system_monitor.sh` to change the frequency of updates.
* **Metrics Tracked**: Edit the scripts to add or remove specific metrics as per your requirements.
* **Output Format**: Customize the output formatting within the scripts to suit your preferences.
