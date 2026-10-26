# Testes do subcomando updates (verificar novidades e atualizar com segurança).

linha() { gc updates scan --dir "$SANDBOX/projetos" | grep "	$1	"; }

test_scan_estados_basicos() {
  make_github_pair emdia >/dev/null
  local a; a=$(make_github_pair atras); push_remote_commit atras n1.txt "um"; push_remote_commit atras n2.txt "dois"
  local f; f=$(make_github_pair frente); echo x > "$f/x.txt"; git -C "$f" add x.txt; git -C "$f" commit -qm local
  local d; d=$(make_github_pair diverge); push_remote_commit diverge r.txt "remoto"; echo y > "$d/y.txt"; git -C "$d" add y.txt; git -C "$d" commit -qm local
  make_local_repo semremote >/dev/null
  assert_contains "$(linha emdia)" "	0	0	0	em-dia" ""; assert_contains "$(linha atras)" "	0	2	0	novidades" ""
  assert_contains "$(linha frente)" "	1	0	0	a-frente" ""; assert_contains "$(linha diverge)" "	1	1	0	divergiu" ""
  assert_eq "" "$(linha semremote)" "repositório fora do GitHub é ignorado"
}

test_scan_estados_estranhos() {
  local h; h=$(make_github_pair destacado); git -C "$h" checkout -q --detach
  local o; o=$(make_github_pair ocupado); : > "$o/$(git -C "$o" rev-parse --git-path MERGE_HEAD)"
  mkdir -p "$SANDBOX/projetos/vazio" && git -C "$SANDBOX/projetos/vazio" init -q && git -C "$SANDBOX/projetos/vazio" remote add origin https://github.com/teste/vazio.git
  local w; w=$(make_github_pair comwt); git -C "$w" worktree add -q "$w/wt" -b wt
  local out; out=$(gc updates scan --no-fetch --dir "$SANDBOX/projetos")   # sem rede: "vazio" não tem remote local
  assert_eq "1" "$(printf '%s\n' "$out" | grep -c '	destacado	.*	destacado$')" "HEAD destacado"
  assert_eq "1" "$(printf '%s\n' "$out" | grep -c '	ocupado	.*	ocupado$')" "merge em andamento"
  assert_eq "1" "$(printf '%s\n' "$out" | grep -c '	vazio	.*	sem-commits$')" "sem commits"
  assert_eq "1" "$(printf '%s\n' "$out" | grep -c comwt)" "worktree não aparece duas vezes"
}

test_scan_remote_inacessivel_vira_erro() { local r; r=$(make_github_pair caiu); rm -rf "$SANDBOX/remotes/caiu.git"; assert_contains "$(linha caiu)" "erro" ""; }

test_scan_sem_pasta_configurada() {
  local err; err=$(gc updates scan 2>&1); assert_eq "1" "$?" ""
  assert_contains "$err" "pasta de projetos" "explica o que falta"
}

test_scan_pasta_sem_permissao_vira_erro() {
  [ "$(gc os)" = windows ] && skip "no Windows o chmod não tira a leitura"
  [ "$(id -u)" = 0 ] && skip "o root lê qualquer pasta"
  make_github_pair app >/dev/null; chmod 000 "$SANDBOX/projetos"
  local err; err=$(gc updates scan --dir "$SANDBOX/projetos" 2>&1); local rc=$?
  chmod 755 "$SANDBOX/projetos"
  assert_eq "1" "$rc" "não pode dizer que deu certo"; assert_contains "$err" "sem permissão" ""
}

test_save_e_news() {
  gc config set projects_dir "$SANDBOX/projetos"; local a; a=$(make_github_pair atras); push_remote_commit atras n.txt "um"
  gc updates scan --save >/dev/null; assert_contains "$(gc updates news)" "atras	1	" ""
  gc updates pull "$a" >/dev/null; assert_exit 1 gc updates news
}

test_pull_seguro() {
  local a; a=$(make_github_pair a); push_remote_commit a novo.txt "um"
  echo solto > "$a/solto.txt"; assert_contains "$(gc updates pull "$a")" "atualizado: +1" "arquivo solto não atrapalha"
  push_remote_commit a README.md "remoto mexe no README"; echo "meu" >> "$a/README.md"
  gc updates pull "$a" >/dev/null; assert_eq "3" "$?" "alteração sem commit"; assert_contains "$(cat "$a/README.md")" "meu" "nada perdido"
}

test_pull_divergiu_e_sem_upstream() {
  local d; d=$(make_github_pair d); push_remote_commit d r.txt "r"; echo y > "$d/y.txt"; git -C "$d" add y.txt; git -C "$d" commit -qm l
  gc updates pull "$d" >/dev/null; assert_eq "4" "$?" ""
  git -C "$d" switch -qc sozinha; gc updates pull "$d" >/dev/null; assert_eq "5" "$?" ""
}

test_detail_secoes() {
  local a; a=$(make_github_pair a); push_remote_commit a README.md "Muda o README"; echo "meu" >> "$a/README.md"
  local out; out=$(gc updates detail "$a")
  assert_contains "$out" "== Novidades no GitHub (1 commits)" ""; assert_contains "$out" "Muda o README" ""
  assert_contains "$out" "== Mexidos dos dois lados (podem dar conflito)" ""; assert_contains "$out" "README.md" ""
}

test_scan_nao_mexe_no_index() {
  local a; a=$(make_github_pair app); touch -t 202001010000 "$a/README.md"
  local antes; antes=$(cksum < "$a/.git/index")
  gc updates scan --no-fetch --dir "$SANDBOX/projetos" >/dev/null
  assert_eq "$antes" "$(cksum < "$a/.git/index")" "a varredura reescreveu o index (pode pegar o index.lock da pessoa)"
}
