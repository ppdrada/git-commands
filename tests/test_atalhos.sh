# Testes dos atalhos (/git-commands:pr, commit, push, …): só rodam quando a pessoa digita e apontam para uma skill que existe.

test_atalhos_so_quando_digitados_e_apontam_para_skill_que_existe() {
  local a alvo
  for a in branch commit pr pull pull-request push; do
    grep -qx 'disable-model-invocation: true' "$PLUGIN/skills/$a/SKILL.md" || fail "o atalho $a pode rodar sem a pessoa digitar"
    alvo=$(grep -o 'skill `git-commands:[a-z-]*`' "$PLUGIN/skills/$a/SKILL.md" | sed 's/.*:\(.*\)`/\1/')
    [ -f "$PLUGIN/skills/$alvo/SKILL.md" ] || fail "o atalho $a aponta para uma skill que não existe: $alvo"
  done
}
