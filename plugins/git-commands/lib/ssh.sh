# ssh: a chave SSH do GitHub (git-commands ssh ...). Nunca lê nem mostra a parte privada da
# chave e nunca recebe a senha dela: só a parte pública (.pub) é lida.

gc_ssh_usage() {
  printf 'uso: git-commands ssh status | test | known-hosts | config | remote <repositório> ssh|https\n' >&2
}

# Caminho da chave privada cujo .pub existe, na ordem id_ed25519, id_ecdsa, id_rsa (código 1 se
# não houver nenhuma).
gc_ssh_key() {
  local n
  for n in id_ed25519 id_ecdsa id_rsa; do
    [ -f "$HOME/.ssh/$n.pub" ] && { printf '%s\n' "$HOME/.ssh/$n"; return 0; }
  done
  return 1
}

# O ssh que o git usa: GIT_COMMANDS_SSH (testes), o core.sshCommand ou o ssh do PATH.
gc_ssh_cmd() {
  local c
  if [ -n "${GIT_COMMANDS_SSH:-}" ]; then printf '%s\n' "$GIT_COMMANDS_SSH"; return 0; fi
  c=$(git config --global --get core.sshCommand 2>/dev/null)
  printf '%s\n' "${c:-ssh}"
}

# O ssh-add do mesmo OpenSSH: o ssh.exe do Windows tem o ssh-add.exe na mesma pasta.
gc_ssh_add_cmd() {
  local c; c=$(gc_ssh_cmd)
  case "$c" in *ssh.exe) printf '%sssh-add.exe\n' "${c%ssh.exe}" ;; *) printf 'ssh-add\n' ;; esac
}

# https://github.com/dono/repo(.git) vira git@github.com:dono/repo.git (código 1 para o resto).
gc_github_https_to_ssh() {
  local caminho re='^https://([^/@]+@)?(www\.)?github\.com/(.+)$'
  [[ $1 =~ $re ]] || return 1
  caminho=${BASH_REMATCH[3]}; caminho=${caminho%/}; caminho=${caminho%.git}
  printf 'git@github.com:%s.git\n' "$caminho"
}

gc_ssh_status() {
  local k fp="" lista rc agente cfg=nao kh=nao gh proto="" dir repos r url https=0 sshn=0
  k=$(gc_ssh_key) || k=""
  [ -n "$k" ] && fp=$(ssh-keygen -lf "$k.pub" 2>/dev/null | awk '{print $2}')
  lista=$("$(gc_ssh_add_cmd)" -l 2>/dev/null); rc=$?
  if [ "$rc" -eq 2 ] || [ "$rc" -eq 127 ]; then agente=sem-agente
  elif [ -n "$fp" ] && printf '%s\n' "$lista" | grep -qF -- "$fp"; then agente=sim
  else agente=nao; fi
  [ -f "$HOME/.ssh/config" ] && grep -qiE '^[[:space:]]*Host[[:space:]]([^#]*[[:space:]])?github\.com([[:space:]]|$)' "$HOME/.ssh/config" && cfg=sim
  [ -f "$HOME/.ssh/known_hosts" ] && ssh-keygen -F github.com -f "$HOME/.ssh/known_hosts" >/dev/null 2>&1 && kh=sim
  gh=$(gc_gh_bin)
  [ -n "$gh" ] && proto=$("$gh" config get -h github.com git_protocol 2>/dev/null)
  dir=$(gc_config_get projects_dir)
  if [ -n "$dir" ] && [ -d "$dir" ]; then
    repos=$(gc_updates_repos "$dir")
    local IFS=$'\n'
    for r in $repos; do
      url=$(git -C "$r" config --get remote.origin.url 2>/dev/null)
      if gc_github_ssh_to_https "$url" >/dev/null; then sshn=$((sshn + 1))
      elif gc_is_github_url "$url"; then https=$((https + 1)); fi
    done
  fi
  printf 'chave=%s\nimpressao=%s\nagente=%s\nconfig=%s\nknown_hosts=%s\nprotocolo=%s\nprojetos_https=%s\nprojetos_ssh=%s\n' \
    "$k" "$fp" "$agente" "$cfg" "$kh" "${proto:-https}" "$https" "$sshn"
}

# Testa a chave com o GitHub, sem perguntas (BatchMode): 0 ok, 1 chave recusada,
# 2 servidor desconhecido, 3 sem conexão. O ssh roda pelo shell, como o git roda o core.sshCommand.
gc_ssh_test() {
  local out usuario
  out=$(gc_run_with_timeout 15 sh -c "$(gc_ssh_cmd)"' "$@"' sh -T -o BatchMode=yes -o ConnectTimeout=10 git@github.com 2>&1)
  case "$out" in
    *"successfully authenticated"*)
      usuario=${out#*Hi }; usuario=${usuario%%!*}
      printf 'ok %s\n' "$usuario"; return 0 ;;
    *"Permission denied"*) printf 'chave-recusada\n'; return 1 ;;
    *"Host key verification failed"*|*"REMOTE HOST IDENTIFICATION HAS CHANGED"*) printf 'servidor-desconhecido\n'; return 2 ;;
    *) printf 'sem-conexao\n'; return 3 ;;
  esac
}

# Grava no known_hosts as chaves do servidor do GitHub, buscadas pela API do próprio GitHub
# (por HTTPS e com login), para o SSH nunca aceitar o servidor no escuro.
gc_ssh_known_hosts() {
  local gh chaves k kh="$HOME/.ssh/known_hosts" n=0
  gh=$(gc_gh_bin)
  if [ -n "$gh" ]; then chaves=$(gc_run_with_timeout 15 "$gh" api meta --jq '.ssh_keys[]' 2>/dev/null); fi
  [ -n "$chaves" ] || { printf 'git-commands: não consegui buscar as chaves do servidor do GitHub\n' >&2; return 1; }
  mkdir -p "$HOME/.ssh" || return 1
  chmod 700 "$HOME/.ssh" 2>/dev/null
  local IFS=$'\n'
  for k in $chaves; do
    [ -f "$kh" ] && grep -qF -- "$k" "$kh" && continue
    printf 'github.com %s\n' "$k" >> "$kh" || return 1
    n=$((n + 1))
  done
  if [ "$n" -gt 0 ]; then printf 'adicionadas %s\n' "$n"; else printf 'já estavam\n'; fi
}

# Escreve no ~/.ssh/config um bloco Host github.com do git-commands (marcado, uma vez só) que usa
# a chave da pessoa e a guarda no agente; no macOS, também no Keychain. Nunca mexe num
# Host github.com que já exista: código 3.
gc_ssh_config() {
  local k cfg="$HOME/.ssh/config" novo=nao
  k=$(gc_ssh_key) || { printf 'git-commands: nenhuma chave SSH em ~/.ssh\n' >&2; return 1; }
  if [ -f "$cfg" ] && grep -qF '# git-commands: inicio' "$cfg"; then printf 'já existe\n'; return 0; fi
  if [ -f "$cfg" ] && grep -qiE '^[[:space:]]*Host[[:space:]]([^#]*[[:space:]])?github\.com([[:space:]]|$)' "$cfg"; then
    printf 'outro Host github.com\n'; return 3
  fi
  mkdir -p "$HOME/.ssh" || return 1
  chmod 700 "$HOME/.ssh" 2>/dev/null
  [ -f "$cfg" ] || novo=sim
  {
    [ -s "$cfg" ] && printf '\n'
    # IdentitiesOnly: só essa chave vai para o GitHub (outra chave da pessoa poderia entrar em outra
    # conta). IgnoreUnknown: o OpenSSH do Homebrew não conhece UseKeychain e recusaria o arquivo.
    printf '%s\n' '# git-commands: inicio' 'Host github.com' '  AddKeysToAgent yes' '  IdentitiesOnly yes'
    [ "$(gc_os)" = mac ] && printf '%s\n' '  IgnoreUnknown UseKeychain' '  UseKeychain yes'
    printf '%s\n' "  IdentityFile ~/.ssh/${k##*/}" '# git-commands: fim'
  } >> "$cfg" || return 1
  [ "$novo" = sim ] && chmod 600 "$cfg" 2>/dev/null
  printf 'escrito\n'
}

# Troca o origin do repositório entre SSH e HTTPS.
gc_ssh_remote() {
  local r url novo
  r=$(gc_toplevel "${1:-.}") || { printf 'git-commands: não é um repositório git: %s\n' "${1:-.}" >&2; return 1; }
  url=$(git -C "$r" config --get remote.origin.url 2>/dev/null)
  gc_is_github_url "$url" || { printf 'git-commands: o origin não é do GitHub: %s\n' "${url:-(nenhum)}" >&2; return 1; }
  case "${2:-}" in
    ssh) novo=$(gc_github_https_to_ssh "$url") || { printf 'já está em ssh\n'; return 0; } ;;
    https) novo=$(gc_github_ssh_to_https "$url") || { printf 'já está em https\n'; return 0; } ;;
    *) gc_ssh_usage; return 1 ;;
  esac
  git -C "$r" remote set-url origin "$novo" || return 1
  printf '%s -> %s\n' "$url" "$novo"
}

gc_cmd_ssh() {
  local sub=${1:-}
  [ $# -gt 0 ] && shift
  case "$sub" in
    status) gc_ssh_status ;;
    test) gc_ssh_test ;;
    known-hosts) gc_ssh_known_hosts ;;
    config) gc_ssh_config ;;
    remote) gc_ssh_remote "$@" ;;
    *) gc_ssh_usage; return 1 ;;
  esac
}
