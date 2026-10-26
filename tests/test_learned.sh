# Testes do subcomando learned (conceitos já explicados para a pessoa).

test_learned_ciclo() {
  assert_exit 1 gc learned has commit
  gc learned add commit branch commit
  assert_eq "$(printf 'branch\ncommit')" "$(gc learned list)" "ordenado e sem repetição"
  assert_exit 0 gc learned has branch
  gc learned forget branch; assert_exit 1 gc learned has branch
  gc learned reset; assert_eq "" "$(gc learned list)" ""
}

test_learned_id_desconhecido() { assert_exit 2 gc learned add bananas; }

test_learned_sobrevive_em_disco() { gc learned add push; assert_contains "$(cat "$(gc home)/learned")" "push" ""; }

test_learned_compara_texto_exato() {
  gc learned add commit
  gc learned has c.mmit && fail "has c.mmit achou commit"
  gc learned forget c.mmit; gc learned has commit || fail "forget c.mmit apagou commit"; return 0
}
