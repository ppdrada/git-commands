# Testes do hook session-start (contexto na abertura do Claude).

ss() { printf '{"cwd":"%s","source":"startup"}' "$1" | CLAUDE_PLUGIN_ROOT="$PLUGIN" bash "$PLUGIN/hooks/run-hook.cmd" session-start; }

test_ss_fora_de_repo_silencioso() { local out; out=$(ss "$SANDBOX"); assert_eq "0" "$?" "o hook rodou"; assert_eq "" "$out" ""; }

test_ss_repo_nao_github_silencioso() { local r out; r=$(make_local_repo l); out=$(ss "$r"); assert_eq "0" "$?" "o hook rodou"; assert_eq "" "$out" ""; }

test_ss_repo_github_injeta_regras() {
  local r; r=$(make_github_pair app); local out; out=$(ss "$r")
  assert_contains "$out" "git-commands está ativo neste projeto (app)" ""; assert_contains "$out" "Conceitos já explicados para esta pessoa: nenhum" ""
  gc learned add commit push; assert_contains "$(ss "$r")" "commit, push" ""
}

test_ss_respeita_desligado() { local r out; r=$(make_github_pair app); gc proactive off "$r"; out=$(ss "$r"); assert_eq "0" "$?" "o hook rodou"; assert_eq "" "$out" ""; }

test_ss_avisa_novidades_so_com_auto_check() {
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
  gc config set projects_dir "$SANDBOX/projetos"; gc config set auto_check on; local i; for i in 1 2 3; do make_github_pair "r$i" >/dev/null; done
  gc updates scan --save >/dev/null
  touch -t 202001010000 "$SANDBOX/ref"; for i in 1 2 3; do touch -t 202001010000 "$SANDBOX/projetos/r$i/.git/FETCH_HEAD"; done
  local t0; t0=$(date +%s); ss "$SANDBOX/projetos/r1" >/dev/null
  [ $(( $(date +%s) - t0 )) -le 5 ] || fail "session-start demorou mais de 5s"
  assert_eq "" "$(find "$SANDBOX"/projetos/r*/.git/FETCH_HEAD -newer "$SANDBOX/ref")" "o hook não fez fetch"
}

test_ss_apaga_marcadores_de_sessao_antigos() {
  local s; s="$(gc home)/sessions"; mkdir -p "$s/velha" "$s/nova"
  touch -t 202001010000 "$s/velha"
  ss "$SANDBOX" >/dev/null
  [ -e "$s/velha" ] && fail "marcador antigo ficou"; assert_file "$s/nova" "marcador recente fica"
}

test_ss_cwd_com_barras_invertidas() { local r; r=$(make_github_pair app); [ "$(gc os)" = windows ] || skip "só no Windows"; assert_contains "$(ss "$(native_path "$r" | sed 's#/#\\\\#g')")" "(app)" ""; }
