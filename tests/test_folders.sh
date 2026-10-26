# Testes de lib/folders.sh: a conta do GitHub da pessoa e as pastas onde a verificação procura projetos.

test_github_user_vem_do_gh() {
  . "$PLUGIN/lib/common.sh"; . "$PLUGIN/lib/doctor.sh"; . "$PLUGIN/lib/folders.sh"
  # GIT_COMMANDS_GH sempre aponta para o stub ou para um caminho que não existe: o gh da máquina nunca entra.
  make_gh_stub; export GIT_COMMANDS_GH="$SANDBOX/stub/gh"
  local out rc cfg log="$SANDBOX/gh.log"; cfg="$(gc_home)/config"
  # A chave github_user existe e começa vazia.
  assert_exit 0 gc config get github_user; assert_eq "" "$(gc config get github_user)" "começa vazio"
  # gh sem login guardado: não imprime, não grava e sai com 0.
  out=$(STUB_GH_USER= gc_github_user); rc=$?
  assert_eq "0" "$rc" "gh sem login: código"; assert_eq "" "$out" "gh sem login: saída"
  grep -q '^github_user=' "$cfg" 2>/dev/null && fail "gravou um login vazio no config"
  assert_eq "" "$(gc config get github_user)" "gh sem login: config"
  # Sem gh no computador: o mesmo.
  out=$(GIT_COMMANDS_GH=/nao/existe gc_github_user); rc=$?
  assert_eq "0" "$rc" "sem gh: código"; assert_eq "" "$out" "sem gh: saída"
  assert_eq "" "$(gc config get github_user)" "sem gh: config"
  # gh logado: imprime o login e grava no config, lendo só o que o gh guarda no computador (sem rede).
  : > "$log"
  out=$(STUB_GH_USER=ppdrada gc_github_user); rc=$?
  assert_eq "0" "$rc" "gh logado: código"; assert_eq "ppdrada" "$out" "login do gh"
  assert_eq "ppdrada" "$(gc config get github_user)" "gravou no config"
  assert_eq "config get -h github.com user" "$(cat "$log")" "só leu o login guardado"
  # Já gravado: vale o config e o gh nem é chamado.
  : > "$log"
  out=$(STUB_GH_USER=outra-conta gc_github_user); rc=$?
  assert_eq "0" "$rc" "já gravado: código"; assert_eq "ppdrada" "$out" "o login gravado vale"
  [ -s "$log" ] && fail "chamou o gh com o login já gravado: $(cat "$log")"
  assert_eq "ppdrada" "$(gc config get github_user)" "o config continua igual"
}
