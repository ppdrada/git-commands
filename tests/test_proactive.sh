# Testes do subcomando proactive (modo automático por projeto).

test_proactive_por_projeto() {
  local a b; a=$(make_github_pair a); b=$(make_github_pair b)
  assert_eq "on" "$(gc proactive status "$a")" ""; gc proactive off "$a"
  assert_eq "off" "$(gc proactive status "$a")" ""; assert_eq "on" "$(gc proactive status "$b")" ""
  gc proactive off --all; assert_eq "off" "$(gc proactive status "$b")" ""; gc proactive on --all; assert_eq "on" "$(gc proactive status "$b")" ""
}

test_proactive_fora_de_repo_sem_all() {
  local err; err=$(gc proactive off 2>&1); assert_eq "1" "$?" ""
  assert_contains "$err" "--all" "explica como desligar em todos os projetos"
}
