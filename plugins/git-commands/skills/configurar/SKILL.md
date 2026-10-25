---
name: configurar
description: Use quando a pessoa quer preparar o computador para git e GitHub, quando falta algo para usar o git-commands (git ou GitHub CLI não instalados, sem login no GitHub, sem nome e e-mail no git, sem pasta de projetos) ou quando ela quer ligar ou desligar o git-commands num projeto, com frases como "configurar git", "instalar git", "fazer login no GitHub", "mudar minha pasta de projetos" ou "desligar o git-commands neste projeto".
---

# Preparar o computador

Leia `${CLAUDE_PLUGIN_ROOT}/reference/regras.md` antes de qualquer passo.

Rode `git-commands doctor` e resolva só o que faltar, nesta ordem. Antes de instalar qualquer coisa, mostre o comando e de onde vem o programa, e espere o ok.

## 1. git (`git_ok=no`)

Comando conforme o `os` do doctor:
- windows: `winget install --id Git.Git -e --source winget`
- mac: `xcode-select --install`
- linux: `sudo apt install git` (Ubuntu/Debian), `sudo dnf install git` (Fedora) ou `sudo pacman -S git` (Arch)

Depois, peça para a pessoa fechar e abrir o Claude de novo, para o git aparecer.

## 2. GitHub CLI (`gh=` vazio)

- windows: `winget install --id GitHub.cli -e --source winget`
- mac: `brew install gh` (sem Homebrew: https://cli.github.com)
- linux: siga https://github.com/cli/cli/blob/trunk/docs/install_linux.md

Se `gh_on_path=no` mas `gh_path` tem um caminho, o gh já está instalado e só não aparece nesta sessão: peça para reabrir o Claude.

## 3. Conta e login (`gh_auth=no`): quem faz é a pessoa

- Sem conta: mande para https://github.com/signup e espere ela criar.
- Login: o `gh auth login` precisa de uma janela de terminal de verdade, então quem roda é a pessoa. Passe exatamente:
  1. Abrir um terminal (no Windows, o PowerShell ou o painel Terminal do app do Claude).
  2. Rodar `gh auth login`.
  3. Escolher GitHub.com → HTTPS → "Yes" para autenticar o git → "Login with a web browser".
  4. Copiar o código que aparecer, apertar Enter, colar o código na página do GitHub e autorizar.
- Quando ela disser que terminou: confira com `gh auth status` e rode `gh auth setup-git`.
- Nunca peça senha, token ou código para colar no chat.

## 4. Nome e e-mail do git (`user_name` ou `user_email` vazio) [conceito: git-config]

Pergunte o nome e o e-mail. Ofereça o e-mail privado do GitHub, para o e-mail pessoal não aparecer nos commits públicos: `gh api user --jq '"\(.id)+\(.login)@users.noreply.github.com"'`. Depois do ok:

```
git config --global user.name "<nome>"
git config --global user.email "<e-mail>"
```

## 5. Pasta de projetos (`projects_dir` vazio)

Pergunte onde a pessoa quer guardar os projetos. Sugira `~/Documents/git` se `~/Documents` existir, senão `~/git`. Crie a pasta e grave: `git-commands config set projects_dir "<pasta>"`.

## Ligar e desligar o git-commands

- Só neste projeto: `git-commands proactive off` ou `git-commands proactive on`.
- Em todos: `git-commands proactive off --all` ou `git-commands proactive on --all`.

Explique que, desligado, o plugin só age quando a pessoa pede.

## Erros comuns

| Erro | Certo |
|---|---|
| Rodar `gh auth login` pelo Claude | Ele precisa de terminal de verdade: a pessoa roda e o Claude guia |
| Pedir senha, token ou código no chat | O login acontece só no navegador, no site do GitHub |
| Dizer que o gh não está instalado logo depois do winget | Se há `gh_path`, pedir para reabrir o Claude |
| Inventar nome ou e-mail | Perguntar, oferecendo o e-mail privado do GitHub |
| Esquecer a pasta de projetos | Perguntar quando `projects_dir` estiver vazio |
