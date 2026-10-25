<div align="center">

# Git Commands

**Git e GitHub para quem está começando, dentro do Claude Code.**

O Claude faz os comandos por você, explica cada conceito na primeira vez e pede a sua confirmação antes de tudo o que importa.

[![Testes](https://github.com/ppdrada/git-commands/actions/workflows/test.yml/badge.svg)](https://github.com/ppdrada/git-commands/actions/workflows/test.yml)
![Windows, macOS e Linux](https://img.shields.io/badge/Windows%20%7C%20macOS%20%7C%20Linux-suportados-2ea44f)
![Plugin do Claude Code](https://img.shields.io/badge/Claude%20Code-plugin-D97757)
[![Licença MIT](https://img.shields.io/badge/licen%C3%A7a-MIT-blue)](LICENSE)

</div>

---

## Sumário

- [O que ele faz](#o-que-ele-faz)
- [Requisitos](#requisitos)
- [Instalação](#instalação)
- [Primeiros passos](#primeiros-passos)
- [Configuração](#configuração)
- [Comandos do git-commands](#comandos-do-git-commands)
- [Segurança](#segurança)
- [Solução de problemas](#solução-de-problemas)
- [Atualizar e desinstalar](#atualizar-e-desinstalar)
- [Para quem quer contribuir](#para-quem-quer-contribuir)

## O que ele faz

- **Começa um projeto do zero até o GitHub**: repositório, README, `.gitignore`, primeiro commit e envio, um passo de cada vez.
- **Salva e envia o seu trabalho** (commit e push), sempre mostrando a mensagem do commit antes e perguntando se você quer mudar.
- **Cria branches e pull requests**, explicando o que são, e sempre manda o link do PR.
- **Avisa quando os seus projetos têm novidades no GitHub** e pergunta antes de atualizar. Se der conflito, resolve junto com você.
- **Ensina enquanto faz**: cada conceito é explicado uma vez só, na primeira vez que aparece. Depois disso, ele não repete, a não ser que você pergunte.
- **Protege o seu trabalho**: comandos que podem apagar alguma coisa sempre pedem confirmação, e arquivos com cara de senha ou chave são barrados antes de ir para o GitHub.
- **Verificação automática (opcional)**: procura novidades de tempos em tempos, mesmo com o Claude fechado, usando o agendador do próprio sistema.

## Requisitos

| O que | Para quê | Se não tiver |
|---|---|---|
| [Claude Code](https://code.claude.com/docs/en/setup) | onde o plugin roda | instale antes de tudo |
| git 2.28 ou mais novo | os comandos de git | o plugin mostra como instalar |
| GitHub CLI (`gh`) | criar repositórios, PRs e fazer login | o plugin mostra como instalar e guia o login |
| Conta no GitHub | onde os projetos ficam | o plugin manda para o cadastro |
| Git for Windows (só no Windows) | o Git Bash, que roda os hooks | o próprio Claude Code já pede |

## Instalação

**1. Adicione o marketplace e instale o plugin**, no terminal:

```bash
claude plugin marketplace add ppdrada/git-commands
claude plugin install git-commands@git-commands
```

Se preferir, faça o mesmo dentro do Claude Code:

```text
/plugin marketplace add ppdrada/git-commands
/plugin install git-commands@git-commands
```

No Claude Code 2.1.275 ou mais novo, também dá para instalar num passo só: `/plugin install git-commands --marketplace ppdrada/git-commands`.

**2. Feche e abra o Claude Code de novo**, para ele carregar o plugin.

**3. Confira se está ligado:**

```bash
claude plugin list
```

```text
❯ git-commands@git-commands
  Version: 1.0.0
  Status: ✔ enabled
```

**4. Prepare o computador.** Na primeira vez, diga ao Claude:

> configura o git e o GitHub no meu computador

Ele confere o que falta e resolve uma coisa de cada vez, sempre mostrando o comando e esperando o seu ok: instala o git e o `gh`, guia o login no GitHub pelo navegador, configura o seu nome e e-mail (sugerindo o e-mail privado do GitHub, para o seu e-mail pessoal não aparecer nos commits) e pergunta em que pasta ficam os seus projetos.

## Primeiros passos

Fale com o Claude do seu jeito. Ele reconhece o que você quer e usa a skill certa:

| Você diz | O que acontece | Skill |
|---|---|---|
| "configura o git e o GitHub no meu PC" | instala o que falta e guia o login | `configurar` |
| "quero começar um projeto" | cria o repositório e coloca no GitHub | `novo-projeto` |
| "salva meu trabalho e manda pro GitHub" | commit e push, mostrando a mensagem antes | `salvar` |
| "vou começar a mexer na página de login" | pergunta se você quer uma branch e, no fim, abre o PR | `branch-e-pr` |
| "tem algo novo nos meus projetos?" | mostra as novidades e pergunta o que fazer | `atualizar` |
| "verifica meus projetos a cada 30 minutos" | liga a verificação automática | `verificacao-automatica` |
| "o que é um commit?" | explica, mesmo que já tenha explicado antes | `comandos` |

Também dá para chamar uma skill direto: `/git-commands:novo-projeto`, `/git-commands:salvar` e assim por diante.

### Exemplo: do zero ao GitHub

> **Você:** quero colocar meu site no GitHub
>
> **Claude:** Antes de criar qualquer coisa, me responda:
> 1. Qual o nome do repositório? Sugiro `meu-site`.
> 2. Público ou privado?
> 3. O código já está numa pasta?
> 4. Quer o Claude como colaborador? Os commits feitos com a ajuda dele levam a linha `Co-Authored-By: Claude`, e o GitHub mostra o Claude como colaborador.
>
> **Você:** 1. meu-site 2. público 3. está em ~/git/meu-site 4. sim
>
> **Claude:** `git init` é criar ou inicializar um novo repositório Git em um diretório do seu computador. Vou rodar na pasta `~/git/meu-site`. [...] Este é o README que eu sugiro: [...] Posso criar?

Depois vêm o `.gitignore`, a mensagem do primeiro commit ("Quer mudar alguma coisa nessa mensagem?") e o envio para o GitHub. Cada passo espera o seu ok, e no fim o Claude manda o link do repositório.

## Configuração

O jeito mais simples de configurar é pedir ao Claude ("muda minha pasta de projetos para ~/git"). Se preferir, os comandos abaixo rodam no terminal do Claude Code.

### Onde ficam as configurações

Tudo fica na pasta `~/.git-commands/`. Para usar outra, defina a variável `GIT_COMMANDS_HOME`.

| Arquivo | O que guarda |
|---|---|
| `config` | as opções da tabela abaixo |
| `learned` | os conceitos que o Claude já explicou para você |
| `proactive-off` | os projetos em que você desligou o modo automático |
| `status.tsv`, `status.time` e `check.log` | o resultado da verificação automática |

### Opções

| Chave | Padrão | Para que serve |
|---|---|---|
| `projects_dir` | (vazio) | a pasta dos seus projetos; a verificação automática olha aqui |
| `auto_check` | `off` | se a verificação automática está ligada (use `schedule enable` e `disable`) |
| `interval` | `30` | minutos entre as verificações, de 5 a 1440 |
| `proactive` | `on` | o modo automático em todos os projetos (regras ao abrir o Claude e checagem antes de editar) |
| `auto_check_asked` | (vazio) | se o plugin já perguntou sobre a verificação automática |

```bash
git-commands config list                    # mostra todas as opções
git-commands config set projects_dir ~/git  # muda a pasta de projetos
git-commands config get interval            # mostra uma opção
```

### Verificação automática

```bash
git-commands schedule enable 30   # liga, a cada 30 minutos
git-commands schedule status      # mostra "ligado 30" ou "desligado"
git-commands schedule disable     # desliga
```

| Sistema | Onde fica o agendamento |
|---|---|
| Windows | Agendador de Tarefas, tarefa `git-commands-verificar` |
| macOS | `~/Library/LaunchAgents/com.git-commands.verificar.plist` (launchd) |
| Linux | uma linha no seu `crontab`, marcada com `# git-commands` |

A verificação só lê (`git fetch`), nunca muda os seus arquivos e nunca abre janela de senha. Quando você abre o Claude, ele conta quais projetos têm novidades e avisa se a verificação deu erro ou parou de rodar.

> **No macOS**, guarde os projetos fora de Documentos, Mesa e Downloads (por exemplo, em `~/git`): o sistema não deixa tarefas em segundo plano lerem essas pastas.

### Modo automático por projeto

Num projeto do GitHub, o plugin entra em ação sozinho: traz as regras dele quando o Claude abre e, antes da primeira edição de cada sessão, confere se há novidades no GitHub.

```bash
git-commands proactive off         # desliga só no projeto atual
git-commands proactive on          # liga de novo
git-commands proactive off --all   # desliga em todos os projetos
git-commands proactive status      # mostra como está
```

Desligado, o plugin só age quando você pede.

### Conceitos já explicados

```bash
git-commands learned list            # o que o Claude já explicou para você
git-commands learned forget commit   # faz o Claude explicar "commit" de novo
git-commands learned reset           # recomeça do zero
```

### Claude como colaborador

O `novo-projeto` pergunta isso no começo e guarda a resposta no próprio projeto. Para mudar depois:

```bash
git config git-commands.coauthor true    # os commits levam Co-Authored-By: Claude
git config git-commands.coauthor false   # não levam
```

## Comandos do git-commands

As skills usam o executável `git-commands`, que o Claude Code coloca no terminal dele. Normalmente é o Claude quem roda esses comandos por você.

| Comando | O que faz |
|---|---|
| `git-commands doctor` | diz o que falta no computador (git, `gh`, login, nome e e-mail, pasta de projetos) |
| `git-commands config get\|set\|list` | lê e muda as opções |
| `git-commands schedule enable [minutos]\|disable\|status` | liga, desliga e mostra a verificação automática |
| `git-commands proactive on\|off [--all]\|status` | liga e desliga o modo automático |
| `git-commands learned list\|has\|add\|forget\|reset` | os conceitos já explicados |
| `git-commands updates scan\|news\|detail\|pull` | procura novidades, mostra as diferenças e atualiza com segurança |
| `git-commands secrets [--staged\|--push]` | procura arquivos com cara de senha ou chave |

Exemplo de `git-commands doctor`:

```text
os=windows
git=2.47.0.windows.1
git_ok=yes
gh=2.60.0
gh_path=/c/Program Files/GitHub CLI/gh.exe
gh_on_path=yes
gh_auth=yes
gh_user=seu-usuario
user_name=Seu Nome
user_email=12345678+seu-usuario@users.noreply.github.com
projects_dir=C:/Users/voce/git
auto_check=on
interval=30
proactive=on
```

## Segurança

- **Confirmação antes do que importa.** Mensagem de commit, README, `.gitignore`, título e descrição de PR, envio para o GitHub e junção de PR: o Claude mostra antes e espera o seu ok.
- **Comandos que podem apagar trabalho sempre pedem confirmação**, venham de onde vierem, inclusive de ajudantes e automações: forçar o envio, descartar alterações, apagar arquivos que o git não acompanha, reescrever o histórico, apagar branch, stash ou o repositório no GitHub.
- **Senhas e chaves não vão para o GitHub sem você saber.** Antes do commit e antes do envio, o plugin procura arquivos `.env`, chaves privadas, tokens do GitHub e chaves de API, inclusive em commits que ainda não foram enviados, e pergunta o que fazer.
- **O login é seu.** Ele acontece no navegador, no site do GitHub, e o `gh` guarda o acesso no cofre do próprio sistema (Gerenciador de Credenciais no Windows, Chaves no macOS). Nunca cole senhas, tokens ou códigos no chat.
- **E-mail privado.** Na configuração, o plugin sugere o e-mail privado do GitHub (`…@users.noreply.github.com`), para o seu e-mail pessoal não aparecer nos commits públicos.

## Solução de problemas

<details>
<summary><b>"gh: command not found" logo depois de instalar o GitHub CLI</b></summary>

O terminal foi aberto antes da instalação e ainda não enxerga o `gh`. O plugin percebe isso sozinho e usa o caminho completo do `gh` até o fim da sessão. Na próxima vez que abrir o terminal, o nome curto volta a funcionar.
</details>

<details>
<summary><b>"refusing to allow an OAuth App to create or update workflow ... without `workflow` scope"</b></summary>

Acontece ao enviar arquivos de `.github/workflows/` (GitHub Actions): o login do `gh` precisa de uma permissão a mais. Rode o comando abaixo e autorize no navegador; depois envie de novo.

```bash
gh auth refresh -h github.com -s workflow
```
</details>

<details>
<summary><b>O Claude avisa que a verificação automática deu erro ou parou</b></summary>

Peça "confere a verificação automática". Os casos mais comuns:

- **macOS, "sem permissão para ler a pasta de projetos":** a pasta está em Documentos, Mesa ou Downloads. Mova os projetos para `~/git` e rode `git-commands config set projects_dir ~/git`.
- **Agendamento desligado ou parado:** `git-commands schedule enable 30` recria o agendamento.
- **Linux (WSL), mesmo ligado:** o serviço do cron pode estar desligado. Rode `sudo service cron start`.
</details>

<details>
<summary><b>Os hooks não rodam no Windows</b></summary>

Os hooks usam o Git Bash do Git for Windows, instalado no lugar padrão (`C:\Program Files\Git`). Sem ele, o plugin continua funcionando quando você pede, mas sem as checagens automáticas.
</details>

<details>
<summary><b>O plugin está perguntando demais num projeto</b></summary>

Desligue o modo automático só nele: `git-commands proactive off`. As skills continuam funcionando quando você pede.
</details>

## Atualizar e desinstalar

**Atualizar** para a versão mais nova, e depois reabrir o Claude Code:

```bash
claude plugin marketplace update git-commands
claude plugin update git-commands@git-commands
```

**Desinstalar:**

1. Se a verificação automática estiver ligada, desligue antes: peça "desliga a verificação automática" ou rode `git-commands schedule disable`.
2. Remova o plugin:

   ```bash
   claude plugin uninstall git-commands@git-commands
   ```

3. Se quiser começar do zero numa próxima instalação, apague a pasta `~/.git-commands`.

Se você já desinstalou com a verificação ligada, remova o agendamento à mão:

| Sistema | Comando |
|---|---|
| Windows (PowerShell) | `Unregister-ScheduledTask -TaskName git-commands-verificar -Confirm:$false` |
| macOS | `launchctl bootout gui/$(id -u)/com.git-commands.verificar && rm ~/Library/LaunchAgents/com.git-commands.verificar.plist` |
| Linux | `crontab -l \| grep -v '# git-commands' \| crontab -` |

## Para quem quer contribuir

```text
.claude-plugin/marketplace.json  o marketplace (aponta para plugins/git-commands)
plugins/git-commands/
  .claude-plugin/plugin.json     nome, versão e descrição do plugin
  skills/                        configurar, novo-projeto, salvar, branch-e-pr, atualizar,
                                 comandos e verificacao-automatica
  agents/git.md                  ajudante que resume as novidades dos repositórios (só lê)
  hooks/                         session-start, guard e pre-edit (pelo run-hook.cmd)
  bin/git-commands               o executável que as skills usam
  lib/                           o código, em bash compatível com o 3.2 do macOS
  scheduler/                     o que o agendador do sistema roda
  reference/                     regras, glossário de conceitos e modelos de .gitignore
  evals/                         avaliações de comportamento das skills
tests/                           os testes
docs/superpowers/                o design e o plano de construção
```

- **Testes:** `bash tests/run.sh`, ou `bash tests/run.sh <parte do nome>` para rodar só alguns.
- **CI:** a cada envio, os testes rodam no GitHub em Windows, macOS (com o bash 3.2) e Linux, criando e removendo o agendamento de verdade nos três.
- **Validação:** `claude plugin validate plugins/git-commands --strict`.
- **Avaliações de comportamento** (o Claude pergunta antes de agir?): `claude plugin eval plugins/git-commands --scaffold --ablation none --allow-tools Bash Read`. Rodam no macOS e no Linux; no Windows, o Claude Code recusa, porque não consegue isolar os comandos do terminal.

## Licença

[MIT](LICENSE)
