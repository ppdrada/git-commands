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

# Os testes de "git-commands folders" rodam com GIT_COMMANDS_GH=/nao/existe: só o list olha o login da
# pessoa, e o gh logado da máquina de quem desenvolve nunca pode entrar.

test_folders_lines_sem_linhas_vazias() {
  . "$PLUGIN/lib/common.sh"; . "$PLUGIN/lib/folders.sh"
  local f="$SANDBOX/lista" out rc
  out=$(gc_folders_lines "$SANDBOX/nao-existe"); rc=$?
  assert_eq "0" "$rc" "arquivo que não existe: código"; assert_eq "" "$out" "arquivo que não existe: saída"
  : > "$f"
  out=$(gc_folders_lines "$f"); rc=$?
  assert_eq "0" "$rc" "arquivo vazio: código"; assert_eq "" "$out" "arquivo vazio: saída"
  # Espaço, apóstrofo, barra invertida e espaço nas pontas ficam como estão; a última linha pode vir sem quebra.
  printf '%s\n' "C:/Users/a b" "" "D'Avila" "" " a\\b " > "$f"; printf 'sem quebra no fim' >> "$f"
  assert_eq "$(printf '%s\n' "C:/Users/a b" "D'Avila" " a\\b " "sem quebra no fim")" "$(gc_folders_lines "$f")" "sem linhas vazias"
}

test_folders_pedir_e_tirar() {
  . "$PLUGIN/lib/common.sh"; export GIT_COMMANDS_GH=/nao/existe
  local dir="$SANDBOX/fora/meu-site" tab=$'\t' real out rc
  mkdir -p "$dir"; real=$(gc_real_dir "$dir")
  # Sem lista nenhuma ainda, não há o que tirar.
  assert_exit 1 gc folders remove "$dir"
  # Pedir: avisa, guarda a pasta na forma real e o list mostra.
  out=$(gc folders add "$dir"); rc=$?
  assert_eq "0" "$rc" "add: código"; assert_eq "pasta pedida: $real" "$out" "add: saída"
  assert_eq "$real" "$(cat "$(gc home)/folders")" "add: a pasta guardada"
  assert_contains "$(gc folders list)" "pedida${tab}${real}${tab}ok" "list: a pasta pedida"
  # Pasta vazia (uma variável que ficou sem valor) nunca está na lista, e a lista não muda.
  assert_exit 1 gc folders remove ""
  assert_eq "$real" "$(cat "$(gc home)/folders")" "remove de pasta vazia: a lista ficou igual"
  # Pedir de novo, escrevendo o caminho de outro jeito: já estava, e o arquivo não muda.
  out=$(gc folders add "$dir/../meu-site/"); rc=$?
  assert_eq "0" "$rc" "segundo add: código"; assert_eq "a pasta já estava na lista: $real" "$out" "segundo add: saída"
  assert_eq "$real" "$(cat "$(gc home)/folders")" "segundo add: o arquivo ficou igual"
  # Tirar, também escrevendo o caminho de outro jeito.
  out=$(gc folders remove "$dir/../meu-site/"); rc=$?
  assert_eq "0" "$rc" "remove: código"; assert_eq "pasta tirada da lista: $real" "$out" "remove: saída"
  assert_not_contains "$(gc folders list)" "pedida${tab}" "list: sem a pasta pedida"
  # Tirar de novo: erro no stderr, código 1.
  out=$(gc folders remove "$dir" 2>&1 >/dev/null); rc=$?
  assert_eq "1" "$rc" "segundo remove: código"
  assert_eq "git-commands: a pasta não está na lista: $real" "$out" "segundo remove: mensagem"
  assert_eq "" "$(ls "$(gc home)" | grep '\.tmp\.')" "não sobra arquivo temporário"
}

test_folders_ignorar_e_voltar() {
  . "$PLUGIN/lib/common.sh"; export GIT_COMMANDS_GH=/nao/existe
  local dir="$SANDBOX/projetos/velho" tab=$'\t' real out rc
  mkdir -p "$dir"; real=$(gc_real_dir "$dir")
  # Sem lista nenhuma ainda, não há o que voltar a mostrar.
  assert_exit 1 gc folders unignore "$dir"
  # Ignorar: avisa, guarda a pasta na forma real e o list mostra. Ignorar não pede a pasta.
  out=$(gc folders ignore "$dir"); rc=$?
  assert_eq "0" "$rc" "ignore: código"; assert_eq "pasta ignorada: $real" "$out" "ignore: saída"
  assert_eq "$real" "$(cat "$(gc home)/ignored")" "ignore: a pasta guardada"
  assert_contains "$(gc folders list)" "ignorada${tab}${real}${tab}ok" "list: a pasta ignorada"
  assert_not_contains "$(gc folders list)" "pedida${tab}" "ignorar não pede a pasta"
  # Ignorar de novo, escrevendo o caminho de outro jeito: já estava, e o arquivo não muda.
  out=$(gc folders ignore "$dir/../velho/"); rc=$?
  assert_eq "0" "$rc" "segundo ignore: código"; assert_eq "a pasta já estava ignorada: $real" "$out" "segundo ignore: saída"
  assert_eq "$real" "$(cat "$(gc home)/ignored")" "segundo ignore: o arquivo ficou igual"
  # Voltar a mostrar, também escrevendo o caminho de outro jeito.
  out=$(gc folders unignore "$dir/../velho/"); rc=$?
  assert_eq "0" "$rc" "unignore: código"; assert_eq "a pasta volta a aparecer: $real" "$out" "unignore: saída"
  assert_not_contains "$(gc folders list)" "ignorada${tab}" "list: sem a pasta ignorada"
  # Voltar de novo: erro no stderr, código 1.
  out=$(gc folders unignore "$dir" 2>&1 >/dev/null); rc=$?
  assert_eq "1" "$rc" "segundo unignore: código"
  assert_eq "git-commands: a pasta não está ignorada: $real" "$out" "segundo unignore: mensagem"
  assert_eq "" "$(ls "$(gc home)" | grep '\.tmp\.')" "não sobra arquivo temporário"
}

test_folders_pasta_que_nao_existe() {
  . "$PLUGIN/lib/common.sh"; export GIT_COMMANDS_GH=/nao/existe
  local nada="$SANDBOX/nao/existe" apagada="$SANDBOX/fora/apagada" tab=$'\t' sub real out rc
  # Pasta que não existe não entra em lista nenhuma.
  for sub in add ignore; do
    out=$(gc folders "$sub" "$nada" 2>&1 >/dev/null); rc=$?
    assert_eq "1" "$rc" "$sub: código"
    assert_eq "git-commands: a pasta não existe: $nada" "$out" "$sub: mensagem no stderr"
    assert_eq "" "$(gc folders "$sub" "$nada" 2>/dev/null)" "$sub: nada no stdout"
    assert_exit 1 gc folders "$sub" ""
  done
  [ -e "$(gc home)/folders" ] && fail "add de pasta que não existe gravou a lista de pedidas"
  [ -e "$(gc home)/ignored" ] && fail "ignore de pasta que não existe gravou a lista de ignoradas"
  # Pasta pedida ou ignorada que some do disco continua na lista, marcada como não encontrada.
  mkdir -p "$apagada"; real=$(gc_real_dir "$apagada")
  gc folders add "$apagada" >/dev/null; gc folders ignore "$apagada" >/dev/null
  rm -rf "$apagada"
  out=$(gc folders list)
  assert_contains "$out" "pedida${tab}${real}${tab}nao-encontrada" "pedida que sumiu"
  assert_contains "$out" "ignorada${tab}${real}${tab}nao-encontrada" "ignorada que sumiu"
  # Dá para tirá-la da lista escrevendo o caminho como o list mostra.
  assert_eq "pasta tirada da lista: $real" "$(gc folders remove "$real")" "remove da pasta que sumiu"
  assert_eq "a pasta volta a aparecer: $real" "$(gc folders unignore "$real")" "unignore da pasta que sumiu"
  assert_not_contains "$(gc folders list)" "nao-encontrada" "list: nada mais para tirar"
}

test_folders_nomes_com_espaco_e_acento() {
  . "$PLUGIN/lib/common.sh"; export GIT_COMMANDS_GH=/nao/existe
  local tab=$'\t' nome real out
  for nome in "site - Cópia" "D'Avila"; do
    mkdir -p "$SANDBOX/fora/$nome"; real=$(gc_real_dir "$SANDBOX/fora/$nome")
    assert_eq "pasta pedida: $real" "$(gc folders add "$SANDBOX/fora/$nome")" "add: $nome"
    assert_eq "pasta ignorada: $real" "$(gc folders ignore "$SANDBOX/fora/$nome")" "ignore: $nome"
    out=$(gc folders list)
    assert_contains "$out" "pedida${tab}${real}${tab}ok" "list (pedida): $nome"
    assert_contains "$out" "ignorada${tab}${real}${tab}ok" "list (ignorada): $nome"
    assert_eq "pasta tirada da lista: $real" "$(gc folders remove "$SANDBOX/fora/$nome")" "remove: $nome"
    assert_eq "a pasta volta a aparecer: $real" "$(gc folders unignore "$SANDBOX/fora/$nome")" "unignore: $nome"
  done
  # O nome de uma pasta pode ser o começo do nome de outra, e o ponto vale só como ponto: add e remove só
  # valem para a pasta exata, e a de nome parecido fica.
  mkdir -p "$SANDBOX/fora/v.1" "$SANDBOX/fora/vx1" "$SANDBOX/fora/v.1 - Cópia"
  gc folders add "$SANDBOX/fora/v.1 - Cópia" >/dev/null
  assert_eq "pasta pedida: $(gc_real_dir "$SANDBOX/fora/v.1")" "$(gc folders add "$SANDBOX/fora/v.1")" "add de um nome que é o começo de outro"
  gc folders add "$SANDBOX/fora/vx1" >/dev/null
  assert_eq "pasta tirada da lista: $(gc_real_dir "$SANDBOX/fora/v.1")" "$(gc folders remove "$SANDBOX/fora/v.1")" "remove de v.1"
  assert_exit 1 gc folders remove "$SANDBOX/fora/v.1"
  assert_eq "$(printf '%s\n' "$(gc_real_dir "$SANDBOX/fora/v.1 - Cópia")" "$(gc_real_dir "$SANDBOX/fora/vx1")")" \
    "$(cat "$(gc home)/folders")" "as pastas de nome parecido ficaram"
}

test_folders_lista_as_fontes() {
  . "$PLUGIN/lib/common.sh"; export GIT_COMMANDS_GH=/nao/existe
  local tab=$'\t' home pedida="$SANDBOX/fora/pedida" ignorada="$SANDBOX/fora/ignorada" out
  home=$(gc_real_dir "$HOME")
  # Sem login e sem pasta de projetos: só as duas linhas fixas, a busca no usuário desligada.
  out=$(gc folders list)
  assert_eq "usuario${tab}${home}${tab}desligada" "$(printf '%s\n' "$out" | sed -n 1p)" "usuário sem login"
  assert_eq "projetos${tab}${tab}nao-configurada" "$(printf '%s\n' "$out" | sed -n 2p)" "projetos sem pasta"
  assert_eq "2" "$(printf '%s\n' "$out" | grep -c .)" "só as duas linhas fixas"
  # Com login, a busca no usuário liga.
  gc config set github_user teste
  assert_eq "usuario${tab}${home}${tab}ok" "$(gc folders list | sed -n 1p)" "usuário com login"
  # A pasta de projetos: com a pasta, e com uma pasta que não existe.
  gc config set projects_dir "$SANDBOX/projetos"
  assert_eq "projetos${tab}$SANDBOX/projetos${tab}ok" "$(gc folders list | sed -n 2p)" "pasta de projetos que existe"
  gc config set projects_dir "$SANDBOX/projetos-que-sumiu"
  assert_eq "projetos${tab}$SANDBOX/projetos-que-sumiu${tab}nao-encontrada" "$(gc folders list | sed -n 2p)" "pasta de projetos que não existe"
  # As quatro fontes, na ordem: usuário, projetos, pedida, ignorada.
  gc config set projects_dir "$SANDBOX/projetos"
  mkdir -p "$pedida" "$ignorada"; gc folders add "$pedida" >/dev/null; gc folders ignore "$ignorada" >/dev/null
  assert_eq "$(printf 'usuario\t%s\tok\nprojetos\t%s\tok\npedida\t%s\tok\nignorada\t%s\tok' \
    "$home" "$SANDBOX/projetos" "$(gc_real_dir "$pedida")" "$(gc_real_dir "$ignorada")")" \
    "$(gc folders list)" "as quatro fontes, na ordem"
}

test_folders_lista_usa_o_login_do_gh() {
  . "$PLUGIN/lib/common.sh"
  make_gh_stub; export GIT_COMMANDS_GH="$SANDBOX/stub/gh"
  local tab=$'\t' home; home=$(gc_real_dir "$HOME")
  # gh sem login guardado: a busca no usuário continua desligada, e nada é gravado.
  assert_eq "usuario${tab}${home}${tab}desligada" "$(STUB_GH_USER= gc folders list | sed -n 1p)" "gh sem login"
  assert_eq "" "$(gc config get github_user)" "gh sem login: o config continua vazio"
  # gh logado: o list já mostra a busca ligada, porque o login do gh vira o github_user.
  assert_eq "usuario${tab}${home}${tab}ok" "$(STUB_GH_USER=ppdrada gc folders list | sed -n 1p)" "gh logado"
  assert_eq "ppdrada" "$(gc config get github_user)" "gh logado: o login foi gravado"
}

test_folders_comparacao_so_ignora_maiusculas_no_windows() {
  . "$PLUGIN/lib/common.sh"; export GIT_COMMANDS_GH=/nao/existe
  local dir="$SANDBOX/fora/Meu Site" real maiusculas out rc
  mkdir -p "$dir"; real=$(gc_real_dir "$dir"); maiusculas=$(printf '%s\n' "$real" | tr 'a-z' 'A-Z')
  gc folders add "$dir" >/dev/null; gc folders ignore "$dir" >/dev/null
  # Onde o disco também não diferencia maiúsculas (Windows, e em geral o Mac), pedir ou ignorar a mesma pasta
  # escrita em maiúsculas é repetir o pedido. Em outros discos a pasta em maiúsculas não existe, e isto não roda.
  if [ -d "$maiusculas" ]; then
    assert_contains "$(GIT_COMMANDS_OS=windows gc folders add "$maiusculas")" "já estava" "windows: add em maiúsculas"
    assert_contains "$(GIT_COMMANDS_OS=windows gc folders ignore "$maiusculas")" "já estava" "windows: ignore em maiúsculas"
    assert_eq "$real" "$(cat "$(gc home)/folders")" "windows: add em maiúsculas não repete a linha"
  fi
  # A pasta some do disco, para só o texto do caminho contar, em qualquer sistema.
  rm -rf "$dir"
  # No Linux e no Mac as letras contam: outra grafia é outra pasta.
  GIT_COMMANDS_OS=linux gc folders remove "$maiusculas" >/dev/null 2>&1; assert_eq "1" "$?" "linux: remove com outra grafia"
  GIT_COMMANDS_OS=linux gc folders unignore "$maiusculas" >/dev/null 2>&1; assert_eq "1" "$?" "linux: unignore com outra grafia"
  assert_eq "$real" "$(cat "$(gc home)/folders")" "linux: a pasta pedida continua na lista"
  assert_eq "$real" "$(cat "$(gc home)/ignored")" "linux: a pasta ignorada continua na lista"
  # No Windows não importa se o caminho vem em maiúsculas ou minúsculas.
  out=$(GIT_COMMANDS_OS=windows gc folders remove "$maiusculas"); rc=$?
  assert_eq "0" "$rc" "windows: remove, código"; assert_eq "pasta tirada da lista: $maiusculas" "$out" "windows: remove, saída"
  out=$(GIT_COMMANDS_OS=windows gc folders unignore "$maiusculas"); rc=$?
  assert_eq "0" "$rc" "windows: unignore, código"; assert_eq "a pasta volta a aparecer: $maiusculas" "$out" "windows: unignore, saída"
  [ -s "$(gc home)/folders" ] && fail "windows: sobrou linha na lista de pedidas"
  [ -s "$(gc home)/ignored" ] && fail "windows: sobrou linha na lista de ignoradas"
  return 0
}

test_folders_uso() {
  local out rc a uso='uso: git-commands folders add <pasta> | remove <pasta> | ignore <pasta> | unignore <pasta> | list'
  out=$(gc folders 2>&1 >/dev/null); rc=$?
  assert_eq "1" "$rc" "sem argumento: código"; assert_eq "$uso" "$out" "sem argumento: o uso vai para o stderr"
  assert_eq "" "$(gc folders 2>/dev/null)" "sem argumento: nada no stdout"
  out=$(gc folders voar 2>&1); rc=$?
  assert_eq "1" "$rc" "subcomando desconhecido: código"; assert_contains "$out" "uso: git-commands folders" "subcomando desconhecido: o uso"
  # Falta a pasta, ou sobra argumento (um caminho com espaço escrito sem aspas): sai com 1 e não grava nada.
  mkdir -p "$SANDBOX/fora/site"
  for a in add remove ignore unignore; do assert_exit 1 gc folders "$a"; done
  assert_exit 1 gc folders add "$SANDBOX/fora/site" - Cópia
  assert_exit 1 gc folders ignore "$SANDBOX/fora/site" - Cópia
  assert_exit 1 gc folders list sobrando
  [ -e "$(gc home)/folders" ] && fail "gravou uma pasta pedida com argumentos a mais"
  [ -e "$(gc home)/ignored" ] && fail "gravou uma pasta ignorada com argumentos a mais"
  # Com a pasta nas duas listas, argumento a mais em remove e unignore também cai no uso, e a pasta fica.
  gc folders add "$SANDBOX/fora/site" >/dev/null; gc folders ignore "$SANDBOX/fora/site" >/dev/null
  assert_exit 1 gc folders remove "$SANDBOX/fora/site" - Cópia
  assert_exit 1 gc folders unignore "$SANDBOX/fora/site" - Cópia
  [ -s "$(gc home)/folders" ] || fail "remove com argumentos a mais tirou a pasta pedida"
  [ -s "$(gc home)/ignored" ] || fail "unignore com argumentos a mais tirou a pasta ignorada"
  # O folders está na lista de subcomandos que o git-commands mostra.
  assert_contains "$(gc 2>&1)" "folders" "gc_usage"
  return 0
}
