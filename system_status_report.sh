#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  cat >&2 <<EOF
Usage: ${0##*/} [options]

Options:
  -h, --help              Show this help text.
  -o, --output FILE       Write report to FILE. Default: report.html.
  -t, --title TEXT        Set the HTML report title.
      --sections LIST     Include only comma-separated sections.
      --only LIST         Alias for --sections.
      --skip LIST         Skip comma-separated sections from the default report.
      --list-sections     Print available section names and exit.

Available sections:
  summary, os, cpu, memory, disk, temperature, network, sockets, processes, logins

Examples:
  ${0##*/} -o report.html
  ${0##*/} --title "Laptop Status" --sections summary,cpu,memory,temperature
  ${0##*/} --skip sockets,logins
EOF
}

html_escape() {
  sed \
    -e 's/&/\&amp;/g' \
    -e 's/</\&lt;/g' \
    -e 's/>/\&gt;/g' \
    -e 's/"/\&quot;/g' \
    -e "s/'/\&#39;/g"
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

section_title() {
  case "$1" in
    summary) printf 'System Summary' ;;
    os) printf 'Operating System' ;;
    cpu) printf 'CPU' ;;
    memory) printf 'Memory' ;;
    disk) printf 'Disk Usage' ;;
    temperature) printf 'Temperature' ;;
    network) printf 'Network Addresses' ;;
    sockets) printf 'Listening Sockets' ;;
    processes) printf 'Top CPU Processes' ;;
    logins) printf 'Logged-In Users' ;;
    *) return 1 ;;
  esac
}

section_command() {
  case "$1" in
    summary) printf 'system_summary' ;;
    os) printf 'os_release' ;;
    cpu) printf 'cpu_summary' ;;
    memory) printf 'memory_summary' ;;
    disk) printf 'disk_summary' ;;
    temperature) printf 'temperature_summary' ;;
    network) printf 'network_summary' ;;
    sockets) printf 'socket_summary' ;;
    processes) printf 'process_summary' ;;
    logins) printf 'login_summary' ;;
    *) return 1 ;;
  esac
}

list_sections() {
  printf '%s\n' summary os cpu memory disk temperature network sockets processes logins
}

run_section() {
  local title=$1
  local escaped_title
  shift

  escaped_title=$(printf '%s' "$title" | html_escape)
  printf '<section>\n<h2>%s</h2>\n<pre>\n' "$escaped_title"
  if "$@" 2>&1 | html_escape; then
    :
  else
    printf 'Command failed: %s\n' "$*" | html_escape
  fi
  printf '</pre>\n</section>\n'
}

system_summary() {
  printf 'Generated: %s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')"
  printf 'Hostname:  %s\n' "$(hostname)"
  printf 'Kernel:    %s\n' "$(uname -srmo)"
  printf 'Uptime:    %s\n' "$(uptime -p 2>/dev/null || uptime)"
  printf 'User:      %s\n' "${USER:-unknown}"
}

os_release() {
  if [[ -r /etc/os-release ]]; then
    awk -F= '
      $1 == "PRETTY_NAME" {
        gsub(/^"|"$/, "", $2)
        print $2
      }
    ' /etc/os-release
  else
    printf 'OS release information unavailable\n'
  fi
}

cpu_summary() {
  if [[ -r /proc/cpuinfo ]]; then
    awk -F: '
      $1 ~ /^model name/ && !model { sub(/^ /, "", $2); model=$2 }
      $1 ~ /^processor/ { count++ }
      END {
        printf "CPU model: %s\n", model ? model : "unknown"
        printf "CPU cores: %d\n", count ? count : 0
      }
    ' /proc/cpuinfo
  else
    printf 'CPU information unavailable\n'
  fi
}

memory_summary() {
  if command_exists free; then
    free -h
  elif [[ -r /proc/meminfo ]]; then
    awk '/MemTotal|MemAvailable|SwapTotal|SwapFree/ { print }' /proc/meminfo
  else
    printf 'Memory information unavailable\n'
  fi
}

disk_summary() {
  if command_exists df; then
    df -hT -x tmpfs -x devtmpfs
  else
    printf 'Disk usage information unavailable\n'
  fi
}

temperature_summary() {
  local found=0
  local name
  local temp_file
  local type_file
  local raw

  if command_exists sensors; then
    sensors
    return 0
  fi

  for temp_file in /sys/class/thermal/thermal_zone*/temp; do
    [[ -r "$temp_file" ]] || continue
    type_file=${temp_file%/temp}/type
    name=${temp_file%/temp}
    name=${name##*/}
    if [[ -r "$type_file" ]]; then
      name=$(<"$type_file")
    fi
    raw=$(<"$temp_file")
    if [[ $raw =~ ^-?[0-9]+$ ]]; then
      awk -v name="$name" -v raw="$raw" 'BEGIN { printf "%-24s %.1f C\n", name ":", raw / 1000 }'
      found=1
    fi
  done

  for temp_file in /sys/class/hwmon/hwmon*/temp*_input; do
    [[ -r "$temp_file" ]] || continue
    name=${temp_file%_input}_label
    if [[ -r "$name" ]]; then
      name=$(<"$name")
    elif [[ -r "${temp_file%/*}/name" ]]; then
      name=$(<"${temp_file%/*}/name")
    else
      name=${temp_file##*/}
      name=${name%_input}
    fi
    raw=$(<"$temp_file")
    if [[ $raw =~ ^-?[0-9]+$ ]]; then
      awk -v name="$name" -v raw="$raw" 'BEGIN { printf "%-24s %.1f C\n", name ":", raw / 1000 }'
      found=1
    fi
  done

  if ((found == 0)); then
    printf 'Temperature data unavailable. Install lm-sensors or expose thermal data under /sys/class/thermal or /sys/class/hwmon.\n'
  fi
}

network_summary() {
  if command_exists ip; then
    ip -brief address
  else
    hostname -I 2>/dev/null || printf 'Network address information unavailable\n'
  fi
}

socket_summary() {
  if command_exists ss; then
    ss -tulpen
  else
    printf 'Socket summary unavailable: ss is not installed\n'
  fi
}

process_summary() {
  ps -eo pid,ppid,user,stat,%cpu,%mem,comm --sort=-%cpu | head -n 16
}

login_summary() {
  who 2>/dev/null || printf 'Login information unavailable\n'
}

write_report() {
  local output=$1
  local report_title=$2
  shift 2
  local selected_sections=("$@")
  local escaped_report_title
  local section
  local title
  local command_name
  local tmp
  tmp=$(mktemp)
  trap 'rm -f "$tmp"' RETURN
  escaped_report_title=$(printf '%s' "$report_title" | html_escape)

  {
    cat <<'HTML'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
HTML
    printf '<title>%s</title>\n' "$escaped_report_title"
    cat <<'HTML'
<style>
:root {
  color-scheme: light dark;
  --bg: #f7f8fa;
  --fg: #1d232a;
  --muted: #586474;
  --panel: #ffffff;
  --border: #cfd6df;
  --accent: #176b87;
}
@media (prefers-color-scheme: dark) {
  :root {
    --bg: #101418;
    --fg: #e7ebef;
    --muted: #aab4c0;
    --panel: #171d23;
    --border: #303943;
    --accent: #5fb3ce;
  }
}
* { box-sizing: border-box; }
body {
  margin: 0;
  background: var(--bg);
  color: var(--fg);
  font: 15px/1.45 system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
}
main {
  max-width: 1120px;
  margin: 0 auto;
  padding: 32px 20px;
}
header {
  border-bottom: 3px solid var(--accent);
  margin-bottom: 22px;
  padding-bottom: 14px;
}
h1 {
  font-size: 2rem;
  margin: 0 0 4px;
}
.subtitle {
  color: var(--muted);
  margin: 0;
}
section {
  background: var(--panel);
  border: 1px solid var(--border);
  border-radius: 8px;
  margin: 18px 0;
  overflow: hidden;
}
h2 {
  border-bottom: 1px solid var(--border);
  font-size: 1.05rem;
  margin: 0;
  padding: 12px 14px;
}
pre {
  margin: 0;
  overflow-x: auto;
  padding: 14px;
  white-space: pre;
}
footer {
  color: var(--muted);
  font-size: .9rem;
  margin-top: 24px;
}
</style>
</head>
<body>
<main>
<header>
HTML
    printf '<h1>%s</h1>\n' "$escaped_report_title"
    cat <<'HTML'
<p class="subtitle">Generated by Bash from local system status commands.</p>
</header>
HTML
    for section in "${selected_sections[@]}"; do
      title=$(section_title "$section")
      command_name=$(section_command "$section")
      run_section "$title" "$command_name"
    done
    cat <<'HTML'
<footer>Report content reflects command output at generation time.</footer>
</main>
</body>
</html>
HTML
  } >"$tmp"

  mv "$tmp" "$output"
  chmod u=rw,go=r "$output"
  trap - RETURN
}

main() {
  local -a all_sections=(summary os cpu memory disk temperature network sockets processes logins)
  local -a selected_sections=("${all_sections[@]}")
  local -A selected=()
  local section
  local output=report.html
  local report_title='System Status Report'

  set_selected_sections() {
    local list=$1
    local entry
    local -a parsed=()

    IFS=',' read -r -a parsed <<<"$list"
    selected_sections=()
    selected=()
    for entry in "${parsed[@]}"; do
      entry=${entry//[[:space:]]/}
      [[ -n "$entry" ]] || continue
      if ! section_title "$entry" >/dev/null; then
        printf 'Unknown section: %s\n' "$entry" >&2
        usage
        return 2
      fi
      if [[ -z ${selected[$entry]+set} ]]; then
        selected_sections+=("$entry")
        selected[$entry]=1
      fi
    done
    if ((${#selected_sections[@]} == 0)); then
      printf 'At least one section must be selected.\n' >&2
      usage
      return 2
    fi
  }

  skip_sections() {
    local list=$1
    local entry
    local -a parsed=()
    local -A skip=()
    local -a kept=()

    IFS=',' read -r -a parsed <<<"$list"
    for entry in "${parsed[@]}"; do
      entry=${entry//[[:space:]]/}
      [[ -n "$entry" ]] || continue
      if ! section_title "$entry" >/dev/null; then
        printf 'Unknown section: %s\n' "$entry" >&2
        usage
        return 2
      fi
      skip[$entry]=1
    done

    for section in "${selected_sections[@]}"; do
      if [[ -z ${skip[$section]+set} ]]; then
        kept+=("$section")
      fi
    done
    selected_sections=("${kept[@]}")
    if ((${#selected_sections[@]} == 0)); then
      printf 'At least one section must remain after --skip.\n' >&2
      usage
      return 2
    fi
  }

  while (($# > 0)); do
    case "$1" in
      -h | --help)
        usage
        return 0
        ;;
      -o | --output)
        if (($# < 2)); then
          printf '%s requires an argument.\n' "$1" >&2
          usage
          return 2
        fi
        output=$2
        shift 2
        ;;
      --output=*)
        output=${1#*=}
        shift
        ;;
      -t | --title)
        if (($# < 2)); then
          printf '%s requires an argument.\n' "$1" >&2
          usage
          return 2
        fi
        report_title=$2
        shift 2
        ;;
      --title=*)
        report_title=${1#*=}
        shift
        ;;
      --sections | --only)
        if (($# < 2)); then
          printf '%s requires an argument.\n' "$1" >&2
          usage
          return 2
        fi
        set_selected_sections "$2"
        shift 2
        ;;
      --sections=* | --only=*)
        set_selected_sections "${1#*=}"
        shift
        ;;
      --skip)
        if (($# < 2)); then
          printf '%s requires an argument.\n' "$1" >&2
          usage
          return 2
        fi
        skip_sections "$2"
        shift 2
        ;;
      --skip=*)
        skip_sections "${1#*=}"
        shift
        ;;
      --list-sections)
        list_sections
        return 0
        ;;
      --)
        shift
        break
        ;;
      -*)
        printf 'Unknown option: %s\n' "$1" >&2
        usage
        return 2
        ;;
      *)
        break
        ;;
    esac
  done

  if (($# > 0)); then
    usage
    return 2
  fi

  write_report "$output" "$report_title" "${selected_sections[@]}"
  printf 'Wrote %s\n' "$output"
}

main "$@"
