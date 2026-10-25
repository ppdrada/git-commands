# guard: reconhece comandos git e gh que podem apagar trabalho.
# gc_guard_reason "<comando>" imprime o motivo e devolve 0 se for perigoso; devolve 1 se for seguro.

GC_GUARD_FORCA="força o envio e pode apagar commits que estão no GitHub"
GC_GUARD_BRANCH="apaga uma branch"
GC_GUARD_DESCARTE="descarta alterações que ainda não foram salvas"
GC_GUARD_LIMPEZA="apaga arquivos que o git não acompanha"
GC_GUARD_REESCRITA="reescreve o histórico de commits"
GC_GUARD_STASH="apaga alterações guardadas no stash"
GC_GUARD_REPO="apaga o repositório no GitHub"

GC_GUARD_SEP=$'\036'

gc_guard_say() { printf '%s\n' "$1"; return 0; }

# Usa as variáveis cur e has de gc_guard_tokenize (escopo dinâmico do bash).
gc_guard_flush() {
  if [ -n "$cur" ] || [ "$has" = 1 ]; then GC_GUARD_TOKENS+=("$cur"); fi
  cur=""; has=0
}

# Quebra o comando em palavras, respeitando aspas, e põe GC_GUARD_SEP onde um comando
# termina (; | || && e quebra de linha). Resultado em GC_GUARD_TOKENS. A barra invertida
# só escapa " e \ dentro de aspas duplas, para caminhos do Windows continuarem inteiros.
gc_guard_tokenize() {
  local s=$1 n=${#1} i=0 c nx q="" cur="" has=0
  GC_GUARD_TOKENS=()
  while [ "$i" -lt "$n" ]; do
    c=${s:i:1}
    if [ -n "$q" ]; then
      if [ "$c" = "$q" ]; then
        q=""
      elif [ "$c" = '\' ] && [ "$q" = '"' ]; then
        nx=${s:i+1:1}
        case "$nx" in
          '"'|'\') cur="$cur$nx"; i=$((i + 1)) ;;
          *) cur="$cur$c" ;;
        esac
      else
        cur="$cur$c"
      fi
    else
      case "$c" in
        '"'|"'") q=$c; has=1 ;;
        ' '|$'\t'|$'\r') gc_guard_flush ;;
        ';'|$'\n') gc_guard_flush; GC_GUARD_TOKENS+=("$GC_GUARD_SEP") ;;
        '|') gc_guard_flush
             [ "${s:i+1:1}" = '|' ] && i=$((i + 1))
             GC_GUARD_TOKENS+=("$GC_GUARD_SEP") ;;
        '&') gc_guard_flush
             if [ "${s:i+1:1}" = '&' ]; then i=$((i + 1)); GC_GUARD_TOKENS+=("$GC_GUARD_SEP")
             else GC_GUARD_TOKENS+=("&"); fi ;;
        *) cur="$cur$c" ;;
      esac
    fi
    i=$((i + 1))
  done
  gc_guard_flush
}

gc_guard_git() {
  while [ $# -gt 0 ]; do
    case "$1" in
      -C|-c|--git-dir|--work-tree|--namespace) [ $# -ge 2 ] || return 1; shift 2 ;;
      --git-dir=*|--work-tree=*|--namespace=*|--exec-path=*|--no-pager|-p|--paginate|--bare|--no-replace-objects|--literal-pathspecs) shift ;;
      *) break ;;
    esac
  done
  [ $# -gt 0 ] || return 1
  local sub=$1 t staged=0 wt=0
  shift
  case "$sub" in
    push)
      for t; do
        case "$t" in
          --force|--force-with-lease|--force-with-lease=*|--force-if-includes|--mirror|+*) gc_guard_say "$GC_GUARD_FORCA"; return ;;
          --delete|:*) gc_guard_say "$GC_GUARD_BRANCH"; return ;;
          --*) ;;
          -*f*) gc_guard_say "$GC_GUARD_FORCA"; return ;;
          -*d*) gc_guard_say "$GC_GUARD_BRANCH"; return ;;
        esac
      done ;;
    reset)
      for t; do [ "$t" = --hard ] && { gc_guard_say "$GC_GUARD_DESCARTE"; return; }; done ;;
    checkout)
      for t; do
        case "$t" in --|.|-f|--force) gc_guard_say "$GC_GUARD_DESCARTE"; return ;; esac
      done ;;
    restore)
      for t; do
        case "$t" in
          --staged) staged=1 ;;
          --worktree) wt=1 ;;
          --*) ;;
          -*) case "$t" in *S*) staged=1 ;; esac
              case "$t" in *W*) wt=1 ;; esac ;;
        esac
      done
      if [ "$staged" = 0 ] || [ "$wt" = 1 ]; then gc_guard_say "$GC_GUARD_DESCARTE"; return; fi ;;
    switch)
      for t; do
        case "$t" in --discard-changes|-f|--force) gc_guard_say "$GC_GUARD_DESCARTE"; return ;; esac
      done ;;
    worktree)
      if [ "${1:-}" = remove ]; then
        for t; do
          case "$t" in --force|-f) gc_guard_say "$GC_GUARD_DESCARTE"; return ;; esac
        done
      fi ;;
    clean)
      for t; do
        case "$t" in
          --force) gc_guard_say "$GC_GUARD_LIMPEZA"; return ;;
          --*) ;;
          -*f*) gc_guard_say "$GC_GUARD_LIMPEZA"; return ;;
        esac
      done ;;
    rebase)
      for t; do [ "$t" = --continue ] && return 1; done
      gc_guard_say "$GC_GUARD_REESCRITA"; return ;;
    pull)
      for t; do
        case "$t" in
          --rebase|--rebase=true|--rebase=merges|--rebase=interactive|--rebase=i|-r) gc_guard_say "$GC_GUARD_REESCRITA"; return ;;
        esac
      done ;;
    filter-branch|filter-repo)
      gc_guard_say "$GC_GUARD_REESCRITA"; return ;;
    stash)
      case "${1:-}" in drop|clear) gc_guard_say "$GC_GUARD_STASH"; return ;; esac ;;
    branch)
      for t; do
        case "$t" in
          --delete|--force|-d|-D|-f) gc_guard_say "$GC_GUARD_BRANCH"; return ;;
          --*) ;;
          -*[dDf]*) gc_guard_say "$GC_GUARD_BRANCH"; return ;;
        esac
      done ;;
  esac
  return 1
}

gc_guard_gh() {
  local t
  case "${1:-} ${2:-}" in
    "repo delete") gc_guard_say "$GC_GUARD_REPO"; return ;;
    "pr merge")
      for t; do
        case "$t" in --delete-branch|-d) gc_guard_say "$GC_GUARD_BRANCH"; return ;; esac
      done ;;
  esac
  return 1
}

# Um comando (sem separadores): pula prefixos e olha se é git ou gh.
gc_guard_segment() {
  while [ $# -gt 0 ]; do
    case "$1" in
      sudo|command|exec|nohup|time|'&') shift ;;
      [A-Za-z_]*=*) shift ;;
      *) break ;;
    esac
  done
  [ $# -gt 0 ] || return 1
  local prog
  prog=$(printf '%s' "${1##*[/\\]}" | tr 'A-Z' 'a-z')
  shift
  case "$prog" in
    git|git.exe) gc_guard_git "$@" ;;
    gh|gh.exe) gc_guard_gh "$@" ;;
    *) return 1 ;;
  esac
}

gc_guard_reason() {
  case "$1" in *[Gg][Ii][Tt]*|*[Gg][Hh]*) ;; *) return 1 ;; esac
  gc_guard_tokenize "$1"
  local seg=() t
  for t in "${GC_GUARD_TOKENS[@]}" "$GC_GUARD_SEP"; do
    if [ "$t" = "$GC_GUARD_SEP" ]; then
      if [ ${#seg[@]} -gt 0 ] && gc_guard_segment "${seg[@]}"; then return 0; fi
      seg=()
    else
      seg+=("$t")
    fi
  done
  return 1
}

gc_cmd_guard() {
  case "${1:-}" in
    check) local cmd; cmd=$(cat); gc_guard_reason "$cmd" ;;
    *) printf 'uso: git-commands guard check  (o comando vem pela entrada padrão)\n' >&2; return 1 ;;
  esac
}
