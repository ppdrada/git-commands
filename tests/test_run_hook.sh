# Testes do run-hook.cmd: os hooks rodam do jeito que o Claude Code chama.

# No Mac e no Linux, o Claude Code roda o comando do hook com sh -c; no Windows, pelo Git Bash,
# que entrega o .cmd ao cmd.exe.
test_run_hook_como_o_claude_code_chama() {
  local r out; r=$(make_github_pair app)
  out=$(printf '{"cwd":"%s","source":"startup"}' "$r" | CLAUDE_PLUGIN_ROOT="$PLUGIN" sh -c '"$1" session-start' sh "$PLUGIN/hooks/run-hook.cmd" 2>&1)
  # Numa linha só, para o CI mostrar a saída inteira se falhar.
  assert_contains "$out" "git-commands está ativo neste projeto (app)" "saída: $(printf '%s' "$out" | tr '\r\n' '^|')"
}

# O Windows do GitHub (e quem usa UTF-8 no terminal) roda o cmd.exe na página de código 65001,
# em que ele se perde com acentos no .cmd e corta o começo das linhas.
test_run_hook_cmd_em_utf8() {
  [ "$(gc os)" = windows ] || skip "só no Windows"
  local w out; w=$(cygpath -w "$PLUGIN/hooks/run-hook.cmd")
  out=$(printf '%s' '{"tool_input":{"command":"git status"}}' | cmd.exe //c "chcp 65001 >nul & $w guard" 2>&1)
  assert_eq "" "$out" "saída: $(printf '%s' "$out" | tr '\r\n' '^|')"
}

# O sh do Mac é o bash 3.2 em modo POSIX, e o $BASH dele vale /bin/sh.
test_run_hook_pelo_sh_roda_no_bash_normal() {
  mkdir -p "$SANDBOX/h"; cp "$PLUGIN/hooks/run-hook.cmd" "$SANDBOX/h/"
  printf '%s\n' 'if shopt -oq posix; then echo posix; else echo normal; fi' > "$SANDBOX/h/sonda"
  assert_eq "normal" "$(sh "$SANDBOX/h/run-hook.cmd" sonda)" "o hook rodou em modo POSIX"
}

test_run_hook_acha_bash_pela_variavel() {
  [ "$(gc os)" = windows ] || skip "só no Windows"
  local w b out; w=$(cygpath -w "$PLUGIN/hooks/run-hook.cmd"); b=$(cygpath -w "$(command -v bash)")
  # O Git Bash não deixa trocar o ProgramFiles de fora, e aspas dentro do //c chegam ao cmd
  # como \": por isso as pastas falsas vão por set, sem aspas, dentro do próprio cmd.
  out=$(printf '%s' '{"tool_input":{"command":"git reset --hard"}}' \
    | PATH=/c/Windows/System32 CLAUDE_CODE_GIT_BASH_PATH="$b" \
      cmd.exe //c "set ProgramFiles=C:\\nao-existe& set LOCALAPPDATA=C:\\nao-existe& $w guard" 2>&1)
  assert_contains "$out" "permissionDecision" "saída: $(printf '%s' "$out" | tr '\r\n' '^|')"
}

test_run_hook_acha_bash_pelo_git_do_path() {
  [ "$(gc os)" = windows ] || skip "só no Windows"
  local w g out; w=$(cygpath -w "$PLUGIN/hooks/run-hook.cmd"); g=$(dirname "$(command -v git)")
  out=$(printf '%s' '{"tool_input":{"command":"git reset --hard"}}' \
    | PATH="/c/Windows/System32:$g" cmd.exe //c "set ProgramFiles=C:\nao-existe& set LOCALAPPDATA=C:\nao-existe& $w guard" 2>&1)
  assert_contains "$out" "permissionDecision" "saída: $(printf '%s' "$out" | tr '\r\n' '^|')"
}
