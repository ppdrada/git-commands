# Testes do hook pre-edit (checagem de novidades antes da primeira edição).

pe() { printf '{"session_id":"%s","tool_name":"Edit","tool_input":{"file_path":"%s"}%s}' "$1" "$2" "${3:-}" | CLAUDE_PLUGIN_ROOT="$PLUGIN" bash "$PLUGIN/hooks/run-hook.cmd" pre-edit; }

test_pre_edit_bloqueia_uma_vez_quando_atras() {
  local a; a=$(make_github_pair app); push_remote_commit app n.txt "um"
  local out; out=$(pe s1 "$a/README.md"); assert_contains "$out" '"permissionDecision":"deny"' ""; assert_contains "$out" "o projeto app tem 1 novidade(s)" ""
  assert_eq "" "$(pe s1 "$a/README.md")" "não volta na mesma sessão"
}

test_pre_edit_em_dia_libera() { local a out; a=$(make_github_pair app); out=$(pe s1 "$a/README.md"); assert_eq "0" "$?" "o hook rodou"; assert_eq "" "$out" ""; }

test_pre_edit_subagente_libera() { local a out; a=$(make_github_pair app); push_remote_commit app n.txt "um"; out=$(pe s1 "$a/README.md" ',"agent_id":"ag1"'); assert_eq "0" "$?" "o hook rodou"; assert_eq "" "$out" ""; }

test_pre_edit_desligado_libera() { local a out; a=$(make_github_pair app); push_remote_commit app n.txt "um"; gc proactive off "$a"; out=$(pe s1 "$a/README.md"); assert_eq "0" "$?" "o hook rodou"; assert_eq "" "$out" ""; }

test_pre_edit_remote_inacessivel_libera() { local a out; a=$(make_github_pair app); rm -rf "$SANDBOX/remotes/app.git"; out=$(pe s1 "$a/README.md"); assert_eq "0" "$?" "o hook rodou"; assert_eq "" "$out" ""; }

test_pre_edit_arquivo_novo_em_pasta_nova() { local a; a=$(make_github_pair app); push_remote_commit app n.txt "um"; assert_contains "$(pe s2 "$a/nova/pasta/x.txt")" "deny" ""; }

test_pre_edit_caminho_windows() {
  [ "$(gc os)" = windows ] || skip "só no Windows"; local a; a=$(make_github_pair app); push_remote_commit app n.txt "um"
  assert_contains "$(pe s3 "$(native_path "$a" | sed 's#/#\\\\#g')\\\\README.md")" "deny" ""
}
