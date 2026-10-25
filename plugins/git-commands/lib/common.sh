# Funções comuns do git-commands (usadas pelo executável, pelos hooks e pelo agendador).
# Compatível com bash 3.2. Sem heredoc: o bash 5.3 pode travar com heredoc dentro de hooks.

case "${BASH_SOURCE[0]}" in
  */*|*\\*) GC_LIB_DIR="${BASH_SOURCE[0]%[/\\]*}" ;;
  *) GC_LIB_DIR=. ;;
esac
GC_ROOT="$(cd "$GC_LIB_DIR/.." && pwd)"

GC_CONFIG_KEYS="projects_dir auto_check interval proactive auto_check_asked"

# ---------- estado e ambiente ----------

gc_home() {
  local h="${GIT_COMMANDS_HOME:-$HOME/.git-commands}"
  mkdir -p "$h" && printf '%s\n' "$h"
}

gc_os() {
  if [ -n "${GIT_COMMANDS_OS:-}" ]; then printf '%s\n' "$GIT_COMMANDS_OS"; return 0; fi
  case "$(uname -s 2>/dev/null)" in
    MINGW*|MSYS*|CYGWIN*) printf 'windows\n' ;;
    Darwin) printf 'mac\n' ;;
    *) printf 'linux\n' ;;
  esac
}

gc_plugin_root() { printf '%s\n' "$GC_ROOT"; }

# Versão do plugin: do plugin.json (instalação normal) ou do VERSION (cópia em app/).
gc_plugin_version() {
  if [ -f "$GC_ROOT/.claude-plugin/plugin.json" ]; then
    sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$GC_ROOT/.claude-plugin/plugin.json" | head -n 1
  elif [ -f "$GC_ROOT/VERSION" ]; then
    cat "$GC_ROOT/VERSION"
  fi
}

# Cópia do executável para <home>/app, que é o que o agendador do sistema roda: o caminho
# do plugin muda a cada atualização, o de <home>/app não. Só recopia quando a versão muda,
# a não ser com "force".
gc_app_sync() {
  local app v tmp
  app="$(gc_home)/app"; v=$(gc_plugin_version)
  [ -n "$v" ] || return 0
  [ "${1:-}" != force ] && [ -f "$app/VERSION" ] && [ "$(cat "$app/VERSION")" = "$v" ] && return 0
  [ "$GC_ROOT" = "$(cd "$app" 2>/dev/null && pwd)" ] && return 0
  tmp="$app.tmp.$$"
  rm -rf "$tmp" && mkdir -p "$tmp" || return 1
  cp -R "$GC_ROOT/bin" "$GC_ROOT/lib" "$tmp/" || { rm -rf "$tmp"; return 1; }
  [ -d "$GC_ROOT/scheduler" ] && cp -R "$GC_ROOT/scheduler" "$tmp/"
  printf '%s\n' "$v" > "$tmp/VERSION"
  rm -rf "$app" && mv "$tmp" "$app"
}

# Rede sem perguntas: nada de pedir senha no terminal nem abrir janela de login.
gc_quiet_net() { export GIT_TERMINAL_PROMPT=0 GCM_INTERACTIVE=never; }

# ---------- configuração ----------

gc_config_valid_key() {
  case " $GC_CONFIG_KEYS " in *" $1 "*) return 0 ;; esac
  printf 'git-commands: chave de configuração inválida: %s (válidas: %s)\n' "$1" "$GC_CONFIG_KEYS" >&2
  return 1
}

gc_config_default() {
  case "$1" in
    proactive) printf 'on\n' ;;
    auto_check) printf 'off\n' ;;
    interval) printf '30\n' ;;
    *) printf '\n' ;;
  esac
}

gc_config_get() {
  gc_config_valid_key "$1" || return 1
  local f; f="$(gc_home)/config"
  if [ -f "$f" ] && grep -q "^$1=" "$f"; then
    sed -n "s/^$1=//p" "$f" | tail -n 1
  else
    gc_config_default "$1"
  fi
}

gc_config_set() {
  gc_config_valid_key "$1" || return 1
  local f tmp; f="$(gc_home)/config"; tmp="$f.tmp.$$"
  { [ -f "$f" ] && grep -v "^$1=" "$f"; printf '%s=%s\n' "$1" "$2"; } > "$tmp" && mv -f "$tmp" "$f"
}

gc_config_list() {
  local k
  for k in $GC_CONFIG_KEYS; do printf '%s=%s\n' "$k" "$(gc_config_get "$k")"; done
}

# ---------- GitHub e repositórios ----------

gc_is_github_url() {
  local u re='(^|[/@.])github\.com([:/]|$)'
  u=$(printf '%s' "$1" | tr 'A-Z' 'a-z')
  [[ $u =~ $re ]]
}

# 0 se algum remote do repositório aponta (na configuração crua) para o GitHub.
gc_repo_is_github() {
  local url
  for url in $(git -C "$1" config --get-regexp '^remote\..*\.url$' 2>/dev/null | sed 's/^[^ ]* //'); do
    gc_is_github_url "$url" && return 0
  done
  return 1
}

gc_norm_path() { local bs='\'; printf '%s\n' "${1//"$bs"//}"; }

# Topo do repositório que contém o caminho (o caminho pode ainda não existir).
gc_toplevel() {
  local p; p=$(gc_norm_path "$1")
  while [ -n "$p" ] && [ ! -d "$p" ]; do
    case "$p" in */*) p="${p%/*}" ;; *) p="" ;; esac
  done
  [ -n "$p" ] || return 1
  git -C "$p" rev-parse --show-toplevel 2>/dev/null
}

# ---------- JSON (sem jq) ----------

# As substituições ficam sem aspas em volta e com o texto novo entre aspas: é o único
# jeito que trata a barra invertida igual do bash 3.2 ao 5.3.
gc_json_unescape() {
  local s=$1 bs='\' q='"' sl='/' ph=$'\001' nl=$'\n' tab=$'\t' cr=$'\r'
  s=${s//"$bs$bs"/"$ph"}
  s=${s//"$bs$q"/"$q"}
  s=${s//"$bs$sl"/"$sl"}
  s=${s//"${bs}n"/"$nl"}
  s=${s//"${bs}t"/"$tab"}
  s=${s//"${bs}r"/"$cr"}
  s=${s//"$ph"/"$bs"}
  printf '%s\n' "$s"
}

# Primeiro valor string da chave no JSON (código 1 se não houver).
gc_json_field() {
  local re='"'"$2"'"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)"'
  [[ $1 =~ $re ]] || return 1
  gc_json_unescape "${BASH_REMATCH[1]}"
}

gc_json_escape() {
  local s=$1 bs='\' q='"' nl=$'\n' tab=$'\t' cr=$'\r'
  s=${s//"$bs"/"$bs$bs"}
  s=${s//"$q"/"$bs$q"}
  s=${s//"$nl"/"${bs}n"}
  s=${s//"$cr"/"${bs}r"}
  s=${s//"$tab"/"${bs}t"}
  printf '%s' "$s"
}

# ---------- tempo ----------

# Roda o comando com limite de tempo (o macOS não tem `timeout`). Devolve o código
# do comando, ou 124 se o tempo estourou. O vigia não segura o stdout de quem chamou.
gc_run_with_timeout() {
  local secs=$1; shift
  "$@" &
  local pid=$!
  ( sleep "$secs" && kill "$pid" ) </dev/null >/dev/null 2>&1 &
  local watcher=$!
  wait "$pid"
  local rc=$?
  if kill -0 "$watcher" 2>/dev/null; then
    kill "$watcher" 2>/dev/null
    wait "$watcher" 2>/dev/null
    return "$rc"
  fi
  return 124
}

# ---------- subcomandos simples ----------

gc_cmd_home() { gc_home; }
gc_cmd_os() { gc_os; }

gc_cmd_config() {
  case "${1:-}" in
    get) [ $# -eq 2 ] && gc_config_get "$2" && return 0 ;;
    set) [ $# -eq 3 ] && gc_config_set "$2" "$3" && return 0 ;;
    list) gc_config_list; return 0 ;;
  esac
  printf 'uso: git-commands config get <chave> | set <chave> <valor> | list\n' >&2
  return 1
}
