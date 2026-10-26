# Funções comuns do git-commands (usadas pelo executável, pelos hooks e pelo agendador).
# Compatível com bash 3.2. Sem heredoc: o bash 5.3 pode travar com heredoc dentro de hooks.
# Sem case dentro de $(...): o bash 3.2 do Mac lê o ")" do padrão como o fim do $( e não
# carrega o arquivo.

case "${BASH_SOURCE[0]}" in
  */*|*\\*) GC_LIB_DIR="${BASH_SOURCE[0]%[/\\]*}" ;;
  *) GC_LIB_DIR=. ;;
esac
GC_ROOT="$(cd "$GC_LIB_DIR/.." && pwd)"

GC_CONFIG_KEYS="projects_dir auto_check interval proactive auto_check_asked github_user"

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
  # Troca sem deixar o agendador sem app: o antigo sai do caminho, o novo entra, e só então
  # o antigo é apagado.
  if [ -d "$app" ]; then mv "$app" "$app.old.$$" || { rm -rf "$tmp"; return 1; }; fi
  mv "$tmp" "$app" || { [ -d "$app.old.$$" ] && mv "$app.old.$$" "$app"; return 1; }
  rm -rf "$app.old.$$"
}

# Rede sem perguntas: nada de pedir senha no terminal nem abrir janela de login.
# O git tenta os programas de senha (GIT_ASKPASS, SSH_ASKPASS) antes de olhar o
# GIT_TERMINAL_PROMPT, e o login do Git Bash deixa um deles definido: por isso vão vazios.
# No SSH, BatchMode faz falhar em vez de perguntar senha ou chave do servidor.
gc_quiet_net() {
  export GIT_TERMINAL_PROMPT=0 GCM_INTERACTIVE=never GIT_ASKPASS= SSH_ASKPASS= SSH_ASKPASS_REQUIRE=never
  if [ -z "${GIT_SSH_COMMAND:-}" ] && [ -z "$(git config --get core.sshCommand 2>/dev/null)" ]; then
    export GIT_SSH_COMMAND='ssh -o BatchMode=yes -o ConnectTimeout=10'
  fi
}

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
  local u re='^(https?://([^/@]+@)?(www\.)?github\.com(:[0-9]+)?(/|$)|[^/@:]+@github\.com:|ssh://([^/@]+@)?(ssh\.)?github\.com(:[0-9]+)?(/|$)|git://github\.com/)'
  u=$(printf '%s' "$1" | tr 'A-Z' 'a-z')
  [[ $u =~ $re ]]
}

# O começo de um endereço do GitHub que vem antes do dono, numa ERE só, para o endereço já em minúsculas: o dono é o que
# vem depois dele, até a primeira /. O gc_github_owner e a busca na pasta do usuário (o awk do gc_home_repos) usam esta
# mesma variável, para os dois concordarem sempre sobre quem é o dono.
GC_GITHUB_OWNER_RE='^(https?://([^/@]+@)?(www\.)?github\.com(:[0-9]+)?/|[^/@:]+@github\.com:|ssh://([^/@]+@)?(ssh\.)?github\.com(:[0-9]+)?/|git://github\.com/)'

# Dono, em minúsculas, de um endereço do GitHub: https://github.com/dono/repo (com ou sem www. e
# usuário), git@github.com:dono/repo, ssh://git@github.com/dono/repo (ou ssh.github.com pela
# porta 443) e git://github.com/dono/repo. Código 1, sem imprimir nada, para qualquer outro.
gc_github_owner() {
  local u resto dono
  u=$(printf '%s' "$1" | tr 'A-Z' 'a-z')
  [[ $u =~ $GC_GITHUB_OWNER_RE ]] || return 1
  resto=${u#"${BASH_REMATCH[0]}"}; dono=${resto%%/*}
  [ -n "$dono" ] || return 1
  printf '%s\n' "$dono"
}

# 0 se $1 tem forma de login do GitHub: letras, números, - e _ (as contas de empresa têm _), começando por letra ou número.
gc_is_github_login() {
  local re='^[A-Za-z0-9][A-Za-z0-9_-]*$'
  [[ $1 =~ $re ]]
}

# Endereço HTTPS equivalente a um endereço SSH do GitHub (git@github.com:dono/repo,
# ssh://git@github.com/dono/repo, ssh://git@ssh.github.com:443/dono/repo). Código 1 para o resto.
gc_github_ssh_to_https() {
  local caminho re1='^[^/@:]+@github\.com:(.+)$' re2='^ssh://([^/@]+@)?(ssh\.)?github\.com(:[0-9]+)?/(.+)$'
  if [[ $1 =~ $re1 ]]; then caminho=${BASH_REMATCH[1]}
  elif [[ $1 =~ $re2 ]]; then caminho=${BASH_REMATCH[4]}
  else return 1; fi
  caminho=${caminho%/}; caminho=${caminho%.git}
  printf 'https://github.com/%s.git\n' "$caminho"
}

# Busca o origin com limite de tempo (quem chama faz o gc_quiet_net antes). Um origin SSH do
# GitHub é buscado primeiro pelo endereço HTTPS equivalente, com o login do gh: assim o segundo
# plano não precisa da senha da chave SSH. Se o HTTPS falhar (projeto privado sem o login do gh
# no git), tenta pelo próprio SSH, sem perguntas, como na 1.0.0; estouro de tempo não tenta de novo.
gc_fetch_origin() {
  local url https rc
  url=$(git -C "$1" config --get remote.origin.url 2>/dev/null)
  if https=$(gc_github_ssh_to_https "$url"); then
    gc_run_with_timeout "$2" git -C "$1" fetch --prune --quiet "$https" '+refs/heads/*:refs/remotes/origin/*' && return 0
    rc=$?
    [ "$rc" -eq 124 ] && return 124
  fi
  gc_run_with_timeout "$2" git -C "$1" fetch --prune --quiet
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

# Caminho real de uma pasta que existe: C:/... no Git Bash (pwd -W), o caminho físico nos outros
# sistemas (pwd -P). Código 1, sem imprimir nada, se a pasta não existe.
gc_real_dir() {
  [ -d "$1" ] || return 1
  ( CDPATH= cd -- "$1" >/dev/null 2>&1 && { pwd -W 2>/dev/null || pwd -P; } )
}

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

# As funções terminadas em _to gravam o resultado na variável cujo nome vem em $1, sem
# subshell: no Windows cada subshell custa caro, e os hooks rodam a cada comando ou edição.

# As substituições ficam sem aspas em volta e com o texto novo entre aspas: é o único
# jeito que trata a barra invertida igual do bash 3.2 ao 5.3.
gc_json_unescape_to() {
  local s=$2 bs='\' q='"' sl='/' ph=$'\001' nl=$'\n' tab=$'\t' cr=$'\r'
  s=${s//"$bs$bs"/"$ph"}
  s=${s//"$bs$q"/"$q"}
  s=${s//"$bs$sl"/"$sl"}
  s=${s//"${bs}n"/"$nl"}
  s=${s//"${bs}t"/"$tab"}
  s=${s//"${bs}r"/"$cr"}
  s=${s//"$ph"/"$bs"}
  printf -v "$1" '%s' "$s"
}

gc_json_unescape() { local gc__u; gc_json_unescape_to gc__u "$1"; printf '%s\n' "$gc__u"; }

# Primeiro valor string da chave $3 no JSON $2, na variável $1 (código 1 se não houver).
gc_json_field_to() {
  local re='"'"$3"'"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)"'
  [[ $2 =~ $re ]] || return 1
  gc_json_unescape_to "$1" "${BASH_REMATCH[1]}"
}

# Primeiro valor string da chave no JSON (código 1 se não houver).
gc_json_field() { local gc__v; gc_json_field_to gc__v "$1" "$2" || return 1; printf '%s\n' "$gc__v"; }

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
  local secs=$1 t0=$SECONDS; shift
  "$@" &
  local pid=$!
  ( sleep "$secs" && kill "$pid" ) </dev/null >/dev/null 2>&1 &
  local watcher=$!
  wait "$pid"
  local rc=$?
  kill "$watcher" 2>/dev/null
  wait "$watcher" 2>/dev/null
  # Morto por sinal depois do prazo: foi o vigia, o tempo estourou. (Olhar se o vigia ainda
  # está vivo dava corrida: ele pode ter matado o comando e ainda não ter saído.)
  [ "$rc" -gt 128 ] && [ $(( SECONDS - t0 )) -ge "$secs" ] && return 124
  return "$rc"
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
