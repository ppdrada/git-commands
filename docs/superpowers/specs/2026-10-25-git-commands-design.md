# git-commands — design

**Data:** 2026-10-25 · **Dono:** Dev (GitHub: `ppdrada`) · **Status:** rascunho para aprovação

Legenda: **[Dev]** = decidido pelo Dev na conversa. **[Claude]** = escolha do Claude, que o Dev pode mudar.

## 1. O que é e por quê

`git-commands` é um plugin do Claude Code que cuida de git e GitHub para quem **não sabe nada de git**. A pessoa fala do jeito dela ("quero começar um projeto", "salva meu trabalho", "manda pro GitHub", "tem algo novo nos meus projetos?") e o plugin roda os comandos git por ela, **ensinando enquanto faz**: explica cada conceito na primeira vez que ele aparece e pede confirmação antes de tudo que muda o projeto ou o GitHub.

**Por quê [Dev]:** o Dev está aprendendo git (disse que não sabe direito como branch funciona) e quer uma ferramenta que ensine fazendo, para ele e para outras pessoas no mesmo nível. O plugin substitui o `commit-commands` (que ele não vai usar) e absorve a skill `git-sync` e o agente `git` que já existem no PC dele. Ele vai ser publicado no GitHub para outras pessoas instalarem.

**Sucesso:** uma pessoa que nunca usou git consegue criar um projeto, salvar o trabalho, mandar para o GitHub, manter os projetos atualizados e abrir PRs, entendendo o que aconteceu, sem perder trabalho e sem ser incomodada com explicações repetidas.

## 2. Para quem

- Quem nunca usou git: não sabe o que é repositório, commit, branch, push, PR. [Dev]
- O público principal fala português do Brasil. Os textos do plugin são em pt-BR; o plugin responde no idioma em que a pessoa escrever. [Claude]

## 3. Regras de comportamento (valem para o plugin todo)

### 3.1 Explica na primeira vez, depois não repete [Dev]

- Na primeira vez que um conceito aparece, o plugin explica em 1 ou 2 frases simples **antes** de fazer. Exemplo do Dev: "git init é criar ou inicializar um novo repositório Git em um diretório do seu computador."
- Depois de explicado, não explica de novo, nem em outra conversa, nem em outro projeto. Exemplo: no segundo repositório criado, só cria.
- Se a pessoa perguntar o que é um comando ou conceito, explica de novo, a qualquer momento. [Dev]
- O que já foi explicado fica gravado num arquivo de progresso da pessoa, que sobrevive a atualizações e reinstalações do plugin. [Claude]
- Lista inicial de conceitos [Claude]: repositório (`git init`), `git config`, commit, `add` (preparar arquivos), README, `.gitignore`, remote, push, pull, fetch, branch, merge, conflito, pull request, clone, stash, histórico (`log`), diferença (`diff`), repositório público × privado.

### 3.2 Confirma sempre [Dev]

A explicação some com o tempo; a confirmação nunca some.

- **Commit:** sempre mostra a mensagem sugerida e pergunta se a pessoa quer mudar. Só faz o commit depois do ok.
- **Tudo o que o plugin escreve** (README, `.gitignore`, descrição de PR) aparece antes, para a pessoa aprovar ou mudar.
- **Tudo o que mexe no GitHub** (criar repositório, push, abrir ou juntar PR): mostra o que vai fazer e pede ok.
- **PR:** sempre manda o link do PR.

### 3.3 Nunca perde trabalho

- Nunca descarta alterações da pessoa sem perguntar. [Dev]
- **Comando que pode apagar trabalho sempre para e pede o ok da pessoa, não importa quem rodou** (o próprio plugin, o Claude ou outra ferramenta). [Dev: Caminho A] Isso é garantido de forma mecânica (um hook que força a confirmação do Claude Code), e não só por instrução. Entram nessa regra, no mínimo: `push --force` (e variações), `reset --hard`, `clean`, `rebase`, `checkout`/`restore` que descarta alterações, `stash drop`/`stash clear`, apagar branch (local ou no GitHub) e apagar repositório. [Claude: a lista]
- Atualizações (pull) nunca reescrevem o histórico. [Claude]
- Avisa antes de mandar para o GitHub qualquer arquivo com cara de senha ou chave (`.env`, chaves, credenciais). [Claude]

### 3.4 Linguagem [Claude]

Português simples, sem jargão sem explicação. O comando git aparece junto da explicação, para a pessoa ir aprendendo o nome, mas o foco é o que acontece.

### 3.5 Onde e quando o plugin age

- **Proativo, sem a pessoa precisar pedir.** Quando o Claude é aberto dentro de um repositório ligado ao GitHub, o plugin já entra em ação: verifica atualizações antes de mexer no código, pergunta sobre branch quando uma mudança nova começa e oferece commit e PR quando a mudança termina. [Dev: "antes da pessoa começar a usar o código sempre verificar se está atualizado"; "sempre perguntar se a pessoa quer criar" a branch]
- **Só em código ligado ao GitHub.** [Dev: o agente "precisa trabalhar somente nos códigos que estão conectados no GitHub"] Fora de um repositório do GitHub, o plugin fica quieto e só age quando a pessoa pede algo de git (por exemplo, começar um projeto). A exceção é o aviso de novidades da seção 4.4, que aparece ao abrir o Claude em qualquer lugar, só quando há novidade.
- Vale em qualquer repositório ligado ao GitHub, não só nos que estão na pasta de projetos (inclusive repositórios de trabalho). A pessoa pode desligar o modo proativo num projeto ou em todos, pedindo ao plugin. [Claude]
- Isso pede contexto inserido na abertura do Claude e uma checagem antes da primeira edição de código na sessão, as duas rápidas (ver seção 5). [Claude]

### 3.6 Quando outra ferramenta usa git [Dev: Caminho A]

- As regras de conversa do plugin (mostrar a mensagem do commit e pedir ok, perguntar sobre branch, mandar o link do PR) valem quando o plugin está conversando com a pessoa: nos fluxos dele e no trabalho normal do Claude na conversa principal.
- Outras ferramentas e automações seguem trabalhando sem interrupção. Exemplo: o superpowers executa planos com ajudantes que fazem um commit depois de cada tarefa; o git-commands não pede confirmação para esses commits.
- A única regra que vale para todo mundo é a da seção 3.3: comando que pode apagar trabalho sempre para e pede o ok da pessoa, venha de onde vier.

## 4. Partes do plugin

### 4.1 Começar um projeto [Dev aprovou o fluxo]

Quando a pessoa diz que quer começar um projeto. O plugin **assume que nada existe ainda** (nem git na pasta, nem repositório no GitHub), mesmo que algumas pessoas já tenham criado. [Dev]

1. **Checagem inicial:** git instalado? GitHub CLI (`gh`) instalado? Tem conta no GitHub? Está logado? O que faltar, o plugin explica e guia com o comando certo para o sistema. Criar a conta e fazer login é a própria pessoa quem faz; o plugin diz onde clicar.
2. **git config:** se nome e e-mail não estiverem configurados, pergunta e configura. Sugere o e-mail privado do GitHub (noreply), para não expor o e-mail pessoal. [Claude: a sugestão do noreply]
3. **Nome do repositório:** pergunta. Pergunta também se vai ser público ou privado, explicando a diferença. [Claude: público/privado]
   - **Claude como colaborador** [Dev]: no começo, pergunta se a pessoa quer que o Claude apareça como colaborador (co-autor) dos commits feitos com a ajuda dele. Se sim, os commits levam a linha `Co-Authored-By: Claude <noreply@anthropic.com>`, que o GitHub mostra como colaborador. A resposta vale para aquele projeto e fica guardada na configuração local do git dele (`git-commands.coauthor`), que não vai para o GitHub. [Claude: onde guardar]
4. **Pasta:** pergunta se já existe uma pasta com o código. Se não existir, cria uma nova dentro da pasta de projetos (ver 4.5).
5. **git init**, com a explicação de primeiro contato. Branch principal: `main`. [Claude: `main`]
6. **README:** pergunta do que se trata o projeto, escreve um rascunho, mostra e só cria depois do ok.
7. **.gitignore:** cria a lista de arquivos a ignorar adequada ao tipo de projeto e mostra antes. [Claude]
8. **Primeiro commit:** mostra a mensagem e espera o ok.
9. **Criar no GitHub e enviar (push):** mostra o que vai fazer, pede ok, cria o repositório, envia e manda o link do repositório.

**Se já existir um repositório com esse nome no GitHub:** avisa e pergunta se é para usar o que já existe ou escolher outro nome. [Dev]

### 4.2 Dia a dia [Dev]

- **Sem roteiro fixo:** a pessoa pede com as palavras dela; o plugin traduz para git. Se ela perguntar o que é um comando, o plugin explica. Comandos que precisam estar cobertos [Claude]: status, add, commit, push, pull, fetch, log, diff, branch, switch, merge, clone, stash, restore, remote e PR (abrir, ver, juntar).
- **Antes de mexer no código de um projeto:** verifica se está atualizado. Se tiver novidade, pergunta se quer atualizar, ver a diferença ou deixar para depois (mesmo fluxo da seção 4.3).
- **Ao começar uma mudança nova:** sempre pergunta se a pessoa quer criar uma branch (na primeira vez, explica o que é). Se criar, quando ela terminar o plugin oferece abrir o PR e manda o link. Se não criar, trabalha direto na `main`.
- **Juntar o PR** [Claude]: a pessoa pode juntar pelo site do GitHub ou pedir ao plugin (com confirmação). Depois de juntado, o plugin volta para a `main`, atualiza e oferece apagar a branch que já foi juntada (explicando na primeira vez).
- **Todo commit:** mensagem sugerida e pergunta se quer mudar (seção 3.2). Se o projeto tiver o Claude como colaborador, a linha de co-autor já aparece na mensagem mostrada. Num projeto que não começou pelo plugin, a pergunta sobre o Claude como colaborador é feita uma vez, no primeiro commit. [Claude]

### 4.3 Verificar atualizações (evolução da skill git-sync) [Dev]

- Olha todos os repositórios da pessoa que têm remote no GitHub (dentro da pasta de projetos) e busca novidades (fetch).
- Mostra só os que têm novidade: quantos commits novos, de quem e a mensagem de cada um.
- Para cada um, pergunta: **atualizar agora**, **ver a diferença antes** ou **deixar para depois**. **Nunca atualiza sozinho.**
- **Ver a diferença:** primeiro um resumo em português simples (quais arquivos mudaram e o que mudou em cada um). O código linha a linha só se a pessoa pedir.
- **Alterações ainda sem commit:** oferece guardá-las antes de atualizar, para não perder nada.
- **Conflitos:** se a pessoa mexeu nos mesmos arquivos, o plugin para e explica o que aconteceu (na primeira vez, explica o que é conflito). Depois mostra as duas versões (a dela e a do GitHub) e pergunta qual manter ou se é para juntar as duas.
- **Branch que divergiu** (commits novos dos dois lados): explica e pergunta o que fazer. Nunca resolve sozinho.

### 4.4 Verificação automática a cada 30 minutos [Dev]

- O plugin **pergunta** se a pessoa quer que ele verifique sozinho a cada 30 minutos. [Dev] Quando perguntar: na primeira vez que a pessoa usar a verificação de atualizações ou criar o primeiro projeto. [Claude]
- Se ela quiser, o plugin cria o agendamento do jeito de cada sistema [Dev: depende do sistema]: **Windows**, Agendador de Tarefas; **macOS**, launchd (LaunchAgent do usuário); **Linux**, cron do usuário [Claude: launchd e cron]. Sem precisar de administrador/root.
- O agendamento **só verifica** (fetch) e grava o resultado num arquivo. **Nunca faz pull.**
- No Windows, roda escondido, sem janela piscando.
- Quando a pessoa abre o Claude, o plugin lê esse resultado e, **só se houver novidade**, avisa ("o projeto tem 3 novidades, quer ver?") e segue o fluxo da seção 4.3.
- A pessoa pode pedir para desligar, religar ou mudar o intervalo. [Claude]

### 4.5 Pasta de projetos [Claude]

- É onde a verificação procura repositórios e onde o plugin cria projetos novos.
- Na primeira vez, o plugin pergunta qual é (sugerindo uma pasta padrão do sistema) e lembra a resposta. No PC do Dev: `C:\Users\<usuário>\Documents\git`.
- Repositórios sem remote no GitHub são ignorados.

### 4.6 Agente `git` [Dev]

O agente `git`, que já existe no PC do Dev, vem para dentro do plugin. Papel [Claude]: fazer a verificação de atualizações em segundo plano e devolver um resumo curto, usando um modelo barato. Ele não edita arquivos e não faz commit nem push.

## 5. Restrições técnicas [Claude, salvo indicação]

- **Plugin do Claude Code**, instalado no escopo do usuário.
- **Funciona em Windows, macOS e Linux.** [Dev] Os scripts são em **bash**, que já vem no Mac e no Linux e vem junto com o Git for Windows (Git Bash). Nenhuma dependência além de git, gh e bash (sem Python ou Node obrigatórios).
- **GitHub pelo GitHub CLI (`gh`):** criar repositório, abrir e juntar PR, pegar links, checar login.
- Arquivos de estado (progresso das explicações, resultado da verificação, pasta de projetos, preferências) ficam no diretório de dados persistentes do plugin (`${CLAUDE_PLUGIN_DATA}`, confirmar na documentação do Claude Code), nunca dentro dos repositórios da pessoa.
- O aviso ao abrir o Claude não pode atrasar a abertura de forma perceptível e não aparece quando não há novidade.

## 6. Repositório e instalação

- Repositório **público** no GitHub: `ppdrada/git-commands`. [Dev: o nome; Claude: público, necessário para outras pessoas instalarem]
- O repositório é também o "marketplace" do plugin, para instalar com dois comandos:

  ```
  claude plugin marketplace add ppdrada/git-commands
  claude plugin install git-commands@git-commands
  ```

- README em pt-BR com: o que o plugin faz, como instalar (passo a passo para iniciante), como ligar e desligar a verificação automática e como desinstalar.
- Licença MIT. [Claude]

## 7. Migração no PC do Dev [Claude]

Hoje existem, fora do plugin:

- a skill pessoal `~/.claude/skills/git-sync` (script PowerShell que **puxa sozinho**);
- o agente pessoal `~/.claude/agents/git.md`;
- a tarefa agendada `git-sync` do Windows, a cada 30 minutos, que **faz pull automático**.

Depois que o plugin estiver instalado e testado no PC do Dev: perguntar ao Dev e então remover a skill e o agente pessoais (para não ficarem duplicados) e trocar a tarefa atual pela do plugin, que só verifica.

## 8. Testes e publicação

- Construir e testar no PC do Dev: Windows 11, git 2.55, Git Bash e winget disponíveis; `gh` **ainda não instalado**; `git config` já preenchido (nome `ppdrada`).
- Instalar o plugin a partir da pasta local para testar antes de publicar.
- Testar macOS e Linux com GitHub Actions (máquinas macOS, Ubuntu e Windows do próprio GitHub), cobrindo pelo menos a verificação de atualizações e a criação e remoção do agendamento.
- Publicar **por partes** [Dev], usando o próprio plugin para criar o repositório e subir os arquivos. Esse é o primeiro teste real do fluxo "começar um projeto". [Claude: usar o próprio plugin]

## 9. Fora do escopo

- Recursos avançados: rebase interativo, cherry-pick, submodules, tags e releases, GitHub Actions da pessoa, issues, revisão de código em PRs.
- GitLab, Bitbucket e outros: só GitHub.
- Interface gráfica: tudo acontece na conversa com o Claude.

## 10. O que seria fracasso (mesmo funcionando)

- Perder trabalho da pessoa ou reescrever o histórico dela.
- Fazer qualquer coisa no GitHub sem a pessoa confirmar.
- Atualizar repositórios sozinho em segundo plano.
- Repetir a mesma explicação toda vez (chato) ou nunca explicar (a pessoa fica perdida).
- Jargão sem explicação.
- Mandar senha ou chave para o GitHub.
- Avisar alguma coisa na abertura do Claude quando não há nada novo.

## 11. Deixado para quem for construir

Estrutura interna (quantas skills, nomes, comandos com `/`, hooks), formato dos arquivos de estado, como detectar a "primeira vez", texto exato das explicações, como esconder a janela no Windows, modelos de `.gitignore`, como o resultado da verificação chega ao Claude na abertura e a forma dos testes.
