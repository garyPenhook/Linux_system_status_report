# Linux System Status Report

Bash report generator that collects local Linux system statistics and writes an
HTML status report.

The script is self-contained and uses common Linux command-line tools. It is
intended for quick local snapshots of machine status, not long-term monitoring.

## Requirements

- Bash
- Standard Linux tools such as `date`, `hostname`, `uname`, `awk`, `ps`, and
  `head`
- Optional: `free`, `df`, `ip`, `ss`, and `sensors`

The temperature section works best with `sensors` from `lm-sensors`. If
`sensors` is not installed, the script falls back to thermal data exposed by the
kernel under `/sys/class/thermal` and `/sys/class/hwmon`.

## Usage

```bash
./system_status_report.sh
```

This writes `report.html` in the current directory.

To choose a different output path:

```bash
./system_status_report.sh -o status.html
```

To set the title shown in the HTML page:

```bash
./system_status_report.sh --title "Laptop Status" -o laptop.html
```

To include only selected sections:

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

| Option | Description |
| --- | --- |
| `-h`, `--help` | Show help text. |
| `-o`, `--output FILE` | Write report to a chosen HTML file. Default: `report.html`. |
| `-t`, `--title TEXT` | Set the report title used by the HTML `<title>` and page heading. |
| `--sections LIST` | Include only comma-separated sections. |
| `--only LIST` | Alias for `--sections`. |
| `--skip LIST` | Skip comma-separated sections from the default report. |
| `--list-sections` | Print section names and exit. |

## Report Sections

Use these names with `--sections`, `--only`, and `--skip`.

| Section | Name | Data Source |
| --- | --- | --- |
| System summary | `summary` | `date`, `hostname`, `uname`, `uptime`, current user |
| Operating system | `os` | `/etc/os-release` |
| CPU | `cpu` | `/proc/cpuinfo` |
| Memory | `memory` | `free -h` or `/proc/meminfo` |
| Disk usage | `disk` | `df -hT` |
| Temperature | `temperature` | `sensors`, `/sys/class/thermal`, `/sys/class/hwmon` |
| Network addresses | `network` | `ip -brief address` or `hostname -I` |
| Listening sockets | `sockets` | `ss -tulpen` |
| Top CPU processes | `processes` | `ps` sorted by CPU usage |
| Logged-in users | `logins` | `who` |

## Examples

Full default report:

```bash
./system_status_report.sh
```

Temperature-focused report:

```bash
./system_status_report.sh --title "Temperature Check" \
  --sections summary,temperature \
  -o temperature.html
```

Smaller report without sockets or login data:

```bash
./system_status_report.sh --skip sockets,logins -o slim-report.html
```

Report with a custom title and output file:

```bash
./system_status_report.sh -t "Workstation Status" -o workstation-status.html
```

## Generated Files

The generated HTML report is intentionally ignored by Git because it contains
machine-specific status information.

The repository ignores `*.html`, so generated reports can be created freely in
the project directory without being accidentally committed.

## Validation

Run these checks after editing the script:

```bash
/home/gary/.codex/skills/wicked-cool-shell-scripts/scripts/check-shell-script.sh system_status_report.sh
shellcheck system_status_report.sh
shfmt -d -i 2 -ci system_status_report.sh
./system_status_report.sh -o report.html
```
