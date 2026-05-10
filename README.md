# Linux System Status Report

Bash report generator that collects local Linux system statistics and writes an
HTML status report.

## Usage

```bash
./system_status_report.sh
```

This writes `report.html` in the current directory.

To choose a different output path:

```bash
./system_status_report.sh -o status.html
```

To choose selected sections:

```bash
./system_status_report.sh --sections summary,cpu,memory,temperature
```

To skip noisy sections:

```bash
./system_status_report.sh --skip sockets,logins
```

To list all available section names:

```bash
./system_status_report.sh --list-sections
```

## Options

- `-h`, `--help`: show help text
- `-o`, `--output FILE`: write report to a chosen HTML file
- `-t`, `--title TEXT`: set the report title
- `--sections LIST`: include only comma-separated sections
- `--only LIST`: alias for `--sections`
- `--skip LIST`: skip comma-separated sections
- `--list-sections`: print section names and exit

## Report Sections

- System summary
- Operating system
- CPU
- Memory
- Disk usage
- Temperature
- Network addresses
- Listening sockets
- Top CPU processes
- Logged-in users

Temperature data uses `sensors` from `lm-sensors` when available. If `sensors`
is not installed, the script falls back to Linux thermal data under
`/sys/class/thermal` and `/sys/class/hwmon`.

The generated HTML report is intentionally ignored by Git because it contains
machine-specific status information.
