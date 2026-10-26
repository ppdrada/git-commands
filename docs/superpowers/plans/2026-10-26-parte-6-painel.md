# git-commands — Parte 6: o painel — Plano de construção

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** criar o `git-commands-painel` 0.1.0, um mod opcional do Claude Code que mostra, sem perguntar nada, o estado dos projetos que a verificação automática do `git-commands` já gravou: linha de status, faixa acima da caixa de mensagem, aviso rápido e um painel aberto por `/painel`.

**Architecture:** um plugin separado em `plugins/git-commands-painel/`, com um módulo de hooks em TypeScript. A lógica fica em funções puras (`hooks/resumo.ts` lê os arquivos e monta o resumo; `hooks/textos.ts` tem todos os textos), testadas sem o Claude. O `hooks/register.tsx` só lê os arquivos por `$.fs.read`, guarda o resumo em `$.state` e desenha a partir dele; a faixa e o painel se redesenham sozinhos quando o resumo muda.

**Tech Stack:** mod do Claude Code (hooks de função, TypeScript/TSX, `claude plugin validate` e `claude plugin test` com o kit `claude-code/testing`), GitHub Actions. A Tarefa 7, se o Dev aprovar, mexe em bash no `git-commands`.

**Spec:** `docs/superpowers/specs/2026-10-25-parte-5-ssh-e-painel-design.md`, seção 5 (e as restrições da seção 6). O design original (`2026-10-25-git-commands-design.md`) continua valendo.

## Global Constraints

- **Só lê.** O mod lê `status.tsv`, `status.time` e `check.log` na pasta do git-commands e, além do que a spec lista, o `config` (só `auto_check` e `interval`), para saber se a verificação está ligada e de quanto em quanto tempo ela roda. Nunca chama `$.fs.write`, `$.http`, `$.process` nem `$.env.set`, não roda git e nunca atualiza nada.
- **Pasta:** `GIT_COMMANDS_HOME`; senão `<HOME>/.git-commands`; senão `<USERPROFILE>/.git-commands` (a mesma pasta que o bash usa no Windows).
- **Atualiza:** ao abrir a sessão, no fim de cada resposta da conversa principal e a cada minuto (`60_000` ms).
- **Estado:** tudo o que é desenhado ou precisa sobreviver a um recarregamento fica em `$.state`, declarado em `types/index.d.ts` sob `'git-commands-painel'`.
- **Telas:** os testes de desenho rodam em `terminal`, `desktop`, `vscode` e `mobile`. Num Claude Code sem mods, o painel simplesmente não aparece.
- **Independência:** o `git-commands` não depende do painel, e o painel não declara `dependencies` (funciona com o que houver na pasta).
- Nome `git-commands-painel`, versão `0.1.0`, comando `/painel`. Textos em pt-BR simples, exatamente como nas tabelas das Tarefas 2 e 4.
- Fim de linha LF. Mensagens de commit em pt-BR, no imperativo, com o e-mail privado e terminando com `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Branch `parte-6-painel`. **Nada vai para o GitHub sem o Dev mandar** (envio, PR, junção, marca de versão).
- Documentação pública sem nomes de pessoas nem de projetos pessoais ("Dev", "projeto").

## Review Focus

1. **Computador acordando depois de dormir** (o `status.time` fica velho até o agendador rodar de novo; o do macOS e o do Linux só rodam no próximo intervalo): o esperado é "esperando a verificação" por até 1 intervalo mais 5 minutos, com as novidades da última verificação ainda à mostra, nunca "verificação parada" logo de cara. Teste: `a verificação só fica parada depois de um intervalo e 5 minutos atrasada` (Tarefa 3; corrigido na revisão final, veja no fim).
2. **Windows sem `HOME`** (só `USERPROFILE`): o esperado é achar `C:\Users\<pessoa>\.git-commands`. Teste: `lê a pasta do GIT_COMMANDS_HOME, do HOME ou do USERPROFILE` (Tarefa 3).
3. **git-commands nunca configurado** (sem a pasta): o esperado é "git-commands: verificação desligada" e o painel explicar como ligar, sem erro nenhum. Testes: `sem a pasta do git-commands, a verificação está desligada` (Tarefa 1) e `o painel explica quando a verificação está desligada` (Tarefa 5).
4. **Sem internet na última verificação** (todos os projetos com `erro`): o esperado é "git-commands: 2 com erro", nunca "em dia". Teste: `projetos com erro não aparecem como em dia` (Tarefa 2).
5. **Muitos projetos com novidades** (8): o esperado é a faixa e o aviso continuarem curtos ("a (1), b (2), c (3) e mais 5"). Teste: `a lista de novidades mostra 3 e conta o resto` (Tarefa 2).

---

## Estrutura de arquivos

```
plugins/git-commands-painel/
  .claude-plugin/plugin.json   nome, versão 0.1.0, descrição, "types"
  hooks/hooks.json             { "modules": ["./register.tsx"] }
  hooks/resumo.ts              lê config, status.tsv, status.time e check.log; monta o resumo (puro)
  hooks/textos.ts              todos os textos e cores (puro)
  hooks/register.tsx           os hooks: atualizar, linha de status, aviso, faixa, /painel e o painel
  types/index.d.ts             o contrato do $.state
  tests/resumo.test.ts         funções de resumo.ts
  tests/textos.test.ts         funções de textos.ts
  tests/painel.test.tsx        os hooks, pelo kit de testes
.claude-plugin/marketplace.json  a entrada do git-commands-painel
.github/workflows/test.yml       o job "validar" valida o painel; um job "painel" roda os testes dele nos três sistemas
README.md                        seção "Painel (opcional)" e a estrutura em "Para quem quer contribuir"
plugins/git-commands/lib/updates.sh, tests/test_updates.sh, plugin.json   só na Tarefa 7, se aprovada
```

**O que o kit de testes faz (conferido num teste descartável antes deste plano):**
- `claude plugin test <pasta>` roda todo `*.test.ts(x)` da pasta, funciona sem login e importa os arquivos do mod (`import { lerProjetos } from '../hooks/resumo'`).
- Os hooks do teste (`on(...)`) ficam embaixo do mod e fazem o papel do Claude. **Todos** são registrados antes da primeira chamada em `$`.
- `$.fs.read` chega ao hook `fs.read` do teste com o caminho já absoluto do sistema (no Windows, `/casa/.git-commands/status.tsv` vira `C:\casa\.git-commands\status.tsv`): o teste reconhece o arquivo pelas duas últimas partes do caminho. Arquivo que falta: o hook do teste lança um erro.
- `mock.env(on, {...})` responde `$.env.get`; `mock.clock(on, { now })` responde `$.clock`, e `clock.advance(60_000)` dispara o `every`.
- O hook de teste para `prompt.submit` devolve `{ text: e.text }`; para `turn.complete`, `{ text: e.answer }`; para `ui.open`, `{ value: { isPlaced: true } }`; para `ui.status` e `ui.toast`, `{ value: undefined }`; para `command.register`, `{ value: { command: e.name } }`.
- Quando a faixa devolve `next(e)`, alguém embaixo precisa desenhar: o teste registra `on('ui.render', ...)` que desenha `<Text>engine</Text>`.
- `$.turn.complete({ answer, durationMs, isAborted, turnId, reason: 'answer' })` dispara o fim de uma resposta.

---

### Task 1: O esqueleto do mod e a leitura dos arquivos

**Files:**
- Create: `plugins/git-commands-painel/.claude-plugin/plugin.json`
- Create: `plugins/git-commands-painel/hooks/hooks.json`
- Create: `plugins/git-commands-painel/hooks/register.tsx` (por enquanto, `export const register: Register = () => {}`)
- Create: `plugins/git-commands-painel/types/index.d.ts`
- Create: `plugins/git-commands-painel/hooks/resumo.ts`
- Test: `plugins/git-commands-painel/tests/resumo.test.ts`

**Interfaces:**
- Produces, em `types/index.d.ts`:
  - `Projeto = { caminho: string; nome: string; branch: string; estado: string; novos: number; seus: number }` (`novos` = commits do GitHub que faltam, a 5ª coluna; `seus` = commits ainda não enviados, a 4ª)
  - `Situacao = 'desligada' | 'erro' | 'esperando' | 'parada' | 'ok'`
  - `Resumo = { situacao: Situacao; projetos: Projeto[]; verificadoEm: number | null; motivo: string | null; intervalo: number; visto: number }` (`verificadoEm` e `visto` em ms; `visto` = quando o resumo foi feito)
  - `PluginState['git-commands-painel'] = { resumo: Resumo | null; escondida: string | null; avisado: { verificadoEm: number | null; novos: Record<string, number> } | null; parada: { verificadoEm: number | null; desde: number } | null }`
- Produces, em `hooks/resumo.ts`:
  - `GRACA_MS = 300_000`, `INTERVALO_PADRAO = 30`
  - `type Arquivos = { config?: string; tsv?: string; time?: string; log?: string }` (`undefined` = o arquivo não existe)
  - `lerConfig(texto?: string): { ligada: boolean; intervalo: number }` — `auto_check=on` liga; `interval=` com um inteiro ≥ 1, senão 30
  - `lerProjetos(texto?: string): Projeto[]` — uma por linha com 7 colunas separadas por tab; aceita `\r\n`; linha com menos colunas fica de fora; número inválido vira 0
  - `lerHora(texto?: string): number | null` — segundos do `status.time` × 1000
  - `lerErro(texto?: string): string | null` — se a última linha não vazia termina em ` erro <N>`: a linha de antes sem o prefixo `git-commands: ` (só se tiver esse prefixo), senão `código <N>`; caso contrário `null`
  - `atrasada(arquivos: Arquivos, agora: number): boolean` — sem `status.time`, ou mais velho que 3 intervalos
  - `resumir(arquivos: Arquivos, agora: number, paradaDesde: number | null): Resumo` — situação, nesta ordem: desligada (config não diz `on`); erro (`lerErro` ≠ null); com `paradaDesde`: `parada` se `agora - paradaDesde >= GRACA_MS`, senão `esperando`; sem `status.tsv`: `esperando`; senão `ok`
  - `comNovidades(projetos: readonly Projeto[]): Projeto[]` — estado `novidades` ou `divergiu` com `novos > 0`, na ordem do arquivo
  - `assinatura(projetos: readonly Projeto[]): string` — `caminho:novos` dos que têm novidades, unidos por `|` (`''` sem novidades)
  - `temNovidadeNova(antes: Readonly<Record<string, number>>, projetos: readonly Projeto[]): boolean` — algum com novidades tem `novos` maior que `antes[caminho] ?? 0`
  - `ordenarParaOPainel(projetos: readonly Projeto[]): Projeto[]` — primeiro novidades/divergiu, depois os outros estados, por último `em-dia`; dentro de cada grupo, a ordem do arquivo

- [ ] **Step 1: Write the failing tests** em `tests/resumo.test.ts`:
  - `lerConfig entende auto_check e interval, com 30 de padrão`: `'auto_check=on\ninterval=45\n'` → `{ ligada: true, intervalo: 45 }`; `'auto_check=off\n'` → `{ ligada: false, intervalo: 30 }`; `'interval=abc'` e `undefined` → `intervalo: 30`.
  - `lerProjetos lê o status.tsv e pula linhas quebradas`: `'C:/git/site\tsite\tmain\t1\t3\t2\tdivergiu\r\nquebrada\tsó\n'` → `[{ caminho: 'C:/git/site', nome: 'site', branch: 'main', estado: 'divergiu', novos: 3, seus: 1 }]`; `''` e `undefined` → `[]`.
  - `lerHora lê o status.time em milissegundos`: `'1793006349\n'` → `1793006349000`; `'x'` e `undefined` → `null`.
  - `lerErro devolve o motivo da última verificação com erro`: log terminando em `'2026-10-26 06:19:09 verificação ok\n'` → `null`; `'git-commands: a pasta de projetos não existe: /x\n2026-10-26 06:49:07 erro 1\n'` → `'a pasta de projetos não existe: /x'`; `'2026-10-26 06:49:07 erro 3\n'` → `'código 3'`.
  - `resumir: desligada, erro, esperando, parada e ok`: um caso para cada regra da ordem acima, com `agora` fixo; no `ok`, `projetos`, `verificadoEm`, `intervalo` e `visto` preenchidos; `parada` só com `agora - paradaDesde >= 300_000`.
  - `sem a pasta do git-commands, a verificação está desligada`: `resumir({}, agora, null).situacao === 'desligada'` e `projetos` vazio.
  - `atrasada depois de 3 intervalos`: com `interval=30`, `status.time` de 90 min atrás → `false`; de 91 min → `true`; sem `status.time` → `true`.
  - `temNovidadeNova só quando algum projeto ganhou commits`: `{ 'C:/git/site': 3 }` contra site com 3 → `false`; com 4 → `true`; projeto novo com novidades → `true`; lista vazia → `false`.
  - `assinatura e ordenarParaOPainel`: assinatura de site(3) e api(1) = `'C:/git/site:3|C:/git/api:1'`; ordem `[em-dia, erro, novidades]` → `[novidades, erro, em-dia]`.

- [ ] **Step 2: Run to verify they fail**

Run: `claude plugin test plugins/git-commands-painel`
Expected: FAIL (o `resumo.ts` ainda não existe).

- [ ] **Step 3: Write the scaffold and implement `hooks/resumo.ts`** com as assinaturas acima. `plugin.json`:

```json
{
  "name": "git-commands-painel",
  "version": "0.1.0",
  "description": "Painel opcional do git-commands: mostra no Claude quais projetos têm novidades no GitHub. Só lê, nunca atualiza nada.",
  "author": { "name": "ppdrada" },
  "homepage": "https://github.com/ppdrada/git-commands",
  "repository": "https://github.com/ppdrada/git-commands",
  "license": "MIT",
  "keywords": ["git", "github", "painel", "pt-br"],
  "types": "./types/index.d.ts"
}
```

- [ ] **Step 4: Run to verify they pass**

Run: `claude plugin test plugins/git-commands-painel` e `claude plugin validate plugins/git-commands-painel --strict`
Expected: todos os testes passam; o validate passa e lista os quatro valores do `$.state`.

- [ ] **Step 5: Commit**

```bash
git add plugins/git-commands-painel
git commit -m "Painel: esqueleto do mod e leitura dos arquivos da verificação"
```

### Task 2: Os textos

**Files:**
- Create: `plugins/git-commands-painel/hooks/textos.ts`
- Test: `plugins/git-commands-painel/tests/textos.test.ts`

**Interfaces:**
- Consumes: `Projeto`, `Resumo` (Tarefa 1); `comNovidades` (Tarefa 1).
- Produces, em `hooks/textos.ts`:
  - `PERGUNTA = 'tem algo novo nos meus projetos?'`
  - `linhaDeStatus(resumo: Resumo): string`
  - `rotuloDoEstado(projeto: Projeto): string`
  - `corDoEstado(estado: string): 'warning' | 'error' | 'success' | undefined` — `novidades`/`divergiu` → `warning`; `erro`/`ocupado` → `error`; `em-dia` → `success`
  - `listaDeNovidades(projetos: readonly Projeto[]): string` — os 3 primeiros com novidades como `nome (novos)`, separados por `, `, e ` e mais <N>` se houver mais
  - `haQuanto(ms: number): string`
  - `cabecalhoDoPainel(resumo: Resumo): string`

**Linha de status** (`linhaDeStatus`), N = `comNovidades(...).length`, E = projetos com estado `erro`:

| Quando | Texto |
|---|---|
| `desligada` | `git-commands: verificação desligada` |
| `erro` | `git-commands: verificação com erro` |
| `esperando` | `git-commands: esperando a verificação` |
| `parada` | `git-commands: verificação parada` |
| `ok`, N > 0 | `git-commands: N com novidades` |
| `ok`, N = 0, E > 0 | `git-commands: E com erro` |
| `ok`, resto | `git-commands: em dia` |

**Estado de cada projeto** (`rotuloDoEstado`), N = `novos`, S = `seus`:

| Estado | Rótulo |
|---|---|
| `em-dia` | `em dia` |
| `novidades` | `com novidades (N)` |
| `divergiu` | `divergiu: N do GitHub e S seu` (S = 1) / `... S seus` |
| `a-frente` | `1 commit para enviar` / `S commits para enviar` |
| `sem-upstream` | `sem upstream: a branch ainda não está no GitHub` |
| `ocupado` | `ocupado: no meio de um merge ou rebase` |
| `destacado` | `HEAD destacado: fora de uma branch` |
| `sem-commits` | `ainda sem commits` |
| `erro` | `erro: não deu para falar com o GitHub` |
| outro | o próprio estado |

**Há quanto tempo** (`haQuanto`, os mesmos cortes do hook `session-start`): menos de 60 s → `há menos de 1 minuto`; menos de 2 h → `há 1 minuto` / `há N minutos`; menos de 48 h → `há N horas`; senão `há N dias`.

**Cabeçalho do painel** (`cabecalhoDoPainel`), T = `haQuanto(visto - verificadoEm)`, I = `intervalo`:

| Situação | Texto |
|---|---|
| `ok` | `Última verificação T. Ela roda a cada I minutos.` |
| `desligada` | `A verificação automática está desligada. Para ligar, peça ao Claude: "quero que verifique meus projetos sozinho".` |
| `erro` | `A última verificação deu erro: <motivo>. Peça ao Claude para conferir a verificação automática.` |
| `parada` | `A verificação não roda T (o normal é a cada I minutos). Peça ao Claude para conferir a verificação automática.` |
| `esperando`, sem `verificadoEm` | `Esperando a primeira verificação.` |
| `esperando`, com `verificadoEm` | `Esperando a próxima verificação. A última foi T.` |

- [ ] **Step 1: Write the failing tests** em `tests/textos.test.ts`:
  - `linha de status para cada situação`: as 7 linhas da tabela, com `git-commands: 2 com novidades` e `git-commands: 1 com novidades`.
  - `projetos com erro não aparecem como em dia`: `ok` com dois projetos `erro` → `git-commands: 2 com erro`; um `novidades` e um `erro` → `git-commands: 1 com novidades`.
  - `rótulo de cada estado do status.tsv`: cada linha da tabela, inclusive `divergiu: 3 do GitHub e 1 seu`, `divergiu: 3 do GitHub e 2 seus`, `1 commit para enviar` e um estado desconhecido.
  - `a lista de novidades mostra 3 e conta o resto`: dois → `site (3), api (1)`; oito → `a (1), b (2), c (3) e mais 5`; projetos `em-dia` não entram.
  - `haQuanto em minutos, horas e dias`: 30 s, 60 s, 119 min, 120 min, 47 h, 48 h → os textos dos cortes.
  - `cabeçalho do painel para cada situação`: as 6 linhas da tabela.

- [ ] **Step 2: Run to verify they fail**

Run: `claude plugin test plugins/git-commands-painel`
Expected: FAIL nos testes de `textos.test.ts`.

- [ ] **Step 3: Implement `hooks/textos.ts`** com as assinaturas e os textos exatos das tabelas.

- [ ] **Step 4: Run to verify they pass**

Run: `claude plugin test plugins/git-commands-painel`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add plugins/git-commands-painel/hooks/textos.ts plugins/git-commands-painel/tests/textos.test.ts
git commit -m "Painel: textos da linha de status, dos estados e do painel"
```

### Task 3: A linha de status e quando atualizar

**Files:**
- Modify: `plugins/git-commands-painel/hooks/register.tsx`
- Test: `plugins/git-commands-painel/tests/painel.test.tsx`

**Interfaces:**
- Consumes: `resumir`, `atrasada`, `lerHora`, `lerConfig`, `Arquivos` (Tarefa 1); `linhaDeStatus` (Tarefa 2).
- Produces, em `register.tsx` (usado pelas Tarefas 4 e 5):
  - refs `resumo`, `escondida`, `avisado`, `parada`: `atom({ plugin: 'git-commands-painel', key: '<nome>' } as const, null)`
  - `pastaDoGitCommands($: EngineInterface): Promise<string | undefined>` — as três fontes da regra global, cada `$.env.get` com o nome literal
  - `lerArquivos($: EngineInterface): Promise<Arquivos>` — os quatro arquivos com `$.fs.read`; o que falhar vira `undefined`
  - `atualizar($: EngineInterface): Promise<void>` — lê, cuida do `parada` (se `atrasada`: mantém o `desde` enquanto o `status.time` for o mesmo, senão grava `{ verificadoEm, desde: agora }`; se não está atrasada, volta a `null`), grava o `resumo` e chama `$.ui.status(linhaDeStatus(...))` só quando o texto muda; nunca lança (erro fica de fora em silêncio)
  - hooks: `session.start` (atualiza e liga `$.clock.every(60_000, ...)`), `turn.complete` (depois de `next(e)`, atualiza só quando `e.agentId` não existe)
- Test helper, no topo de `tests/painel.test.tsx`: `mundo(on, arquivos: Record<string, string>)` registra os hooks de teste da seção "O que o kit de testes faz" e devolve `{ status: (string | undefined)[], avisos: string[], perguntas: string[], escritas: string[], arquivos }`. O `fs.read` responde pelo nome (`status.tsv`, `status.time`, `check.log`, `config`) de `arquivos`, que o teste pode trocar no meio; `fs.write`, `http.fetch`, `process.run` e `process.spawn` só anotam em `escritas` e recusam.

- [ ] **Step 1: Write the failing tests** em `tests/painel.test.tsx` (`mock.env(on, { HOME: '/casa' })`, relógio começando num `now` fixo, `status.time` 5 min antes):
  - `ao abrir a sessão, a linha de status conta os projetos com novidades`: `status.tsv` com `site` (novidades 3) e `api` (em-dia) → depois de `$.session.start(...)`, a última linha é `git-commands: 1 com novidades`.
  - `atualiza no fim de cada resposta da conversa`: troca o `status.tsv` para tudo em dia, dispara `$.turn.complete(...)` → `git-commands: em dia`; o mesmo com `agentId: 'a1'` não atualiza.
  - `atualiza a cada minuto`: troca o arquivo, `clock.advance(60_000)` → a linha muda.
  - `a verificação só fica parada depois de 5 minutos atrasada`: `status.time` de 4 h atrás → `git-commands: esperando a verificação`; `advance` de 4 min → ainda esperando; mais 1 min → `git-commands: verificação parada`; `status.time` novo + 1 min → `git-commands: em dia`.
  - `lê a pasta do GIT_COMMANDS_HOME, do HOME ou do USERPROFILE`: três testes curtos, conferindo que o caminho lido contém `outra`, `casa` ou `perfil` (`mock.env` com só uma das variáveis).
  - `só lê: nunca escreve, nunca usa a rede e nunca roda comandos`: depois de abrir a sessão, uma resposta e dois minutos, `escritas` continua vazio.

- [ ] **Step 2: Run to verify they fail**

Run: `claude plugin test plugins/git-commands-painel`
Expected: FAIL nos testes de `painel.test.tsx` (nenhuma linha de status ainda).

- [ ] **Step 3: Implement** em `register.tsx` as funções e os dois hooks acima.

- [ ] **Step 4: Run to verify they pass**

Run: `claude plugin test plugins/git-commands-painel` e `claude plugin validate plugins/git-commands-painel --strict`
Expected: PASS; o validate lista as chamadas `$.fs.read`, `$.env.get`, `$.clock.every`, `$.ui.status`, `$.state.*` e nenhuma de escrita, rede ou processo.

- [ ] **Step 5: Commit**

```bash
git add plugins/git-commands-painel
git commit -m "Painel: linha de status ao abrir, no fim de cada resposta e a cada minuto"
```

### Task 4: A faixa e o aviso rápido

**Files:**
- Modify: `plugins/git-commands-painel/hooks/register.tsx`
- Test: `plugins/git-commands-painel/tests/painel.test.tsx`

**Interfaces:**
- Consumes: refs e `atualizar` (Tarefa 3); `comNovidades`, `assinatura`, `temNovidadeNova` (Tarefa 1); `listaDeNovidades`, `PERGUNTA` (Tarefa 2).
- Produces:
  - Faixa: hook `ui.render` em `{ component: 'AbovePrompt' }`. Devolve `next(e)` quando `e.props.hasSurvey`, sem resumo, situação diferente de `ok`, sem novidades, ou quando `escondida === assinatura(projetos)`. Senão desenha `Novidades no GitHub: <listaDeNovidades>` e os botões `Ver agora` (`key="ver"`, `variant="primary"`) e `Depois` (`key="depois"`). Os dois gravam em `escondida` a assinatura que estava desenhada; o `Ver agora` também chama `$.prompt.submit({ text: PERGUNTA })`.
  - Aviso rápido, dentro de `atualizar`: na primeira leitura da sessão só grava `avisado`. Depois, quando o `verificadoEm` muda, a situação é `ok` e `temNovidadeNova(avisado.novos, projetos)`, chama `$.ui.toast('Novidades no GitHub: ' + listaDeNovidades(projetos))`. Em toda leitura, grava `avisado` com o `verificadoEm` e os `novos` atuais (por caminho) quando mudarem.

- [ ] **Step 1: Write the failing tests** (constante `FAIXA` com os props de `AbovePrompt`: `hasSurvey: false, isWorking: false, maxRows: 10, bodyColumns: 80, scroll: { offset: 0, bodyRows: 9 }, view: {}`):
  - `a faixa aparece só quando há novidades, em todas as telas`: com `site` (3) e `api` (1), em cada uma das 4 telas, o texto achado por `/Novidades/` é `Novidades no GitHub: site (3), api (1)`; com tudo em dia, a faixa é a do `engine`.
  - `Ver agora manda a pergunta e esconde a faixa`: `press({ key: 'ver' })` → `perguntas` = `['tem algo novo nos meus projetos?']` e a faixa some.
  - `Depois esconde a faixa até a lista mudar`: `press({ key: 'depois' })` → some; outro minuto com a mesma lista → continua escondida; `site` passa a 4 e um minuto → volta.
  - `a faixa dá lugar a uma pesquisa`: com `hasSurvey: true`, a faixa é a do `engine`.
  - `aviso rápido só quando uma verificação nova traz novidade`: ao abrir a sessão com novidades, nenhum aviso; `status.time` novo com a mesma lista → nenhum; `status.time` novo com `api` (2) → um aviso `Novidades no GitHub: site (3), api (2)`; mais um minuto sem mudança → ainda um só.

- [ ] **Step 2: Run to verify they fail**

Run: `claude plugin test plugins/git-commands-painel`
Expected: FAIL nos testes novos.

- [ ] **Step 3: Implement** a faixa e o aviso como descritos.

- [ ] **Step 4: Run to verify they pass**

Run: `claude plugin test plugins/git-commands-painel` e `claude plugin validate plugins/git-commands-painel --strict`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add plugins/git-commands-painel
git commit -m "Painel: faixa com Ver agora e Depois, e aviso rápido de novidades"
```

### Task 5: O painel e o comando /painel

**Files:**
- Modify: `plugins/git-commands-painel/hooks/register.tsx`
- Test: `plugins/git-commands-painel/tests/painel.test.tsx`

**Interfaces:**
- Consumes: refs e `atualizar` (Tarefa 3); `ordenarParaOPainel` (Tarefa 1); `cabecalhoDoPainel`, `rotuloDoEstado`, `corDoEstado`, `comNovidades`, `PERGUNTA` (Tarefas 1 e 2).
- Produces:
  - Em `session.start`: `$.command.register({ name: 'painel', description: 'Mostra o estado dos seus projetos do GitHub (git-commands)' })`.
  - Hook `command.run` em `{ command: 'painel' }`: atualiza e abre `$.ui.open({ id: 'painel', title: 'git-commands' })`; devolve `{}` se `isPlaced`, senão `{ text: 'Não deu para abrir o painel aqui.' }`.
  - Hook `ui.render` em `{ component: 'Pane', requestId: 'painel' }`: uma coluna com o cabeçalho (`dimColor`), uma linha por projeto em `ordenarParaOPainel` como `<nome> (<branch>): <rótulo>`, na cor de `corDoEstado`; `Nenhum projeto do GitHub na pasta de projetos.` quando a situação não é `desligada` e a lista está vazia; e, havendo novidades, a dica `Para ver e atualizar, peça ao Claude: "tem algo novo nos meus projetos?"` (`dimColor`).

- [ ] **Step 1: Write the failing tests** (constante `PAINEL` com os props de `Pane`: `title: 'git-commands', isFocused: false, bodyColumns: 60, placement: 'dock', scroll: { offset: 0, bodyRows: 20 }, view: {}`):
  - `/painel abre o painel com o estado de cada projeto, em todas as telas`: `$.command.run({ command: 'painel', args: '', ... })` → `{}`, e o `ui.open` do teste recebeu `id: 'painel'`; montado nas 4 telas, acha `Última verificação há 5 minutos. Ela roda a cada 30 minutos.`, `site (main): com novidades (3)` antes de `api (main): em dia`, e a dica.
  - `o painel explica quando a verificação está desligada`: sem nenhum arquivo, acha o texto de `desligada` e não acha `Nenhum projeto`.
  - `quando não dá para abrir, o comando diz isso`: `ui.open` do teste devolvendo `{ value: { isPlaced: false, reason: 'no-surface' } }` → `{ text: 'Não deu para abrir o painel aqui.' }`.

- [ ] **Step 2: Run to verify they fail**

Run: `claude plugin test plugins/git-commands-painel`
Expected: FAIL nos testes novos.

- [ ] **Step 3: Implement** o comando e o desenho do painel.

- [ ] **Step 4: Run to verify they pass**

Run: `claude plugin test plugins/git-commands-painel` e `claude plugin validate plugins/git-commands-painel --strict`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add plugins/git-commands-painel
git commit -m "Painel: comando /painel e o painel com o estado de cada projeto"
```

### Task 6: Marketplace, CI e README

**Files:**
- Modify: `.claude-plugin/marketplace.json`
- Modify: `.github/workflows/test.yml` (job `validar`)
- Modify: `README.md`

- [ ] **Step 1: Registrar no marketplace**: uma segunda entrada em `plugins`, `{ "name": "git-commands-painel", "source": "./plugins/git-commands-painel", "description": "<a mesma do plugin.json>" }`.

- [ ] **Step 2: CI**: no job `validar`, depois de validar o plugin principal, `claude plugin validate plugins/git-commands-painel --strict`. E um job novo, `painel`, na mesma matriz dos testes (`ubuntu-latest`, `macos-latest`, `windows-latest`, `fail-fast: false`): checkout, Node 22, `npm install -g @anthropic-ai/claude-code` e `claude plugin test plugins/git-commands-painel` (o kit roda sem login).

- [ ] **Step 3: README**: uma seção `### Painel (opcional)` logo depois de `### Chaves SSH (opcional)`, curta, com: o que ele mostra (linha de status, faixa com "Ver agora" e "Depois", aviso rápido, `/painel`), que só lê o que a verificação automática grava e precisa dela ligada, e como instalar:

```bash
claude plugin install git-commands-painel@git-commands
```

  mais a mesma linha com `/plugin install` dentro do Claude Code, o caminho no app (botão + ao lado da caixa de mensagem, Plugins, Adicionar plugin) e "feche e abra o Claude Code de novo". Em "Atualizar e desinstalar", a linha `claude plugin uninstall git-commands-painel@git-commands`. Em "Para quem quer contribuir", a pasta `plugins/git-commands-painel/` na árvore e o comando `claude plugin test plugins/git-commands-painel`.

- [ ] **Step 4: Verify**

Run: `claude plugin validate . --strict` e `claude plugin validate plugins/git-commands --strict` e `claude plugin validate plugins/git-commands-painel --strict`
Expected: os três passam.

- [ ] **Step 5: Commit**

```bash
git add .claude-plugin/marketplace.json .github/workflows/test.yml README.md
git commit -m "Painel no marketplace, no CI e no README"
```

### Task 7 (só se o Dev aprovar): o updates pull refaz a linha do projeto no status.tsv

**Por quê:** o painel não roda git. Hoje, depois que a pessoa atualiza um projeto pelo "Ver agora", o `status.tsv` continua dizendo que há novidades até a próxima verificação (até 30 minutos), e a linha de status mostra "1 com novidades" para um projeto que já está em dia. Com esta mudança, a linha certa aparece no fim da mesma resposta. Ela vale para o `git-commands` com ou sem o painel.

**Files:**
- Modify: `plugins/git-commands/lib/updates.sh` (`gc_updates_pull`)
- Modify: `plugins/git-commands/.claude-plugin/plugin.json` (versão `1.1.1`)
- Test: `tests/test_updates.sh`

**Interfaces:**
- Produces: `gc_updates_save_line <repositório>` — se `$(gc_home)/status.tsv` existe e tem uma linha cujo caminho é o do repositório, troca só essa linha por `gc_updates_line "$r" no` (sem rede), gravando por arquivo temporário e `mv`; não mexe no `status.time`. O `gc_updates_pull` chama nos dois caminhos que terminam bem (`já estava em dia` e `atualizado`).

- [ ] **Step 1: Write the failing test** `test_pull_atualiza_a_linha_salva`: `projects_dir` no sandbox, `atras` com um commit novo no "GitHub" e `emdia` sem nada; `gc updates scan --save`; guarda o `status.time`; `gc updates pull "$a"`; a linha de `atras` termina em `em-dia`, a de `emdia` não mudou e o `status.time` é o mesmo.

- [ ] **Step 2: Run to verify it fails**

Run: `bash tests/run.sh updates`
Expected: FAIL em `test_pull_atualiza_a_linha_salva` (a linha ainda diz `novidades`).

- [ ] **Step 3: Implement** `gc_updates_save_line` e as duas chamadas; versão `1.1.1` no `plugin.json`.

- [ ] **Step 4: Run to verify it passes**

Run: `bash tests/run.sh`
Expected: todos passam (ou pulados pelos motivos de sempre).

- [ ] **Step 5: Commit**

```bash
git add plugins/git-commands/lib/updates.sh plugins/git-commands/.claude-plugin/plugin.json tests/test_updates.sh
git commit -m "Depois de atualizar um projeto, a linha dele no status.tsv já fica certa"
```

### Task 8: Testar no app com os arquivos reais

- [ ] **Step 1: Carregar o mod nesta sessão**: copiar `plugins/git-commands-painel` para `~/.claude/dev-mods/<sessão>/git-commands-painel` (a pasta que esta sessão recarrega). O app pergunta uma vez "Turn on the mods Claude writes in this session?": **quem responde é o Dev** ("Turn them on"). O mod carrega quando a resposta termina.

- [ ] **Step 2: Conferir com os arquivos de verdade**: com o `~/.git-commands` real (hoje, 2 projetos em dia), o Dev confere: a linha de status diz `git-commands: em dia`; `/painel` abre o painel com os dois projetos `em dia` e `Última verificação há N minutos. Ela roda a cada 30 minutos.`; nenhuma faixa.

- [ ] **Step 3: Conferir com novidades (só com o ok do Dev)**: guardar uma cópia do `status.tsv` e do `status.time` reais no scratchpad; gravar um `status.tsv` com um projeto `novidades` (3) e um `status.time` novo; em até 1 minuto o Dev vê o aviso rápido, a faixa e `git-commands: 1 com novidades`; aperta "Depois" e a faixa some; devolver as cópias e conferir que volta a `em dia`.

- [ ] **Step 4: Anotar o resultado** no relatório final (o que o Dev viu em cada tela).

### Task 9: Revisão final e publicação (só com a ordem do Dev)

- [ ] **Step 1: Verificar tudo**: `bash tests/run.sh`, `claude plugin test plugins/git-commands-painel` e os três `claude plugin validate ... --strict`. Opcional, local: conferir os tipos com o TypeScript do npm (`npx -y -p typescript@5.6.3 tsc -p <tsconfig no scratchpad>`, com o arquivo de tipos da skill), sem que nada disso entre no projeto.
- [ ] **Step 2: Revisão** da branch inteira por um revisor novo (`superpowers:requesting-code-review`), e correção do que ele achar.
- [ ] **Step 3: Publicação**, cada passo com o ok do Dev: `git push -u origin parte-6-painel`, o PR (título e descrição mostrados antes, com o link), a junção e as marcas de versão (`git-commands-painel--v0.1.0` e, com a Tarefa 7, `git-commands--v1.1.1`).

## Depois da revisão final

A revisão da branch inteira trouxe estas mudanças, já feitas e testadas:

- **Folga depois de acordar:** "parada" só depois de 1 intervalo mais 5 minutos de atraso (`intervalo * 60_000 + GRACA_MS`), porque o agendador do macOS (launchd) e o do Linux (cron) não rodam a verificação que perderam enquanto o computador dormia. Enquanto espera, as novidades da última verificação continuam na linha de status e na faixa.
- **Faixa escondida:** o `$.state` guarda `escondidas: string[]` (cada novidade como `caminho:commits`) no lugar de `escondida`, e `entradas`, `temNovidadeAMostrar` e `podarEscondidas` substituem `assinatura`. A faixa volta só quando chega uma novidade que ainda não foi escondida: um projeto que sai da lista não a traz de volta, e o que sai da lista é esquecido.
- **Primeira verificação:** sem `status.tsv`, `verificadoEm` é `null`. O painel diz "Esperando a primeira verificação." e não diz "Nenhum projeto do GitHub na pasta de projetos.".
- **Registro do /painel:** a linha de status e o relógio começam antes do registro do comando; se o registro for recusado, o resto continua.
