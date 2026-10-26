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
  assert_eq "os git git_ok gh gh_path gh_on_path gh_auth gh_user user_name user_email projects_dir github_user folders folders_missing ignored auto_check interval proactive ssh_key git_protocol " \
    "$(printf '%s\n' "$out" | sed 's/=.*//' | tr '\n' ' ')" ""
}

test_doctor_conta_as_pastas() {
  # O doctor só conta as listas: o gh da máquina nunca entra.
  export GIT_COMMANDS_GH=/nao/existe
  local a="$SANDBOX/fora/Meu Site" b="$SANDBOX/fora/velha" c="$SANDBOX/fora/copia" out
  mkdir -p "$a" "$b" "$c"
  # Sem lista nenhuma, tudo zero.
  out=$(gc doctor)
  assert_eq "folders=0" "$(linha_de "$out" folders)" "sem pastas pedidas"
  assert_eq "folders_missing=0" "$(linha_de "$out" folders_missing)" "sem pastas pedidas que faltam"
  assert_eq "ignored=0" "$(linha_de "$out" ignored)" "sem pastas ignoradas"
  # Duas pastas pedidas (uma é apagada depois) e uma ignorada.
  gc folders add "$a" >/dev/null; gc folders add "$b" >/dev/null; gc folders ignore "$c" >/dev/null
  rm -rf "$b"
  out=$(gc doctor)
  assert_eq "folders=2" "$(linha_de "$out" folders)" "duas pastas pedidas"
  assert_eq "folders_missing=1" "$(linha_de "$out" folders_missing)" "uma pedida não existe mais"
  assert_eq "ignored=1" "$(linha_de "$out" ignored)" "uma pasta ignorada"
  # Uma pasta ignorada que sumiu continua ignorada, e não entra na conta das pedidas que faltam.
  rm -rf "$c"
  out=$(gc doctor)
  assert_eq "folders_missing=1" "$(linha_de "$out" folders_missing)" "ignorada que sumiu não é pedida que falta"
  assert_eq "ignored=1" "$(linha_de "$out" ignored)" "ignorada que sumiu continua na lista"
}

test_doctor_grava_o_login() {
  make_gh_stub; export GIT_COMMANDS_GH="$SANDBOX/stub/gh"
  local out
  assert_eq "" "$(gc config get github_user)" "começa sem login gravado"
  # O gh do computador não guarda login (STUB_GH_USER vazio): quem sabe é a API, e o doctor grava o que ela disse.
  out=$(STUB_GH_USER= gc doctor)
  assert_eq "github_user=tester" "$(linha_de "$out" github_user)" "mostra o login da API"
  assert_eq "tester" "$(gc config get github_user)" "gravou o login da API"
  assert_eq "1" "$(grep -c '^api ' "$SANDBOX/gh.log")" "só a chamada à API que o doctor já fazia"
  # Login diferente do gravado: vale o da API (a pessoa pode ter trocado de conta no gh).
  gc config set github_user antigo
  out=$(gc doctor)
  assert_eq "github_user=tester" "$(linha_de "$out" github_user)" "mostra o login novo"
  assert_eq "tester" "$(gc config get github_user)" "trocou o login gravado"
  # A API sem resposta (aqui, sem login no gh) não apaga o que já está gravado.
  gc config set github_user fulano
  out=$(STUB_GH_AUTH=1 gc doctor)
  assert_eq "github_user=fulano" "$(linha_de "$out" github_user)" "mostra o login gravado"
  assert_eq "fulano" "$(gc config get github_user)" "o login gravado ficou"
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
