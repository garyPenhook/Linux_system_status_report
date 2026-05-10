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

## Report Sections

- System summary
- Operating system
- CPU
- Memory
- Disk usage
- Network addresses
- Listening sockets
- Top CPU processes
- Logged-in users

The generated HTML report is intentionally ignored by Git because it contains
machine-specific status information.
