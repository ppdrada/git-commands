---
name: atualizar
description: Use quando a pessoa quer saber se os projetos têm novidades no GitHub, quer atualizar um projeto, ver o que mudou no GitHub ou resolver um conflito, ou quando o git-commands avisou que há novidades, com frases como "tem algo novo nos meus projetos?", "atualiza meus repositórios", "git pull", "sincronizar" ou "ver o que mudou no GitHub".
---

# Novidades do GitHub

Leia `${CLAUDE_PLUGIN_ROOT}/reference/regras.md` antes de qualquer passo. Nada é atualizado antes de a pessoa escolher.

## 1. Ver o que há de novo [conceito: fetch]

- Se a pessoa falou "deste projeto", ou se o aviso do git-commands citou um projeto: `git-commands updates scan --repo <pasta>`.
- Senão: `git-commands updates scan`, que olha todos os projetos da pasta de projetos. Se a pasta não estiver configurada, use a skill `git-commands:configurar`.
- Mostre só os projetos com estado `novidades`, `divergiu` ou `erro`. Para cada um com novidades, rode `git-commands updates detail <pasta>` e conte os commits novos (quem fez e o quê). Se nada mudou, diga isso em uma frase.

## 2. Perguntar, por projeto [conceito: pull]

"O que você quer fazer com <projeto>?", com as 3 opções numeradas:
1. atualizar agora;
2. ver a diferença antes;
3. deixar para depois.

Se algum arquivo foi mexido dos dois lados (seção "Mexidos dos dois lados" do `detail`), avise que pode dar conflito.

## 3. Ver a diferença

Resuma em português, a partir do `detail`, quais arquivos mudaram e o que mudou em cada um. Linha a linha (`git diff HEAD...@{u} -- <arquivo>`) só se a pessoa pedir. Depois volte à pergunta do passo 2.

## 4. Atualizar: `git-commands updates pull <pasta>`

| Código | O que fazer |
|---|---|
| 0 | Conte o que chegou. |
| 3 (alterações sem commit) | Explique e ofereça salvar antes com a skill `git-commands:salvar`, ou guardar com `git stash` [conceito: stash], atualizar e depois `git stash pop`. Se o `pop` der conflito, siga o passo 5. |
| 4 (divergiu) | Explique que há commits seus e do GitHub e ofereça juntar com `git pull --no-rebase` [conceito: merge]. Se der conflito, siga o passo 5. |
| 5 (sem upstream) | A branch ainda não existe no GitHub: ofereça enviar com a skill `git-commands:salvar`. |
| 6 (erro de rede) | Diga que não deu para falar com o GitHub agora e sugira tentar de novo mais tarde. |

## 5. Conflito [conceito: conflito]

1. Liste os arquivos com conflito: `git diff --name-only --diff-filter=U`.
2. Para cada um, mostre as duas versões do trecho (a da pessoa e a do GitHub), em palavras simples.
3. Pergunte o que fica: 1) a versão da pessoa, 2) a do GitHub, ou 3) juntar as duas. No caso 3, escreva o texto juntado, mostre e espere o ok.
4. Grave a escolha no arquivo, rode `git add <arquivo>` e faça o commit com a mensagem mostrada e confirmada.

Ofereça sempre a saída: `git merge --abort` volta tudo para como estava antes da atualização.

## 6. No fim

Se `git-commands config get auto_check_asked` vier vazio, pergunte se a pessoa quer que o plugin procure novidades sozinho a cada 30 minutos (skill `git-commands:verificacao-automatica`). Se ela disser não, grave `git-commands config set auto_check_asked yes`.

## Erros comuns

| Erro | Certo |
|---|---|
| Rodar `git pull` porque a pessoa perguntou se tem algo novo | Mostrar as novidades e perguntar o que fazer |
| Oferecer só "atualizar" | Dar as 3 opções: atualizar, ver a diferença ou deixar para depois |
| Usar `git pull --rebase`, `git reset --hard` ou `git checkout -- .` para destravar | Guardar as alterações, juntar com merge e resolver o conflito com a pessoa |
| Escolher sozinho a versão num conflito | Mostrar as duas versões e perguntar |
