# Testes do subcomando doctor (o que falta no computador).

linha_de() { printf '%s\n' "$1" | grep "^$2="; }

test_doctor_com_gh_logado() {
  make_gh_stub; local out; out=$(STUB_GH_AUTH=0 GIT_COMMANDS_GH="$SANDBOX/stub/gh" gc doctor)
  assert_contains "$out" "gh=2.62.0" ""; assert_contains "$out" "gh_auth=yes" ""; assert_contains "$out" "gh_user=tester" ""
  assert_contains "$out" "user_name=Teste" ""; assert_contains "$out" "git_ok=yes" ""
}

test_doctor_gh_nao_logado() { make_gh_stub; assert_contains "$(STUB_GH_AUTH=1 GIT_COMMANDS_GH="$SANDBOX/stub/gh" gc doctor)" "gh_auth=no" ""; }

test_doctor_sem_gh() {
  local out; out=$(GIT_COMMANDS_GH=/nao/existe gc doctor)
  assert_eq "gh=" "$(linha_de "$out" gh)" "gh vazio"
  assert_eq "gh_path=" "$(linha_de "$out" gh_path)" "sem caminho"
  assert_eq "gh_auth=no" "$(linha_de "$out" gh_auth)" "sem login"
}

test_doctor_gh_fora_do_path() {
  [ "$(dirname "$(command -v gh 2>/dev/null || echo /x/y)")" = "$(dirname "$(command -v git)")" ] && skip "gh e git na mesma pasta"
  make_gh_stub; local out; out=$(PATH="$(dirname "$(command -v git)"):/usr/bin:/bin" GIT_COMMANDS_GH_DIRS="$SANDBOX/stub" STUB_GH_AUTH=0 gc doctor)
  assert_contains "$out" "gh_path=$SANDBOX/stub/gh" ""; assert_contains "$out" "gh_on_path=no" ""
}

test_doctor_chaves_na_ordem() {
  local out; out=$(GIT_COMMANDS_GH=/nao/existe gc doctor)
  assert_eq "os git git_ok gh gh_path gh_on_path gh_auth gh_user user_name user_email projects_dir auto_check interval proactive ssh_key git_protocol " \
    "$(printf '%s\n' "$out" | sed 's/=.*//' | tr '\n' ' ')" ""
}

test_doctor_sem_rede() {
  make_gh_stub; local out
  out=$(STUB_GH_AUTH=1 STUB_GH_OFFLINE=1 GIT_COMMANDS_GH="$SANDBOX/stub/gh" gc doctor)
  printf '%s\n' "$out" | grep -qx 'gh_auth=sem-rede' || fail "sem internet devia dar sem-rede"
  out=$(STUB_GH_AUTH=1 GIT_COMMANDS_GH="$SANDBOX/stub/gh" gc doctor)
  printf '%s\n' "$out" | grep -qx 'gh_auth=no' || fail "sem login devia dar no"
}

test_doctor_ssh_e_protocolo() {
  make_gh_stub; local out
  out=$(GIT_COMMANDS_GH="$SANDBOX/stub/gh" gc doctor)
  printf '%s\n' "$out" | grep -qx 'ssh_key=' || fail "sem chave"
  printf '%s\n' "$out" | grep -qx 'git_protocol=https' || fail "protocolo padrão"
  mkdir -p "$HOME/.ssh"; : > "$HOME/.ssh/id_ed25519.pub"
  out=$(STUB_GH_PROTOCOL=ssh GIT_COMMANDS_GH="$SANDBOX/stub/gh" gc doctor)
  assert_contains "$out" "ssh_key=$HOME/.ssh/id_ed25519.pub" ""
  printf '%s\n' "$out" | grep -qx 'git_protocol=ssh' || fail "protocolo ssh"
}
