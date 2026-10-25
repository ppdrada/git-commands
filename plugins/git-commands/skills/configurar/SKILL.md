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

Depois de instalar, rode o `git-commands doctor` de novo. Se `gh_on_path=no` mas `gh_path` tem um caminho, o gh já está instalado e só não aparece pelo nome nesta sessão. Não peça para reabrir o Claude: até o fim da sessão, use o caminho completo (`"<gh_path>"` no lugar de `gh`).

## 3. Conta e login (`gh_auth=no`): quem faz é a pessoa

- Sem conta: mande para https://github.com/signup e espere ela criar.
- Login (quem autoriza é a pessoa, no navegador):
  1. Ofereça começar o login daqui. Com o ok, rode em segundo plano `gh auth login --web --hostname github.com --git-protocol https` e leia a saída: ela mostra um código de 8 caracteres (o gh também copia o código para a área de transferência) e o endereço https://github.com/login/device.
  2. Mostre o código e o endereço, e peça para a pessoa abrir o endereço, colar o código, clicar em "Continue" e depois em "Authorize".
  3. Quando o login terminar, confira com `gh auth status` e rode `gh auth setup-git`.
- Se ela preferir fazer sozinha: abrir o PowerShell pelo menu Iniciar (uma janela nova já enxerga o gh recém-instalado), rodar `gh auth login` e escolher GitHub.com → HTTPS → "Yes" → "Login with a web browser". O código aparece nessa janela.
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
| Mandar a pessoa achar o código do login sozinha | Começar o login daqui e mostrar o código e o endereço |
| Pedir senha, token ou código no chat | O login acontece só no navegador, no site do GitHub |
| Pedir para reabrir o Claude logo depois do winget | Usar o caminho completo do gh (`gh_path`) até o fim da sessão |
| Inventar nome ou e-mail | Perguntar, oferecendo o e-mail privado do GitHub |
| Esquecer a pasta de projetos | Perguntar quando `projects_dir` estiver vazio |
