---
name: novo-projeto
description: Use quando a pessoa quer começar um projeto novo com git ou colocar uma pasta no GitHub pela primeira vez, com frases como "quero começar um projeto", "criar um repositório", "subir meu projeto pro GitHub" ou "iniciar git aqui".
---

# Começar um projeto

Leia `${CLAUDE_PLUGIN_ROOT}/reference/regras.md` antes de qualquer passo.

Este fluxo leva o projeto do zero até o GitHub, e a pessoa confirma cada passo que cria ou envia algo. Trate como se nada existisse ainda (nem git na pasta, nem repositório no GitHub). Se algo já existir, diga isso e siga para o próximo passo.

Pressa não pula passo: com pressa, fale menos, mas faça as mesmas perguntas e confirmações.

## Passos

1. **Conferir o computador.** Rode `git-commands doctor`. Se faltar git, gh, login ou nome e e-mail, use a skill `git-commands:configurar` antes de continuar.
2. **Perguntar, numa mensagem só, antes de criar qualquer coisa:**
   - o nome do repositório, sem espaços nem acentos (sugira um a partir do que a pessoa contou);
   - se vai ser público ou privado [conceito: publico-privado];
   - se o código já está numa pasta. Se não estiver, a pasta será `<pasta de projetos>/<nome>` (`git-commands config get projects_dir`; se vier vazio, a skill `git-commands:configurar` pergunta);
   - se a pessoa quer o Claude como colaborador do projeto: os commits feitos com a ajuda dele levam a linha `Co-Authored-By: Claude <noreply@anthropic.com>`, e o GitHub mostra o Claude como colaborador.
3. **Repositório local** [conceito: repositorio]: `git init -b main` na pasta. Se `git rev-parse --is-inside-work-tree` já funcionar ali, diga que a pasta já é um repositório e pule. Depois grave a resposta sobre o Claude no projeto: `git config git-commands.coauthor true` (ou `false`).
4. **README** [conceito: readme]: pergunte em uma frase do que se trata o projeto, escreva um rascunho curto, mostre e só crie depois do ok. Se já existir, mostre e pergunte se quer mudar.
5. **.gitignore** [conceito: gitignore]: escolha o modelo em `${CLAUDE_PLUGIN_ROOT}/reference/gitignore/` (`package.json` → `node.gitignore`; `pyproject.toml` ou `requirements.txt` → `python.gitignore`; senão `geral.gitignore`). Mostre e crie depois do ok. Depois rode `git-commands secrets` (regra 4).
6. **Primeiro commit** [conceito: add] [conceito: commit]: `git add .` e a mensagem sugerida, mostrada e confirmada. Se `git config --get git-commands.coauthor` for `true`, a mensagem mostrada termina com a linha `Co-Authored-By: Claude <noreply@anthropic.com>`.
7. **Criar no GitHub e enviar.** Diga o que vai acontecer e espere o ok:
   - Dono: `gh api user --jq .login`.
   - Se `gh repo view <dono>/<nome>` funcionar, o repositório já existe: pergunte se usa esse ou escolhe outro nome. Para usar, `git remote add origin <url>`; se ele já tiver commits, `git pull origin main --allow-unrelated-histories --no-rebase` e resolva conflitos como na skill `git-commands:atualizar` [conceito: conflito].
   - Se não existir: `gh repo create <nome> --public` (ou `--private`) `--source . --remote origin` [conceito: remote].
   - Antes de enviar, rode `git-commands secrets --push` e pergunte sobre cada arquivo listado (regra 4).
   - `git push -u origin main` [conceito: push].
   - Mande o link: `gh repo view --json url --jq .url`.
8. **Verificação automática.** Se `git-commands config get auto_check_asked` vier vazio, pergunte se a pessoa quer que o plugin procure novidades sozinho a cada 30 minutos (skill `git-commands:verificacao-automatica`).

## Erros comuns

| Erro | Certo |
|---|---|
| Criar pasta ou rodar `git init` antes de saber o nome | Perguntar nome, visibilidade e pasta primeiro |
| Tratar o GitHub como opcional e não perguntar se é público ou privado | O fluxo vai até o GitHub; a visibilidade é perguntada junto com o nome |
| Rodar `git init` sem explicar, na primeira vez | Explicar com o glossário e registrar com `git-commands learned add repositorio` |
| Pular uma confirmação porque a pessoa está com pressa | Encurtar o texto, nunca a confirmação |
| Decidir sozinho se o Claude aparece como colaborador | Perguntar no começo e guardar a resposta no projeto |
