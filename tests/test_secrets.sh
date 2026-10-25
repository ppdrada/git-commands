# Testes do subcomando secrets (arquivos com cara de senha ou chave).

test_secrets_env() { local r; r=$(make_local_repo s); echo "SENHA=1" > "$r/.env"; local out; out=$(gc secrets "$r"); assert_eq "3" "$?" ""; assert_contains "$out" ".env	arquivo .env (senhas e chaves)" ""; }

test_secrets_env_example_ok() { local r; r=$(make_local_repo s); echo "SENHA=" > "$r/.env.example"; assert_exit 0 gc secrets "$r"; }

test_secrets_token_no_conteudo() { local r; r=$(make_local_repo s); echo "t='ghp_$(printf 'a%.0s' $(seq 36))'" > "$r/config.js"; assert_contains "$(gc secrets "$r")" "config.js	parece um token do GitHub" ""; }

test_secrets_staged_so_preparados() { local r; r=$(make_local_repo s); echo x > "$r/.env"; echo y > "$r/ok.txt"; git -C "$r" add ok.txt; assert_exit 0 gc secrets --staged "$r"; }

test_secrets_repo_limpo() { local r; r=$(make_local_repo s); assert_exit 0 gc secrets "$r"; }

test_secrets_tabela() {
  local r; r=$(make_local_repo s)
  mkdir -p "$r/chaves"
  echo x > "$r/chaves/id_rsa"
  printf -- '-----BEGIN RSA PRIVATE KEY-----\nabc\n' > "$r/notas.txt"
  echo x > "$r/service-credentials.json"
  echo "k=AKIA$(printf 'A%.0s' $(seq 16))" > "$r/aws.cfg"
  local out; out=$(gc secrets "$r")
  assert_contains "$out" "chaves/id_rsa	chave privada" "nome de chave"
  assert_contains "$out" "notas.txt	chave privada" "conteúdo de chave"
  assert_contains "$out" "service-credentials.json	arquivo de credenciais" ""
  assert_contains "$out" "aws.cfg	parece uma chave de API" ""
}

test_secrets_ignorado_nao_conta() { local r; r=$(make_local_repo s); echo ".env" > "$r/.gitignore"; echo x > "$r/.env"; assert_exit 0 gc secrets "$r"; }

test_secrets_env_ja_preparado_conta() { local r; r=$(make_local_repo s); echo x > "$r/.env"; git -C "$r" add .env; assert_contains "$(gc secrets "$r")" ".env	arquivo .env" "sem --staged também olha o que já foi preparado"; }
