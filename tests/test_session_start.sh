# Testes do hook session-start (contexto na abertura do Claude).

ss() { printf '{"cwd":"%s","source":"startup"}' "$1" | CLAUDE_PLUGIN_ROOT="$PLUGIN" "$BASH" "$PLUGIN/hooks/run-hook.cmd" session-start; }

test_ss_fora_de_repo_silencioso() { local out; out=$(ss "$SANDBOX"); assert_eq "0" "$?" "o hook rodou"; assert_eq "" "$out" ""; }

test_ss_repo_nao_github_silencioso() { local r out; r=$(make_local_repo l); out=$(ss "$r"); assert_eq "0" "$?" "o hook rodou"; assert_eq "" "$out" ""; }

test_ss_repo_github_injeta_regras() {
  local r; r=$(make_github_pair app); local out; out=$(ss "$r")
  assert_contains "$out" "git-commands está ativo neste projeto (app)" ""; assert_contains "$out" "Conceitos já explicados para esta pessoa: nenhum" ""
  gc learned add commit push; assert_contains "$(ss "$r")" "commit, push" ""
}

test_ss_respeita_desligado() { local r out; r=$(make_github_pair app); gc proactive off "$r"; out=$(ss "$r"); assert_eq "0" "$?" "o hook rodou"; assert_eq "" "$out" ""; }

test_ss_avisa_novidades_so_com_auto_check() {
  export GIT_COMMANDS_GH=/nao/existe   # o scan sem --dir pede o login ao gh: o da máquina nunca entra
  gc config set projects_dir "$SANDBOX/projetos"; local a; a=$(make_github_pair app); push_remote_commit app n.txt "um"; gc updates scan --save >/dev/null
  assert_not_contains "$(ss "$SANDBOX")" "Novidades no GitHub" "auto_check desligado"
  gc config set auto_check on; assert_contains "$(ss "$SANDBOX")" "Novidades no GitHub: app (1)." ""
  gc updates pull "$a" >/dev/null; assert_not_contains "$(ss "$SANDBOX")" "Novidades" "some depois de atualizar"
}

test_ss_recopia_app_quando_versao_muda() {
  gc config set auto_check on; ss "$SANDBOX" >/dev/null
  assert_file "$(gc home)/app/bin/git-commands" ""; assert_eq "$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$PLUGIN/.claude-plugin/plugin.json")" "$(cat "$(gc home)/app/VERSION")" ""
}

test_ss_rapido_e_sem_rede() {
  export GIT_COMMANDS_GH=/nao/existe   # o scan sem --dir pede o login ao gh: o da máquina nunca entra
  gc config set projects_dir "$SANDBOX/projetos"; gc config set auto_check on; local i; for i in 1 2 3; do make_github_pair "r$i" >/dev/null; done
  gc updates scan --save >/dev/null
  touch -t 202001010000 "$SANDBOX/ref"; for i in 1 2 3; do touch -t 202001010000 "$SANDBOX/projetos/r$i/.git/FETCH_HEAD"; done
  local t0; t0=$(date +%s); ss "$SANDBOX/projetos/r1" >/dev/null
  [ $(( $(date +%s) - t0 )) -le 5 ] || fail "session-start demorou mais de 5s"
  assert_eq "" "$(find "$SANDBOX"/projetos/r*/.git/FETCH_HEAD -newer "$SANDBOX/ref")" "o hook não fez fetch"
}

test_ss_avisa_verificacao_parada() {
  gc config set auto_check on; gc config set interval 30
  local h t visto; h=$(gc home); t=$(( $(date +%s) - 3 * 3600 )); echo "$t" > "$h/status.time"
  assert_not_contains "$(ss "$SANDBOX")" "não roda há" "na primeira vez, o computador pode ter acabado de acordar"
  read -r visto _ < "$h/status.stale"; assert_eq "$t" "$visto" "guardou que viu a verificação velha"
  echo "$t $(( $(date +%s) - 2 * 3600 ))" > "$h/status.stale"   # como se a primeira vez tivesse sido há 2 horas
  assert_contains "$(ss "$SANDBOX")" "não roda há 3 horas" "3 h sem verificar, e já era assim 2 h atrás"
  date +%s > "$h/status.time"
  assert_not_contains "$(ss "$SANDBOX")" "não roda há" "verificação em dia"
}

test_ss_avisa_erro_da_verificacao() {
  gc config set auto_check on; local h out; h=$(gc home)
  printf '%s\n' 'git-commands: sem permissão para ler a pasta de projetos: /x/Documents/git' '2026-10-25 18:00:00 erro 1' > "$h/check.log"
  out=$(ss "$SANDBOX"); assert_contains "$out" "deu erro" ""; assert_contains "$out" "sem permissão para ler a pasta de projetos" "mostra o motivo"
  echo '2026-10-25 18:30:00 verificação ok' >> "$h/check.log"
  assert_not_contains "$(ss "$SANDBOX")" "deu erro" "a última deu certo"
}

test_ss_apaga_marcadores_de_sessao_antigos() {
  local s; s="$(gc home)/sessions"; mkdir -p "$s/velha" "$s/nova"
  touch -t 202001010000 "$s/velha"
  ss "$SANDBOX" >/dev/null
  [ -e "$s/velha" ] && fail "marcador antigo ficou"; assert_file "$s/nova" "marcador recente fica"
}

test_ss_cwd_com_barras_invertidas() { local r; r=$(make_github_pair app); [ "$(gc os)" = windows ] || skip "só no Windows"; assert_contains "$(ss "$(native_path "$r" | sed 's#/#\\\\#g')")" "(app)" ""; }

ss_src() { printf '{"cwd":"%s","source":"%s"}' "$1" "$2" | CLAUDE_PLUGIN_ROOT="$PLUGIN" "$BASH" "$PLUGIN/hooks/run-hook.cmd" session-start; }

test_ss_avisos_so_ao_abrir_ou_limpar() {
  export GIT_COMMANDS_GH=/nao/existe   # o scan sem --dir pede o login ao gh: o da máquina nunca entra
  gc config set projects_dir "$SANDBOX/projetos"; local a; a=$(make_github_pair app); push_remote_commit app n.txt "um"
  gc updates scan --save >/dev/null; gc config set auto_check on
  printf '%s\n' '2026-10-25 18:00:00 erro 1' >> "$(gc home)/check.log"
  assert_contains "$(ss_src "$SANDBOX" startup)" "Novidades no GitHub" "startup"
  assert_contains "$(ss_src "$SANDBOX" clear)" "deu erro" "clear"
  assert_not_contains "$(ss_src "$SANDBOX" compact)" "Novidades" "compact"
  assert_not_contains "$(ss_src "$SANDBOX" resume)" "deu erro" "resume"
  assert_contains "$(ss_src "$a" compact)" "git-commands está ativo" "as regras voltam depois de resumir"
}
