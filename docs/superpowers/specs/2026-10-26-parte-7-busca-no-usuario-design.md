# git-commands — Parte 7: os projetos do usuário inteiro — design

**Data:** 2026-10-26 · **Dono:** Dev (GitHub: `ppdrada`) · **Base:** `git-commands` 1.1.1 e `git-commands-painel` 0.1.0. Os designs anteriores (`2026-10-25-git-commands-design.md` e `2026-10-25-parte-5-ssh-e-painel-design.md`) continuam valendo em tudo que este documento não muda.

Legenda: **[Dev]** = pedido ou decisão do Dev. **[Claude]** = escolha do Claude, que vale até o Dev mudar.

## 1. O que é e por quê

Hoje a verificação automática olha só a pasta de projetos (`projects_dir`), até 2 níveis abaixo dela. Quem guarda projetos em mais de um lugar não vê todos no painel nem nos avisos. No computador do Dev, a pasta de projetos era `Documents/git`, mas três dos projetos dele ficam direto em `Documents`, e o painel mostrava só um. A pergunta do Dev foi "o painel não deveria aparecer todos os códigos que estão no git?".

**Pedido [Dev]:**
- o git-commands procura os projetos na pasta do usuário inteira, com filtros. No Windows, essa pasta é a do usuário no disco C:, `C:\Users\<pessoa>`;
- a pasta `git` continua sendo onde nascem os projetos novos;
- outras pastas entram se a pessoa pedir, e isso fica na documentação;
- o painel mostra o caminho de cada projeto.

**Medição [Claude]:** num computador com Windows, a busca por pastas `.git` na pasta do usuário inteira, até 5 níveis, levou cerca de 1,3 s. Sem filtro, ela achou 9 repositórios:
- os 5 projetos da pessoa;
- 3 cópias de marketplaces de plugins em `~/.claude/plugins/marketplaces`, uma delas do próprio git-commands;
- 1 pasta temporária em `AppData`.

Com os filtros da seção 5.1, sobraram exatamente os 5 projetos.

**Sucesso:** a pessoa vê no painel e nos avisos ao abrir o Claude todos os projetos da conta dela que estão no computador. Ela não precisa configurar nada nem guardar tudo numa pasta só.

## 2. Objetivos

- Encontrar sozinho os projetos da conta do GitHub da pessoa em qualquer lugar da pasta do usuário.
- Continuar verificando a pasta de projetos e passar a verificar as pastas que a pessoa pedir.
- Mostrar no painel onde cada projeto está, para dar para diferenciar duas cópias do mesmo projeto.

## 3. Não-objetivos

- **Procurar sozinho fora da pasta do usuário** (outros discos, `C:\`): isso só entra se a pessoa pedir [Dev].
- **Achar sozinho os repositórios de organizações ou de outras pessoas** na busca do usuário: eles entram pela pasta de projetos ou pelas pastas pedidas [Dev: "todos os meus", os da conta].
- **Apagar ou juntar cópias repetidas:** o painel só mostra onde cada uma está.
- **Passar por cima da proteção do macOS**, que não deixa tarefas em segundo plano lerem Documentos, Mesa e Downloads.
- GitLab, Bitbucket e outros serviços.

## 4. O que seria um fracasso (anti-objetivos)

- Buscar no GitHub, a cada verificação, repositórios que não são da pessoa e que ela não pediu.
- Mostrar as cópias que o Claude guarda dos plugins, ou pastas temporárias.
- Deixar o Claude mais lento para abrir, ou a verificação presa numa pasta do usuário muito grande.
- Ler o conteúdo dos arquivos dos projetos, ou usar a rede para descobrir onde eles estão.
- Quem hoje depende só da pasta de projetos perder algum projeto.

## 5. Onde procurar

A lista de projetos é a soma de três fontes, sem repetição: a busca no usuário (5.1), a pasta de projetos (5.3) e as pastas pedidas (5.4).

### 5.1 Busca no usuário [Dev]

- **Raiz:** a pasta do usuário, e só ela [Dev]. É o `$HOME` de cada sistema:
  - no Windows, a pasta do usuário no disco C:, `C:\Users\<pessoa>`;
  - no Mac, `/Users/<pessoa>`;
  - no Linux, `/home/<pessoa>`.

  A busca nunca sobe para `C:\` nem vai para outros discos.
- **Pula:** pastas escondidas (nome começando com `.`, como `.claude`) e a `AppData` [Dev]. **[Claude]** Também pula `node_modules` e, no Mac, a `Library`.
- **[Claude] No Mac**, a busca no usuário também pula Mesa, Documentos e Downloads, em qualquer situação (verificação agendada, skill `atualizar`, ajudante `git`, `ssh status`). Entrar nelas faria o macOS perguntar "… quer acessar arquivos da pasta Documentos", até três vezes de uma vez. Um "Não permitir" tira o acesso daquele app à pasta para tudo, não só para o plugin. Projetos nessas pastas entram pela pasta de projetos ou como pasta pedida: aí foi a pessoa que escolheu, e um pedido de permissão faz sentido. O README explica isso junto do aviso do Mac que já existe.
- **Só entra repositório da conta da pessoa** [Dev]: o endereço do GitHub no `origin` tem que ser da conta dela (seção 5.2).
- **[Claude] Profundidade:** até 5 níveis abaixo da raiz. Um projeto em `~/a/b/c/d/projeto` entra; mais fundo, não. Dentro de um repositório, a busca continua descendo como a de hoje, que acha repositórios guardados dentro de outros.
- **[Claude] Limite de tempo:** a busca tem um limite, usando o `gc_run_with_timeout` que já existe; o valor exato fica para quem constrói (seção 10). Se o limite estourar, a verificação segue com o que já achou e com as outras fontes, e a busca no usuário nunca faz a verificação dar erro.
- **[Claude] Sem rede:** a busca só lista pastas e lê o `.git/config` de cada repositório.

### 5.2 A conta da pessoa [Claude]

- O login do GitHub é guardado no config numa chave nova, `github_user`. A verificação em segundo plano lê o config e nunca pergunta ao GitHub.
- **Quem preenche:** com `github_user` vazio, a própria verificação (`updates scan`) e o `doctor` leem o login que o `gh` guarda no computador, sem rede (`gh config get -h github.com user`), e gravam no config. Assim, quem atualiza de uma versão antiga ganha a busca no usuário na primeira verificação depois de atualizar, sem rodar nada. O `doctor` também confere com o `gh_user` que ele já descobre pela API quando há internet.
- **Ordem no computador do Dev:** a pasta de projetos só volta para `Documents/git` (seção 5.3) depois que o `doctor` mostrar `github_user=` preenchido. Senão, os projetos em `Documents` somem de novo.
- O dono vem do endereço do `origin`, nos formatos que o `gc_is_github_url` já reconhece: HTTPS, `git@github.com:dono/repo` e `ssh://git@ssh.github.com:443/dono/repo`. A comparação não diferencia maiúsculas.
- **Sem `github_user`** (sem login), a busca no usuário fica desligada e valem só a pasta de projetos e as pastas pedidas, como hoje.

### 5.3 A pasta de projetos [Dev]

- Continua sendo onde nascem os projetos novos (skill `novo-projeto`) e para onde vão os clones (skill `comandos`).
- Continua sempre verificada, com todos os repositórios do GitHub dentro dela, até 2 níveis, como hoje, esteja ela dentro ou fora do usuário.
- **[Claude]** A sugestão continua `~/Documents/git`, ou `~/git` no Mac. No computador do Dev, ela foi trocada para `Documents` para os projetos aparecerem antes desta parte. Depois que esta parte for publicada, ela volta para `Documents/git`, com o ok dele.

### 5.4 Pastas pedidas [Dev]

- A pessoa pode pedir para monitorar outras pastas, dentro ou fora do usuário, como `C:\git` ou `D:\projetos`. Uma pasta `git` deixada em `C:\` também precisa ser pedida [Dev].
- **[Claude]** Numa pasta pedida entram todos os repositórios do GitHub, até 2 níveis, como na pasta de projetos: a pessoa escolheu a pasta, então o filtro da conta não vale ali.
- **[Claude]** Subcomando novo, `git-commands folders add <pasta>|remove <pasta>|ignore <pasta>|unignore <pasta>|list`. As pastas pedidas ficam num arquivo próprio, `~/.git-commands/folders`, e as ignoradas (seção 5.7) em `~/.git-commands/ignored`, uma por linha, porque um caminho pode ter qualquer caractere. O `list` mostra as duas listas.
- A skill `verificacao-automatica` atende pedidos como "monitorar a pasta X" e "parar de monitorar a pasta X", e o README explica.

### 5.5 Repetidos [Claude]

- Uma mesma pasta achada por mais de uma fonte aparece uma vez só. A comparação é pelo caminho real da pasta (por exemplo, a pasta de projetos dentro do usuário).
- Duas cópias do mesmo repositório em pastas diferentes aparecem as duas. O caminho no painel mostra qual é qual.

### 5.6 Pasta que falta [Claude]

- Uma fonte que não dá para ler (pasta apagada, sem permissão, disco externo desligado como `D:\projetos`) é pulada. A verificação segue com as outras, grava o que achou e termina como "verificação ok".
- `folders list` marca a pasta como "não encontrada", e o `doctor` mostra quantas faltam. A skill `verificacao-automatica` explica o caso e oferece tirar a pasta da lista.
- Se nenhuma fonte puder ser lida (sem `github_user`, sem pasta de projetos que exista e sem pastas pedidas que existam), a verificação dá erro como hoje: `updates scan` sai com 1 e explica, e o `check.log` termina em `erro 1`. Assim o aviso do `session-start` e o estado "verificação com erro" do painel continuam valendo para uma configuração quebrada de verdade.

### 5.7 Pastas ignoradas [Dev]

- A pessoa pode pedir para ignorar uma pasta que a busca acha sozinha, como uma cópia velha ou de backup de um projeto ("site - Cópia") ou um projeto antigo esquecido em Downloads [Dev].
- **[Claude]** Ignorar vale para tudo o que está dentro daquela pasta e para as três fontes: a busca no usuário, a pasta de projetos e as pastas pedidas. Quem pediu para ignorar não quer ver aquilo em lugar nenhum. A comparação é pelo caminho real da pasta.
- **[Claude]** É feito por `git-commands folders ignore <pasta>`, e desfeito por `folders unignore <pasta>`. Uma pasta ignorada que não existe mais continua na lista sem atrapalhar nada, e `folders list` a marca como "não encontrada".
- A skill `verificacao-automatica` atende pedidos como "ignora a pasta X" e "volta a mostrar a pasta X". O README explica, junto das pastas pedidas.

## 6. Quem usa a lista [Claude]

| Parte | O que muda |
|---|---|
| `updates scan` sem `--dir` e sem `--repo` | usa a lista nova (seção 5); com `--dir`, continua olhando só aquela pasta |
| agendador, skill `atualizar` e ajudante `git` | herdam a lista pelo `updates scan` |
| `ssh status` | conta os projetos em HTTPS e em SSH na lista nova |
| `doctor` | preenche `github_user` (seção 5.2) e mostra `github_user=`, `folders=` (quantas pastas pedidas, e quantas não foram encontradas) e `ignored=` (quantas ignoradas) |
| hooks `session-start` e `pre-edit` | nada: um lê o `status.tsv`, o outro olha só o projeto atual |
| `status.tsv` | o mesmo formato: o caminho já é a primeira coluna |
| skill `verificacao-automatica` | sem pasta de projetos, a verificação funciona se houver `github_user` ou pastas pedidas |

## 7. Painel (`git-commands-painel` 0.2.0) [Dev]

- Cada projeto aparece numa linha: primeiro a pasta onde ele está, em cinza, e depois `nome (branch): estado`, na cor do estado: verde em dia, amarelo com novidades ou divergiu, vermelho erro ou ocupado. O Dev aprovou o esboço "Exemplo com novidades e erro":

  ```
  Última verificação há 5 minutos. Ela roda a cada 30 minutos.

  Documents\        site (main): com novidades (3)         ← caminho cinza, resto amarelo
  Documents\git\    api (main): erro: não deu para falar com o GitHub   ← resto vermelho
  Documents\        blog (main): em dia                   ← resto verde

  Para ver e atualizar, peça ao Claude: "tem algo novo nos meus projetos?"
  ```

- **[Claude]** O caminho é a pasta do projeto contada a partir da pasta do usuário, com o nome que a pasta tem no disco. No Windows, por exemplo, aparece `Documents`, que o Explorador mostra como "Documentos".
  - O separador é `\` quando o caminho tem letra de unidade (Windows) e `/` nos outros sistemas.
  - Um projeto fora da pasta do usuário mostra o caminho inteiro (`C:\git\`).
  - Um projeto direto na pasta do usuário aparece sem caminho na frente.
- A ordem continua a mesma: novidades primeiro, depois os outros estados e, por último, os em dia. A faixa, o aviso rápido e a linha de status não mudam.

## 8. Restrições (as mesmas das outras partes)

- bash compatível com o 3.2 do macOS: sem `case` dentro de `$(...)` e sem heredoc nos hooks. O `run-hook.cmd` continua só com ASCII.
- Windows, macOS e Linux, com testes para tudo e o CI nos três sistemas. Os testes da busca usam uma pasta de usuário de mentira (`HOME` no sandbox), com repositórios da conta, de outra conta, escondidos, em `AppData` e fundos demais.
- O painel continua só lendo: não usa a rede, não roda git e nunca atualiza nada.
- Documentação pública sem nomes pessoais ("Dev", "projeto"); commits com o e-mail privado do GitHub.
- **Nada vai para o GitHub sem o Dev mandar:** push, PR, merge e tag pedem um ok cada.

## 9. Versões e documentação

- `git-commands` 1.2.0, porque o comportamento da verificação muda; `git-commands-painel` 0.2.0.
- **README:** a seção "Verificação automática" explica:
  - onde ela procura: na pasta do usuário, dita com todas as letras (no Windows, `C:\Users\<você>`), para a pessoa saber de onde vêm os projetos [Dev];
  - os filtros;
  - como pedir e tirar pastas, e como ignorar uma pasta que a busca acha sozinha;
  - o limite de profundidade;
  - o aviso do Mac.

  A seção do painel ganha o caminho.
- **Glossário e regras:** sem conceito novo.

## 10. Fica para quem constrói

- Os textos exatos das mensagens, das skills e do README, no tom das outras partes.
- O valor do limite de tempo da busca e como cortá-la em cada sistema.
- Os nomes das funções e o formato de `folders list`.
