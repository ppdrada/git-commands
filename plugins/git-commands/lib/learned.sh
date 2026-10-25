# Conceitos de git já explicados para a pessoa: <home>/learned, um id por linha.
# Os ids válidos são as seções "## <id>" de reference/conceitos.md.

gc_glossary_file() { printf '%s\n' "$GC_ROOT/reference/conceitos.md"; }

# 0 se o id existe no glossário. Sem glossário (a cópia app/ não leva reference/), aceita.
gc_learned_known_id() {
  case "$1" in ""|*[!a-z-]*) return 1 ;; esac
  local g; g=$(gc_glossary_file)
  [ -f "$g" ] || return 0
  grep -q "^## $1\$" "$g"
}

gc_cmd_learned() {
  local f id; f="$(gc_home)/learned"
  case "${1:-}" in
    list)
      [ -f "$f" ] && LC_ALL=C sort -u "$f"
      return 0 ;;
    has)
      [ $# -eq 2 ] || { gc_learned_usage; return 1; }
      [ -f "$f" ] && grep -qx -- "$2" "$f" ;;
    add)
      shift
      [ $# -ge 1 ] || { gc_learned_usage; return 1; }
      for id in "$@"; do
        gc_learned_known_id "$id" || { printf 'git-commands: conceito desconhecido: %s\n' "$id" >&2; return 2; }
      done
      { [ -f "$f" ] && cat "$f"; printf '%s\n' "$@"; } | LC_ALL=C sort -u > "$f.tmp.$$" && mv -f "$f.tmp.$$" "$f" ;;
    forget)
      [ $# -eq 2 ] || { gc_learned_usage; return 1; }
      [ -f "$f" ] || return 0
      grep -vx -- "$2" "$f" > "$f.tmp.$$"
      mv -f "$f.tmp.$$" "$f" ;;
    reset)
      rm -f "$f" ;;
    *)
      gc_learned_usage; return 1 ;;
  esac
}

gc_learned_usage() {
  printf 'uso: git-commands learned list | has <id> | add <id>... | forget <id> | reset\n' >&2
}
