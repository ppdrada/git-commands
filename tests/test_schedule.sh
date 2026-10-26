# Testes do subcomando schedule (verificação automática) e do run-scheduled.

dr() { GIT_COMMANDS_SCHEDULE_DRY_RUN=1 GIT_COMMANDS_OS="$1" gc schedule "${@:2}"; }

test_schedule_mac() {
  dr mac enable 30 >/dev/null; local p="$HOME/Library/LaunchAgents/com.git-commands.verificar.plist"
  assert_contains "$(cat "$p")" "<integer>1800</integer>" ""; assert_contains "$(cat "$p")" "scheduler/run-scheduled" ""
  assert_eq "ligado 30" "$(dr mac status)" ""; dr mac disable >/dev/null; [ -e "$p" ] && fail "plist ficou"; assert_eq "desligado" "$(dr mac status)" ""
}

test_schedule_linux_preserva_outras_linhas() {
  make_crontab_stub "0 5 * * * backup"   # crontab falso que guarda em $SANDBOX/crontab.txt
  dr linux enable 30 >/dev/null; assert_contains "$(cat "$SANDBOX/crontab.txt")" "*/30 * * * * /bin/bash -l" ""; assert_contains "$(cat "$SANDBOX/crontab.txt")" "0 5 * * * backup" ""
  dr linux enable 120 >/dev/null; assert_contains "$(cat "$SANDBOX/crontab.txt")" "0 */2 * * *" ""; assert_eq "1" "$(grep -c '# git-commands' "$SANDBOX/crontab.txt")" "sem duplicar"
  dr linux disable >/dev/null; assert_not_contains "$(cat "$SANDBOX/crontab.txt")" "git-commands" ""; assert_contains "$(cat "$SANDBOX/crontab.txt")" "backup" ""
}

test_schedule_windows_script() {
  dr windows enable 30 >/dev/null; local s; s=$(cat "$(gc home)/schedule.ps1")
  assert_contains "$s" "git-commands-verificar" ""; assert_contains "$s" "New-TimeSpan -Minutes 30" ""; assert_contains "$s" "--headless" ""
  assert_eq "ligado 30" "$(dr windows status)" ""
}

test_schedule_intervalo_invalido() {
  local m err
  for m in 0 4 1441 abc; do
    err=$(GIT_COMMANDS_SCHEDULE_DRY_RUN=1 gc schedule enable "$m" 2>&1); assert_eq "1" "$?" "intervalo $m"
    assert_contains "$err" "intervalo" "explica o intervalo ($m)"
  done
}

test_schedule_copia_app() { make_crontab_stub ""; dr linux enable 30 >/dev/null; local h; h=$(gc home); assert_file "$h/app/bin/git-commands" ""; assert_file "$h/app/scheduler/run-scheduled" ""; assert_file "$h/app/VERSION" ""; }

test_schedule_enable_recomeca_a_contagem() {
  make_crontab_stub ""; echo 100 > "$(gc home)/status.time"; dr linux enable 30 >/dev/null
  local t; read -r t < "$(gc home)/status.time"; [ "$t" -ge $(( $(date +%s) - 60 )) ] || fail "o enable não recomeçou a contagem ($t)"
}

test_run_scheduled_grava_status_e_log() {
  export GIT_COMMANDS_GH=/nao/existe   # a verificação agendada pede o login ao gh: o da máquina nunca entra
  gc config set projects_dir "$SANDBOX/projetos"; make_github_pair app >/dev/null; push_remote_commit app n.txt "um"
  make_crontab_stub ""; dr linux enable 30 >/dev/null; "$BASH" "$(gc home)/app/scheduler/run-scheduled"
  assert_contains "$(cat "$(gc home)/status.tsv")" "novidades" ""; assert_contains "$(cat "$(gc home)/check.log")" "verificação ok" ""
}

test_schedule_real_ida_e_volta() {
  [ "${GIT_COMMANDS_TEST_REAL_SCHEDULE:-}" = 1 ] || skip "defina GIT_COMMANDS_TEST_REAL_SCHEDULE=1"
  [ "$(gc os)" = linux ] && ! command -v crontab >/dev/null && skip "este Linux não tem cron"
  export GIT_COMMANDS_SCHED_ID="teste-$$"   # nunca mexe na tarefa de verdade da pessoa
  gc schedule enable 30 >/dev/null; assert_eq "ligado 30" "$(gc schedule status)" ""; gc schedule disable >/dev/null; assert_eq "desligado" "$(gc schedule status)" ""
}

test_schedule_windows_apostrofo() {
  export HOME="$SANDBOX/home/D'Avila"; mkdir -p "$HOME"
  dr windows enable 30 >/dev/null; assert_contains "$(cat "$(gc home)/schedule.ps1")" "D''Avila" ""
}

test_schedule_disable_que_falhou_nao_diz_desligado() {
  make_crontab_stub ""; dr linux enable 30 >/dev/null
  local out; out=$(STUB_CRONTAB_FAIL=1 dr linux disable 2>&1); assert_eq "1" "$?" ""
  assert_not_contains "$out" "desligado" ""; assert_eq "on" "$(gc config get auto_check)" ""
}

test_schedule_cron_divisores_de_60() {
  . "$PLUGIN/lib/common.sh"; . "$PLUGIN/lib/schedule.sh"
  assert_eq "*/30 * * * *" "$(gc_sched_cron_expr 45)" ""; assert_eq "*/6 * * * *" "$(gc_sched_cron_expr 7)" ""
  assert_eq "0 * * * *" "$(gc_sched_cron_expr 50)" ""; assert_eq "*/20 * * * *" "$(gc_sched_cron_expr 25)" ""
  make_crontab_stub ""; assert_eq "ligado 30" "$(dr linux enable 45)" "mostra o intervalo de verdade"
  assert_eq "30" "$(gc config get interval)" ""
}

test_schedule_nome_de_teste() {
  GIT_COMMANDS_SCHED_ID=teste dr windows enable 30 >/dev/null; local s; s=$(cat "$(gc home)/schedule.ps1")
  assert_contains "$s" "'git-commands-teste'" ""; assert_not_contains "$s" "git-commands-verificar" ""
}

test_schedule_windows_acentos() {
  export HOME="$SANDBOX/home/João"; mkdir -p "$HOME"
  dr windows enable 30 >/dev/null; local f; f="$(gc home)/schedule.ps1"
  assert_eq "efbbbf" "$(head -c 3 "$f" | od -An -tx1 | tr -d ' \n')" "sem BOM, o PowerShell 5.1 lê o .ps1 como ANSI e estraga o caminho com acento"
  assert_contains "$(cat "$f")" "João" ""
}
