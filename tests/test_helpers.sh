# Testes dos utilitários de teste (helpers.sh).

test_sandbox_isola_home() { assert_contains "$HOME" "$SANDBOX" "HOME fica no sandbox"; }

test_par_github_tem_url_do_github_e_fica_atras() {
  local r; r=$(make_github_pair app)
  assert_eq "https://github.com/teste/app.git" "$(git -C "$r" config --get remote.origin.url)" "url crua"
  push_remote_commit app novo.txt "novidade"
  git -C "$r" fetch -q
  assert_eq "1" "$(git -C "$r" rev-list --count HEAD..@{u})" "1 commit atrás"
}

test_repo_em_qualquer_pasta_tem_dono_e_um_commit() {
  local r; r=$(make_repo_at "$HOME/a/b/site" PPDRADA)
  assert_eq "$HOME/a/b/site" "$r" "imprime o caminho"
  assert_eq "https://github.com/PPDRADA/site.git" "$(git -C "$r" config --get remote.origin.url)" "origin com o dono e o nome da pasta"
  assert_eq "1" "$(git -C "$r" rev-list --count HEAD)" "um commit"
  r=$(make_repo_at "$HOME/x" teste outro)
  assert_eq "https://github.com/teste/outro.git" "$(git -C "$r" config --get remote.origin.url)" "com o nome dado"
}
