# proactive: liga ou desliga o modo automático do git-commands, em geral ou por projeto.
# O geral fica em config (proactive); os projetos desligados ficam em <home>/proactive-off,
# um topo de repositório por linha.

gc_proactive_off_file() { printf '%s\n' "$(gc_home)/proactive-off"; }

gc_proactive_repo_off() {
  local f; f=$(gc_proactive_off_file)
  [ -f "$f" ] && grep -qxF -- "$1" "$f"
}

# 0 quando o modo automático vale para a pasta: geral ligado, projeto não desligado e do GitHub.
gc_proactive_applies() {
  local top
  [ "$(gc_config_get proactive)" = on ] || return 1
  top=$(gc_toplevel "$1") || return 1
  gc_repo_is_github "$top" || return 1
  gc_proactive_repo_off "$top" && return 1
  return 0
}

gc_proactive_usage() {
  printf 'uso: git-commands proactive on|off [--all] [<repositório>] | status [<repositório>]\n' >&2
}

gc_cmd_proactive() {
  local action=${1:-} all=no repo="" a top f
  [ $# -gt 0 ] && shift
  for a in "$@"; do
    case "$a" in --all) all=yes ;; *) repo=$a ;; esac
  done
  case "$action" in
    on|off)
      if [ "$all" = yes ]; then
        gc_config_set proactive "$action"
        [ "$action" = on ] && rm -f "$(gc_proactive_off_file)"
        return 0
      fi
      top=$(gc_toplevel "${repo:-.}") || {
        printf 'git-commands: esta pasta não é um repositório git. Para todos os projetos, use: git-commands proactive %s --all\n' "$action" >&2
        return 1; }
      f=$(gc_proactive_off_file)
      if [ "$action" = off ]; then
        gc_proactive_repo_off "$top" || printf '%s\n' "$top" >> "$f"
      elif [ -f "$f" ]; then
        grep -vxF -- "$top" "$f" > "$f.tmp.$$"
        mv -f "$f.tmp.$$" "$f"
      fi ;;
    status)
      if [ "$(gc_config_get proactive)" != on ]; then printf 'off\n'; return 0; fi
      top=$(gc_toplevel "${repo:-.}") || { printf 'on\n'; return 0; }
      if gc_proactive_repo_off "$top"; then printf 'off\n'; else printf 'on\n'; fi ;;
    *)
      gc_proactive_usage; return 1 ;;
  esac
}
