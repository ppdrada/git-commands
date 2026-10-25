# guard: reconhece comandos git e gh que podem apagar trabalho.
# gc_guard_reason "<comando>" [<pasta>] imprime o motivo e devolve 0 se for perigoso; devolve 1
# se for seguro. A pasta (padrão: a atual) diz se "git checkout <x>" fala de um arquivo.
# Sem processos extras por palavra: este código roda antes de todo comando Bash/PowerShell.

GC_GUARD_FORCA="força o envio e pode apagar commits que estão no GitHub"
GC_GUARD_BRANCH="apaga uma branch"
GC_GUARD_DESCARTE="descarta alterações que ainda não foram salvas"
GC_GUARD_LIMPEZA="apaga arquivos que o git não acompanha"
GC_GUARD_REESCRITA="reescreve o histórico de commits"
GC_GUARD_STASH="apaga alterações guardadas no stash"
GC_GUARD_REPO="apaga o repositório no GitHub"

GC_GUARD_SEP=$'\036'
GC_GUARD_CWD=.

gc_guard_say() { printf '%s\n' "$1"; return 0; }

# Usa as variáveis cur e has de gc_guard_tokenize (escopo dinâmico do bash).
gc_guard_flush() {
  if [ -n "$cur" ] || [ "$has" = 1 ]; then GC_GUARD_TOKENS+=("$cur"); fi
  cur=""; has=0
}

# Quebra o comando em palavras, respeitando aspas, e põe GC_GUARD_SEP onde um comando termina:
# ; | || & && quebra de linha, parênteses, chaves e crase (subshells, blocos, laços e
# $(...) viram comandos separados). A barra invertida só escapa " e \ dentro de aspas
# duplas, para caminhos do Windows continuarem inteiros. Resultado em GC_GUARD_TOKENS.
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
        ';'|$'\n'|'('|')'|'{'|'}'|'`') gc_guard_flush; GC_GUARD_TOKENS+=("$GC_GUARD_SEP") ;;
        '|'|'&') gc_guard_flush
             [ "${s:i+1:1}" = "$c" ] && i=$((i + 1))
             GC_GUARD_TOKENS+=("$GC_GUARD_SEP") ;;
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
  local sub=$1 t staged=0 wt=0 skip=no
  local args=()
  shift
  case "$sub" in
    push)
      for t; do
        case "$t" in
          --force|--force-with-lease|--force-with-lease=*|--force-if-includes|--mirror|+*) gc_guard_say "$GC_GUARD_FORCA"; return ;;
          --delete|--prune|:*) gc_guard_say "$GC_GUARD_BRANCH"; return ;;
          --*) ;;
          -*f*) gc_guard_say "$GC_GUARD_FORCA"; return ;;
          -*d*) gc_guard_say "$GC_GUARD_BRANCH"; return ;;
        esac
      done ;;
    reset)
      for t; do [ "$t" = --hard ] && { gc_guard_say "$GC_GUARD_DESCARTE"; return; }; done ;;
    checkout)
      for t; do
        if [ "$skip" = yes ]; then skip=no; continue; fi
        case "$t" in
          --|-f|--force) gc_guard_say "$GC_GUARD_DESCARTE"; return ;;
          -B) gc_guard_say "$GC_GUARD_BRANCH"; return ;;
          -b|--orphan) skip=yes ;;
          -*) ;;
          *) args+=("$t") ;;
        esac
      done
      # Dois ou mais nomes ("git checkout HEAD app.js"), "." ou um arquivo que existe: descarta.
      if [ ${#args[@]} -ge 2 ]; then gc_guard_say "$GC_GUARD_DESCARTE"; return; fi
      if [ ${#args[@]} -eq 1 ]; then
        if [ "${args[0]}" = . ] || [ -e "$GC_GUARD_CWD/${args[0]}" ]; then gc_guard_say "$GC_GUARD_DESCARTE"; return; fi
      fi ;;
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
        case "$t" in
          --discard-changes|-f|--force) gc_guard_say "$GC_GUARD_DESCARTE"; return ;;
          -C|--force-create) gc_guard_say "$GC_GUARD_BRANCH"; return ;;
        esac
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
    rm)
      for t; do
        case "$t" in
          --force) gc_guard_say "$GC_GUARD_DESCARTE"; return ;;
          --*) ;;
          -*f*) gc_guard_say "$GC_GUARD_DESCARTE"; return ;;
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
          --delete|--force) gc_guard_say "$GC_GUARD_BRANCH"; return ;;
          --*) ;;
          -*[dDfMC]*) gc_guard_say "$GC_GUARD_BRANCH"; return ;;
        esac
      done ;;
  esac
  return 1
}

gc_guard_gh() {
  local t
  case "${1:-} ${2:-}" in
    "repo delete") gc_guard_say "$GC_GUARD_REPO"; return ;;
    "pr merge"|"pr close")
      for t; do
        case "$t" in --delete-branch|-d) gc_guard_say "$GC_GUARD_BRANCH"; return ;; esac
      done ;;
  esac
  return 1
}

# Um comando (sem separadores): pula o que vem antes do programa e olha se é git, gh ou um
# shell que roda outro comando (bash -c, powershell -Command, cmd /c).
gc_guard_segment() {
  local depth=$1 base
  shift
  while [ $# -gt 0 ]; do
    case "$1" in
      sudo|command|exec|nohup|time|then|do|else|elif|if|while|until|'!'|ForEach-Object|foreach|'%') shift ;;
      env) shift
           while [ $# -gt 0 ]; do case "$1" in -*|[A-Za-z_]*=*) shift ;; *) break ;; esac; done ;;
      xargs) shift
           while [ $# -gt 0 ]; do
             case "$1" in -n|-I|-P|-L|-s|-d|-E|-a) shift; [ $# -gt 0 ] && shift ;; -*) shift ;; *) break ;; esac
           done ;;
      timeout) shift
           while [ $# -gt 0 ]; do
             case "$1" in -s|-k|--signal|--kill-after) shift; [ $# -gt 0 ] && shift ;; -*) shift ;; *) shift; break ;; esac
           done ;;
      nice) shift
           while [ $# -gt 0 ]; do case "$1" in -n) shift; [ $# -gt 0 ] && shift ;; -*) shift ;; *) break ;; esac; done ;;
      [A-Za-z_]*=*) shift ;;
      *) break ;;
    esac
  done
  [ $# -gt 0 ] || return 1
  base=${1##*[/\\]}
  shift
  case "$base" in
    [Gg][Ii][Tt]|[Gg][Ii][Tt].[Ee][Xx][Ee]) gc_guard_git "$@"; return ;;
    [Gg][Hh]|[Gg][Hh].[Ee][Xx][Ee]) gc_guard_gh "$@"; return ;;
    bash|sh|zsh|dash|bash.exe|sh.exe|[Pp]ower[Ss]hell|[Pp]ower[Ss]hell.exe|pwsh|pwsh.exe|cmd|cmd.exe)
      [ "$depth" -lt 2 ] || return 1
      while [ $# -gt 0 ]; do
        case "$1" in
          -c|-C|-Command|-command|/c|/C) shift; [ $# -gt 0 ] || return 1; gc_guard_scan "$1" $((depth + 1)); return ;;
        esac
        shift
      done ;;
  esac
  return 1
}

# Confere todos os comandos de um texto.
gc_guard_scan() {
  local depth=$2 t
  local seg=()
  gc_guard_tokenize "$1"
  for t in "${GC_GUARD_TOKENS[@]}" "$GC_GUARD_SEP"; do
    if [ "$t" = "$GC_GUARD_SEP" ]; then
      if [ ${#seg[@]} -gt 0 ] && gc_guard_segment "$depth" "${seg[@]}"; then return 0; fi
      seg=()
    else
      seg+=("$t")
    fi
  done
  return 1
}

gc_guard_reason() {
  local cmd=$1 rest line
  GC_GUARD_CWD=${2:-$PWD}
  case "$cmd" in *[Gg][Ii][Tt]*|*[Gg][Hh]*) ;; *) return 1 ;; esac
  gc_guard_scan "$cmd" 0 && return 0
  # Um apóstrofo no texto de um heredoc engana a leitura das aspas; então também
  # confere cada linha sozinha.
  case "$cmd" in *$'\n'*) ;; *) return 1 ;; esac
  rest=$cmd
  while [ -n "$rest" ]; do
    line=${rest%%$'\n'*}
    if [ "$line" = "$rest" ]; then rest=""; else rest=${rest#*$'\n'}; fi
    gc_guard_scan "$line" 0 && return 0
  done
  return 1
}

gc_cmd_guard() {
  case "${1:-}" in
    check) local cmd; cmd=$(cat); gc_guard_reason "$cmd" "$PWD" ;;
    *) printf 'uso: git-commands guard check  (o comando vem pela entrada padrão)\n' >&2; return 1 ;;
  esac
}
