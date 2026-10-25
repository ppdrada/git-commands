# git-commands — Partes 5 e 6: chaves SSH e painel — design

**Data:** 2026-10-25 · **Dono:** Dev (GitHub: `ppdrada`) · **Base:** versão 1.0.0 e o design original (`2026-10-25-git-commands-design.md`), que continua valendo em tudo que este documento não muda.

Legenda: **[Dev]** = pedido ou decisão do Dev. **[Claude]** = escolha do Claude. O Dev pediu para seguir com as escolhas do Claude ("pode ser com as suas"), então todas as **[Claude]** valem até o Dev mudar alguma.

## 1. O que é e por quê

Três pedidos chegaram depois da 1.0.0:

- **Chaves SSH [Dev]:** "configurar uma máquina como segura, como as SSH keys do GitHub". Hoje o plugin só usa HTTPS, com o login do `gh` pelo navegador.
- **Um ícone do git-commands no Claude [Dev]:** algo parecido com o ícone de PR que o app do Claude mostra, para ver o estado dos projetos sem perguntar.
- **Os pontos menores da revisão final da 1.0.0 (M1–M22) [Claude]:** escolher quais entram agora.

**Sucesso:** a pessoa termina com uma chave SSH protegida por senha, registrada no GitHub e funcionando, sem nunca colar senha ou chave no chat, e sem quebrar nada do que já funcionava (verificação automática, checagem antes de editar, PRs). Com o painel instalado, ela vê de relance quantos projetos têm novidades.

## 2. Entrega em duas partes [Claude]

| Parte | O que entra | Versão |
|---|---|---|
| 5 | chaves SSH e os pontos menores, no plugin `git-commands` | `git-commands` 1.1.0 |
| 6 | o painel, como um plugin separado e opcional, `git-commands-painel`, no mesmo marketplace | `git-commands-painel` 0.1.0 |

**Por quê:** são tecnologias diferentes (o plugin é bash; o painel é um "mod" do Claude Code, em TypeScript) e não dependem uma da outra. Duas partes deixam cada PR menor e fácil de revisar. A Parte 6 começa depois que a Parte 5 for publicada.

## 3. Chaves SSH (Parte 5)

### 3.1 Objetivos

- Guiar a pessoa, passo a passo e com confirmação, a: criar uma chave SSH com senha, guardar a senha num lugar seguro do sistema para não digitar sempre, registrar a chave no GitHub, testar, e passar os projetos para SSH.
- Explicar o conceito na primeira vez (glossário, `chave-ssh`).
- Dar um caminho de volta para HTTPS a qualquer momento.

### 3.2 Não-objetivos

- **SSH não vira o padrão [Claude].** Para quem está começando, o HTTPS com o login do `gh` continua o caminho padrão: é seguro (o acesso fica no cofre do sistema) e tem menos passos. O SSH é oferecido quando a pessoa pede, e o `configurar` menciona que existe.
- **Assinar commits com a chave (selo "Verified") fica para depois [Claude].** Com chave protegida por senha, cada commit precisa do agente de chaves; se o agente falhar, o commit falha, e isso travaria a pessoa no meio do trabalho.
- Outros serviços além do GitHub (GitLab, Bitbucket).
- Gerenciar várias chaves por pessoa ou por projeto.

### 3.3 O que seria um fracasso (anti-objetivos)

- **Sobrescrever uma chave que já existe:** a pessoa perderia o acesso a outros lugares que usam essa chave.
- **A senha da chave ou a parte privada passarem pelo chat**, por um comando do Claude ou por um log.
- **A verificação automática ou a checagem antes de editar pararem de funcionar** para quem passar a usar SSH.
- **Um envio (push) falhar sem explicação** porque a senha da chave não pôde ser pedida.

### 3.4 Segurança da chave [Claude]

- **Tipo:** ed25519, no lugar padrão (`~/.ssh/id_ed25519`), com o e-mail do git no comentário.
- **Com senha (passphrase), sempre.** É a parte que protege a chave se alguém copiar o arquivo.
- **Quem cria a chave é a pessoa, no terminal dela.** O Claude mostra o comando exato (`ssh-keygen -t ed25519 -C "<e-mail>"`) e espera. Assim, a senha é digitada só ali, nunca no chat e nunca num comando que o Claude roda. É o mesmo princípio do login do GitHub.
- **A parte privada nunca é lida, mostrada nem enviada.** A parte pública (`.pub`) pode ser mostrada: ela é feita para ser compartilhada.
- **Se já existir uma chave**, o plugin oferece usar essa, e nunca cria outra por cima. A proteção (guard) passa a pedir confirmação para um `ssh-keygen` que escreveria num arquivo de chave que já existe.

### 3.5 Guardar a senha da chave, por sistema [Claude]

Para o Claude conseguir enviar por SSH (o terminal dele não consegue perguntar a senha), a chave precisa estar destravada num "agente de chaves". Cada sistema tem o seu:

- **macOS:** o Keychain. O plugin escreve no `~/.ssh/config` um bloco `Host github.com` com `AddKeysToAgent yes`, `UseKeychain yes` e `IdentityFile ~/.ssh/id_ed25519`; a pessoa roda `ssh-add --apple-use-keychain ~/.ssh/id_ed25519` uma vez e digita a senha.
- **Windows:** o serviço "OpenSSH Authentication Agent" do próprio Windows. Ele vem desligado, e ligar exige um PowerShell como administrador: a pessoa roda `Get-Service ssh-agent | Set-Service -StartupType Automatic; Start-Service ssh-agent`, depois `ssh-add $env:USERPROFILE\.ssh\id_ed25519`. Com o ok, o plugin configura `git config --global core.sshCommand "C:/Windows/System32/OpenSSH/ssh.exe"`, para o git usar esse agente (o ssh que vem com o Git for Windows não usa).
- **Linux:** o bloco `Host github.com` com `AddKeysToAgent yes` (sem `UseKeychain`, que só o macOS entende). Se não houver agente (`ssh-add -l` diz que não conseguiu falar com ele, comum no WSL e em servidores), o plugin explica as opções da distribuição e não segue sem a pessoa decidir.

O bloco do `~/.ssh/config` é marcado com comentários do git-commands, é escrito uma vez só, e nunca mexe num `Host github.com` que a pessoa já tenha.

### 3.6 Confiar no servidor do GitHub [Claude]

Na primeira conexão, o SSH pergunta "Are you sure you want to continue connecting?". O Claude não consegue responder essa pergunta, e aceitar no escuro é exatamente o que um ataque explora. O plugin busca as chaves do servidor do GitHub pela API do próprio GitHub (`gh api meta`, por HTTPS e com login) e as grava no `~/.ssh/known_hosts`, se ainda não estiverem lá.

### 3.7 Registrar a chave no GitHub [Claude]

- `gh ssh-key add ~/.ssh/id_ed25519.pub --title "<nome do computador> (git-commands)"`.
- Isso pede a permissão `admin:public_key` no login do `gh`: o plugin pede com `gh auth refresh -h github.com -s admin:public_key` e mostra o código, e a pessoa autoriza no navegador, como na permissão `workflow` da 1.0.0.
- Se a pessoa preferir, ela cola a parte pública em https://github.com/settings/ssh/new.

### 3.8 Testar e trocar os projetos [Claude]

- **Teste:** `ssh -T git@github.com` em modo sem perguntas (BatchMode). O GitHub responde "Hi <usuário>! You've successfully authenticated". O plugin traduz cada falha para a pessoa: chave fora do agente, chave não registrada, servidor não confiável, sem rede.
- **Daqui para a frente:** `gh config set -h github.com git_protocol ssh`, para repositórios novos e clones já virem em SSH.
- **Projetos que já existem:** o plugin lista os projetos da pasta de projetos que usam HTTPS e oferece trocar o `origin` para SSH, um por um ou todos de uma vez, com o ok. Volta: o mesmo comando com `https`.

### 3.9 Segundo plano continua sem senha [Claude]

A verificação automática e a checagem antes de editar continuam buscando novidades por **HTTPS**, mesmo nos projetos com `origin` em SSH. Para isso, quando o `origin` é um endereço SSH do GitHub, o fetch usa o endereço HTTPS equivalente, com o login do `gh` que já existe. Assim, elas nunca precisam da senha da chave, nunca perguntam nada e funcionam no agendador de qualquer sistema. Os envios da pessoa (push) usam SSH normalmente.

### 3.10 Peças novas

- `lib/ssh.sh` e o subcomando `git-commands ssh`: `status` (chave, agente, protocolo do `gh`, projetos em HTTPS e em SSH), `test`, `known-hosts`, `config` e `remote <repositório> ssh|https`.
- O `doctor` ganha `ssh_key=` (o caminho do `.pub`, ou vazio) e `git_protocol=` (`https` ou `ssh`), sem rede.
- Skill nova, `chave-ssh` ("quero usar chave SSH", "configurar SSH no GitHub"). O `configurar` menciona que ela existe.
- Glossário: `chave-ssh`, totalizando 20 conceitos.
- Regras (`regras.md`): nunca pedir, ver ou digitar a senha da chave; nunca ler nem mostrar a parte privada.
- Proteção (guard): pede confirmação para `gh ssh-key delete` (apaga uma chave no GitHub) e para `ssh-keygen` que escreveria por cima de um arquivo de chave existente.
- README: uma seção "Chaves SSH (opcional)".

## 4. Pontos menores da revisão da 1.0.0 (Parte 5) [Claude]

Entram os que uma pessoa usando o plugin sentiria, mais os baratos:

| Ponto | O que muda |
|---|---|
| M1 | o limite de tempo devolve sempre 124 quando estoura (o teste deixa de falhar às vezes) |
| M2 | `updates pull` junta com `git merge --ff-only @{u}` depois do fetch com limite, sem uma segunda ida à rede |
| M4 | os `git status` em segundo plano não pegam o `index.lock` (`GIT_OPTIONAL_LOCKS=0`) |
| M5 | o `run-hook.cmd` também acha o Git Bash por `CLAUDE_CODE_GIT_BASH_PATH` e pelo `git` no PATH (Scoop, instalação portátil) |
| M6 | apóstrofo no caminho da pasta do usuário não quebra o agendamento no Windows |
| M7 | `schedule disable` só diz "desligado" se a remoção deu certo |
| M8 | no Linux, intervalos que não dividem 60 viram o divisor de 60 mais próximo |
| M9 | o teste do agendador de verdade usa nomes de teste, nunca os da tarefa real |
| M10 | as novidades não se repetem quando a conversa é retomada ou resumida |
| M11 | a skill `atualizar` mostra os projetos parados no meio de um merge ou rebase |
| M12 | conflito ao devolver um stash tem caminho próprio, e o stash é apagado só depois de resolvido |
| M13 | HEAD destacado tem mensagem própria, e a skill não oferece envio nesse caso |
| M14 | `git rebase --abort` não pede confirmação (só volta ao estado de antes) |
| M15 | sem internet, o doctor diz `gh_auth=sem-rede` em vez de `no` |
| M16 | o comando de avaliação do README usa uma pasta de estado separada; o caso `novo-projeto` ganha o `case.yaml` |
| M20 | `gitlab.com/github.com` deixa de contar como GitHub; o `learned` compara texto exato; o teste do glossário confere "exatamente"; a cópia do app fica atômica |
| M21 | numa branch nova, o `secrets --push` olha só os commits que ainda não estão em nenhum remoto |
| M22 | se um envio falhar por falta da permissão `workflow`, o Claude explica e oferece `gh auth refresh -s workflow` |

Ficam de fora: **M17**, já resolvido pelo README da 1.0.0; **M18**, que só pede registrar que o `updates detail` usa a rede (a skill `atualizar` pede isso de propósito); e **M19** (varredura de muitos projetos passar de 2 minutos), raro para quem está começando, e que precisa de um desenho próprio.

## 5. Painel (Parte 6)

### 5.1 O que é [Dev pediu o ícone; formato do Claude]

Um plugin separado e opcional, `git-commands-painel`, no mesmo marketplace. Ele é um "mod" do Claude Code, uma extensão da interface. Quem não instala não perde nada, e o `git-commands` não depende dele.

### 5.2 O que mostra [Claude]

- **Na linha de status:** "git-commands: 2 com novidades", "git-commands: em dia" ou "git-commands: verificação parada".
- **Uma faixa acima da caixa de mensagem**, só quando há novidades: "Novidades no GitHub: site (3), api (1)", com os botões "Ver agora" (manda "tem algo novo nos meus projetos?", que aciona a skill `atualizar`) e "Depois" (esconde até a lista mudar).
- **Um aviso rápido** quando uma verificação nova encontra novidades.
- **Um painel ao lado da conversa**, aberto pelo comando `/painel`, com todos os projetos da pasta e o estado de cada um: em dia, com novidades, divergiu, sem upstream, ocupado ou erro.

### 5.3 Regras [Claude]

- **Só lê.** Lê os arquivos que a verificação automática já grava (`~/.git-commands/status.tsv`, `status.time` e `check.log`). Não usa a rede, não roda git e nunca atualiza nada: atualizar continua sendo pela skill `atualizar`, com o ok da pessoa.
- **Atualiza a tela** ao abrir a sessão, ao fim de cada resposta e a cada minuto.
- Funciona no app do Claude, no terminal e no VS Code. Num Claude Code sem suporte a mods, simplesmente não aparece.
- Os textos seguem o plugin principal: português simples.

## 6. Restrições (as mesmas da 1.0.0)

- bash compatível com o 3.2 do macOS: sem `case` dentro de `$(...)` e sem heredoc nos hooks. O `run-hook.cmd` continua só com ASCII.
- Windows, macOS e Linux, com testes para tudo e o CI nos três sistemas.
- Documentação pública sem nomes pessoais ("Dev", "projeto"); commits com o e-mail privado do GitHub.
- **Nada vai para o GitHub sem o Dev mandar:** branch, PR, junção e marca de versão, cada um com o ok dele.

## 7. Fica para quem constrói

- Os textos exatos das mensagens e da skill `chave-ssh`, no tom das outras skills.
- Como o `ssh status` descobre o agente em cada sistema (por exemplo, `ssh-add -l` do mesmo OpenSSH que o git usa).
- Os detalhes de desenho do painel (cores, ordem e espaçamento), dentro do que o mod permite.
