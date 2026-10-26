---
name: chave-ssh
description: Use quando a pessoa quer usar chave SSH com o GitHub, quer deixar o computador mais seguro com SSH, ou quando um envio por SSH falhou, com frases como "configurar SSH", "chave SSH", "ssh key", "usar SSH no GitHub" ou "Permission denied (publickey)".
---

# Chave SSH do GitHub

Leia `${CLAUDE_PLUGIN_ROOT}/reference/regras.md` antes de qualquer passo. A regra 8 vale o tempo todo: a senha da chave e a parte privada nunca passam por você.

Seja honesto com a pessoa: o login que ela já tem (HTTPS, pelo `gh`) também é seguro. A chave SSH só protege mais se tiver senha, então este fluxo sempre cria a chave com senha. Tudo o que muda algo, no computador ou na conta do GitHub, espera o ok.

## 1. Ver como está [conceito: chave-ssh]

Rode `git-commands ssh status` e `git-commands doctor`.
- `chave=` com um caminho: já existe uma chave. Pergunte se usa essa. Se for uma chave antiga de outro lugar (um servidor da empresa, por exemplo) e `~/.ssh/id_ed25519` estiver livre, ofereça criar uma nova só para o GitHub (passo 2). Nunca crie uma chave por cima de outra.
- `chave=` vazio: passo 2.

## 2. A pessoa cria a chave, com senha, no terminal dela

Seu terminal não responde perguntas, e a senha não pode passar por você. Passe o comando e espere:
- **Windows:** no PowerShell (menu Iniciar → PowerShell). **Mac:** no Terminal. **Linux:** no terminal.
- Comando: `ssh-keygen -t ed25519 -C "<user_email do doctor>"`.
- Explique: Enter para o lugar padrão; a senha da chave duas vezes (não aparece nada enquanto digita, é normal); anotar a senha num lugar seguro; nunca colar a senha aqui.

Quando ela disser que terminou, `git-commands ssh status` mostra a chave. Confira que a chave tem senha, sem ver a chave: `ssh-keygen -y -P "" -f <chave> >/dev/null 2>&1`. Código 255 é o certo (tem senha). Código 0 é chave sem senha: explique o risco e ofereça refazer (apagar só com o ok, regra 4).

## 3. Guardar a senha no sistema, para digitar uma vez só

Sem isso, você não consegue enviar por SSH.
- **Mac:** rode `git-commands ssh config`; a pessoa roda no Terminal `ssh-add --apple-use-keychain ~/.ssh/<chave>` e digita a senha (ela fica no Chaveiro do Mac).
- **Windows:** a pessoa abre o PowerShell como administrador (menu Iniciar → PowerShell → botão direito → Executar como administrador) e roda `Set-Service -Name ssh-agent -StartupType Automatic` e `Start-Service ssh-agent`. Depois, num PowerShell normal, `ssh-add $env:USERPROFILE\.ssh\<chave>` e a senha. Então, com o ok, você roda `git config --global core.sshCommand "C:/Windows/System32/OpenSSH/ssh.exe"` (o ssh do Git for Windows não enxerga esse agente) e `git-commands ssh config`.
- **Linux:** rode `git-commands ssh config`; a pessoa roda no terminal dela `ssh-add ~/.ssh/<chave>` e digita a senha. Se o `ssh-add` disser que não conseguiu falar com o agente (comum no WSL e em servidores), explique as opções da distribuição (o chaveiro do ambiente gráfico; ou `eval "$(ssh-agent -s)"` e `ssh-add` em cada sessão) e não siga sem a pessoa decidir.

Confira com `git-commands ssh status`: `agente=sim`. Com `agente=nao`, a chave ainda não está no agente: peça de novo o `ssh-add` do sistema dela, no terminal dela. Se o `ssh config` responder `outro Host github.com` (código 3), a pessoa já tem uma configuração para o GitHub: mostre o bloco dela e não mexa sem o ok.

## 4. Confiar no servidor do GitHub

`git-commands ssh known-hosts`. Ele busca as chaves do servidor pela API do GitHub. Nunca aceite o servidor no escuro (`StrictHostKeyChecking=no`, `ssh-keyscan`).

## 5. Registrar a chave no GitHub (mexe na conta da pessoa)

Diga o que vai acontecer e espere o ok: `gh ssh-key add ~/.ssh/<chave>.pub --title "<nome do computador> (git-commands)"`. Se faltar permissão, peça só a necessária: rode em segundo plano `gh auth refresh -h github.com -s write:public_key`, mostre o código e o endereço https://github.com/login/device, e espere a pessoa autorizar. Se ela preferir, cola a parte pública em https://github.com/settings/ssh/new (o `.pub` pode ser mostrado).

## 6. Testar: `git-commands ssh test`

| Resposta | O que fazer |
|---|---|
| `ok <usuário>` | Confira que é o usuário da pessoa e siga. |
| `chave-recusada` | Rode `git-commands ssh status`. Com `agente=nao`, peça o `ssh-add` do passo 3 de novo, no terminal da pessoa. Com `agente=sim`, a chave não foi registrada: passo 5. |
| `servidor-desconhecido` | Rode o passo 4. |
| `sem-conexao` | Sem internet, ou a rede bloqueia a porta do SSH (comum em empresas): tente mais tarde. |

## 7. Passar para SSH (espere o ok)

- Daqui para a frente: `gh config set -h github.com git_protocol ssh`.
- Projetos que já existem: o `ssh status` mostra quantos estão em HTTPS. Ofereça trocar, um por um ou todos: `git-commands ssh remote <pasta> ssh`, e confira com `git -C <pasta> ls-remote origin HEAD`.
- Para voltar: `git-commands ssh remote <pasta> https` e `gh config set -h github.com git_protocol https`.
- A verificação automática continua buscando por HTTPS e não precisa da senha da chave.

## Erros comuns

| Erro | Certo |
|---|---|
| Gerar a chave no seu terminal, com `-N ""` ou com uma senha que a pessoa mandou | A pessoa gera no terminal dela, com senha |
| Aceitar o servidor no escuro (`StrictHostKeyChecking=no`, `ssh-keyscan`) | `git-commands ssh known-hosts` |
| Criar uma chave por cima de outra | Usar a que existe, ou criar em `~/.ssh/id_ed25519` só se estiver livre |
| Esquecer o agente e o `core.sshCommand` no Windows | Passo 3 |
| Pedir a permissão `admin:public_key` | `write:public_key` basta |
| Ler ou mostrar a chave privada | Só o `.pub` |
| `gh config set git_protocol ssh` sem `-h github.com` | Com `-h github.com`: a configuração do servidor vence a geral |
