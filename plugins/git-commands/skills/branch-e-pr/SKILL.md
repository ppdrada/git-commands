---
name: branch-e-pr
description: Use quando a pessoa vai começar uma mudança nova num projeto do GitHub, quer criar uma branch, abrir, ver ou juntar um pull request (PR), fazer merge, ou terminou uma mudança que está numa branch, com frases como "vou mexer em…", "criar uma branch", "abrir um PR", "pull request", "juntar o PR", "merge" ou "terminei".
---

# Branches e pull requests

Leia `${CLAUDE_PLUGIN_ROOT}/reference/regras.md` antes de qualquer passo.

## Começar uma mudança

1. Antes de rodar qualquer comando, pergunte: "Quer criar uma branch para isso?" Na primeira vez, explique o que é uma branch [conceito: branch]. Sugira um nome curto, sem espaços nem acentos, a partir da mudança (por exemplo, `pagina-de-login`).
2. Só depois do sim:
   - Confira se a `main` tem novidades no GitHub (`git fetch` e `git status -sb`). Se tiver, pergunte se a pessoa quer atualizar antes (skill `git-commands:atualizar`; se ela não estiver instalada, `git pull --ff-only` depois do ok). Nunca atualize sem perguntar.
   - `git switch -c <nome>`.
3. Se a resposta for não, siga na `main`.

## Terminar a mudança (numa branch)

1. Salve e envie com a skill `git-commands:salvar`.
2. Escreva o título e a descrição do PR em português simples (o que mudou e por quê, em poucas linhas), mostre e espere o ok [conceito: pull-request].
3. `gh pr create --base main --head <branch> --title "<título>" --body "<descrição>"`.
4. Mande o link: `gh pr view --json url --jq .url`.

## Juntar o PR

- A pessoa pode juntar pelo site do GitHub (botão "Merge pull request") ou pedir aqui.
- Pedindo aqui: diga o que vai acontecer, espere o ok e rode `gh pr merge <número> --merge` [conceito: merge]. Mande o link do PR.
- Depois: `git switch main` e `git pull --ff-only`, para a `main` do computador ficar igual à do GitHub.
- Ofereça apagar a branch que já foi juntada: `git branch -d <branch>` e `git push origin --delete <branch>`. Avise que o Claude Code vai pedir confirmação.

Toda vez que citar um PR, mande o link.

## Erros comuns

| Erro | Certo |
|---|---|
| Criar a branch antes de perguntar | Perguntar primeiro; criar só depois do sim |
| Atualizar a `main` sem perguntar (`git pull` automático) | Conferir as novidades e perguntar |
| Abrir o PR sem mostrar o título e a descrição | Mostrar e esperar o ok |
| Falar do PR sem o link | Mandar o link sempre |
| Apagar a branch junto com o merge (`--delete-branch`) | Juntar primeiro e depois oferecer apagar, com confirmação |
