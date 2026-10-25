# schedule: liga, desliga e mostra a verificação automática de novidades.
# Windows: Agendador de Tarefas; macOS: launchd; Linux: cron. Só verifica, nunca atualiza.
# Com GIT_COMMANDS_SCHEDULE_DRY_RUN=1, launchctl e powershell.exe só são mostrados (ensaio).

GC_SCHED_TASK="git-commands-verificar"
GC_SCHED_LABEL="com.git-commands.verificar"
GC_SCHED_MARK="# git-commands"

gc_sched_dry() { [ "${GIT_COMMANDS_SCHEDULE_DRY_RUN:-}" = 1 ]; }

gc_sched_run() {
  if gc_sched_dry; then printf 'ensaio: %s\n' "$*"; return 0; fi
  "$@"
}

gc_sched_valid_minutes() {
  case "$1" in ""|*[!0-9]*) return 1 ;; esac
  [ "$1" -ge 5 ] && [ "$1" -le 1440 ]
}

# Caminho no formato do sistema (no Windows, C:\...).
gc_sched_native() {
  if command -v cygpath >/dev/null 2>&1; then cygpath -w "$1"; else printf '%s\n' "$1"; fi
}

gc_sched_runner() { printf '%s\n' "$(gc_home)/app/scheduler/run-scheduled"; }

# ---------- Windows: Agendador de Tarefas (scripts .ps1 só com ASCII) ----------

gc_sched_windows_enable() {
  local min=$1 h ps1 bash_w runner_w
  h=$(gc_home); ps1="$h/schedule.ps1"
  bash_w=$(gc_sched_native "$(command -v bash)")
  runner_w=$(gc_sched_native "$(gc_sched_runner)")
  printf '%s\r\n' \
    '$ErrorActionPreference = "Stop"' \
    "\$acao = New-ScheduledTaskAction -Execute 'conhost.exe' -Argument '--headless \"$bash_w\" -l \"$runner_w\"'" \
    "\$gatilho = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes $min)" \
    '$ajustes = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 10)' \
    "Register-ScheduledTask -TaskName '$GC_SCHED_TASK' -Description 'git-commands: verifica novidades no GitHub (nunca atualiza nada)' -Action \$acao -Trigger \$gatilho -Settings \$ajustes -Force | Out-Null" \
    > "$ps1"
  gc_sched_run powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(gc_sched_native "$ps1")" || return 1
  if gc_sched_dry; then : > "$h/dry-run-windows-task"; fi
  return 0
}

gc_sched_windows_disable() {
  local h ps1; h=$(gc_home); ps1="$h/unschedule.ps1"
  printf '%s\r\n' "Unregister-ScheduledTask -TaskName '$GC_SCHED_TASK' -Confirm:\$false -ErrorAction SilentlyContinue" > "$ps1"
  gc_sched_run powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(gc_sched_native "$ps1")" >/dev/null 2>&1
  rm -f "$h/dry-run-windows-task"
}

gc_sched_windows_on() {
  if gc_sched_dry; then [ -e "$(gc_home)/dry-run-windows-task" ]; return; fi
  powershell.exe -NoProfile -Command "if (Get-ScheduledTask -TaskName '$GC_SCHED_TASK' -ErrorAction SilentlyContinue) { exit 0 } else { exit 1 }" >/dev/null 2>&1
}

# ---------- macOS: launchd ----------

gc_sched_plist() { printf '%s\n' "$HOME/Library/LaunchAgents/$GC_SCHED_LABEL.plist"; }

gc_sched_mac_enable() {
  local min=$1 p h uid
  p=$(gc_sched_plist); h=$(gc_home); uid=$(id -u)
  mkdir -p "${p%/*}" || return 1
  printf '%s\n' \
    '<?xml version="1.0" encoding="UTF-8"?>' \
    '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
    '<plist version="1.0">' \
    '<dict>' \
    "  <key>Label</key><string>$GC_SCHED_LABEL</string>" \
    '  <key>ProgramArguments</key>' \
    '  <array>' \
    '    <string>/bin/bash</string>' \
    '    <string>-l</string>' \
    "    <string>$(gc_sched_runner)</string>" \
    '  </array>' \
    "  <key>StartInterval</key><integer>$((min * 60))</integer>" \
    '  <key>RunAtLoad</key><true/>' \
    "  <key>StandardOutPath</key><string>$h/check.log</string>" \
    "  <key>StandardErrorPath</key><string>$h/check.log</string>" \
    '</dict>' \
    '</plist>' > "$p"
  gc_sched_run launchctl bootout "gui/$uid/$GC_SCHED_LABEL" >/dev/null 2>&1
  gc_sched_run launchctl bootstrap "gui/$uid" "$p"
}

gc_sched_mac_disable() {
  gc_sched_run launchctl bootout "gui/$(id -u)/$GC_SCHED_LABEL" >/dev/null 2>&1
  rm -f "$(gc_sched_plist)"
}

gc_sched_mac_on() {
  if gc_sched_dry; then [ -e "$(gc_sched_plist)" ]; return; fi
  launchctl print "gui/$(id -u)/$GC_SCHED_LABEL" >/dev/null 2>&1
}

# ---------- Linux: cron ----------

# O cron não repete a cada 90 minutos, por exemplo: acima de 60, arredonda para horas inteiras.
gc_sched_cron_expr() {
  local m=$1 hrs
  if [ "$m" -lt 60 ]; then printf '*/%s * * * *\n' "$m"; return; fi
  [ "$m" -ge 1440 ] && { printf '0 0 * * *\n'; return; }
  hrs=$(( (m + 30) / 60 ))
  [ "$hrs" -ge 24 ] && { printf '0 0 * * *\n'; return; }
  printf '0 */%s * * *\n' "$hrs"
}

gc_sched_linux_enable() {
  command -v crontab >/dev/null 2>&1 || { printf 'git-commands: este Linux não tem cron instalado\n' >&2; return 1; }
  local line atual
  line="$(gc_sched_cron_expr "$1") /bin/bash -l \"$(gc_sched_runner)\" $GC_SCHED_MARK"
  atual=$(crontab -l 2>/dev/null | grep -vF "$GC_SCHED_MARK")
  { [ -n "$atual" ] && printf '%s\n' "$atual"; printf '%s\n' "$line"; } | crontab -
}

gc_sched_linux_disable() {
  command -v crontab >/dev/null 2>&1 || return 0
  local atual; atual=$(crontab -l 2>/dev/null | grep -vF "$GC_SCHED_MARK")
  printf '%s\n' "$atual" | crontab -
}

gc_sched_linux_on() {
  command -v crontab >/dev/null 2>&1 || return 1
  crontab -l 2>/dev/null | grep -qF "$GC_SCHED_MARK"
}

# ---------- subcomando ----------

gc_sched_enable() {
  local min=${1:-}
  [ -n "$min" ] || min=$(gc_config_get interval)
  gc_sched_valid_minutes "$min" || {
    printf 'git-commands: intervalo inválido: %s (use de 5 a 1440 minutos)\n' "$min" >&2; return 1; }
  gc_app_sync force || { printf 'git-commands: não consegui copiar o executável para %s/app\n' "$(gc_home)" >&2; return 1; }
  case "$(gc_os)" in
    windows) gc_sched_windows_enable "$min" ;;
    mac) gc_sched_mac_enable "$min" ;;
    *) gc_sched_linux_enable "$min" ;;
  esac || return 1
  # A contagem do aviso de verificação parada (hook session-start) começa agora.
  date +%s > "$(gc_home)/status.time"
  gc_config_set auto_check on
  gc_config_set interval "$min"
  gc_config_set auto_check_asked yes
  printf 'ligado %s\n' "$min"
}

gc_sched_disable() {
  case "$(gc_os)" in
    windows) gc_sched_windows_disable ;;
    mac) gc_sched_mac_disable ;;
    *) gc_sched_linux_disable ;;
  esac
  gc_config_set auto_check off
  printf 'desligado\n'
}

gc_sched_status() {
  local on=no
  case "$(gc_os)" in
    windows) gc_sched_windows_on && on=yes ;;
    mac) gc_sched_mac_on && on=yes ;;
    *) gc_sched_linux_on && on=yes ;;
  esac
  if [ "$on" = yes ]; then printf 'ligado %s\n' "$(gc_config_get interval)"; else printf 'desligado\n'; fi
}

gc_cmd_schedule() {
  case "${1:-}" in
    enable) gc_sched_enable "${2:-}" ;;
    disable) gc_sched_disable ;;
    status) gc_sched_status ;;
    *) printf 'uso: git-commands schedule enable [minutos] | disable | status\n' >&2; return 1 ;;
  esac
}
