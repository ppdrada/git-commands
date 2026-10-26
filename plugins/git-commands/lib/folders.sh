# folders: de onde a verificação automática tira os projetos: a pasta do usuário (os projetos da
# conta do GitHub da pessoa), a pasta de projetos e as pastas que a pessoa pediu, menos as que
# ela mandou ignorar.

# Login da pessoa no GitHub. Vem do config (github_user); se estiver vazio, pergunta ao gh do
# computador, que guarda o login em arquivo (sem rede), e grava a resposta no config. Sem gh ou
# sem login não imprime nada, e sai com 0 do mesmo jeito.
gc_github_user() {
  local u gh
  u=$(gc_config_get github_user)
  if [ -z "$u" ]; then
    gh=$(gc_gh_bin)
    if [ -n "$gh" ]; then
      u=$(gc_run_with_timeout 10 "$gh" config get -h github.com user 2>/dev/null)
      [ -n "$u" ] && gc_config_set github_user "$u"
    fi
  fi
  [ -n "$u" ] && printf '%s\n' "$u"
  return 0
}
