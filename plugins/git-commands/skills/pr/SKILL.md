---
name: pr
description: Abre, mostra ou junta um pull request (PR).
disable-model-invocation: true
---

Siga a skill `git-commands:branch-e-pr`, partes "Terminar a mudança" e "Juntar o PR". Se a pessoa não disse o que quer, veja se a branch já tem um PR (`gh pr view --json state,url`): sem PR aberto, ofereça abrir um; com PR aberto, mande o link e pergunte se ela quer juntar.
