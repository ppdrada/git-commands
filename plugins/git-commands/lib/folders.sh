# folders: de onde a verificação automática tira os projetos: a pasta do usuário (os projetos da
# conta do GitHub da pessoa), a pasta de projetos e as pastas que a pessoa pediu, menos as que
# ela mandou ignorar.

# Login da pessoa no GitHub. Vem do config (github_user); se estiver vazio, pergunta ao gh do
# computador, que guarda o login em arquivo (sem rede), e grava a resposta no config. Sem gh ou
# sem login não imprime nada, e sai com 0 do mesmo jeito.
gc_github_user() {
  local u gh
  u=$(gc_config_get github_user)
  if [ -z "$u" ]; then
    gh=$(gc_gh_bin)
    if [ -n "$gh" ]; then
      u=$(gc_run_with_timeout 10 "$gh" config get -h github.com user 2>/dev/null)
      [ -n "$u" ] && gc_config_set github_user "$u"
    fi
  fi
  [ -n "$u" ] && printf '%s\n' "$u"
  return 0
}

# ---------- pastas pedidas e ignoradas ----------

# As pastas pedidas ficam em <home>/folders e as ignoradas em <home>/ignored: uma pasta por linha, sempre na
# forma do gc_real_dir. Toda gravação passa por arquivo temporário e mv, como no gc_config_set. No Windows o
# caminho se compara sem diferenciar maiúsculas (grep -i, com LC_ALL=C: só as letras ASCII, como o tr).

# As pastas do arquivo, uma por linha, sem linhas vazias. Arquivo que não existe é lista vazia.
gc_folders_lines() {
  local linha
  [ -f "$1" ] || return 0
  while IFS= read -r linha || [ -n "$linha" ]; do
    [ -z "$linha" ] || printf '%s\n' "$linha"
  done < "$1"
}

# grep da linha inteira, em texto fixo: a opção $1 (-q ou -v) para a pasta $3 no arquivo $2. No Windows não
# diferencia maiúsculas.
gc_folders_grep() {
  local i=""
  [ "$(gc_os)" = windows ] && i=-i
  LC_ALL=C grep -xF "$1" $i -- "$3" "$2"
}

# 0 se a pasta $2 está no arquivo $1. Pasta vazia nunca está: o grep nem é chamado com padrão vazio.
gc_folders_has() { [ -f "$1" ] && [ -n "$2" ] && gc_folders_grep -q "$1" "$2"; }

# Põe a pasta $2 no fim do arquivo $1.
gc_folders_append() {
  local tmp="$1.tmp.$$"
  { gc_folders_lines "$1"; printf '%s\n' "$2"; } > "$tmp" && mv -f "$tmp" "$1"
}

# Tira a pasta $2 do arquivo $1. O grep -v sai com 1 quando não sobra linha: só o 2 é erro.
gc_folders_drop() {
  local tmp="$1.tmp.$$"
  gc_folders_grep -v "$1" "$2" > "$tmp"
  if [ $? -gt 1 ]; then rm -f "$tmp"; return 1; fi
  mv -f "$tmp" "$1"
}

# add e ignore: põem no arquivo $1 a pasta $2, que precisa existir. $3 e $4 são o começo da mensagem de
# "pus" e o da de "já estava".
gc_folders_put() {
  local dir
  dir=$(gc_real_dir "$2") || { printf 'git-commands: a pasta não existe: %s\n' "$2" >&2; return 1; }
  if gc_folders_has "$1" "$dir"; then printf '%s%s\n' "$4" "$dir"; return 0; fi
  gc_folders_append "$1" "$dir" || { printf 'git-commands: não consegui gravar a lista de pastas: %s\n' "$1" >&2; return 1; }
  printf '%s%s\n' "$3" "$dir"
}

# remove e unignore: tiram do arquivo $1 a pasta $2. $3 e $4 são o começo da mensagem de "tirei" e o da de
# "não estava". A pasta é comparada pela forma do gc_real_dir; se ela já não existe, pelo texto.
gc_folders_take() {
  local dir
  dir=$(gc_real_dir "$2") || dir=$(gc_norm_path "$2")
  gc_folders_has "$1" "$dir" || { printf 'git-commands: %s%s\n' "$4" "$dir" >&2; return 1; }
  gc_folders_drop "$1" "$dir" || { printf 'git-commands: não consegui gravar a lista de pastas: %s\n' "$1" >&2; return 1; }
  printf '%s%s\n' "$3" "$dir"
}

# Uma linha tipo<TAB>pasta<TAB>situação para cada pasta do arquivo $2, com o tipo $1: ok, ou nao-encontrada
# se a pasta sumiu do disco.
gc_folders_list_file() {
  local pasta s
  gc_folders_lines "$2" | while IFS= read -r pasta; do
    if [ -d "$pasta" ]; then s=ok; else s=nao-encontrada; fi
    printf '%s\t%s\t%s\n' "$1" "$pasta" "$s"
  done
}

# As fontes de projetos, uma por linha, tipo<TAB>pasta<TAB>situação: o usuário (desligada sem login), a pasta
# de projetos, as pedidas e as ignoradas.
gc_folders_list() {
  local h p s
  h=$(gc_home)
  s=desligada; [ -n "$(gc_github_user)" ] && s=ok
  printf 'usuario\t%s\t%s\n' "$(gc_real_dir "$HOME")" "$s"
  p=$(gc_config_get projects_dir)
  if [ -z "$p" ]; then s=nao-configurada; elif [ -d "$p" ]; then s=ok; else s=nao-encontrada; fi
  printf 'projetos\t%s\t%s\n' "$p" "$s"
  gc_folders_list_file pedida "$h/folders"
  gc_folders_list_file ignorada "$h/ignored"
}

gc_cmd_folders() {
  local sub=${1:-} h
  [ $# -gt 0 ] && shift
  h=$(gc_home)
  # O subcomando e a quantidade de argumentos juntos: uma pasta com espaço escrita sem aspas dá argumento a mais
  # e cai no uso, em vez de pedir ou ignorar só a primeira palavra.
  case "$sub:$#" in
    add:1) gc_folders_put "$h/folders" "$1" 'pasta pedida: ' 'a pasta já estava na lista: ' ;;
    remove:1) gc_folders_take "$h/folders" "$1" 'pasta tirada da lista: ' 'a pasta não está na lista: ' ;;
    ignore:1) gc_folders_put "$h/ignored" "$1" 'pasta ignorada: ' 'a pasta já estava ignorada: ' ;;
    unignore:1) gc_folders_take "$h/ignored" "$1" 'a pasta volta a aparecer: ' 'a pasta não está ignorada: ' ;;
    list:0) gc_folders_list ;;
    *)
      printf 'uso: git-commands folders add <pasta> | remove <pasta> | ignore <pasta> | unignore <pasta> | list\n' >&2
      return 1 ;;
  esac
}

# ---------- a busca na pasta do usuário ----------

# As pastas .git que ficam dentro das pastas diretas da pasta $1, um por linha. Só conta o .git que é pasta, como no
# gc_updates_repos: o .git de um worktree ou de um submódulo é um arquivo, e esses não são projetos à parte. Ficam de
# fora, pelo NOME da pasta e nunca pelo caminho (a pasta do usuário de um teste pode estar dentro de uma AppData): as
# escondidas, AppData e node_modules, e no Mac também Library, Desktop, Documents e Downloads, que o macOS protege.
# Em cada pasta o find desce até 5 níveis (o .git de ~/a/b/c/d/projeto fica na profundidade 5), pula as escondidas e as
# node_modules e continua descendo dentro dos repositórios. Uma pasta que é atalho (link) não é seguida: a busca não
# sai de $1.
# Roda no gc_run_with_timeout, num subshell em segundo plano: quando o tempo acaba, ele recebe o TERM e leva o find
# que estiver rodando junto, para a busca parar de verdade em vez de ficar lendo o disco. O 143 é o código de quem
# morre por TERM, o que o gc_run_with_timeout entende como tempo estourado.
gc_home_find() {
  local d nome mac= filho=
  [ "$(gc_os)" = mac ] && mac=1
  trap 'kill $filho 2>/dev/null; exit 143' TERM
  for d in "$1"/*/; do
    d=${d%/}; nome=${d##*/}
    [ -d "$d" ] || continue
    case "$nome" in .*|AppData|node_modules) continue ;; esac
    if [ -n "$mac" ]; then
      case "$nome" in Library|Desktop|Documents|Downloads) continue ;; esac
    fi
    find "$d" -maxdepth 5 \( -name '.*' ! -name .git -o -name node_modules \) -prune -o -type d -name .git -print -prune 2>/dev/null &
    filho=$!
    wait "$filho"
    filho=
  done
  return 0
}

# Os repositórios da pasta do usuário ($HOME) cujo origin é do GitHub e tem o dono igual ao login $1, sem
# diferenciar maiúsculas, um por linha. Só lista pastas e lê o origin de cada repositório: não usa a rede e não lê os
# arquivos dos projetos. Sai sempre com 0. A busca tem um limite de tempo, GIT_COMMANDS_SEARCH_SECS (só para os
# testes, 20 s se não existir): se ele estoura, avisa no stderr e segue com o que já achou. A saída do find vai para
# um arquivo temporário, e o stdin, o stdout e o stderr da busca não são os de quem chamou: o que sobrar vivo não
# segura nem escreve na saída dele.
gc_home_repos() {
  local login secs root tmp rc linha repo url
  login=$(printf '%s' "$1" | tr 'A-Z' 'a-z')
  [ -n "$login" ] || return 0
  root=$(gc_real_dir "$HOME") || return 0
  secs=${GIT_COMMANDS_SEARCH_SECS:-20}
  tmp=$(mktemp "${TMPDIR:-/tmp}/git-commands-busca.XXXXXX" 2>/dev/null) || return 0
  gc_run_with_timeout "$secs" gc_home_find "$root" </dev/null >"$tmp" 2>/dev/null
  rc=$?
  if [ "$rc" -eq 124 ]; then
    printf 'git-commands: aviso: a busca na pasta do usuário passou de %s segundos e parou no meio\n' "$secs" >&2
  fi
  while IFS= read -r linha || [ -n "$linha" ]; do
    repo=${linha%/.git}
    url=$(git -C "$repo" config --get remote.origin.url 2>/dev/null)
    [ "$(gc_github_owner "$url")" = "$login" ] && printf '%s\n' "$repo"
  done < "$tmp"
  rm -f "$tmp"
  return 0
}

# ---------- a lista de todos os projetos ----------

# 0 se dá para procurar projetos na pasta $1: ela existe e dá para ler. Senão avisa no stderr e sai com 1. $2 é o aviso de "não foi
# encontrada"; a pasta que existe mas não abre é "sem permissão".
gc_folders_readable() {
  if [ ! -d "$1" ]; then
    printf 'git-commands: aviso: %s: %s\n' "$2" "$1" >&2
    return 1
  fi
  # No macOS, tarefas em segundo plano podem ser proibidas de ler pastas como Documentos.
  if ! ls "$1" >/dev/null 2>&1; then
    printf 'git-commands: aviso: sem permissão para ler a pasta: %s\n' "$1" >&2
    return 1
  fi
}

# As pastas onde procurar além da pasta do usuário, uma por linha: a pasta de projetos e as pedidas, as que dá para ler. Cada uma que
# falta ou não abre vira um aviso no stderr, e as outras seguem.
gc_folders_sources() {
  local p pasta
  p=$(gc_config_get projects_dir)
  if [ -n "$p" ] && gc_folders_readable "$p" 'a pasta de projetos não foi encontrada'; then printf '%s\n' "$p"; fi
  gc_folders_lines "$(gc_home)/folders" | while IFS= read -r pasta; do
    gc_folders_readable "$pasta" 'a pasta pedida não foi encontrada' && printf '%s\n' "$pasta"
  done
}

# Passa adiante a lista de caminhos do stdin (na forma do gc_real_dir, em ordem e sem repetição), menos o que fica numa pasta ignorada
# ou dentro dela: o caminho igual à pasta, ou que começa com ela e uma barra (ignorar ~/proj não esconde ~/projeto). No Windows as
# letras maiúsculas e minúsculas valem o mesmo (só as ASCII, como no gc_folders_grep), e duas grafias da mesma pasta ficam numa linha
# só, a primeira. As pastas ignoradas vão para o awk pelo mesmo cano, antes dos caminhos e separadas deles por uma linha vazia.
gc_folders_filter() {
  local win=0
  [ "$(gc_os)" = windows ] && win=1
  { gc_folders_lines "$(gc_home)/ignored"; printf '\n'; cat; } | LC_ALL=C awk -v win="$win" '
    !fim {
      if ($0 == "") { fim = 1; next }
      ign[++n] = (win == 1 ? tolower($0) : $0)
      next
    }
    {
      c = (win == 1 ? tolower($0) : $0)
      for (i = 1; i <= n; i++)
        if (c == ign[i] || index(c, ign[i] "/") == 1) next
      if (win == 1 && vistos[c]++) next
      print
    }'
}

# Todos os projetos que a verificação confere, um caminho por linha, em ordem e sem repetição: os da conta do GitHub na pasta do
# usuário (só com login, de gc_github_user), os do GitHub na pasta de projetos e os das pastas pedidas (nas pastas escolhidas o dono
# não importa), menos os que ficam numa pasta ignorada ou dentro dela. Cada caminho passa pelo gc_real_dir antes de tudo, porque a
# mesma pasta pode vir escrita de formas diferentes. Uma fonte que falta ou não dá para ler vira um aviso no stderr, e as outras
# seguem. Sai com 0 se ao menos uma fonte foi lida; se nenhuma foi, explica no stderr e sai com 1.
gc_all_repos() {
  local login fontes pasta r
  login=$(gc_github_user)
  fontes=$(gc_folders_sources)
  if [ -z "$login" ] && [ -z "$fontes" ]; then
    printf 'git-commands: não há onde procurar projetos: configure a pasta de projetos (skill configurar), faça login no GitHub ou peça uma pasta (git-commands folders add <pasta>)\n' >&2
    return 1
  fi
  {
    [ -z "$login" ] || gc_home_repos "$login"
    printf '%s\n' "$fontes" | while IFS= read -r pasta; do
      [ -z "$pasta" ] || gc_updates_repos "$pasta" </dev/null
    done
  } | while IFS= read -r r; do gc_real_dir "$r"; done | LC_ALL=C sort -u | gc_folders_filter
}
