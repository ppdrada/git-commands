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

test_github_user_so_vale_com_forma_de_login() {
  . "$PLUGIN/lib/common.sh"; . "$PLUGIN/lib/doctor.sh"; . "$PLUGIN/lib/folders.sh"
  # GIT_COMMANDS_GH aponta para o stub: o gh da máquina nunca entra.
  make_gh_stub; export GIT_COMMANDS_GH="$SANDBOX/stub/gh"
  local out rc v cfg; cfg="$(gc_home)/config"
  # O que o gh do computador responde e não tem forma de login (o corpo de um erro, duas linhas, dois nomes, começo com -)
  # é como se não houvesse login: não imprime nada e não grava nada.
  for v in '{' $'a\nb' 'dois nomes' '-x'; do
    out=$(STUB_GH_USER=$v gc_github_user); rc=$?
    assert_eq "0" "$rc" "[$v]: código"; assert_eq "" "$out" "[$v]: saída"
    grep -q '^github_user=' "$cfg" 2>/dev/null && fail "gravou [$v] no config"
  done
  assert_eq "" "$(gc config get github_user)" "nada foi gravado"
  # O mesmo vale para o que já está no config: o corpo de um erro que uma versão com defeito gravou (a primeira linha dele
  # é o valor) não é login. Sem login no gh, não imprime nada; com login no gh, o login do gh o troca.
  printf '%s\n' 'github_user={' '  "message": "Bad credentials",' '  "status": "401"' '}' > "$cfg"
  out=$(STUB_GH_USER= gc_github_user); rc=$?
  assert_eq "0" "$rc" "erro no config, gh sem login: código"; assert_eq "" "$out" "erro no config, gh sem login: saída"
  out=$(STUB_GH_USER=ppdrada gc_github_user); rc=$?
  assert_eq "0" "$rc" "erro no config, gh logado: código"; assert_eq "ppdrada" "$out" "erro no config, gh logado: saída"
  assert_eq "ppdrada" "$(gc config get github_user)" "o login do gh trocou o erro"
  # Um login com maiúsculas, - e _ tem forma de login: vale como veio.
  gc_config_set github_user ""
  out=$(STUB_GH_USER=Mona-Lisa_octo gc_github_user)
  assert_eq "Mona-Lisa_octo" "$out" "login do gh com maiúsculas, - e _"
  assert_eq "Mona-Lisa_octo" "$(gc_config_get github_user)" "gravado como veio"
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

# ---------- a busca na pasta do usuário ----------

# Estes testes usam a pasta do usuário do sandbox ($HOME) e repositórios feitos por make_repo_at ou repo_com_origin, que
# não têm remoto de verdade: a busca só lê o endereço do origin e nunca vai à rede.

# Os repositórios que o gc_home_repos acha para o login $1, em ordem: a ordem em que o find lista não vale nada.
achados() { gc_home_repos "$@" | LC_ALL=C sort; }

# O caminho real de cada pasta, dada a partir da pasta do usuário, em ordem.
esperados() { local p; for p in "$@"; do gc_real_dir "$HOME/$p"; done | LC_ALL=C sort; }

# Um repositório vazio em $HOME/$1, só com o origin $2: para a busca bastam a pasta .git e o endereço, e assim o teste não
# gasta tempo com commits.
repo_com_origin() { git init -q "$HOME/$1" && git -C "$HOME/$1" config remote.origin.url "$2"; }

# O find de verdade, para um find falso chamar depois de entrar na frente do PATH. No Windows tem de ser o find do Git Bash,
# e não o find.exe do sistema (que não entende as opções): se o do PATH não funcionar como find, é o /usr/bin/find.
find_de_verdade() {
  local f; f=$(command -v find)
  "$f" "$SANDBOX" -maxdepth 0 >/dev/null 2>&1 || f=/usr/bin/find
  printf '%s\n' "$f"
}

test_busca_acha_os_projetos_da_conta() {
  . "$PLUGIN/lib/common.sh"; . "$PLUGIN/lib/folders.sh"
  # No Mac a busca pula a Documents (a lista do Mac é o assunto do teste seguinte): aqui o sistema é sempre o Linux.
  export GIT_COMMANDS_OS=linux
  # A pasta do usuário do teste fica dentro de uma pasta escondida, de uma AppData e de uma node_modules: as
  # regras de pular valem pelo nome das pastas de dentro dela, nunca pelo caminho.
  export HOME="$SANDBOX/.cache/AppData/node_modules/home" TMPDIR="$SANDBOX/tmp"
  mkdir -p "$HOME" "$TMPDIR"
  local r out rc
  # Da conta: uma logo abaixo de uma pasta, uma a 5 níveis (o .git dela fica na profundidade 5 contando da pasta
  # de cima), uma guardada dentro de outro projeto e uma numa pasta com espaço no nome.
  for r in Documents/a a/b/c/d/projeto Documents/a/dentro; do make_repo_at "$HOME/$r" teste >/dev/null; done
  make_repo_at "$HOME/Meus Projetos/site velho" teste site-velho >/dev/null
  # De fora: funda demais, escondida (logo na pasta do usuário e dentro de outra pasta), em AppData, em node_modules,
  # de outra conta, de um dono que só começa igual ao login e sem origin.
  for r in a/b/c/d/e/fundo .claude/plugins/marketplaces/x Documents/.escondida/y \
    AppData/Local/x Documents/node_modules/x; do
    make_repo_at "$HOME/$r" teste >/dev/null
  done
  make_repo_at "$HOME/Documents/outro" outra-conta >/dev/null
  make_repo_at "$HOME/Documents/parecido" teste-dois >/dev/null
  git init -q -b main "$HOME/Documents/sem-origin"
  # Também ficam de fora um worktree de outro projeto (o .git dele é um arquivo, e o projeto já vale pela pasta
  # principal) e uma pasta que é atalho para outra (onde o sistema faz atalho de verdade): a busca não sai da pasta
  # do usuário. Onde o ln -s só copia (Git Bash sem permissão), a cópia sai e o teste segue sem ela.
  git -C "$HOME/Documents/a" worktree add -q "$HOME/Documents/wt" -b wt
  make_repo_at "$SANDBOX/fora/x" teste >/dev/null
  ln -s "$SANDBOX/fora" "$HOME/atalho" 2>/dev/null
  [ -L "$HOME/atalho" ] || rm -rf "$HOME/atalho"
  out=$(gc_home_repos teste 2>"$SANDBOX/err"); rc=$?
  assert_eq "0" "$rc" "código"
  assert_eq "$(esperados Documents/a Documents/a/dentro a/b/c/d/projeto "Meus Projetos/site velho")" \
    "$(printf '%s\n' "$out" | LC_ALL=C sort)" "os projetos da conta"
  assert_eq "" "$(cat "$SANDBOX/err")" "sem aviso quando acaba dentro do limite"
  assert_eq "" "$(ls "$TMPDIR")" "não sobra arquivo temporário"
  # Sem login não há conta: não acha nada, e o repositório sem origin não vira "da conta" por ter o dono vazio.
  out=$(gc_home_repos ""); rc=$?
  assert_eq "0" "$rc" "sem login: código"; assert_eq "" "$out" "sem login: nada"
}

test_busca_no_mac_pula_as_pastas_protegidas() {
  . "$PLUGIN/lib/common.sh"; . "$PLUGIN/lib/folders.sh"
  local r
  for r in Documents/a Desktop/c Downloads/d Library/x projetos/b; do make_repo_at "$HOME/$r" teste >/dev/null; done
  # No Mac o macOS pergunta se o programa pode ler essas pastas: a busca nem entra nelas.
  assert_eq "$(esperados projetos/b)" "$(GIT_COMMANDS_OS=mac achados teste)" "mac: só a pasta que não é protegida"
  # Nos outros sistemas elas valem como qualquer outra.
  assert_eq "$(esperados Documents/a Desktop/c Downloads/d Library/x projetos/b)" \
    "$(GIT_COMMANDS_OS=linux achados teste)" "linux: todas"
}

test_busca_com_dono_em_maiusculas() {
  . "$PLUGIN/lib/common.sh"; . "$PLUGIN/lib/folders.sh"
  local todos
  # Numa pasta que o Mac não pula, para o teste valer em qualquer sistema.
  make_repo_at "$HOME/projetos/c" TESTE c >/dev/null
  make_repo_at "$HOME/projetos/d" teste d >/dev/null
  make_repo_at "$HOME/projetos/e" teste e >/dev/null
  git -C "$HOME/projetos/e" remote set-url origin git@github.com:Teste/e.git
  todos=$(esperados projetos/c projetos/d projetos/e)
  # O dono do endereço vale em qualquer grafia, e o login também: o github_user guarda como o gh devolveu.
  assert_eq "$todos" "$(achados teste)" "login em minúsculas"
  assert_eq "$todos" "$(achados TESTE)" "login em maiúsculas"
  assert_eq "$todos" "$(achados Teste)" "login com a primeira letra maiúscula"
}

test_busca_concorda_com_o_dono_do_endereco() {
  . "$PLUGIN/lib/common.sh"; . "$PLUGIN/lib/folders.sh"
  local u i=0 n=0 r esperado=""
  # Um repositório para cada forma de origin, numa pasta que o Mac não pula. Os onze primeiros são da conta, nas formas que o
  # gc_github_owner conhece (com usuário, www., porta, SSH, git://, maiúsculas no dono e no servidor, sem nada depois do dono).
  # Os outros não são: GitLab, sem dono, outra conta, um dono que só começa igual, um servidor que só começa igual, um com
  # outra letra no lugar do ponto (o \. da gramática é um ponto de verdade também no awk) e o vazio.
  for u in https://github.com/teste/a.git https://usuario@github.com/teste/a https://www.github.com/teste/a \
    https://github.com:443/teste/a git@github.com:teste/a.git ssh://git@github.com/teste/a.git \
    ssh://git@ssh.github.com:443/teste/a.git git://github.com/teste/a HTTPS://GitHub.COM/TESTE/a git@GITHUB.COM:Teste/a \
    https://github.com/teste https://gitlab.com/teste/a https://github.com/ https://github.com/outra-conta/a \
    https://github.com/teste-dois/a https://github.com.exemplo.com/teste/a https://githubxcom/teste/a ""; do
    i=$((i + 1)); r="projetos/r$i"
    repo_com_origin "$r" "$u"
    if [ "$(gc_github_owner "$u")" = teste ]; then esperado="$esperado $r"; n=$((n + 1)); fi
  done
  assert_eq "11" "$n" "o gc_github_owner dá o login nos onze primeiros"
  # A busca usa a mesma gramática do gc_github_owner: ela acha exatamente os repositórios em que ele dá o login.
  assert_eq "$(esperados $esperado)" "$(achados teste)" "os mesmos repositórios que o gc_github_owner"
}

test_busca_so_a_primeira_linha_do_origin_vale() {
  . "$PLUGIN/lib/common.sh"; . "$PLUGIN/lib/folders.sh"
  local outra
  mkdir -p "$HOME/outra"; outra=$(gc_real_dir "$HOME/outra")
  # Um valor do config pode ter quebra de linha (o \n escapado no arquivo). Aqui o origin tem três linhas: um endereço da
  # conta, o caminho de outra pasta e outro endereço da conta. Se a busca passasse adiante as linhas de baixo, o caminho
  # viraria um projeto.
  repo_com_origin projetos/a "$(printf '%s\n%s\n%s' https://github.com/teste/a.git "$outra" https://github.com/teste/b.git)"
  assert_eq "$(esperados projetos/a)" "$(achados teste)" "só o projeto, pela primeira linha do origin"
}

test_busca_linha_cortada_nao_vira_projeto() {
  . "$PLUGIN/lib/common.sh"; . "$PLUGIN/lib/folders.sh"
  mkdir -p "$SANDBOX/stub"
  local real
  # A pasta do usuário é ela mesma um repositório da conta (os dotfiles), e dentro dela há um projeto da conta.
  repo_com_origin . https://github.com/teste/dotfiles.git
  repo_com_origin projetos/novo https://github.com/teste/novo.git
  real=$(gc_real_dir "$HOME")
  # Quando o limite de tempo para o find, a última linha do arquivo da busca pode ficar cortada no meio de um caminho, sem o
  # /.git do fim. O find falso imprime o projeto inteiro e, sem quebra de linha, o começo do caminho seguinte: assim o teste
  # não depende de tempo. Pela linha cortada, o git acharia o repositório de fora (os dotfiles).
  printf '%s\n' '#!/usr/bin/env bash' \
    "case \"\$1\" in */projetos) printf '%s\n%s' '$real/projetos/novo/.git' '$real/projetos' ;; esac" > "$SANDBOX/stub/find"
  chmod +x "$SANDBOX/stub/find"
  export PATH="$SANDBOX/stub:$PATH"
  assert_eq "$(esperados projetos/novo)" "$(achados teste)" "a linha cortada não vira projeto"
}

test_busca_nao_sai_do_disco() {
  . "$PLUGIN/lib/common.sh"; . "$PLUGIN/lib/folders.sh"
  mkdir -p "$SANDBOX/stub"
  local find_real
  repo_com_origin a/b https://github.com/teste/b.git
  repo_com_origin c https://github.com/teste/c.git
  # Não dá para montar um disco num teste: o find falso anota o que vem logo depois do caminho, em cada chamada, e chama o
  # de verdade.
  find_real=$(find_de_verdade)
  printf '%s\n' '#!/usr/bin/env bash' \
    "printf '%s %s\n' \"\$2\" \"\$3\" >> \"$SANDBOX/find.log\"" \
    "exec \"$find_real\" \"\$@\"" > "$SANDBOX/stub/find"
  chmod +x "$SANDBOX/stub/find"
  export PATH="$SANDBOX/stub:$PATH"
  assert_eq "$(esperados a/b c)" "$(achados teste)" "os projetos"
  # Uma chamada para cada pasta da pasta do usuário (a e c), as duas com o -xdev logo depois do caminho: o find não entra
  # num disco montado dentro dela. As chamadas vão numa linha só, separadas por ";".
  assert_eq "-xdev -maxdepth;-xdev -maxdepth;" "$(tr '\n' ';' < "$SANDBOX/find.log")" "o -xdev em cada chamada"
}

test_busca_lenta_para_no_limite() {
  . "$PLUGIN/lib/common.sh"; . "$PLUGIN/lib/folders.sh"
  export TMPDIR="$SANDBOX/tmp"; mkdir -p "$TMPDIR" "$SANDBOX/stub"
  local find_real t0 err rc
  # Duas pastas na pasta do usuário: a primeira a busca lê logo, e na segunda o find é lento.
  make_repo_at "$HOME/rapida/b" teste >/dev/null
  make_repo_at "$HOME/zlenta/c" teste >/dev/null
  # O find falso dorme 10 s antes de chamar o de verdade, mas só na pasta zlenta. Se chegar ao fim do sono, deixa
  # um marcador; se for parado, leva o sleep junto e sai. Na rapida ele chama o de verdade na hora, e o limite de 3 s
  # dá folga para isso mesmo onde criar processos é lento (o Windows do CI).
  find_real=$(find_de_verdade)
  printf '%s\n' '#!/usr/bin/env bash' \
    "trap 'kill \$!; exit 143' TERM" \
    "case \"\$1\" in */zlenta) sleep 10 & wait \$!; : > \"$SANDBOX/find-acabou\" ;; esac" \
    "exec \"$find_real\" \"\$@\"" > "$SANDBOX/stub/find"
  chmod +x "$SANDBOX/stub/find"
  export PATH="$SANDBOX/stub:$PATH"
  # O stderr vem por um cano ($(...)): um find que ficasse vivo com ele aberto seguraria a volta até acabar.
  t0=$SECONDS
  err=$(GIT_COMMANDS_SEARCH_SECS=3 gc_home_repos teste 2>&1 >"$SANDBOX/out"); rc=$?
  [ $((SECONDS - t0)) -lt 7 ] || fail "a busca não parou no limite: levou $((SECONDS - t0)) s"
  assert_eq "0" "$rc" "código"
  assert_eq "git-commands: aviso: a busca na pasta do usuário passou de 3 segundos e parou no meio" "$err" "o aviso"
  assert_eq "$(esperados rapida/b)" "$(cat "$SANDBOX/out")" "fica o que ela achou antes do limite"
  assert_eq "" "$(ls "$TMPDIR")" "não sobra arquivo temporário"
  # O find falso da zlenta começou logo depois da rapida, perto do t0: em t0 + 12 s o sono de 10 s já teria acabado.
  # Passado esse tempo, a busca parou de verdade (nenhum marcador) e nada foi escrito na saída de quem chamou.
  sleep $((12 - (SECONDS - t0)))
  [ -e "$SANDBOX/find-acabou" ] && fail "o find lento continuou rodando depois do limite"
  assert_eq "$(esperados rapida/b)" "$(cat "$SANDBOX/out")" "nada escrito depois do limite"
}

test_conferencia_lenta_para_no_limite() {
  . "$PLUGIN/lib/common.sh"; . "$PLUGIN/lib/folders.sh"
  export TMPDIR="$SANDBOX/tmp"; mkdir -p "$TMPDIR" "$SANDBOX/stub"
  local git_real i t0 err rc n linha todos
  for i in 0 1 2 3 4 5 6 7 8 9; do repo_com_origin "projetos/r$i" "https://github.com/teste/r$i.git"; done
  todos=$(esperados projetos/r0 projetos/r1 projetos/r2 projetos/r3 projetos/r4 projetos/r5 projetos/r6 projetos/r7 \
    projetos/r8 projetos/r9)
  # O git falso dorme 1 s quando lê o origin e depois chama o de verdade, achado antes de o stub entrar no PATH (no Windows,
  # o do Git for Windows). Ele só entra no PATH da chamada do gc_home_repos, dentro do $(...). É export, e não PATH=... na
  # frente da função: a atribuição comum esvazia a tabela em que o bash guarda onde achou o git, em qualquer versão dele.
  git_real=$(command -v git)
  printf '%s\n' '#!/usr/bin/env bash' \
    "case \" \$* \" in *' config --get remote.origin.url '*) sleep 1 ;; esac" \
    "exec \"$git_real\" \"\$@\"" > "$SANDBOX/stub/git"
  chmod +x "$SANDBOX/stub/git"
  # O find acha os dez logo, e a conferência leva 1 s por repositório: o limite dela, de 3 s contados do começo dela, a
  # para no meio.
  t0=$SECONDS
  err=$(export PATH="$SANDBOX/stub:$PATH"; GIT_COMMANDS_SEARCH_SECS=3 gc_home_repos teste 2>&1 >"$SANDBOX/out"); rc=$?
  [ $((SECONDS - t0)) -lt 8 ] || fail "a conferência não parou no limite: levou $((SECONDS - t0)) s"
  assert_eq "0" "$rc" "código"
  assert_eq "git-commands: aviso: a busca na pasta do usuário passou de 3 segundos e parou no meio" "$err" "o aviso, uma vez só"
  n=$(grep -c . "$SANDBOX/out")
  [ "$n" -ge 1 ] && [ "$n" -lt 10 ] || fail "devia ficar com parte dos dez projetos: ficou com $n"
  # Fica só o que já foi conferido: cada linha é um projeto da conta.
  while IFS= read -r linha; do
    printf '%s\n' "$todos" | grep -qxF -- "$linha" || fail "listou o que não é projeto da conta: $linha"
  done < "$SANDBOX/out"
  assert_eq "" "$(ls "$TMPDIR")" "não sobra arquivo temporário"
}

# ---------- a lista de todos os projetos ----------

# Estes testes montam a pasta do usuário do sandbox ($HOME), a pasta de projetos e as pastas pedidas e chamam o gc_all_repos, que
# não usa a rede: os repositórios de make_repo_at só existem no disco, e os de make_github_pair nunca são buscados. GIT_COMMANDS_GH
# aponta sempre para o stub ou para um caminho que não existe, para o gh logado da máquina nunca entrar. O sistema é o Linux,
# porque no Mac a busca no usuário pula a Documents; quem olha a caixa das letras troca o sistema a cada chamada.

# Carrega todas as bibliotecas, como o executável: a lista usa o gc_updates_repos (updates.sh) e o gc_gh_bin (doctor.sh).
carrega_libs() { local l; for l in "$PLUGIN"/lib/*.sh; do . "$l"; done; }

# O caminho real de cada pasta dada (caminho completo, ao contrário do esperados), em ordem.
reais() { local p; for p in "$@"; do gc_real_dir "$p"; done | LC_ALL=C sort; }

test_lista_junta_as_tres_fontes() {
  carrega_libs; export GIT_COMMANDS_GH=/nao/existe GIT_COMMANDS_OS=linux
  local out rc
  gc_config_set github_user teste; gc_config_set projects_dir "$SANDBOX/projetos"
  # A pasta do usuário: um projeto da conta. A pasta de projetos: um da conta e um de outra conta. Uma pasta pedida: um de outra
  # conta. Nas pastas escolhidas o dono não importa, então entram os quatro; um da conta que fica fora das três não entra.
  make_repo_at "$HOME/Documents/a" teste >/dev/null
  make_github_pair app >/dev/null
  make_repo_at "$SANDBOX/projetos/de-outra" outra-conta >/dev/null
  make_repo_at "$SANDBOX/fora/x" outra-conta >/dev/null
  make_repo_at "$SANDBOX/solto/y" teste >/dev/null
  gc_cmd_folders add "$SANDBOX/fora" >/dev/null
  out=$(gc_all_repos 2>"$SANDBOX/err"); rc=$?
  assert_eq "0" "$rc" "código"
  assert_eq "$(reais "$HOME/Documents/a" "$SANDBOX/projetos/app" "$SANDBOX/projetos/de-outra" "$SANDBOX/fora/x")" "$out" "os quatro, em ordem"
  assert_eq "" "$(cat "$SANDBOX/err")" "sem aviso"
}

test_lista_sem_repeticao_entre_fontes() {
  carrega_libs; export GIT_COMMANDS_GH=/nao/existe GIT_COMMANDS_OS=linux
  gc_config_set github_user teste
  make_repo_at "$HOME/Documents/a" teste >/dev/null
  # A pasta de projetos é a Documents, escrita na forma do Git Bash ($HOME/Documents: no Windows, /c/... e não C:/...) e a busca no
  # usuário acha o mesmo projeto: ele aparece uma vez só, na forma real.
  gc_config_set projects_dir "$HOME/Documents"
  assert_eq "$(reais "$HOME/Documents/a")" "$(gc_all_repos)" "usuário e pasta de projetos"
  # Pedir a mesma pasta, escrita de outro jeito, não muda nada.
  gc_cmd_folders add "$HOME/Documents/../Documents/" >/dev/null
  assert_eq "$(reais "$HOME/Documents/a")" "$(gc_all_repos)" "mais a pasta pedida"
}

test_ignorada_some_de_todas_as_fontes() {
  carrega_libs; export GIT_COMMANDS_GH=/nao/existe GIT_COMMANDS_OS=linux
  local a="$HOME/Documents/a" copia="$HOME/Documents/a - Cópia" app="$SANDBOX/projetos/app" velho="$SANDBOX/projetos/velho" \
    velhote="$SANDBOX/projetos/velhote" sub="$SANDBOX/fora/sub" d="$SANDBOX/fora/d"
  gc_config_set github_user teste; gc_config_set projects_dir "$SANDBOX/projetos"
  # Na pasta do usuário, um projeto e uma cópia dele (o nome da pasta de um começa igual ao do outro). Na pasta de projetos, um
  # repositório dentro de "velho" e o "velhote", cujo nome também começa igual. Numa pasta pedida, um dentro de "sub" e um solto.
  make_repo_at "$a" teste >/dev/null
  make_repo_at "$copia" teste a-copia >/dev/null
  make_github_pair app >/dev/null
  make_repo_at "$velho/b" outra-conta >/dev/null
  make_repo_at "$velhote" outra-conta >/dev/null
  make_repo_at "$sub/c" outra-conta >/dev/null
  make_repo_at "$d" outra-conta >/dev/null
  gc_cmd_folders add "$SANDBOX/fora" >/dev/null
  assert_eq "$(reais "$a" "$copia" "$app" "$velho/b" "$velhote" "$sub/c" "$d")" "$(gc_all_repos)" "sem ignorar nada"
  # Ignorar a pasta "a - Cópia" tira o repositório que é ela mesma da busca no usuário, e o "a" fica.
  gc_cmd_folders ignore "$copia" >/dev/null
  assert_eq "$(reais "$a" "$app" "$velho/b" "$velhote" "$sub/c" "$d")" "$(gc_all_repos)" "a busca no usuário"
  # Ignorar uma pasta da pasta de projetos e uma pasta pedida tira os repositórios de dentro delas, e o "velhote" fica.
  gc_cmd_folders ignore "$velho" >/dev/null; gc_cmd_folders ignore "$sub" >/dev/null
  assert_eq "$(reais "$a" "$app" "$velhote" "$d")" "$(gc_all_repos)" "a pasta de projetos e a pasta pedida"
  # Voltar a mostrar traz o repositório de volta.
  gc_cmd_folders unignore "$copia" >/dev/null
  assert_eq "$(reais "$a" "$copia" "$app" "$velhote" "$d")" "$(gc_all_repos)" "voltou a aparecer"
}

test_pasta_que_falta_nao_para_a_lista() {
  carrega_libs; export GIT_COMMANDS_GH=/nao/existe GIT_COMMANDS_OS=linux
  local out rc real
  gc_config_set github_user teste
  make_repo_at "$HOME/Documents/a" teste >/dev/null
  make_repo_at "$SANDBOX/fora/b" outra-conta >/dev/null
  # A pasta de projetos não existe, uma pasta pedida foi apagada e outra continua lá.
  gc_config_set projects_dir "$SANDBOX/projetos-que-sumiu"
  mkdir -p "$SANDBOX/fora/apagada"
  gc_cmd_folders add "$SANDBOX/fora/apagada" >/dev/null; gc_cmd_folders add "$SANDBOX/fora" >/dev/null
  real=$(gc_real_dir "$SANDBOX/fora/apagada"); rm -rf "$SANDBOX/fora/apagada"
  out=$(gc_all_repos 2>"$SANDBOX/err"); rc=$?
  assert_eq "0" "$rc" "código"
  assert_eq "$(reais "$HOME/Documents/a" "$SANDBOX/fora/b")" "$out" "a busca no usuário e a pasta pedida que ficou"
  assert_eq "$(printf '%s\n' "git-commands: aviso: a pasta de projetos não foi encontrada: $SANDBOX/projetos-que-sumiu" \
    "git-commands: aviso: a pasta pedida não foi encontrada: $real")" "$(cat "$SANDBOX/err")" "um aviso para cada pasta que falta"
}

test_sem_fonte_nenhuma_da_erro() {
  carrega_libs; export GIT_COMMANDS_GH=/nao/existe
  local out rc real msg='git-commands: não há onde procurar projetos: configure a pasta de projetos (skill configurar), faça login no GitHub ou peça uma pasta (git-commands folders add <pasta>)'
  # Sem login, sem pasta de projetos e sem pastas pedidas.
  out=$(gc_all_repos 2>"$SANDBOX/err"); rc=$?
  assert_eq "1" "$rc" "código"; assert_eq "" "$out" "nada no stdout"
  assert_eq "$msg" "$(cat "$SANDBOX/err")" "o erro, e só ele"
  # Uma pasta de projetos que não existe e uma pasta pedida que sumiu não são fonte: o mesmo erro, depois dos avisos.
  gc_config_set projects_dir "$SANDBOX/projetos-que-sumiu"
  mkdir -p "$SANDBOX/fora/apagada"; gc_cmd_folders add "$SANDBOX/fora/apagada" >/dev/null
  real=$(gc_real_dir "$SANDBOX/fora/apagada"); rm -rf "$SANDBOX/fora/apagada"
  out=$(gc_all_repos 2>"$SANDBOX/err"); rc=$?
  assert_eq "1" "$rc" "com as pastas que faltam: código"; assert_eq "" "$out" "com as pastas que faltam: nada no stdout"
  assert_eq "$(printf '%s\n' "git-commands: aviso: a pasta de projetos não foi encontrada: $SANDBOX/projetos-que-sumiu" \
    "git-commands: aviso: a pasta pedida não foi encontrada: $real" "$msg")" "$(cat "$SANDBOX/err")" "os avisos e, por último, o erro"
}

test_sem_conta_nao_busca_no_usuario() {
  carrega_libs; export GIT_COMMANDS_GH=/nao/existe GIT_COMMANDS_OS=linux
  make_repo_at "$HOME/Documents/a" teste >/dev/null
  make_github_pair app >/dev/null
  gc_config_set projects_dir "$SANDBOX/projetos"
  # Sem login a busca no usuário fica desligada: só vale a pasta de projetos, mesmo com um projeto da conta na Documents.
  assert_eq "$(reais "$SANDBOX/projetos/app")" "$(gc_all_repos)" "sem login"
  # Com o login no config, ela liga.
  gc_config_set github_user teste
  assert_eq "$(reais "$HOME/Documents/a" "$SANDBOX/projetos/app")" "$(gc_all_repos)" "com login"
}

test_lista_usa_o_login_do_gh() {
  carrega_libs; make_gh_stub; export GIT_COMMANDS_GH="$SANDBOX/stub/gh" GIT_COMMANDS_OS=linux
  make_repo_at "$HOME/Documents/a" teste >/dev/null
  # Quem atualizou de uma versão antiga não tem github_user no config. Com o gh sem login, não há onde procurar.
  STUB_GH_USER= gc_all_repos >/dev/null 2>&1; assert_eq "1" "$?" "gh sem login: código"
  assert_eq "" "$(gc_config_get github_user)" "gh sem login: o config continua vazio"
  # Com o gh logado, o login vira o github_user e a busca no usuário liga na primeira verificação.
  assert_eq "$(reais "$HOME/Documents/a")" "$(STUB_GH_USER=teste gc_all_repos)" "gh logado"
  assert_eq "teste" "$(gc_config_get github_user)" "gh logado: o login foi gravado"
}

test_lista_junta_as_grafias_da_mesma_pasta_so_no_windows() {
  carrega_libs; export GIT_COMMANDS_GH=/nao/existe GIT_COMMANDS_OS=linux
  local maiusculas="$SANDBOX/fora/LOJA" dois=
  make_repo_at "$SANDBOX/fora/Loja/app" teste >/dev/null
  # Onde o disco diferencia as letras (Linux), LOJA é outra pasta e ganha o seu repositório. Onde não diferencia (Windows e, em
  # geral, o Mac), é a mesma pasta, escrita de outro jeito.
  if [ ! -d "$maiusculas" ]; then make_repo_at "$maiusculas/app" teste >/dev/null; dois=1; fi
  gc_cmd_folders add "$SANDBOX/fora/Loja" >/dev/null; gc_cmd_folders add "$maiusculas" >/dev/null
  # No Windows as duas grafias são uma pasta só, e o repositório aparece uma vez.
  assert_eq "1" "$(GIT_COMMANDS_OS=windows gc_all_repos | grep -c .)" "windows: uma linha"
  # No Linux e no Mac as letras contam: outra grafia é outra pasta (só dá para ver com duas pastas de verdade).
  [ -z "$dois" ] || assert_eq "2" "$(GIT_COMMANDS_OS=linux gc_all_repos | grep -c .)" "linux: uma linha para cada pasta"
  return 0
}

test_ignorar_so_ignora_as_letras_no_windows() {
  carrega_libs; export GIT_COMMANDS_GH=/nao/existe GIT_COMMANDS_OS=linux
  make_repo_at "$SANDBOX/fora/Loja/app" teste >/dev/null
  gc_cmd_folders add "$SANDBOX/fora" >/dev/null
  # A pasta ignorada escrita em maiúsculas, direto no arquivo: no Linux a pasta LOJA nem existe.
  printf '%s\n' "$(gc_real_dir "$SANDBOX/fora")/LOJA" > "$(gc_home)/ignored"
  assert_eq "" "$(GIT_COMMANDS_OS=windows gc_all_repos)" "windows: a pasta ignorada vale com outra caixa"
  assert_eq "$(reais "$SANDBOX/fora/Loja/app")" "$(GIT_COMMANDS_OS=linux gc_all_repos)" "linux: outra caixa é outra pasta"
  assert_eq "$(reais "$SANDBOX/fora/Loja/app")" "$(GIT_COMMANDS_OS=mac gc_all_repos)" "mac: outra caixa é outra pasta"
}

test_lista_pasta_sem_permissao_vira_aviso() {
  carrega_libs
  [ "$(gc_os)" = windows ] && skip "no Windows o chmod não tira a leitura"
  [ "$(id -u)" = 0 ] && skip "o root lê qualquer pasta"
  export GIT_COMMANDS_GH=/nao/existe GIT_COMMANDS_OS=linux
  local out rc
  gc_config_set github_user teste
  make_repo_at "$HOME/Documents/a" teste >/dev/null
  make_repo_at "$SANDBOX/fora/b" outra-conta >/dev/null
  mkdir -p "$SANDBOX/fechada/x"
  # A pasta de projetos existe, mas não dá para ler; a pasta pedida dá. O chmod volta antes das conferências, para o sandbox poder ser apagado.
  gc_config_set projects_dir "$SANDBOX/fechada"; gc_cmd_folders add "$SANDBOX/fora" >/dev/null
  chmod 000 "$SANDBOX/fechada"
  out=$(gc_all_repos 2>"$SANDBOX/err"); rc=$?
  chmod 755 "$SANDBOX/fechada"
  assert_eq "0" "$rc" "código"
  assert_eq "$(reais "$HOME/Documents/a" "$SANDBOX/fora/b")" "$out" "as outras fontes seguem"
  assert_eq "git-commands: aviso: sem permissão para ler a pasta: $SANDBOX/fechada" "$(cat "$SANDBOX/err")" "o aviso"
}
