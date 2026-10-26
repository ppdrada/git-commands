# updates: verifica novidades no GitHub e atualiza com segurança. Nunca atualiza sozinho:
# o pull só acontece quando a pessoa pede (git-commands updates pull).

gc_updates_usage() {
  printf 'uso: git-commands updates scan [--no-fetch] [--save] [--dir <pasta>] [--repo <repositório>] | news | detail <repositório> | pull <repositório>\n' >&2
}

# Caminho dentro do .git do repositório (o git devolve relativo à pasta do repositório).
gc_updates_git_path() {
  local p; p=$(git -C "$1" rev-parse --git-path "$2" 2>/dev/null) || return 1
  case "$p" in /*|[A-Za-z]:*) printf '%s\n' "$p" ;; *) printf '%s/%s\n' "$1" "$p" ;; esac
}

# Repositórios do GitHub dentro da pasta, até 2 níveis abaixo dela.
gc_updates_repos() {
  find "$1" -maxdepth 3 \( -name node_modules -prune \) -o \( -type d -name .git -print -prune \) 2>/dev/null \
    | sed 's#/\.git$##' | LC_ALL=C sort | while IFS= read -r r; do
      gc_repo_is_github "$r" && printf '%s\n' "$r"
    done
}

gc_updates_fetch() {
  gc_quiet_net
  gc_fetch_origin "$1" 20 >/dev/null 2>&1
}

# Uma linha: caminho, nome, branch, ahead, behind, alterados, estado.
gc_updates_line() {
  local r=$1 fetch=$2 name branch ahead=0 behind=0 dirty state="" counts
  name=${r##*/}
  dirty=$(GIT_OPTIONAL_LOCKS=0 git -C "$r" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  branch=$(git -C "$r" symbolic-ref --short -q HEAD 2>/dev/null) || branch=""
  if ! git -C "$r" rev-parse -q --verify HEAD >/dev/null 2>&1; then
    state=sem-commits
  elif [ -e "$(gc_updates_git_path "$r" MERGE_HEAD)" ] || [ -d "$(gc_updates_git_path "$r" rebase-merge)" ] || [ -d "$(gc_updates_git_path "$r" rebase-apply)" ]; then
    state=ocupado
  elif [ -z "$branch" ]; then
    state=destacado
  else
    if [ "$fetch" = yes ]; then gc_updates_fetch "$r" || state=erro; fi
    if [ -z "$state" ]; then
      if ! git -C "$r" rev-parse -q --verify '@{u}' >/dev/null 2>&1; then
        state=sem-upstream
      else
        counts=$(git -C "$r" rev-list --left-right --count 'HEAD...@{u}' 2>/dev/null)
        ahead=${counts%%[[:space:]]*}; behind=${counts##*[[:space:]]}
        if [ "$behind" -gt 0 ] && [ "$ahead" -gt 0 ]; then state=divergiu
        elif [ "$behind" -gt 0 ]; then state=novidades
        elif [ "$ahead" -gt 0 ]; then state=a-frente
        else state=em-dia; fi
      fi
    fi
  fi
  [ -n "$branch" ] || branch=HEAD
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$r" "$name" "$branch" "$ahead" "$behind" "$dirty" "$state"
}

gc_updates_scan() {
  local fetch=yes save=no dir="" repo="" top out h
  while [ $# -gt 0 ]; do
    case "$1" in
      --no-fetch) fetch=no ;;
      --save) save=yes ;;
      --dir) [ $# -ge 2 ] || { gc_updates_usage; return 1; }; dir=$2; shift ;;
      --repo) [ $# -ge 2 ] || { gc_updates_usage; return 1; }; repo=$2; shift ;;
      *) gc_updates_usage; return 1 ;;
    esac
    shift
  done
  if [ -n "$repo" ]; then
    [ "$save" = no ] || { printf 'git-commands: --save só vale sem --repo\n' >&2; return 1; }
    top=$(gc_toplevel "$repo") && gc_repo_is_github "$top" || {
      printf 'git-commands: não é um repositório do GitHub: %s\n' "$repo" >&2; return 1; }
    gc_updates_line "$top" "$fetch"
    return 0
  fi
  [ -n "$dir" ] || dir=$(gc_config_get projects_dir)
  [ -n "$dir" ] || { printf 'git-commands: a pasta de projetos não está configurada (use a skill configurar ou --dir <pasta>)\n' >&2; return 1; }
  [ -d "$dir" ] || { printf 'git-commands: a pasta de projetos não existe: %s\n' "$dir" >&2; return 1; }
  # No macOS, tarefas em segundo plano podem ser proibidas de ler pastas como Documentos.
  ls "$dir" >/dev/null 2>&1 || { printf 'git-commands: sem permissão para ler a pasta de projetos: %s\n' "$dir" >&2; return 1; }
  out=$(gc_updates_repos "$dir" | while IFS= read -r r; do gc_updates_line "$r" "$fetch"; done)
  [ -z "$out" ] || printf '%s\n' "$out"
  if [ "$save" = yes ]; then
    h=$(gc_home)
    printf '%s\n' "$out" > "$h/status.tsv.tmp.$$" && mv -f "$h/status.tsv.tmp.$$" "$h/status.tsv"
    date +%s > "$h/status.time"
  fi
  return 0
}

# Novidades salvas pela última varredura que ainda valem (recalcula sem rede).
gc_updates_news() {
  local f out; f="$(gc_home)/status.tsv"
  [ -f "$f" ] || return 1
  out=$(while IFS=$'\t' read -r r name branch ahead behind dirty state; do
    [ "$state" = novidades ] || [ "$state" = divergiu ] || continue
    [ -d "$r" ] || continue
    behind=$(git -C "$r" rev-list --count 'HEAD..@{u}' 2>/dev/null) || continue
    [ "${behind:-0}" -gt 0 ] && printf '%s\t%s\t%s\t%s\n' "$name" "$behind" "$r" "$state"
  done < "$f")
  [ -n "$out" ] || return 1
  printf '%s\n' "$out"
}

# Os arquivos que mudaram dos dois lados (GitHub e computador).
gc_updates_both_sides() {
  local r=$1 remoto local
  remoto=$(git -C "$r" diff --name-only 'HEAD...@{u}' 2>/dev/null | LC_ALL=C sort -u)
  local=$( { git -C "$r" diff --name-only '@{u}...HEAD' 2>/dev/null
             git -C "$r" diff --name-only HEAD 2>/dev/null
             git -C "$r" ls-files --others --exclude-standard 2>/dev/null; } | LC_ALL=C sort -u)
  [ -n "$remoto" ] && [ -n "$local" ] || return 0
  printf '%s\n' "$remoto" | while IFS= read -r arq; do
    printf '%s\n' "$local" | grep -qxF -- "$arq" && printf '%s\n' "$arq"
  done
}

gc_updates_detail() {
  local r n
  r=$(gc_toplevel "${1:-.}") || { printf 'git-commands: não é um repositório git: %s\n' "${1:-.}" >&2; return 1; }
  gc_updates_fetch "$r"
  n=$(git -C "$r" rev-list --count 'HEAD..@{u}' 2>/dev/null) || n=0
  printf '== Novidades no GitHub (%s commits)\n' "$n"
  git -C "$r" log --format='%h%x09%an%x09%ad%x09%s' --date=short 'HEAD..@{u}' 2>/dev/null
  printf '== Arquivos que mudaram no GitHub\n'
  git -C "$r" diff --stat 'HEAD...@{u}' 2>/dev/null
  printf '== Suas alterações ainda sem commit\n'
  git -C "$r" status --short 2>/dev/null
  printf '== Mexidos dos dois lados (podem dar conflito)\n'
  gc_updates_both_sides "$r"
  return 0
}

# Atualiza só por fast-forward e só quando é seguro.
# Códigos: 0 ok; 3 alterações sem commit; 4 divergiu; 5 sem upstream; 6 erro de rede;
# 7 HEAD destacado. Uma ida à rede só (o fetch com limite); depois junta o que já chegou.
gc_updates_pull() {
  local r counts ahead behind mod out
  r=$(gc_toplevel "${1:-.}") || { printf 'git-commands: não é um repositório git: %s\n' "${1:-.}" >&2; return 1; }
  git -C "$r" symbolic-ref -q HEAD >/dev/null 2>&1 || {
    printf 'HEAD destacado: o projeto não está em nenhuma branch\n'; return 7; }
  git -C "$r" rev-parse -q --verify '@{u}' >/dev/null 2>&1 || {
    printf 'sem upstream: a branch %s ainda não existe no GitHub\n' "$(git -C "$r" symbolic-ref --short -q HEAD)"; return 5; }
  gc_updates_fetch "$r" || { printf 'erro de rede: não consegui falar com o GitHub\n'; return 6; }
  counts=$(git -C "$r" rev-list --left-right --count 'HEAD...@{u}')
  ahead=${counts%%[[:space:]]*}; behind=${counts##*[[:space:]]}
  [ "$behind" -gt 0 ] || { printf 'já estava em dia\n'; return 0; }
  mod=$(git -C "$r" status --porcelain --untracked-files=no)
  [ -z "$mod" ] || { printf 'há alterações sem commit:\n%s\n' "$mod"; return 3; }
  [ "$ahead" -eq 0 ] || { printf 'divergiu: %s commit(s) seus e %s do GitHub\n' "$ahead" "$behind"; return 4; }
  out=$(LC_ALL=C git -C "$r" merge --ff-only --quiet '@{u}' 2>&1) || {
    case "$out" in
      *overwritten*) printf 'há arquivos que seriam sobrescritos:\n%s\n' "$out"; return 3 ;;
      *) printf 'erro: %s\n' "$out"; return 6 ;;
    esac; }
  printf 'atualizado: +%s commit(s)\n' "$behind"
}

gc_cmd_updates() {
  local sub=${1:-}
  [ $# -gt 0 ] && shift
  case "$sub" in
    scan) gc_updates_scan "$@" ;;
    news) gc_updates_news ;;
    detail) gc_updates_detail "$@" ;;
    pull) gc_updates_pull "$@" ;;
    *) gc_updates_usage; return 1 ;;
  esac
}
