# Testes de lib/common.sh e dos subcomandos home, os e config.

test_home_padrao_e_override() {
  assert_eq "$HOME/.git-commands" "$(gc home)" "padrão"; assert_file "$HOME/.git-commands" "criado"
  assert_eq "$SANDBOX/x" "$(GIT_COMMANDS_HOME=$SANDBOX/x gc home)" "override"
}

test_os_valido_e_override() {
  case "$(gc os)" in windows|mac|linux) ;; *) fail "os inválido" ;; esac
  assert_eq "mac" "$(GIT_COMMANDS_OS=mac gc os)" "override"
}

test_config_padroes() {
  assert_eq "on" "$(gc config get proactive)" ""; assert_eq "off" "$(gc config get auto_check)" ""
  assert_eq "30" "$(gc config get interval)" ""; assert_eq "" "$(gc config get projects_dir)" ""
}

test_config_guarda_valor_com_espaco_e_igual() {
  gc config set projects_dir "C:/Users/Nome Sobrenome/a=b"
  assert_eq "C:/Users/Nome Sobrenome/a=b" "$(gc config get projects_dir)" ""
  assert_contains "$(gc config list)" "projects_dir=C:/Users/Nome Sobrenome/a=b" ""
}

test_config_chave_invalida() { assert_exit 1 gc config set cor azul; }

test_is_github_url() {
  . "$PLUGIN/lib/common.sh"
  for u in https://github.com/a/b.git git@github.com:a/b.git ssh://git@github.com/a/b https://www.github.com/a/b; do
    gc_is_github_url "$u" || fail "devia aceitar $u"; done
  for u in https://gitlab.com/a/b https://notgithub.com/a/b /tmp/x.git; do
    gc_is_github_url "$u" && fail "devia recusar $u"; done; true
}

test_json_field_e_escape() {
  . "$PLUGIN/lib/common.sh"
  local j='{"session_id":"s1","tool_input":{"command":"git commit -m \"oi\""},"cwd":"C:\\Users\\a"}'
  assert_eq 'git commit -m "oi"' "$(gc_json_field "$j" command)" ""
  assert_eq 'C:\Users\a' "$(gc_json_field "$j" cwd)" ""
  assert_eq 'a\"b\\c' "$(gc_json_escape 'a"b\c')" ""
}

test_norm_path_windows() { . "$PLUGIN/lib/common.sh"; assert_eq "C:/Users/Nome Sobrenome/a.txt" "$(gc_norm_path 'C:\Users\Nome Sobrenome\a.txt')" ""; }

test_quiet_net_nao_chama_programa_de_senha() {
  . "$PLUGIN/lib/common.sh"
  local logger="$SANDBOX/askpass.sh"
  printf '%s\n' '#!/usr/bin/env bash' "echo chamado >> \"$SANDBOX/askpass.log\"" 'echo segredo' > "$logger"; chmod +x "$logger"
  ( export SSH_ASKPASS="$logger" GIT_ASKPASS="$logger" DISPLAY=:0; gc_quiet_net
    printf 'protocol=https\nhost=example.invalid\n\n' | git -c credential.helper= credential fill >/dev/null 2>&1 )
  [ -e "$SANDBOX/askpass.log" ] && fail "o git chamou o programa que abre a janela de senha"; true
}

test_timeout() {
  . "$PLUGIN/lib/common.sh"
  gc_run_with_timeout 1 sleep 5; assert_eq "124" "$?" "estourou"
  gc_run_with_timeout 5 false; assert_eq "1" "$?" "código real"
}

test_toplevel_sobe_ate_pasta_existente() {
  . "$PLUGIN/lib/common.sh"; local r t; r=$(make_local_repo l); : > "$r/.marca"
  t=$(gc_toplevel "$r/nao/existe/a.txt") || fail "não achou o topo"
  # Pela marca, e não pelo texto: o mesmo lugar tem nomes diferentes (/private/var no Mac, RUNNER~1 no Windows).
  assert_file "$t/.marca" "o topo veio como $t"
}

test_timeout_devolve_124_sempre() {
  . "$PLUGIN/lib/common.sh"; local i rc
  for i in 1 2 3 4 5; do gc_run_with_timeout 1 sleep 5; rc=$?; assert_eq "124" "$rc" "rodada $i"; done
}

test_github_url_so_o_servidor_github() {
  . "$PLUGIN/lib/common.sh"; local u
  for u in https://github.com/a/b.git https://usuario@github.com/a/b HTTPS://GitHub.com/a/b \
           git@github.com:a/b.git ssh://git@github.com/a/b.git ssh://git@ssh.github.com:443/a/b.git; do
    gc_is_github_url "$u" || fail "devia aceitar $u"
  done
  for u in https://gitlab.com/github.com/x https://github.com.exemplo.com/a/b git@gitlab.com:a/b.git \
           https://exemplo.com/github.com ssh://git@exemplo.com/github.com/a.git; do
    gc_is_github_url "$u" && fail "não devia aceitar $u"
  done; return 0
}

test_github_ssh_to_https() {
  . "$PLUGIN/lib/common.sh"
  assert_eq "https://github.com/a/b.git" "$(gc_github_ssh_to_https git@github.com:a/b.git)" ""
  assert_eq "https://github.com/a/b.git" "$(gc_github_ssh_to_https git@github.com:a/b)" ""
  assert_eq "https://github.com/a/b.git" "$(gc_github_ssh_to_https ssh://git@github.com/a/b.git)" ""
  assert_eq "https://github.com/a/b.git" "$(gc_github_ssh_to_https ssh://git@ssh.github.com:443/a/b.git)" ""
  gc_github_ssh_to_https https://github.com/a/b.git >/dev/null && fail "já é https: devia devolver 1"
  gc_github_ssh_to_https git@gitlab.com:a/b.git >/dev/null && fail "gitlab não é GitHub"; return 0
}

test_dono_do_endereco() {
  . "$PLUGIN/lib/common.sh"; local u out rc
  for u in https://github.com/PPDRADA/site.git https://www.github.com/ppdrada/site https://usuario@github.com/ppdrada/site \
           git@github.com:ppdrada/site.git ssh://git@github.com/ppdrada/site ssh://git@ssh.github.com:443/ppdrada/site.git \
           git://github.com/ppdrada/site git@github.com:PPDRADA/site ssh://git@ssh.github.com:443/PPDRADA/site; do
    out=$(gc_github_owner "$u"); rc=$?
    assert_eq "0" "$rc" "código de $u"; assert_eq "ppdrada" "$out" "dono de $u"
  done
  for u in https://gitlab.com/ppdrada/site https://gitlab.com/github.com/x "qualquer coisa" "" https://github.com/ \
           https://github.com.exemplo.com/ppdrada/site git@gitlab.com:ppdrada/site.git ssh://git@exemplo.com/github.com/ppdrada/site.git; do
    out=$(gc_github_owner "$u"); rc=$?
    assert_eq "1" "$rc" "código de [$u]"; assert_eq "" "$out" "não devia imprimir nada para [$u]"
  done
}

test_caminho_real_da_pasta() {
  . "$PLUGIN/lib/common.sh"; local r out re='^[A-Za-z]:/'
  r=$(gc_real_dir "$SANDBOX/home"); assert_eq "0" "$?" "a pasta existe"
  assert_eq "$r" "$(gc_real_dir "$SANDBOX/home/")" "com e sem a barra no fim"
  assert_eq "$r" "$(gc_real_dir "$SANDBOX/home/../home")" "o caminho vem resolvido"
  if [ "$(gc_os)" = windows ]; then
    [[ $r =~ $re ]] || fail "no Windows o caminho devia começar com a letra da unidade (C:/...), veio [$r]"
  else
    assert_eq "$(cd "$SANDBOX/home" && pwd -P)" "$r" "fora do Windows é o pwd -P"
  fi
  out=$(gc_real_dir "$SANDBOX/nao/existe"); assert_eq "1" "$?" "pasta que não existe"; assert_eq "" "$out" "não imprime nada"
  : > "$SANDBOX/arquivo"; assert_exit 1 gc_real_dir "$SANDBOX/arquivo"
}
