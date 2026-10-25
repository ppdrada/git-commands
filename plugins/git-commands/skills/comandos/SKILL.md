---
name: comandos
description: Use quando a pessoa pergunta o que é um comando ou conceito do git, ou quer ver o estado do projeto, o histórico, o que mudou, guardar alterações por um tempo, desfazer alterações, baixar um projeto do GitHub ou ver o endereço do GitHub, com frases como "o que é <comando>?", "o que mudou?", "ver histórico", "desfazer", "guardar para depois", "baixar um projeto do GitHub" ou "git status".
---

# Outros comandos do dia a dia

Leia `${CLAUDE_PLUGIN_ROOT}/reference/regras.md` antes de qualquer passo.

| A pessoa quer | Comando | Conceito |
|---|---|---|
| Ver o estado do projeto | `git status --short`, contado em palavras simples | |
| Ver o histórico | `git log --oneline -n 10`: quem, quando e a mensagem de cada commit | [conceito: log] |
| Ver o que mudou | `git diff --stat` e um resumo em português; linha a linha (`git diff`) só se ela pedir | [conceito: diff] |
| Guardar alterações por um tempo | `git stash` para guardar, `git stash list` para ver, `git stash pop` para trazer de volta | [conceito: stash] |
| Desfazer alterações de um arquivo | `git restore <arquivo>`, só depois de explicar o que se perde e perguntar | |
| Baixar um projeto do GitHub | `gh repo clone <dono>/<nome>` dentro da pasta de projetos (`git-commands config get projects_dir`) | [conceito: clone] |
| Ver o endereço do GitHub | `git remote -v` | [conceito: remote] |

## Desfazer

Desfazer alterações que não estão em nenhum commit não tem volta. Antes de `git restore`, diga o que vai se perder e ofereça primeiro guardar uma cópia com `git stash`. Só rode depois do ok, e avise que o Claude Code também vai pedir confirmação. Apagar algo guardado (`git stash drop`) também não tem volta: pergunte antes.

## "O que é…?"

Quando a pessoa perguntar o que é um comando ou conceito, explique com o glossário (`${CLAUDE_PLUGIN_ROOT}/reference/conceitos.md`), mesmo que já tenha explicado antes. Se não estiver no glossário, explique em 1 ou 2 frases simples.
