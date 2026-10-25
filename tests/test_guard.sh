# Testes da proteção contra comandos que apagam trabalho (guard).

test_guard_tabela() {
  : > "$SANDBOX/app.js"   # "git checkout app.js" só descarta se app.js for um arquivo
  local perigosos=(
    "git push --force|força" "git push -f origin main|força" "git push --force-with-lease|força" "git push origin +main|força"
    "git push origin :feature|apaga uma branch" "git push origin --delete feature|apaga uma branch"
    "git -C ../x reset --hard HEAD~1|descarta" "cd app && git reset --hard|descarta" "git checkout -- .|descarta"
    "git checkout .|descarta" "git checkout -f main|descarta" "git restore app.js|descarta"
    "git restore --staged --worktree app.js|descarta" "git switch --discard-changes main|descarta"
    "git worktree remove --force ../wt|descarta" "Git.exe clean -fdx|não acompanha" "git rebase main|reescreve"
    "git pull --rebase|reescreve" "git filter-branch --tree-filter x|reescreve" "git stash drop|stash" "git stash clear|stash"
    "git branch -D feature|apaga uma branch" "git branch -d feature|apaga uma branch"
    "gh repo delete ppdrada/x --yes|repositório" "gh pr merge 3 --delete-branch|apaga uma branch"
    '"C:\Program Files\Git\bin\git.exe" reset --hard|descarta' "& git reset --hard|descarta"
    "git branch --merged | grep -v main | xargs git branch -d|apaga uma branch"
    "(cd app && git reset --hard)|descarta" "( git push -f )|força"
    'for b in a c; do git branch -D "$b"; done|apaga uma branch'
    "if true; then git reset --hard origin/main; fi|descarta"
    "env X=1 git push --force|força" "timeout 30 git push --force|força"
    'bash -c "git reset --hard"|descarta' "git fetch & git reset --hard|descarta"
    'Get-ChildItem | ForEach-Object { git -C $_.FullName reset --hard }|descarta'
    "git checkout app.js|descarta" "git checkout HEAD src/app.js|descarta"
    "git switch -C x|apaga uma branch" "git checkout -B x|apaga uma branch"
    "gh pr close 3 --delete-branch|apaga uma branch" "git push --prune origin|apaga uma branch"
    "git branch -M velho novo|apaga uma branch" "git rm -f app.js|descarta"
    "$(printf 'cat > notas.txt <<EOF\nIt'"'"'s fine\nEOF\ngit push --force')|força")
  local seguros=("git status" "git push" "git push -u origin feature" "git pull --ff-only" "git checkout -b nova"
    "git switch -c nova" "git checkout main" "git restore --staged app.js" 'git commit -m "reset --hard explicado"'
    "git rebase --continue" "git stash" "git stash pop" "git branch" "git branch -m velho novo" "ls -la"
    "echo git push --force" "gh pr create --title x" "gh pr merge 3 --merge"
    "git push origin main:main" 'git commit -m "a && git reset --hard"'
    "git checkout -b nova origin/nova" "git rm --cached .env" "git log --oneline | head -5")
  # Cada caso é "comando|motivo"; o comando pode ter pipes, então o motivo vem depois do último |.
  local c; for c in "${perigosos[@]}"; do local out; out=$(printf '%s' "${c%|*}" | gc guard check) || fail "devia ser perigoso: ${c%|*}"; assert_contains "$out" "${c##*|}" "${c%|*}"; done
  for c in "${seguros[@]}"; do printf '%s' "$c" | gc guard check >/dev/null && fail "devia ser seguro: $c"; done; true
}

test_guard_comando_longo_rapido() {
  local cmd i; cmd="cat > notas.md <<EOF"
  for i in $(seq 300); do cmd="$cmd"$'\n'"linha $i: o github tem length e coisas"; done
  cmd="$cmd"$'\n'"EOF"$'\n'"git push --force"
  local t0 out; t0=$(date +%s); out=$(printf '%s' "$cmd" | gc guard check)
  assert_contains "$out" "força" "acha o push forçado no fim"
  [ $(( $(date +%s) - t0 )) -le 3 ] || fail "a proteção demorou mais de 3 s"
}

test_guard_hook_pede_confirmacao() {
  local out; out=$(printf '%s' '{"tool_name":"Bash","tool_input":{"command":"git reset --hard"}}' | CLAUDE_PLUGIN_ROOT="$PLUGIN" bash "$PLUGIN/hooks/run-hook.cmd" guard)
  assert_contains "$out" '"permissionDecision":"ask"' ""; assert_contains "$out" "descarta alterações que ainda não foram salvas" ""
}

test_guard_hook_usa_a_pasta_do_comando() {
  local r; r=$(make_local_repo app); : > "$r/menu.html"
  local out; out=$(printf '{"cwd":"%s","tool_input":{"command":"git checkout menu.html"}}' "$r" | CLAUDE_PLUGIN_ROOT="$PLUGIN" bash "$PLUGIN/hooks/run-hook.cmd" guard)
  assert_contains "$out" "descarta" "menu.html é arquivo na pasta do comando"
}

test_guard_hook_silencioso_em_comando_seguro() {
  local out; out=$(printf '%s' '{"tool_input":{"command":"git status"}}' | CLAUDE_PLUGIN_ROOT="$PLUGIN" bash "$PLUGIN/hooks/run-hook.cmd" guard)
  assert_eq "0" "$?" "o hook rodou e saiu com 0"; assert_eq "" "$out" "nada impresso"
}
