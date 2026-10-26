# Utilitários dos testes do git-commands (carregado por tests/run.sh).
ROOT="${ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
PLUGIN="$ROOT/plugins/git-commands"

gc() { "$BASH" "$PLUGIN/bin/git-commands" "$@"; }

fail() { printf 'FALHOU: %s\n' "$*"; exit 1; }
skip() { printf 'PULADO: %s\n' "$*"; exit 77; }

assert_eq() { [ "$1" = "$2" ] || fail "${3:-assert_eq}: esperado [$1], veio [$2]"; }
assert_contains() { case "$1" in *"$2"*) ;; *) fail "${3:-assert_contains}: [$2] não está em [$1]" ;; esac; }
assert_not_contains() { case "$1" in *"$2"*) fail "${3:-assert_not_contains}: [$2] não devia estar em [$1]" ;; esac; }
assert_file() { [ -e "$1" ] || fail "${2:-assert_file}: não existe $1"; }
assert_exit() {
  local esperado=$1; shift
  "$@" >/dev/null 2>&1
  local rc=$?
  [ "$rc" = "$esperado" ] || fail "assert_exit: esperado código $esperado, veio $rc em: $*"
}

# Caminho no formato que o git.exe do Windows entende (C:/...); igual a pwd fora do Windows.
native_path() {
  if (cd "$1" && pwd -W) >/dev/null 2>&1; then (cd "$1" && pwd -W); else (cd "$1" && pwd); fi
}

# Sandbox novo por teste: HOME, gitconfig global e pastas próprios.
gc_sandbox() {
  SANDBOX="$(mktemp -d "${GC_TEST_TMP:-${TMPDIR:-/tmp}}/sandbox.XXXXXX")"
  export SANDBOX
  export HOME="$SANDBOX/home"
  mkdir -p "$HOME" "$SANDBOX/projetos" "$SANDBOX/remotes"
  unset GIT_COMMANDS_HOME GIT_COMMANDS_OS GIT_COMMANDS_GH GIT_COMMANDS_GH_DIRS GIT_COMMANDS_SCHEDULE_DRY_RUN
  export GIT_CONFIG_GLOBAL="$SANDBOX/gitconfig"
  export GIT_CONFIG_NOSYSTEM=1
  export GIT_TERMINAL_PROMPT=0
  git config --global user.name Teste
  git config --global user.email teste@example.com
  git config --global init.defaultBranch main
  git config --global advice.detachedHead false
  cd "$SANDBOX" || exit 1
}

# Cria um "GitHub" local: repositório bare + clone cuja origin é https://github.com/teste/<nome>.git
# (o insteadOf no gitconfig global redireciona essa URL para o bare). Imprime o caminho do clone.
make_github_pair() {
  local nome=$1
  local bare="$SANDBOX/remotes/$nome.git" clone="$SANDBOX/projetos/$nome"
  git init -q --bare -b main "$bare"
  git config --global "url.$(native_path "$bare").insteadOf" "https://github.com/teste/$nome.git"
  git clone -q "https://github.com/teste/$nome.git" "$clone" 2>/dev/null
  printf '# %s\n' "$nome" > "$clone/README.md"
  git -C "$clone" add README.md
  git -C "$clone" commit -qm "Primeiro commit"
  git -C "$clone" push -q -u origin main 2>/dev/null
  printf '%s\n' "$clone"
}

# Simula outra pessoa mandando um commit para o "GitHub" de <nome>.
push_remote_commit() {
  local nome=$1 arquivo=$2 msg=$3
  local outro="$SANDBOX/outro/$nome"
  if [ ! -d "$outro/.git" ]; then
    mkdir -p "$SANDBOX/outro"
    git clone -q "https://github.com/teste/$nome.git" "$outro"
  fi
  git -C "$outro" pull -q --ff-only 2>/dev/null
  printf '%s\n' "$msg" >> "$outro/$arquivo"
  git -C "$outro" add "$arquivo"
  git -C "$outro" commit -qm "$msg"
  git -C "$outro" push -q 2>/dev/null
}

# gh falso em $SANDBOX/stub/gh, com a mesma saída do gh real nos comandos que o plugin usa.
# auth status sai com $STUB_GH_AUTH (0 = logado). config get com "user" por último dá o login
# ($STUB_GH_USER, tester se não existir, vazio se for definida vazia); com outra chave, dá o
# protocolo ($STUB_GH_PROTOCOL). api user dá o login da API ($STUB_GH_API_USER, tester se não existir);
# com $STUB_GH_API_ERROR escreve esse texto no stdout e sai com 1, como o gh num erro HTTP (o corpo do erro
# vai para o stdout, e não para o stderr). Cada chamada fica anotada em $SANDBOX/gh.log, para os testes
# conferirem se o gh foi chamado.
make_gh_stub() {
  mkdir -p "$SANDBOX/stub"
  printf '%s\n' '#!/usr/bin/env bash' \
    "log=\"$SANDBOX/gh.log\"" \
    'printf "%s\n" "$*" >> "$log"' \
    'case "$1 $2" in' \
    '  "--version "*) printf "gh version 2.62.0 (2024-11-14)\nhttps://github.com/cli/cli/releases/tag/v2.62.0\n" ;;' \
    '  "auth status") [ -n "${STUB_GH_OFFLINE:-}" ] && printf "%s\n" "X Failed to log in to github.com account tester (keyring)" "- The token in keyring is invalid." "- To re-authenticate, run: gh auth refresh -h github.com" >&2; exit "${STUB_GH_AUTH:-0}" ;;' \
    '  "auth token") [ -n "${STUB_GH_OFFLINE:-}" ] && { echo gho_teste; exit 0; }; exit "${STUB_GH_AUTH:-0}" ;;' \
    '  "config get") for a; do :; done; if [ "$a" = user ]; then echo "${STUB_GH_USER-tester}"; else echo "${STUB_GH_PROTOCOL:-https}"; fi ;;' \
    '  "config set") exit 0 ;;' \
    '  "api meta") printf "%s\n" "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl" "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=" ;;' \
    '  "api user") [ -n "${STUB_GH_OFFLINE:-}" ] && { printf "%s\n" "error connecting to api.github.com" "check your internet connection or https://githubstatus.com" >&2; exit 1; }; [ -n "${STUB_GH_API_ERROR:-}" ] && { printf "%s\n" "$STUB_GH_API_ERROR"; printf "%s\n" "gh: Bad credentials (HTTP 401)" >&2; exit 1; }; echo "${STUB_GH_API_USER-tester}" ;;' \
    '  *) exit 1 ;;' \
    'esac' > "$SANDBOX/stub/gh"
  chmod +x "$SANDBOX/stub/gh"
}

# crontab falso em $SANDBOX/stub/crontab, que guarda o conteúdo em $SANDBOX/crontab.txt e entra
# na frente do PATH. Começa com o conteúdo do primeiro argumento.
make_crontab_stub() {
  mkdir -p "$SANDBOX/stub"
  printf '%s\n' "$1" > "$SANDBOX/crontab.txt"
  printf '%s\n' '#!/usr/bin/env bash' \
    "f=\"$SANDBOX/crontab.txt\"" \
    'case "${1:-}" in' \
    '  -l) [ -s "$f" ] || exit 1; cat "$f" ;;' \
    '  -) [ -n "${STUB_CRONTAB_FAIL:-}" ] && exit 1; cat > "$f" ;;' \
    '  -r) : > "$f" ;;' \
    '  *) exit 1 ;;' \
    'esac' > "$SANDBOX/stub/crontab"
  chmod +x "$SANDBOX/stub/crontab"
  export PATH="$SANDBOX/stub:$PATH"
}

# Repositório sem remote, com um commit. Imprime o caminho.
make_local_repo() {
  local r="$SANDBOX/projetos/$1"
  git init -q -b main "$r"
  printf '# %s\n' "$1" > "$r/README.md"
  git -C "$r" add README.md
  git -C "$r" commit -qm "Primeiro commit"
  printf '%s\n' "$r"
}

# Repositório com um commit em <caminho> e origin em https://github.com/<dono>/<nome>.git, sem
# remoto de verdade. O nome padrão é o último pedaço do caminho. Imprime o caminho.
make_repo_at() {
  local r=${1%/} dono=$2 nome
  nome=${3:-${r##*/}}
  mkdir -p "$r"
  git init -q -b main "$r"
  printf '# %s\n' "$nome" > "$r/README.md"
  git -C "$r" add README.md
  git -C "$r" commit -qm "Primeiro commit"
  git -C "$r" remote add origin "https://github.com/$dono/$nome.git"
  printf '%s\n' "$r"
}
