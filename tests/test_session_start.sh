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

test_ss_apaga_marcadores_de_sessao_antigos() {
  local s; s="$(gc home)/sessions"; mkdir -p "$s/velha" "$s/nova"
  touch -t 202001010000 "$s/velha"
  ss "$SANDBOX" >/dev/null
  [ -e "$s/velha" ] && fail "marcador antigo ficou"; assert_file "$s/nova" "marcador recente fica"
}

test_ss_cwd_com_barras_invertidas() { local r; r=$(make_github_pair app); [ "$(gc os)" = windows ] || skip "só no Windows"; assert_contains "$(ss "$(native_path "$r" | sed 's#/#\\\\#g')")" "(app)" ""; }
