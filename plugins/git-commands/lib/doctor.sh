# doctor: diz o que falta no computador para usar git e GitHub (linhas chave=valor).

# Pastas onde o GitHub CLI costuma ficar, mesmo antes de entrar no PATH da sessão
# (por exemplo, logo depois do winget install).
gc_gh_default_dirs() {
  case "$(gc_os)" in
    windows)
      printf '%s\n' "/c/Program Files/GitHub CLI"
      [ -n "${LOCALAPPDATA:-}" ] && printf '%s\n' "$(gc_norm_path "$LOCALAPPDATA")/Programs/GitHub CLI"
      ;;
    mac) printf '%s\n' /opt/homebrew/bin /usr/local/bin ;;
    *) printf '%s\n' /usr/bin /usr/local/bin "$HOME/.local/bin" ;;
  esac
  return 0
}

# Caminho do gh: GIT_COMMANDS_GH (se definido, só ele vale), senão o PATH,
# senão as pastas padrão (trocáveis por GIT_COMMANDS_GH_DIRS, separadas por ":").
gc_gh_bin() {
  if [ -n "${GIT_COMMANDS_GH+x}" ]; then
    [ -x "$GIT_COMMANDS_GH" ] && [ ! -d "$GIT_COMMANDS_GH" ] && printf '%s\n' "$GIT_COMMANDS_GH"
    return 0
  fi
  command -v gh 2>/dev/null && return 0
  local dirs
  if [ -n "${GIT_COMMANDS_GH_DIRS:-}" ]; then
    dirs=$(printf '%s\n' "$GIT_COMMANDS_GH_DIRS" | tr ':' '\n')
  else
    dirs=$(gc_gh_default_dirs)
  fi
  printf '%s\n' "$dirs" | while IFS= read -r d; do
    [ -n "$d" ] || continue
    for p in "$d/gh" "$d/gh.exe"; do
      if [ -x "$p" ] && [ ! -d "$p" ]; then printf '%s\n' "$p"; exit 0; fi
    done
  done
  return 0
}

# 0 se a versão (ex.: 2.55.0.windows.5) é pelo menos 2.28.
gc_git_version_ok() {
  local maj min; maj=${1%%.*}; min=${1#*.}; min=${min%%.*}
  case "$maj$min" in ""|*[!0-9]*) return 1 ;; esac
  [ "$maj" -gt 2 ] || { [ "$maj" -eq 2 ] && [ "$min" -ge 28 ]; }
}

# 0 se a saída do gh fala de falta de conexão, e não de login.
gc_doctor_offline() {
  case "$1" in *[Cc]onnect*|*"dial tcp"*|*[Tt]imeout*|*[Rr]esolve*|*[Nn]etwork*|*"no such host"*) return 0 ;; esac
  return 1
}

# Quantas pastas a lista $1 (<home>/folders ou <home>/ignored) tem. Com "faltam" em $2, só as que já não existem no disco.
gc_doctor_pastas() {
  gc_folders_lines "$1" | {
    local pasta n=0
    while IFS= read -r pasta; do
      if [ "${2:-}" != faltam ] || [ ! -d "$pasta" ]; then n=$((n + 1)); fi
    done
    printf '%s\n' "$n"
  }
}

gc_cmd_doctor() {
  local git_v="" git_ok=no gh gh_v="" gh_on=no gh_auth=no gh_user="" auth_out="" api_out="" api_rc gh_proto="" ssh_pub="" k h
  if command -v git >/dev/null 2>&1; then
    git_v=$(git --version 2>/dev/null | sed -n 's/^git version //p')
    gc_git_version_ok "$git_v" && git_ok=yes
  fi
  command -v gh >/dev/null 2>&1 && gh_on=yes
  gh=$(gc_gh_bin)
  if [ -n "$gh" ]; then
    gh_v=$(gc_run_with_timeout 15 "$gh" --version 2>/dev/null | head -n 1 | sed -n 's/^gh version \([^ ]*\).*/\1/p')
    if auth_out=$(gc_run_with_timeout 15 "$gh" auth status --hostname github.com 2>&1); then
      gh_auth=yes
      gh_user=$(gc_run_with_timeout 15 "$gh" api user --jq .login 2>/dev/null)
    elif "$gh" auth token >/dev/null 2>&1; then
      # Há um token guardado, mas o login não foi confirmado. Sem internet, o gh auth status só
      # diz que o token é inválido; quem mostra a falta de conexão é uma chamada à API.
      api_out=$(gc_run_with_timeout 10 "$gh" api user --jq .login 2>&1); api_rc=$?
      if [ "$api_rc" -eq 124 ] || gc_doctor_offline "$auth_out" || gc_doctor_offline "$api_out"; then
        gh_auth=sem-rede
      fi
    fi
    gh_proto=$("$gh" config get -h github.com git_protocol 2>/dev/null)
  fi
  k=$(gc_ssh_key) && ssh_pub="$k.pub"
  # O login que a API confirmou vale mais que o gravado: a pessoa pode ter trocado de conta no gh, e é com o login que a busca na
  # pasta do usuário reconhece os projetos dela. Se a API não respondeu (sem rede, sem login), o que está gravado fica como está.
  if [ -n "$gh_user" ] && [ "$gh_user" != "$(gc_config_get github_user)" ]; then gc_config_set github_user "$gh_user"; fi
  h=$(gc_home)
  printf 'os=%s\n' "$(gc_os)"
  printf 'git=%s\n' "$git_v"
  printf 'git_ok=%s\n' "$git_ok"
  printf 'gh=%s\n' "$gh_v"
  printf 'gh_path=%s\n' "$gh"
  printf 'gh_on_path=%s\n' "$gh_on"
  printf 'gh_auth=%s\n' "$gh_auth"
  printf 'gh_user=%s\n' "$gh_user"
  printf 'user_name=%s\n' "$(git config --global user.name 2>/dev/null)"
  printf 'user_email=%s\n' "$(git config --global user.email 2>/dev/null)"
  printf 'projects_dir=%s\n' "$(gc_config_get projects_dir)"
  printf 'github_user=%s\n' "$(gc_github_user)"
  printf 'folders=%s\n' "$(gc_doctor_pastas "$h/folders")"
  printf 'folders_missing=%s\n' "$(gc_doctor_pastas "$h/folders" faltam)"
  printf 'ignored=%s\n' "$(gc_doctor_pastas "$h/ignored")"
  printf 'auto_check=%s\n' "$(gc_config_get auto_check)"
  printf 'interval=%s\n' "$(gc_config_get interval)"
  printf 'proactive=%s\n' "$(gc_config_get proactive)"
  printf 'ssh_key=%s\n' "$ssh_pub"
  printf 'git_protocol=%s\n' "${gh_proto:-https}"
}
