# Testes do run-hook.cmd: os hooks rodam do jeito que o Claude Code chama.

# No Mac e no Linux, o Claude Code roda o comando do hook com sh -c; no Windows, pelo Git Bash,
# que entrega o .cmd ao cmd.exe.
test_run_hook_como_o_claude_code_chama() {
  local r out; r=$(make_github_pair app)
  out=$(printf '{"cwd":"%s","source":"startup"}' "$r" | CLAUDE_PLUGIN_ROOT="$PLUGIN" sh -c '"$1" session-start' sh "$PLUGIN/hooks/run-hook.cmd" 2>&1)
  # Numa linha só, para o CI mostrar a saída inteira se falhar.
  assert_contains "$out" "git-commands está ativo neste projeto (app)" "saída: $(printf '%s' "$out" | tr '\r\n' '^|')"
}

# O sh do Mac é o bash 3.2 em modo POSIX, e o $BASH dele vale /bin/sh.
test_run_hook_pelo_sh_roda_no_bash_normal() {
  mkdir -p "$SANDBOX/h"; cp "$PLUGIN/hooks/run-hook.cmd" "$SANDBOX/h/"
  printf '%s\n' 'if shopt -oq posix; then echo posix; else echo normal; fi' > "$SANDBOX/h/sonda"
  assert_eq "normal" "$(sh "$SANDBOX/h/run-hook.cmd" sonda)" "o hook rodou em modo POSIX"
}
