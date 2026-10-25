#!/usr/bin/env bash
# Roda os testes do git-commands.
# Uso: bash tests/run.sh [trecho do nome do arquivo de teste]
# Cada função test_* roda num subshell próprio, dentro de um sandbox novo.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export ROOT
. "$ROOT/tests/helpers.sh"

filtro="${1:-}"
GC_TEST_TMP="$(mktemp -d)"
export GC_TEST_TMP
trap 'rm -rf "$GC_TEST_TMP"' EXIT

passou=0; falhou=0; pulou=0
for arquivo in "$ROOT"/tests/test_*.sh; do
  [ -e "$arquivo" ] || continue
  case "$(basename "$arquivo" .sh)" in *"$filtro"*) ;; *) continue ;; esac
  for t in $(sed -n 's/^\(test_[A-Za-z0-9_]*\)[[:space:]]*()[[:space:]]*{*.*$/\1/p' "$arquivo"); do
    saida=$( ( gc_sandbox; . "$arquivo"; "$t"; exit 0 ) 2>&1 )
    rc=$?
    if [ "$rc" -eq 0 ]; then
      passou=$((passou + 1)); printf 'PASS %s\n' "$t"
    elif [ "$rc" -eq 77 ]; then
      pulou=$((pulou + 1)); printf 'SKIP %s: %s\n' "$t" "$(printf '%s\n' "$saida" | tail -n 1)"
    else
      falhou=$((falhou + 1))
      msg=$(printf '%s\n' "$saida" | grep 'FALHOU:' | tail -n 1)
      [ -n "$msg" ] || msg=$(printf '%s\n' "$saida" | tail -n 1)
      printf 'FAIL %s: %s\n' "$t" "$msg"
    fi
  done
done

printf '%s passaram, %s falharam, %s pulados\n' "$passou" "$falhou" "$pulou"
[ "$falhou" -eq 0 ]
