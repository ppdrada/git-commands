# Testes do glossário de conceitos e das citações [conceito: <id>] nas skills.

test_glossario_tem_exatamente_os_20_ids() {
  local ids; ids=$(sed -n 's/^## //p' "$PLUGIN/reference/conceitos.md" | LC_ALL=C sort | tr '\n' ' ')
  assert_eq "add branch chave-ssh clone commit conflito diff fetch git-config gitignore log merge publico-privado pull pull-request push readme remote repositorio stash " "$ids" ""
  gc learned add chave-ssh || fail "chave-ssh foi recusado"
}

test_frase_do_git_init_literal() {
  assert_contains "$(cat "$PLUGIN/reference/conceitos.md")" "git init é criar ou inicializar um novo repositório Git em um diretório do seu computador." ""
}

test_conceitos_citados_existem() {
  local id
  for id in $(cat "$PLUGIN"/skills/*/SKILL.md "$PLUGIN"/reference/regras.md 2>/dev/null | grep -o '\[conceito: [a-z-]*\]' | sed 's/\[conceito: //; s/\]//' | sort -u); do
    grep -q "^## $id\$" "$PLUGIN/reference/conceitos.md" || fail "conceito sem glossário: $id"; done; true
}
