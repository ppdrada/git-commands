# Testes do subcomando ssh (chave SSH do GitHub).

chave() { mkdir -p "$HOME/.ssh"; ssh-keygen -q -t "${2:-ed25519}" -N '' -C teste -f "$HOME/.ssh/$1" >/dev/null; }

test_ssh_converte_enderecos() {
  . "$PLUGIN/lib/common.sh"; . "$PLUGIN/lib/ssh.sh"
  assert_eq "git@github.com:a/b.git" "$(gc_github_https_to_ssh https://github.com/a/b.git)" ""
  assert_eq "git@github.com:a/b.git" "$(gc_github_https_to_ssh https://github.com/a/b)" ""
  gc_github_https_to_ssh git@github.com:a/b.git >/dev/null && fail "já é ssh"; return 0
}

test_ssh_remote_troca_e_volta() {
  local a; a=$(make_github_pair app)
  assert_contains "$(gc ssh remote "$a" ssh)" "-> git@github.com:teste/app.git" ""
  assert_eq "git@github.com:teste/app.git" "$(git -C "$a" config --get remote.origin.url)" ""
  assert_contains "$(gc ssh remote "$a" ssh)" "já está em ssh" ""
  gc ssh remote "$a" https >/dev/null; assert_eq "https://github.com/teste/app.git" "$(git -C "$a" config --get remote.origin.url)" ""
}

test_ssh_known_hosts_grava_uma_vez() {
  make_gh_stub; export GIT_COMMANDS_GH="$SANDBOX/stub/gh"
  assert_contains "$(gc ssh known-hosts)" "adicionadas 2" ""
  assert_contains "$(cat "$HOME/.ssh/known_hosts")" "github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl" ""
  assert_contains "$(gc ssh known-hosts)" "já estavam" ""
  assert_eq "1" "$(grep -c 'ssh-ed25519' "$HOME/.ssh/known_hosts")" "sem duplicar"
}

test_ssh_config_escreve_bloco() {
  chave id_ed25519
  assert_eq "escrito" "$(GIT_COMMANDS_OS=linux gc ssh config)" ""
  local c; c=$(cat "$HOME/.ssh/config")
  assert_contains "$c" "Host github.com" ""; assert_contains "$c" "IdentityFile ~/.ssh/id_ed25519" ""
  assert_contains "$c" "IdentitiesOnly yes" "só essa chave vai para o GitHub (outra chave poderia entrar em outra conta)"
  assert_not_contains "$c" "UseKeychain" "UseKeychain só no mac"
  assert_eq "já existe" "$(GIT_COMMANDS_OS=linux gc ssh config)" ""; assert_eq "1" "$(grep -c 'Host github.com' "$HOME/.ssh/config")" ""
  rm "$HOME/.ssh/config"; GIT_COMMANDS_OS=mac gc ssh config >/dev/null; c=$(cat "$HOME/.ssh/config")
  assert_contains "$c" "UseKeychain yes" ""
  assert_contains "$c" "IgnoreUnknown UseKeychain" "o OpenSSH do Homebrew não conhece UseKeychain"
}

test_ssh_config_respeita_host_existente() {
  chave id_ed25519; printf 'Host github.com\n  User git\n' > "$HOME/.ssh/config"
  local out; out=$(gc ssh config); assert_eq "3" "$?" ""
  assert_eq "$(printf 'Host github.com\n  User git')" "$(cat "$HOME/.ssh/config")" "não mexeu"
}

test_ssh_usa_a_chave_que_existe() {
  chave id_rsa rsa; GIT_COMMANDS_OS=linux gc ssh config >/dev/null
  assert_contains "$(cat "$HOME/.ssh/config")" "IdentityFile ~/.ssh/id_rsa" ""
  assert_contains "$(SSH_AUTH_SOCK= gc ssh status)" "chave=$HOME/.ssh/id_rsa" ""
}

test_ssh_status_sem_chave_e_sem_agente() {
  make_gh_stub; local out; out=$(SSH_AUTH_SOCK= GIT_COMMANDS_GH="$SANDBOX/stub/gh" gc ssh status)
  assert_eq "chave impressao agente config known_hosts protocolo projetos_https projetos_ssh " "$(printf '%s\n' "$out" | sed 's/=.*//' | tr '\n' ' ')" ""
  printf '%s\n' "$out" | grep -qx 'chave=' || fail "sem chave"
  printf '%s\n' "$out" | grep -qx 'agente=sem-agente' || fail "sem agente"
}

test_ssh_test_traduz_respostas() {
  mkdir -p "$SANDBOX/stub"; local s="$SANDBOX/stub/ssh-falso"
  printf '%s\n' '#!/usr/bin/env bash' 'printf "%s\n" "$SSH_FALSO" >&2; exit 1' > "$s"; chmod +x "$s"; export GIT_COMMANDS_SSH="$s"
  local out
  out=$(SSH_FALSO="Hi tester! You've successfully authenticated, but GitHub does not provide shell access." gc ssh test); assert_eq "0" "$?" ""; assert_eq "ok tester" "$out" ""
  out=$(SSH_FALSO="git@github.com: Permission denied (publickey)." gc ssh test); assert_eq "1" "$?" ""; assert_eq "chave-recusada" "$out" ""
  out=$(SSH_FALSO="Host key verification failed." gc ssh test); assert_eq "2" "$?" ""; assert_eq "servidor-desconhecido" "$out" ""
  out=$(SSH_FALSO="ssh: connect to host github.com port 22: Connection timed out" gc ssh test); assert_eq "3" "$?" ""
}

test_ssh_usa_o_ssh_do_git() {
  . "$PLUGIN/lib/common.sh"; . "$PLUGIN/lib/ssh.sh"
  assert_eq "ssh" "$(gc_ssh_cmd)" ""
  git config --global core.sshCommand "C:/Windows/System32/OpenSSH/ssh.exe"
  assert_eq "C:/Windows/System32/OpenSSH/ssh.exe" "$(gc_ssh_cmd)" ""
}

test_ssh_known_hosts_respeita_arquivo_escrito_a_mao() {
  make_gh_stub; export GIT_COMMANDS_GH="$SANDBOX/stub/gh"; mkdir -p "$HOME/.ssh"; local kh="$HOME/.ssh/known_hosts"
  local ed="AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl"
  printf 'gitlab.com ssh-ed25519 AAAAoutrachave' > "$kh"   # sem quebra de linha no fim
  gc ssh known-hosts >/dev/null
  grep -qx 'gitlab.com ssh-ed25519 AAAAoutrachave' "$kh" || fail "estragou a linha do outro servidor: $(cat "$kh")"
  grep -qx "github.com ssh-ed25519 $ed" "$kh" || fail "a linha do GitHub não ficou inteira"
  printf 'github.com\tssh-ed25519\t%s\n' "$ed" > "$kh"     # separada por tab
  gc ssh known-hosts >/dev/null; assert_eq "1" "$(grep -c "$ed" "$kh")" "duplicou a chave escrita com tab"
  printf '[ssh.github.com]:443 ssh-ed25519 %s\n' "$ed" > "$kh"   # só a porta 443
  gc ssh known-hosts >/dev/null; grep -qx "github.com ssh-ed25519 $ed" "$kh" || fail "a chave do github.com não entrou"
}
