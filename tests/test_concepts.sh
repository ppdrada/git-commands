# Testes do glossário de conceitos e das citações [conceito: <id>] nas skills.

test_glossario_aceita_exatamente_os_19_ids() {
  gc learned add repositorio git-config commit add readme gitignore remote push pull fetch branch merge \
    conflito pull-request clone stash log diff publico-privado || fail "algum conceito do glossário foi recusado"
  assert_eq "add branch clone commit conflito diff fetch git-config gitignore log merge publico-privado pull pull-request push readme remote repositorio stash " \
    "$(gc learned list | tr '\n' ' ')" ""
}

test_frase_do_git_init_literal() {
  assert_contains "$(cat "$PLUGIN/reference/conceitos.md")" "git init é criar ou inicializar um novo repositório Git em um diretório do seu computador." ""
}

test_conceitos_citados_existem() {
  local id
  for id in $(cat "$PLUGIN"/skills/*/SKILL.md "$PLUGIN"/reference/regras.md 2>/dev/null | grep -o '\[conceito: [a-z-]*\]' | sed 's/\[conceito: //; s/\]//' | sort -u); do
    grep -q "^## $id\$" "$PLUGIN/reference/conceitos.md" || fail "conceito sem glossário: $id"; done; true
}
