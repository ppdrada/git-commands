# Utilitários dos testes do git-commands (carregado por tests/run.sh).
ROOT="${ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
PLUGIN="$ROOT/plugins/git-commands"

gc() { bash "$PLUGIN/bin/git-commands" "$@"; }

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

# Repositório sem remote, com um commit. Imprime o caminho.
make_local_repo() {
  local r="$SANDBOX/projetos/$1"
  git init -q -b main "$r"
  printf '# %s\n' "$1" > "$r/README.md"
  git -C "$r" add README.md
  git -C "$r" commit -qm "Primeiro commit"
  printf '%s\n' "$r"
}
