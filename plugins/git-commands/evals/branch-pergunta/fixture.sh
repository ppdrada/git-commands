#!/usr/bin/env bash
set -e
G="git -c user.name=Teste -c user.email=teste@example.com -c init.defaultBranch=main"
# "GitHub" de mentira: um repositório local escondido em .fixture, no lugar de github.com.
mkdir -p .fixture
$G init -q --bare .fixture/app.git
bare=$( (cd .fixture/app.git && pwd -W 2>/dev/null) || (cd .fixture/app.git && pwd) )
$G init -q .
echo ".fixture/" >> .git/info/exclude
git remote add origin https://github.com/teste/app.git
git config "url.$bare.insteadOf" https://github.com/teste/app.git
printf "# app\n" > README.md
git add README.md
$G commit -qm "Primeiro commit"
git push -q -u origin main
:
