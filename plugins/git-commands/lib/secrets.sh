# secrets: avisa sobre arquivos com cara de senha ou chave antes de irem para o GitHub.
# Saída: caminho<TAB>motivo. Código 3 se achou algo, 0 se não.

# Motivo pelo nome do arquivo.
gc_secret_name_reason() {
  case "${1##*/}" in
    .env.example|.env.sample) return 1 ;;
    .env|.env.*) printf 'arquivo .env (senhas e chaves)\n' ;;
    *.pem|*.key|*.p12|*.pfx|id_rsa*|id_ed25519*) printf 'chave privada\n' ;;
    *credentials*.json|*secret*) printf 'arquivo de credenciais\n' ;;
    *) return 1 ;;
  esac
}

# Motivo pelo conteúdo (só arquivos de texto de até 1 MB).
gc_secret_content_reason() {
  local f=$1 size
  [ -f "$f" ] || return 1
  size=$(wc -c < "$f" | tr -d ' ')
  [ "$size" -le 1048576 ] || return 1
  grep -Iq . "$f" 2>/dev/null || return 1
  if grep -Eq -- '-----BEGIN [A-Z ]*PRIVATE KEY-----' "$f"; then printf 'chave privada\n'; return 0; fi
  if grep -Eq 'ghp_[A-Za-z0-9]{36}|github_pat_' "$f"; then printf 'parece um token do GitHub\n'; return 0; fi
  if grep -Eq 'AKIA[0-9A-Z]{16}|sk-[A-Za-z0-9]{20,}|xox[baprs]-' "$f"; then printf 'parece uma chave de API\n'; return 0; fi
  return 1
}

gc_cmd_secrets() {
  local staged=no repo=. top list out
  while [ $# -gt 0 ]; do
    case "$1" in
      --staged) staged=yes ;;
      -*) printf 'uso: git-commands secrets [--staged] [<repositório>]\n' >&2; return 1 ;;
      *) repo=$1 ;;
    esac
    shift
  done
  top=$(git -C "$repo" rev-parse --show-toplevel 2>/dev/null) || {
    printf 'git-commands: não é um repositório git: %s\n' "$repo" >&2; return 1; }
  if [ "$staged" = yes ]; then
    list=$(git -c core.quotepath=false -C "$top" diff --cached --name-only --diff-filter=ACMR)
  else
    list=$( { git -c core.quotepath=false -C "$top" diff --cached --name-only --diff-filter=ACMR
              git -c core.quotepath=false -C "$top" ls-files --modified --others --exclude-standard; } | LC_ALL=C sort -u)
  fi
  out=$(printf '%s\n' "$list" | while IFS= read -r f; do
    [ -n "$f" ] || continue
    reason=$(gc_secret_name_reason "$f") || reason=$(gc_secret_content_reason "$top/$f") || continue
    printf '%s\t%s\n' "$f" "$reason"
  done)
  [ -n "$out" ] || return 0
  printf '%s\n' "$out"
  return 3
}
