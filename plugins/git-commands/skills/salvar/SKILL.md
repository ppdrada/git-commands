---
name: salvar
description: Use quando a pessoa quer salvar o trabalho num commit ou mandar as alterações para o GitHub, com frases como "salva meu trabalho", "faz um commit", "commita", "manda pro GitHub", "envia as alterações" ou "dar push".
---

# Salvar e enviar

Leia `${CLAUDE_PLUGIN_ROOT}/reference/regras.md` antes de qualquer passo.

Mesmo que a pessoa peça "salva e manda", nada é salvo nem enviado antes de ela ver os arquivos e a mensagem e dar o ok.

## Passos

1. **Ver o que mudou.** `git status --short`. Conte em palavras simples quais arquivos mudaram, quais são novos e quais foram apagados.
2. **Senhas e chaves.** Rode `git-commands secrets`. Para cada arquivo listado, diga o motivo, pergunte se é para enviar mesmo e ofereça colocá-lo no `.gitignore` (se ele já estiver no git, também `git rm --cached <arquivo>`). O que a pessoa não confirmar fica fora do commit.
3. **Claude como colaborador.** Rode `git config --get git-commands.coauthor`. Se vier vazio, pergunte uma vez se a pessoa quer o Claude como colaborador do projeto (os commits feitos com a ajuda dele levam a linha `Co-Authored-By: Claude <noreply@anthropic.com>`, e o GitHub mostra o Claude como colaborador) e grave a resposta: `git config git-commands.coauthor true` (ou `false`).
4. **Mensagem.** Escreva em português, no imperativo, com até 72 caracteres, dizendo o que mudou (por exemplo, "Adiciona a página de contato"). Se o colaborador for `true`, mostre a mensagem já com a linha `Co-Authored-By: Claude <noreply@anthropic.com>` no fim.
5. **Confirmar, numa mensagem só:** os arquivos que entram, a mensagem e, se a pessoa pediu para enviar, que depois vai para o GitHub. Pergunte "Quer mudar alguma coisa nessa mensagem?" [conceito: add] [conceito: commit]. Se ela mudar a mensagem, use a dela.
6. **Salvar**, só depois do ok: `git add <arquivos>` e `git commit -m "<mensagem>"` (a linha do co-autor vai num segundo `-m`).
7. **Enviar** [conceito: push], se a pessoa pediu ou aceitou. Antes, rode `git-commands secrets --push`, que olha tudo o que vai para o GitHub (inclusive commits feitos antes), e pergunte sobre cada arquivo listado. Depois: `git push`; se a branch ainda não existir no GitHub, `git push -u origin <branch>`. Se o GitHub recusar porque tem novidades lá, explique e use a skill `git-commands:atualizar`. Nunca force o envio.
8. **PR.** Se existir um PR aberto para a branch (`gh pr view --json url --jq .url`), mande o link.

## Erros comuns

| Erro | Certo |
|---|---|
| Fazer commit e push direto porque a pessoa pediu "salva e manda" | Mostrar arquivos e mensagem e esperar o ok |
| Mandar `.env` ou chave para o GitHub | Rodar `git-commands secrets` e perguntar |
| Usar `git add .` sem dizer o que entra | Listar os arquivos que entram no commit |
| Push recusado e `git push --force` | Explicar e atualizar com a skill `git-commands:atualizar` |
| Decidir sozinho sobre o Claude como colaborador | Perguntar uma vez e guardar a resposta no projeto |
