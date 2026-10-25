# git-commands — Plano de construção

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** construir e publicar no GitHub, em 4 partes, o plugin `git-commands` do Claude Code, que faz git e GitHub por quem está começando, ensinando cada conceito uma vez e pedindo confirmação sempre.

**Architecture:** o repositório é ao mesmo tempo o marketplace e a casa do plugin (`plugins/git-commands/`). Toda a lógica que precisa ser exata (estado, varredura de repositórios, detecção de comando perigoso, agendamento) fica num único executável bash, `bin/git-commands`, com subcomandos e testes automáticos. O jeito de conversar (explicar, confirmar, mandar link) fica em 7 skills em pt-BR que usam esse executável, o `git` e o `gh`. Três hooks garantem o que não pode depender só de instrução: o contexto na abertura, a proteção contra comandos que apagam trabalho e a checagem antes da primeira edição.

**Tech Stack:** bash (compatível com 3.2), git ≥ 2.28, GitHub CLI (`gh`), plugins do Claude Code (skills, agents, hooks, `bin/`), Agendador de Tarefas (Windows), launchd (macOS), cron (Linux), GitHub Actions, `claude plugin validate`, `claude plugin eval`.

**Spec:** `docs/superpowers/specs/2026-10-25-git-commands-design.md`

## Global Constraints

- Bash compatível com 3.2 (o bash do macOS): nada de arrays associativos, `mapfile`/`readarray`, `${x,,}`/`${x^^}`, `;&`. Regex com `[[ $x =~ $re ]]` e a regex numa variável.
- Hooks e executor agendado não usam heredoc (o bash 5.3 trava com heredoc; ver superpowers#571). Use `printf`.
- Dependências em uso: só bash, git, gh e utilitários POSIX (`sed`, `grep`, `find`, `cksum`, `date`, `mkdir`, `mv`, `cat`). Nada de jq, python ou node. Limite de tempo via `gc_run_with_timeout` (o macOS não tem `timeout`).
- Estado em `${GIT_COMMANDS_HOME:-$HOME/.git-commands}`, nunca dentro dos repositórios da pessoa nem em `${CLAUDE_PLUGIN_ROOT}`. Decisão do plano: a spec sugeria `${CLAUDE_PLUGIN_DATA}`, mas a documentação confirma que esse diretório é apagado ao desinstalar o plugin, e a spec exige que o progresso sobreviva a reinstalações; além disso, o agendador roda fora do Claude e precisa de um caminho fixo.
- Textos para a pessoa em pt-BR simples, e o plugin responde no idioma em que ela escrever. Nomes de skills, subcomandos e ids de conceitos em ASCII kebab-case.
- Todo arquivo de texto com fim de linha LF (`.gitattributes`). Executáveis versionados com modo 100755 (`git add --chmod=+x`).
- Scripts de hook sem extensão, chamados por `hooks/run-hook.cmd` (poliglota cmd/bash). No Windows, o Claude Code prefixa `bash` em comandos com `.sh`, e sem Git Bash o hook precisa sair em silêncio.
- Hooks começam consertando o PATH (`/usr/bin:/bin:/mingw64/bin:/usr/local/bin:/opt/homebrew/bin` na frente), porque o SessionStart pode rodar com PATH quebrado (anthropics/claude-code#43127).
- Rede só em `updates scan` (sem `--no-fetch`), `updates pull`, no hook `pre-edit` e no executor agendado. Sempre com `GIT_TERMINAL_PROMPT=0`, `GCM_INTERACTIVE=never` e limite de tempo.
- Nunca existe `git pull` automático. Atualizar só acontece por `git-commands updates pull` (fast-forward), a pedido da pessoa.
- Nome do plugin e do marketplace: `git-commands`. Repositório: `ppdrada/git-commands`, público, licença MIT, `Copyright (c) 2026 ppdrada`.
- Frase fixa da spec para o conceito `repositorio`: "git init é criar ou inicializar um novo repositório Git em um diretório do seu computador."
- Toda mensagem de commit criada pelo Claude neste trabalho termina com a linha `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Mensagens em pt-BR, no imperativo.
- Partes e branches: Parte 1 direto na `main` (publicação inicial). Partes 2, 3 e 4 em `parte-2-dia-a-dia`, `parte-3-atualizacoes` e `parte-4-ci-e-migracao`, cada uma publicada por PR feito pelo próprio plugin.
- Nada vai para o GitHub (criar repositório, push, PR, tag) sem o Dev mandar. As Tasks 7, 11, 17 e 21 só começam quando ele pedir; até lá, tudo fica só no computador dele.
- A documentação do repositório é pública: nada de nomes de pessoas nem de projetos pessoais. Use "o Dev" e "o projeto".

## Review Focus

1. **Caminhos do Windows** (`C:\Users\...`, barras invertidas, espaços como em `Program Files`) chegando nos hooks e no agendador: o esperado é funcionar igual a caminhos POSIX. Testes: `test_norm_path_*` (Task 2) e `test_pre_edit_caminho_windows` (Task 13).
2. **GitHub inacessível** (sem internet, credencial vencida) durante o fetch do hook ou do agendamento: o esperado é não travar, não abrir janela de login e não bloquear a edição. Testes: `test_pre_edit_remote_inacessivel_libera` (Task 13) e `test_scan_remote_inacessivel_vira_erro` (Task 12).
3. **Repositório em estado estranho** (HEAD destacado, merge em andamento, nenhum commit, worktree com `.git` arquivo dentro da pasta de projetos): a varredura não quebra e reporta um estado legível. Testes em Task 12: `test_scan_estados_estranhos`.
4. **Comando perigoso escrito de outro jeito** (`git -C pasta reset --hard`, `cd x && git push -f`, `git push origin +main`, `git push origin :feature`, `Git.exe clean -fdx`): o esperado é pedir confirmação sempre. Teste em tabela na Task 8: `test_guard_tabela`.
5. **gh instalado mas fora do PATH da sessão** (logo depois do `winget install`): o esperado é o plugin dizer "já instalou, reabra o Claude" em vez de "não está instalado". Teste: `test_doctor_gh_fora_do_path` (Task 4).

---

## Estrutura de arquivos

```
.gitattributes  .gitignore  LICENSE  README.md
.claude-plugin/marketplace.json            marketplace "git-commands" → ./plugins/git-commands
.github/workflows/test.yml                 testes em ubuntu, macos (/bin/bash 3.2) e windows
tests/run.sh  tests/helpers.sh             executor e utilitários de teste
tests/test_*.sh                            um arquivo por unidade
plugins/git-commands/
  .claude-plugin/plugin.json
  bin/git-commands                         despachante (fica no PATH do Bash tool)
  lib/common.sh learned.sh doctor.sh secrets.sh guard.sh proactive.sh updates.sh schedule.sh
  hooks/hooks.json run-hook.cmd session-start guard pre-edit
  scheduler/run-scheduled                  o que o agendador do sistema executa
  skills/{configurar,novo-projeto,salvar,branch-e-pr,comandos,atualizar,verificacao-automatica}/SKILL.md
  reference/regras.md conceitos.md gitignore/{geral,node,python}.gitignore
  agents/git.md
  evals/<caso>/{prompt.md,case.yaml,fixture.sh,graders/*.md}
```

## Contrato do executável `git-commands`

Todas as tarefas usam este contrato. Código 1 = erro de uso, com mensagem em pt-BR no stderr.

| Subcomando | Saída | Códigos |
|---|---|---|
| `home` | caminho do diretório de estado (criado se faltar) | 0 |
| `os` | `windows`, `mac` ou `linux` (respeita `GIT_COMMANDS_OS`) | 0 |
| `config get <chave>` / `config set <chave> <valor>` / `config list` | valor / nada / linhas `chave=valor` com os valores efetivos | 0; 1 chave inválida |
| `learned list` / `has <id>` / `add <id>...` / `forget <id>` / `reset` | ids ordenados, um por linha / nada | `has`: 0 sim, 1 não; `add`: 2 id fora do glossário |
| `doctor` | linhas `chave=valor` (Task 4) | 0 |
| `secrets [--staged] [<repo>]` | `caminho⇥motivo` por arquivo suspeito | 0 nada; 3 achou |
| `guard check` (comando no stdin) | motivo em pt-BR | 0 perigoso; 1 seguro |
| `proactive on\|off [--all] [<repo>]` / `proactive status [<repo>]` | `on` ou `off` | 0; 1 fora de repositório sem `--all` |
| `updates scan [--no-fetch] [--save] [--dir <pasta>] [--repo <repo>]` | por repositório: `caminho⇥nome⇥branch⇥ahead⇥behind⇥alterados⇥estado` | 0; 1 sem pasta de projetos |
| `updates news` | `nome⇥behind⇥caminho⇥estado` das novidades que ainda valem | 0 tem; 1 nada |
| `updates detail <repo>` | texto em 4 seções (Task 12) | 0 |
| `updates pull <repo>` | mensagem do resultado | 0 ok; 3 alterações sem commit; 4 divergiu; 5 sem upstream; 6 erro de rede |
| `schedule enable [min]` / `disable` / `status` | `ligado <min>` ou `desligado` | 0; 1 intervalo inválido ou sistema sem agendador |

- Chaves de config, com o padrão quando não definidas: `projects_dir` (vazio), `auto_check` (`off`), `interval` (`30`), `proactive` (`on`), `auto_check_asked` (vazio).
- Estados do scan: `em-dia`, `novidades` (behind>0, ahead=0), `divergiu` (behind>0 e ahead>0), `a-frente`, `sem-upstream`, `sem-commits`, `destacado`, `ocupado` (merge ou rebase em andamento), `erro` (fetch falhou).
- Arquivos no diretório de estado: `config`, `learned`, `proactive-off`, `status.tsv`, `status.time`, `check.log`, `sessions/<id>/<hash>` e `app/` (cópia de `bin`, `lib`, `scheduler` e `VERSION` para o agendador).

---

# Parte 1 — Base e "começar um projeto" (branch `main`)

### Task 1: Esqueleto do repositório, do plugin e dos testes

**Files:**
- Create: `.gitattributes`, `.gitignore`, `LICENSE`, `README.md`, `.claude-plugin/marketplace.json`, `plugins/git-commands/.claude-plugin/plugin.json`, `tests/run.sh`, `tests/helpers.sh`, `tests/test_helpers.sh`

**Interfaces:**
- Produces: `tests/run.sh [filtro]` carrega `helpers.sh` e cada `tests/test_*.sh` (filtrados pelo trecho no nome). Roda cada função `test_*` num subshell depois de `gc_sandbox`. Imprime `PASS nome`, `FAIL nome: msg` ou `SKIP nome: msg` e, no fim, `N passaram, M falharam, K pulados`. Termina com código 1 se M>0.
- Produces (`helpers.sh`): `ROOT`, `PLUGIN`, `gc` (= `bash "$PLUGIN/bin/git-commands" "$@"`), `assert_eq exp act msg`, `assert_contains texto trecho msg`, `assert_not_contains`, `assert_exit codigo cmd...`, `assert_file caminho msg`, `fail msg`, `skip msg` (código 77), `native_path dir` (`pwd -W` quando existir), `gc_sandbox`, `make_github_pair nome`, `push_remote_commit nome arquivo msg`, `make_local_repo nome`.
- O `gc_sandbox` cria `$SANDBOX` temporário e exporta `HOME=$SANDBOX/home` (sem `GIT_COMMANDS_HOME`). Também exporta `GIT_CONFIG_GLOBAL=$SANDBOX/gitconfig`, com `user.name=Teste`, `user.email=teste@example.com`, `init.defaultBranch=main` e `advice.detachedHead=false`, além de `GIT_CONFIG_NOSYSTEM=1` e `GIT_TERMINAL_PROMPT=0`, e entra na pasta.
- O `make_github_pair nome` cria o repositório bare `$SANDBOX/remotes/nome.git`. Grava no gitconfig global `url."<native_path do bare>".insteadOf https://github.com/teste/nome.git`, clona em `$SANDBOX/projetos/nome`, faz o commit de `README.md`, dá push e imprime o caminho do clone.

- [ ] **Step 1: Criar o repositório local**

Run: `git init -b main` na raiz.
Expected: `Initialized empty Git repository`.

- [ ] **Step 2: Escrever o teste dos utilitários**

```bash
test_sandbox_isola_home() { assert_contains "$HOME" "$SANDBOX" "HOME fica no sandbox"; }
test_par_github_tem_url_do_github_e_fica_atras() {
  local r; r=$(make_github_pair app)
  assert_eq "https://github.com/teste/app.git" "$(git -C "$r" config --get remote.origin.url)" "url crua"
  push_remote_commit app novo.txt "novidade"
  git -C "$r" fetch -q
  assert_eq "1" "$(git -C "$r" rev-list --count HEAD..@{u})" "1 commit atrás"
}
```

- [ ] **Step 3: Rodar e ver falhar**

Run: `bash tests/run.sh helpers`
Expected: FAIL (os utilitários ainda não existem).

- [ ] **Step 4: Escrever `run.sh`, `helpers.sh` e os arquivos do repositório**
  - `.gitattributes`: `* text=auto eol=lf`.
  - `.gitignore`: `plugins/git-commands/evals/results/`, `*.log`, `.DS_Store`, `Thumbs.db`, `.worktrees/`.
  - `LICENSE`: MIT.
  - `README.md`: título, uma frase e "em construção".
  - `marketplace.json`: `$schema` = `https://anthropic.com/claude-code/marketplace.schema.json`, `name` = `git-commands`, `owner.name` = `ppdrada`, e um plugin com `name` = `git-commands` e `source` = `./plugins/git-commands`. A `description` do marketplace e do plugin é "Git e GitHub para quem está começando: o Claude faz os comandos, explica e pede confirmação."
  - `plugin.json`: `name` = `git-commands`, `displayName` = `Git Commands`, `version` = `0.1.0`, a mesma `description`, `author.name` = `ppdrada`, `homepage` e `repository` = `https://github.com/ppdrada/git-commands`, `license` = `MIT` e `keywords` = `["git","github","iniciantes","pt-br"]`.

- [ ] **Step 5: Verificar**

Run: `bash tests/run.sh` → `2 passaram, 0 falharam`.
Run: `claude plugin validate . --strict` e `claude plugin validate plugins/git-commands --strict` → `Validation passed`.

- [ ] **Step 6: Commit**

```bash
git add .gitattributes .gitignore LICENSE README.md .claude-plugin plugins docs
git add --chmod=+x tests/run.sh && git add tests
git commit -m "Cria o esqueleto do repositório, do plugin e dos testes"
```

### Task 2: Executável `git-commands` com `home`, `os` e `config`

**Files:**
- Create: `plugins/git-commands/bin/git-commands`, `plugins/git-commands/lib/common.sh`
- Test: `tests/test_common.sh`

**Interfaces:**
- Produces (`lib/common.sh`, usado por todas as outras libs e hooks):
  - Estado e ambiente: `gc_home`, `gc_os`, `gc_config_get chave` (devolve o padrão quando a chave não está definida), `gc_config_set chave valor` (grava com arquivo temporário e `mv`), `gc_plugin_root`, `gc_plugin_version` (lê `version` do `plugin.json` ou de `app/VERSION`), `gc_quiet_net` (exporta `GIT_TERMINAL_PROMPT=0 GCM_INTERACTIVE=never`).
  - GitHub e repositórios: `gc_is_github_url url` (0/1), `gc_repo_is_github dir` (algum `remote.*.url` cru do GitHub), `gc_toplevel caminho` (sobe até uma pasta que exista e devolve o topo do repositório; código 1 se não houver repositório), `gc_norm_path p` (`\` vira `/`).
  - JSON: `gc_json_field json chave` (primeiro valor string da chave, desfazendo `\" \\ \/ \n \t \r`), `gc_json_escape s`.
  - Tempo: `gc_run_with_timeout seg cmd...` (código do comando, ou 124 quando estoura o tempo).
- Produces (`bin/git-commands`): descobre a própria pasta sem `dirname`, carrega `lib/*.sh` e despacha os subcomandos. Subcomando desconhecido mostra o uso e sai com código 1.

- [ ] **Step 1: Escrever os testes**

```bash
test_home_padrao_e_override() {
  assert_eq "$HOME/.git-commands" "$(gc home)" "padrão"; assert_file "$HOME/.git-commands" "criado"
  assert_eq "$SANDBOX/x" "$(GIT_COMMANDS_HOME=$SANDBOX/x gc home)" "override"
}
test_os_valido_e_override() {
  case "$(gc os)" in windows|mac|linux) ;; *) fail "os inválido";; esac
  assert_eq "mac" "$(GIT_COMMANDS_OS=mac gc os)" "override"
}
test_config_padroes() {
  assert_eq "on" "$(gc config get proactive)" ""; assert_eq "off" "$(gc config get auto_check)" ""
  assert_eq "30" "$(gc config get interval)" ""; assert_eq "" "$(gc config get projects_dir)" ""
}
test_config_guarda_valor_com_espaco_e_igual() {
  gc config set projects_dir "C:/Users/Nome Sobrenome/a=b"
  assert_eq "C:/Users/Nome Sobrenome/a=b" "$(gc config get projects_dir)" ""
  assert_contains "$(gc config list)" "projects_dir=C:/Users/Nome Sobrenome/a=b" ""
}
test_config_chave_invalida() { assert_exit 1 gc config set cor azul; }
test_is_github_url() {
  . "$PLUGIN/lib/common.sh"
  for u in https://github.com/a/b.git git@github.com:a/b.git ssh://git@github.com/a/b https://www.github.com/a/b; do
    gc_is_github_url "$u" || fail "devia aceitar $u"; done
  for u in https://gitlab.com/a/b https://notgithub.com/a/b /tmp/x.git; do
    gc_is_github_url "$u" && fail "devia recusar $u"; done; true
}
test_json_field_e_escape() {
  . "$PLUGIN/lib/common.sh"
  local j='{"session_id":"s1","tool_input":{"command":"git commit -m \"oi\""},"cwd":"C:\\Users\\a"}'
  assert_eq 'git commit -m "oi"' "$(gc_json_field "$j" command)" ""
  assert_eq 'C:\Users\a' "$(gc_json_field "$j" cwd)" ""
  assert_eq 'a\"b\\c' "$(gc_json_escape 'a"b\c')" ""
}
test_norm_path_windows() { . "$PLUGIN/lib/common.sh"; assert_eq "C:/Users/Nome Sobrenome/a.txt" "$(gc_norm_path 'C:\Users\Nome Sobrenome\a.txt')" ""; }
test_timeout() {
  . "$PLUGIN/lib/common.sh"
  gc_run_with_timeout 1 sleep 5; assert_eq "124" "$?" "estourou"
  gc_run_with_timeout 5 false; assert_eq "1" "$?" "código real"
}
test_toplevel_sobe_ate_pasta_existente() {
  . "$PLUGIN/lib/common.sh"; local r; r=$(make_local_repo l)
  assert_eq "$(cd "$r" && pwd)" "$(cd "$(gc_toplevel "$r/nao/existe/a.txt")" && pwd)" ""
}
```

- [ ] **Step 2: Rodar e ver falhar** — `bash tests/run.sh common` → FAIL.
- [ ] **Step 3: Implementar `lib/common.sh` e `bin/git-commands`.** Config em linhas `chave=valor`, lida com `sed -n "s/^chave=//p" | tail -n 1`. O timeout roda o comando em segundo plano com um vigia `sleep; kill`.
- [ ] **Step 4: Rodar e ver passar** — `bash tests/run.sh common` → todos PASS.
- [ ] **Step 5: Commit** — `git add --chmod=+x plugins/git-commands/bin/git-commands`; `git add plugins/git-commands/lib tests/test_common.sh`; `git commit -m "Adiciona o executável git-commands com home, os e config"`.

### Task 3: Conceitos aprendidos e glossário

**Files:**
- Create: `plugins/git-commands/lib/learned.sh`, `plugins/git-commands/reference/conceitos.md`
- Test: `tests/test_learned.sh`, `tests/test_concepts.sh`

**Interfaces:**
- Consumes: `gc_home`, `gc_plugin_root`.
- Produces: o subcomando `learned`. Glossário: uma seção `## <id>` por conceito, com 1 ou 2 frases em pt-BR simples, e só estes 19 ids: `repositorio git-config commit add readme gitignore remote push pull fetch branch merge conflito pull-request clone stash log diff publico-privado`. Nas skills e em `regras.md`, cada conceito é citado como `[conceito: <id>]`.

- [ ] **Step 1: Escrever os testes**

```bash
test_learned_ciclo() {
  assert_exit 1 gc learned has commit
  gc learned add commit branch commit
  assert_eq "$(printf 'branch\ncommit')" "$(gc learned list)" "ordenado e sem repetição"
  assert_exit 0 gc learned has branch
  gc learned forget branch; assert_exit 1 gc learned has branch
  gc learned reset; assert_eq "" "$(gc learned list)" ""
}
test_learned_id_desconhecido() { assert_exit 2 gc learned add bananas; }
test_learned_sobrevive_em_disco() { gc learned add push; assert_contains "$(cat "$(gc home)/learned")" "push" ""; }
test_glossario_tem_os_19_ids() {
  local ids; ids=$(sed -n 's/^## //p' "$PLUGIN/reference/conceitos.md" | sort | tr '\n' ' ')
  assert_eq "add branch clone commit conflito diff fetch git-config gitignore log merge publico-privado pull pull-request push readme remote repositorio stash " "$ids" ""
}
test_frase_do_git_init_literal() {
  assert_contains "$(cat "$PLUGIN/reference/conceitos.md")" "git init é criar ou inicializar um novo repositório Git em um diretório do seu computador." ""
}
test_conceitos_citados_existem() {
  local f id
  for id in $(cat "$PLUGIN"/skills/*/SKILL.md "$PLUGIN"/reference/regras.md 2>/dev/null | grep -o '\[conceito: [a-z-]*\]' | sed 's/\[conceito: //; s/\]//' | sort -u); do
    grep -q "^## $id\$" "$PLUGIN/reference/conceitos.md" || fail "conceito sem glossário: $id"; done; true
}
```

- [ ] **Step 2: Rodar e ver falhar** — `bash tests/run.sh learned; bash tests/run.sh concepts` → FAIL.
- [ ] **Step 3: Implementar `lib/learned.sh` e escrever `conceitos.md`.** O `add` só valida contra o glossário quando ele existe, porque a cópia `app/` não leva `reference/`.
- [ ] **Step 4: Rodar e ver passar.**
- [ ] **Step 5: Commit** — `git commit -m "Adiciona o registro de conceitos explicados e o glossário"`.

### Task 4: `doctor` (o que falta no computador)

**Files:**
- Create: `plugins/git-commands/lib/doctor.sh`
- Test: `tests/test_doctor.sh`

**Interfaces:**
- Consumes: `gc_os`, `gc_config_get`.
- Produces: `doctor` imprime exatamente estas chaves, nesta ordem: `os`, `git` (versão ou vazio), `git_ok` (`yes` se ≥ 2.28), `gh` (versão ou vazio), `gh_path`, `gh_on_path` (`yes`/`no`), `gh_auth` (`yes`/`no`), `gh_user`, `user_name`, `user_email`, `projects_dir`, `auto_check`, `interval`, `proactive`.
- Produces: `gc_gh_bin` procura nesta ordem: `GIT_COMMANDS_GH` (se definido, só ele vale); senão `command -v gh`; senão os caminhos padrão, que podem ser trocados por `GIT_COMMANDS_GH_DIRS` (separados por `:`). Os caminhos padrão são:
  - Windows: `/c/Program Files/GitHub CLI`, `$LOCALAPPDATA/Programs/GitHub CLI`;
  - macOS: `/opt/homebrew/bin`, `/usr/local/bin`;
  - Linux: `/usr/bin`, `/usr/local/bin`, `$HOME/.local/bin`.

- [ ] **Step 1: Escrever os testes**

Os testes usam um `gh` falso em `$SANDBOX/stub/gh`. Ele responde `gh version 2.62.0` para `--version`, sai com `$STUB_GH_AUTH` em `auth status` e imprime `tester` em `api user --jq .login`.

```bash
test_doctor_com_gh_logado() {
  make_gh_stub; local out; out=$(STUB_GH_AUTH=0 GIT_COMMANDS_GH="$SANDBOX/stub/gh" gc doctor)
  assert_contains "$out" "gh=2.62.0" ""; assert_contains "$out" "gh_auth=yes" ""; assert_contains "$out" "gh_user=tester" ""
  assert_contains "$out" "user_name=Teste" ""; assert_contains "$out" "git_ok=yes" ""
}
test_doctor_gh_nao_logado() { make_gh_stub; assert_contains "$(STUB_GH_AUTH=1 GIT_COMMANDS_GH="$SANDBOX/stub/gh" gc doctor)" "gh_auth=no" ""; }
test_doctor_sem_gh() { local out; out=$(GIT_COMMANDS_GH=/nao/existe gc doctor); assert_contains "$out" "gh=" ""; assert_contains "$out" "gh_path=" ""; }
test_doctor_gh_fora_do_path() {
  [ "$(dirname "$(command -v gh 2>/dev/null || echo /x/y)")" = "$(dirname "$(command -v git)")" ] && skip "gh e git na mesma pasta"
  make_gh_stub; local out; out=$(PATH="$(dirname "$(command -v git)"):/usr/bin:/bin" GIT_COMMANDS_GH_DIRS="$SANDBOX/stub" STUB_GH_AUTH=0 gc doctor)
  assert_contains "$out" "gh_path=$SANDBOX/stub/gh" ""; assert_contains "$out" "gh_on_path=no" ""
}
```

- [ ] **Step 2: Rodar e ver falhar** · **Step 3: Implementar `lib/doctor.sh` (e `make_gh_stub` em `helpers.sh`)** · **Step 4: Rodar e ver passar**
- [ ] **Step 5: Commit** — `git commit -m "Adiciona o diagnóstico do computador (doctor)"`.

### Task 5: `secrets` (arquivos com cara de senha)

**Files:**
- Create: `plugins/git-commands/lib/secrets.sh`
- Test: `tests/test_secrets.sh`

**Interfaces:**
- Produces: `secrets [--staged] [<repo>]` (repositório padrão: a pasta atual). Sem `--staged`, olha os arquivos modificados mais os não acompanhados e não ignorados. Com `--staged`, só os que estão na área de preparação. Saída: `caminho⇥motivo`. Os motivos são fixos:

| Motivo | O que dispara |
|---|---|
| `arquivo .env (senhas e chaves)` | nome `.env` ou `.env.*`, menos `.env.example` e `.env.sample` |
| `chave privada` | `*.pem`, `*.key`, `*.p12`, `*.pfx`, `id_rsa*`, `id_ed25519*`, ou conteúdo `-----BEGIN [A-Z ]*PRIVATE KEY-----` |
| `arquivo de credenciais` | `*credentials*.json`, `*secret*` |
| `parece um token do GitHub` | `ghp_[A-Za-z0-9]{36}`, `github_pat_` |
| `parece uma chave de API` | `AKIA[0-9A-Z]{16}`, `sk-[A-Za-z0-9]{20,}`, `xox[baprs]-` |

  O conteúdo só é lido em arquivos de texto de até 1 MB.

- [ ] **Step 1: Escrever os testes**

```bash
test_secrets_env() { local r; r=$(make_local_repo s); echo "SENHA=1" > "$r/.env"; local out; out=$(gc secrets "$r"); assert_eq "3" "$?" ""; assert_contains "$out" ".env	arquivo .env (senhas e chaves)" ""; }
test_secrets_env_example_ok() { local r; r=$(make_local_repo s); echo "SENHA=" > "$r/.env.example"; assert_exit 0 gc secrets "$r"; }
test_secrets_token_no_conteudo() { local r; r=$(make_local_repo s); echo "t='ghp_$(printf 'a%.0s' $(seq 36))'" > "$r/config.js"; assert_contains "$(gc secrets "$r")" "config.js	parece um token do GitHub" ""; }
test_secrets_staged_so_preparados() { local r; r=$(make_local_repo s); echo x > "$r/.env"; echo y > "$r/ok.txt"; git -C "$r" add ok.txt; assert_exit 0 gc secrets --staged "$r"; }
test_secrets_repo_limpo() { local r; r=$(make_local_repo s); assert_exit 0 gc secrets "$r"; }
```

- [ ] **Step 2: Ver falhar** · **Step 3: Implementar** · **Step 4: Ver passar**
- [ ] **Step 5: Commit** — `git commit -m "Adiciona o alerta de arquivos com senhas e chaves"`.

### Task 6: Regras, modelos de .gitignore e as skills `configurar` e `novo-projeto`

**Files:**
- Create: `plugins/git-commands/reference/regras.md`, `plugins/git-commands/reference/gitignore/{geral,node,python}.gitignore`, `plugins/git-commands/skills/configurar/SKILL.md`, `plugins/git-commands/skills/novo-projeto/SKILL.md`

**Interfaces:**
- Consumes: `doctor`, `learned`, `secrets`, `config`, `proactive` (a skill `configurar` só cita `proactive`, que nasce na Task 9).
- Produces: `regras.md`, que toda skill manda ler primeiro com `Leia ${CLAUDE_PLUGIN_ROOT}/reference/regras.md antes de qualquer passo.`

- [ ] **Step 1: Escrever `regras.md`, com uma seção por regra da spec**
  1. **Explicar na primeira vez.** Antes de um comando ligado a um conceito, rodar `git-commands learned has <id>`. Se não aprendeu: explicar com o texto do glossário (`${CLAUDE_PLUGIN_ROOT}/reference/conceitos.md`) e depois rodar `git-commands learned add <id>`. Se a pessoa perguntar o que é, explicar de novo, sempre.
  2. **Confirmar sempre:**
     - mensagem de commit sugerida + "Quer mudar alguma coisa nessa mensagem?";
     - tudo o que for escrito (README, `.gitignore`, descrição de PR) é mostrado antes;
     - tudo o que mexe no GitHub (criar repositório, push, abrir ou juntar PR) é mostrado e precisa de ok.
  3. **Sempre mandar o link do PR** (`gh pr view --json url --jq .url`).
  4. **Nunca perder trabalho.** Antes de um comando que apaga trabalho: explicar o que se perde, perguntar no chat e avisar que o Claude Code também vai pedir confirmação.
     - Nunca `pull` com rebase nem `push --force`.
     - Antes de commit e push: `git-commands secrets` e perguntar sobre cada arquivo encontrado.
  5. **Linguagem:** pt-BR simples (ou o idioma da pessoa), sempre com o nome do comando git junto.
  6. **Caminho A:** as regras de conversa valem na conversa com a pessoa; ajudantes e automações seguem sem interrupção.
- [ ] **Step 2: Escrever `skills/configurar/SKILL.md`**
  - Frontmatter `name: configurar`.
  - `description`: "Prepara o computador para git e GitHub: verifica git e GitHub CLI, login no GitHub, nome e e-mail do git e a pasta de projetos, e liga ou desliga o modo automático por projeto. Use quando a pessoa disser 'configurar git', 'instalar git', 'fazer login no GitHub', 'mudar minha pasta de projetos', 'desligar o git-commands neste projeto', ou quando outra skill do git-commands encontrar algo faltando."
  - O corpo cobre, a partir de `git-commands doctor`:
    - **Instalar o que falta, com o comando do sistema (`git-commands os`):**
      - git: Windows `winget install --id Git.Git -e --source winget`; macOS `xcode-select --install`; Linux `sudo apt install git`, `sudo dnf install git` ou `sudo pacman -S git`.
      - gh: Windows `winget install --id GitHub.cli -e --source winget`; macOS `brew install gh` (sem brew: https://cli.github.com); Linux: https://github.com/cli/cli/blob/trunk/docs/install_linux.md.
      - Se `gh_on_path=no` e há `gh_path`: dizer que já está instalado e pedir para reabrir o Claude.
    - **Conta e login (a pessoa faz):**
      - sem conta: guiar até https://github.com/signup;
      - sem login: num terminal, `gh auth login` → GitHub.com → HTTPS → "Login with a web browser" → copiar o código; depois o Claude confere com `gh auth status` e roda `gh auth setup-git`.
    - **Nome e e-mail:** se faltarem, perguntar e configurar com `git config --global` [conceito: git-config]. Sugerir o e-mail privado `<id>+<login>@users.noreply.github.com` (`gh api user --jq '.id,.login'`).
    - **Pasta de projetos:** perguntar, sugerindo `~/Documents/git` se `~/Documents` existir, senão `~/git`. Gravar com `git-commands config set projects_dir`.
    - **Modo automático:** desligar ou religar por projeto ou geral com `git-commands proactive off|on [--all]`.
- [ ] **Step 3: Escrever `skills/novo-projeto/SKILL.md`**
  - Frontmatter `name: novo-projeto`.
  - `description`: "Começa um projeto do zero e coloca no GitHub, ensinando cada passo: pergunta o nome do repositório, cria a pasta, git init, README, .gitignore, primeiro commit e envio para o GitHub com o link. Use quando a pessoa disser 'quero começar um projeto', 'criar um repositório', 'subir meu projeto pro GitHub pela primeira vez' ou 'iniciar git aqui'."
  - O corpo segue a spec 4.1, passos 1 a 9, nesta ordem:
    1. Rodar `doctor` e mandar para a skill `configurar` o que faltar.
    2. Conferir o git config.
    3. Perguntar o nome do repositório, se é público ou privado [conceito: publico-privado] e se a pessoa quer o Claude como colaborador. A resposta vai para `git config git-commands.coauthor true|false` depois do `git init`; se for sim, os commits levam a linha `Co-Authored-By: Claude <noreply@anthropic.com>`.
    4. Perguntar a pasta: se já existe uma pasta com o código, usar ela; se não, criar `<projects_dir>/<nome>`.
    5. `git init -b main` [conceito: repositorio]. Se já for repositório, dizer isso e pular.
    6. README [conceito: readme]: perguntar do que se trata, mostrar o rascunho e criar depois do ok. Se já existir, mostrar e perguntar se quer mudar.
    7. `.gitignore` [conceito: gitignore]: usar o modelo da pasta `reference/gitignore` pelo tipo de projeto (`package.json` → node; `pyproject.toml` ou `requirements.txt` → python; senão geral), mostrar antes e depois rodar `git-commands secrets`.
    8. Primeiro commit [conceito: add] [conceito: commit], com mensagem mostrada e confirmada.
    9. Criar no GitHub e enviar:
       - Pegar o dono com `gh api user --jq .login`.
       - Se `gh repo view <dono>/<nome>` existir, perguntar se quer usar esse ou escolher outro nome. Se o existente tiver commits, rodar `git pull origin main --allow-unrelated-histories --no-rebase` e resolver conflitos como na skill `atualizar` [conceito: conflito].
       - Senão, `gh repo create <nome> --public|--private --source . --remote origin` [conceito: remote].
       - `git push -u origin main` [conceito: push].
       - Mandar o link com `gh repo view --json url --jq .url`.
  - No fim, se `config get auto_check_asked` estiver vazio, perguntar se a pessoa quer a verificação automática (skill `verificacao-automatica`).
- [ ] **Step 4: Verificar** — `bash tests/run.sh concepts` → PASS; `claude plugin validate plugins/git-commands --strict` → `Validation passed`.
- [ ] **Step 5: Commit** — `git commit -m "Adiciona as regras e as skills configurar e novo-projeto"`.

### Task 7: Publicar a Parte 1 usando o próprio plugin

**Files:** nenhum novo (só o README pode mudar, se o fluxo pedir).

- [ ] **Step 1: Instalar a partir da pasta local**

Run: `claude plugin marketplace add "<caminho desta pasta>"` e depois `claude plugin install git-commands@git-commands`.
Expected: `Successfully installed plugin: git-commands@git-commands`.

- [ ] **Step 2: O Dev abre uma sessão nova nesta pasta e diz "quero colocar este projeto no GitHub"**

O Dev conduz a conversa e o Claude não faz nada por ele.
Critérios de aceite:
- (a) a skill `git-commands:novo-projeto` é usada;
- (b) o `gh` é instalado com o comando do Windows mostrado pelo plugin, e o Dev faz o login ele mesmo;
- (c) a pasta já ser repositório é tratada sem erro;
- (d) o nome `git-commands` e "público" são perguntados;
- (e) cada conceito é explicado uma única vez;
- (f) o repositório `ppdrada/git-commands` é criado, recebe o push e o link aparece no chat.

- [ ] **Step 3: Conferir de fora**

Run: `gh repo view ppdrada/git-commands --json visibility,url` → `"visibility":"PUBLIC"`.
Run: `git status -sb` → `## main...origin/main`.

- [ ] **Step 4: Anotar no fim deste plano** o que o Dev estranhou, como ajustes para a Parte 2.

---

# Parte 2 — Dia a dia e proteção (branch `parte-2-dia-a-dia`)

- [ ] **Antes da Task 8:** `git switch -c parte-2-dia-a-dia`, e em `plugin.json` trocar `version` para `0.2.0`.

### Task 8: Proteção contra comandos que apagam trabalho (hook `guard`)

**Files:**
- Create: `plugins/git-commands/lib/guard.sh`, `plugins/git-commands/hooks/{hooks.json,run-hook.cmd,guard}`
- Test: `tests/test_guard.sh`

**Interfaces:**
- Consumes: `gc_json_field`, `gc_json_escape`.
- Produces:
  - `gc_guard_reason "<comando>"` imprime o motivo e devolve 0 quando o comando é perigoso; devolve 1 quando é seguro. O subcomando `guard check` lê o comando do stdin.
  - Os motivos, fixos:
    - força: "força o envio e pode apagar commits que estão no GitHub"
    - branch: "apaga uma branch"
    - descarte: "descarta alterações que ainda não foram salvas"
    - limpeza: "apaga arquivos que o git não acompanha"
    - reescrita: "reescreve o histórico de commits"
    - stash: "apaga alterações guardadas no stash"
    - repositório: "apaga o repositório no GitHub"
  - Algoritmo:
    1. Troca `&&` e `||` por `;` e quebra em `;`, `|` e quebras de linha.
    2. Em cada pedaço, separa por espaços, pula prefixos (`VAR=x`, `sudo`, `command`, `exec`, `&`) e exige que a primeira palavra seja `git`, `git.exe` ou `gh`, `gh.exe` (pelo nome do arquivo, sem diferenciar maiúsculas).
    3. Pula as opções globais do git (`-C x`, `-c x`, `--git-dir[=x]`, `--work-tree[=x]`, `--namespace[=x]`, `--no-pager`, `-p`, `--paginate`, `--bare`).
    4. Aplica as regras do subcomando:
       - `push`: `--force*`, `-f`, `--mirror` ou refspec com `+` → força; `--delete`, `-d` ou refspec com `:` → branch.
       - `reset --hard`, `checkout` com `--`, `.`, `-f` ou `--force`, `restore` sem `--staged`/`-S` ou com `--worktree`/`-W`, `switch --discard-changes|-f|--force` e `worktree remove --force|-f` → descarte.
       - `clean` com `--force` ou opção curta que contém `f` → limpeza.
       - `rebase` (menos `--continue`), `pull --rebase|-r` e `filter-branch` → reescrita.
       - `stash drop|clear` → stash.
       - `branch -d|-D|--delete|-f|--force` → branch.
       - `gh repo delete` → repositório; `gh pr merge` com `--delete-branch` ou `-d` → branch.
  - Hook `guard` (PreToolUse `Bash|PowerShell`): se o motivo existir, imprime `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"git-commands: este comando pode apagar trabalho (<motivo>). Só confirme se você pediu isso."}}`. Se não, não imprime nada. Sai sempre com 0.
  - `run-hook.cmd`, poliglota no modelo do superpowers (MIT):
    - Parte cmd: procura `bash.exe` em `%ProgramFiles%\Git\bin`, `%ProgramFiles(x86)%\Git\bin` e `%LOCALAPPDATA%\Programs\Git\bin`; se não achar, `exit /b 0`; se achar, roda `"%BASH_EXE%" "%~dp0%~1" %2 … %9` e devolve o código.
    - Parte bash: descobre a pasta de `$0` sem `dirname` e roda `exec "${BASH:-bash}" "$dir/$1" "${@:2}"`.
  - `hooks.json`, com este conteúdo: `{"hooks":{"PreToolUse":[{"matcher":"Bash|PowerShell","hooks":[{"type":"command","command":"\"${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd\" guard","timeout":10}]}]}}`.

- [ ] **Step 1: Escrever os testes**

```bash
test_guard_tabela() {
  local perigosos=(
    "git push --force|força" "git push -f origin main|força" "git push --force-with-lease|força" "git push origin +main|força"
    "git push origin :feature|apaga uma branch" "git push origin --delete feature|apaga uma branch"
    "git -C ../x reset --hard HEAD~1|descarta" "cd app && git reset --hard|descarta" "git checkout -- .|descarta"
    "git checkout .|descarta" "git checkout -f main|descarta" "git restore app.js|descarta"
    "git restore --staged --worktree app.js|descarta" "git switch --discard-changes main|descarta"
    "git worktree remove --force ../wt|descarta" "Git.exe clean -fdx|não acompanha" "git rebase main|reescreve"
    "git pull --rebase|reescreve" "git filter-branch --tree-filter x|reescreve" "git stash drop|stash" "git stash clear|stash"
    "git branch -D feature|apaga uma branch" "git branch -d feature|apaga uma branch"
    "gh repo delete ppdrada/x --yes|repositório" "gh pr merge 3 --delete-branch|apaga uma branch")
  local seguros=("git status" "git push" "git push -u origin feature" "git pull --ff-only" "git checkout -b nova"
    "git switch -c nova" "git checkout main" "git restore --staged app.js" 'git commit -m "reset --hard explicado"'
    "git rebase --continue" "git stash" "git stash pop" "git branch" "git branch -m velho novo" "ls -la"
    "echo git push --force" "gh pr create --title x" "gh pr merge 3 --merge")
  local c; for c in "${perigosos[@]}"; do local out; out=$(printf '%s' "${c%%|*}" | gc guard check) || fail "devia ser perigoso: ${c%%|*}"; assert_contains "$out" "${c##*|}" "${c%%|*}"; done
  for c in "${seguros[@]}"; do printf '%s' "$c" | gc guard check >/dev/null && fail "devia ser seguro: $c"; done; true
}
test_guard_hook_pede_confirmacao() {
  local out; out=$(printf '%s' '{"tool_name":"Bash","tool_input":{"command":"git reset --hard"}}' | CLAUDE_PLUGIN_ROOT="$PLUGIN" bash "$PLUGIN/hooks/run-hook.cmd" guard)
  assert_contains "$out" '"permissionDecision":"ask"' ""; assert_contains "$out" "descarta alterações que ainda não foram salvas" ""
}
test_guard_hook_silencioso_em_comando_seguro() { assert_eq "" "$(printf '%s' '{"tool_input":{"command":"git status"}}' | bash "$PLUGIN/hooks/run-hook.cmd" guard)" ""; }
```

- [ ] **Step 2: Ver falhar** · **Step 3: Implementar** · **Step 4: Ver passar** e depois `claude plugin validate plugins/git-commands --strict`.
- [ ] **Step 5: Teste real.** Numa sessão com o plugin, pedir para rodar `git stash drop` num repositório de teste. Expected: o Claude Code mostra a confirmação com o motivo.
- [ ] **Step 6: Commit** — executáveis com `--chmod=+x` (`run-hook.cmd`, `guard`); `git commit -m "Adiciona a proteção contra comandos que apagam trabalho"`.

### Task 9: Modo automático por projeto e contexto na abertura (hook `session-start`)

**Files:**
- Create: `plugins/git-commands/lib/proactive.sh`, `plugins/git-commands/hooks/session-start`
- Modify: `plugins/git-commands/hooks/hooks.json`
- Test: `tests/test_proactive.sh`, `tests/test_session_start.sh`

**Interfaces:**
- Consumes: `gc_toplevel`, `gc_repo_is_github`, `gc_config_get`, `learned list`.
- Produces:
  - `proactive`: o geral fica em `config proactive`; os projetos desligados ficam em `proactive-off`, um topo de repositório por linha. `gc_proactive_applies dir` devolve 0 quando o geral está `on`, o repositório não está desligado e é do GitHub.
  - Hook `session-start`: lê `cwd` do JSON. Se `gc_proactive_applies cwd`, imprime em texto simples (sem JSON) o bloco abaixo. Se não, não imprime nada. Na Task 14 ele também ganha o aviso de novidades.

```
git-commands está ativo neste projeto (<nome>), que está ligado ao GitHub.
Ao conversar com a pessoa sobre este projeto, siga as regras do git-commands (detalhes em <CLAUDE_PLUGIN_ROOT>/reference/regras.md):
- Antes de começar uma mudança nova, pergunte se ela quer criar uma branch (skill git-commands:branch-e-pr).
- Commit: mostre a mensagem sugerida e pergunte se ela quer mudar; só faça o commit depois do ok (skill git-commands:salvar).
- Tudo que mexe no GitHub (push, criar repositório, abrir ou juntar PR): mostre o que vai fazer e peça ok. Sempre mande o link do PR.
- Quando a mudança terminar, ofereça salvar (commit) e, se estiver numa branch, abrir o PR.
- Na primeira vez que um conceito de git aparecer, explique em 1 ou 2 frases e registre com `git-commands learned add <id>`. Conceitos já explicados para esta pessoa: <lista separada por vírgula, ou "nenhum">.
- Essas regras valem na conversa com a pessoa; ajudantes e automações (subagentes) seguem sem interrupção.
```

  - Entrada a acrescentar em `hooks.json`: `"SessionStart":[{"matcher":"startup|resume|clear|compact","hooks":[{"type":"command","command":"\"${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd\" session-start","timeout":10}]}]`.

- [ ] **Step 1: Escrever os testes**

```bash
ss() { printf '{"cwd":"%s","source":"startup"}' "$1" | CLAUDE_PLUGIN_ROOT="$PLUGIN" bash "$PLUGIN/hooks/run-hook.cmd" session-start; }
test_proactive_por_projeto() {
  local a b; a=$(make_github_pair a); b=$(make_github_pair b)
  assert_eq "on" "$(gc proactive status "$a")" ""; gc proactive off "$a"
  assert_eq "off" "$(gc proactive status "$a")" ""; assert_eq "on" "$(gc proactive status "$b")" ""
  gc proactive off --all; assert_eq "off" "$(gc proactive status "$b")" ""; gc proactive on --all; assert_eq "on" "$(gc proactive status "$b")" ""
}
test_proactive_fora_de_repo_sem_all() { assert_exit 1 gc proactive off; }
test_ss_fora_de_repo_silencioso() { assert_eq "" "$(ss "$SANDBOX")" ""; }
test_ss_repo_nao_github_silencioso() { assert_eq "" "$(ss "$(make_local_repo l)")" ""; }
test_ss_repo_github_injeta_regras() {
  local r; r=$(make_github_pair app); local out; out=$(ss "$r")
  assert_contains "$out" "git-commands está ativo neste projeto (app)" ""; assert_contains "$out" "Conceitos já explicados para esta pessoa: nenhum" ""
  gc learned add commit push; assert_contains "$(ss "$r")" "commit, push" ""
}
test_ss_respeita_desligado() { local r; r=$(make_github_pair app); gc proactive off "$r"; assert_eq "" "$(ss "$r")" ""; }
test_ss_cwd_com_barras_invertidas() { local r; r=$(make_github_pair app); [ "$(gc os)" = windows ] || skip "só no Windows"; assert_contains "$(ss "$(native_path "$r" | sed 's#/#\\\\#g')")" "(app)" ""; }
```

- [ ] **Step 2: Ver falhar** · **Step 3: Implementar** · **Step 4: Ver passar** e `claude plugin validate plugins/git-commands --strict`.
- [ ] **Step 5: Commit** — `git commit -m "Adiciona o modo automático por projeto e o contexto na abertura"`.

### Task 10: Skills `salvar`, `branch-e-pr` e `comandos`

**Files:**
- Create: `plugins/git-commands/skills/{salvar,branch-e-pr,comandos}/SKILL.md`

**Interfaces:**
- Consumes: `regras.md`, `secrets`, `learned`, `updates pull` (Task 12; até lá, a skill `branch-e-pr` usa `git pull --ff-only`).

- [ ] **Step 1: Escrever `salvar`**
  - `description`: "Salva o trabalho (add + commit) e envia para o GitHub (push), sempre mostrando a mensagem de commit sugerida e perguntando se a pessoa quer mudar antes de fazer. Use quando a pessoa disser 'salva meu trabalho', 'faz um commit', 'commita', 'manda pro GitHub', 'envia as alterações' ou 'dar push'."
  - O corpo cobre:
    - Mostrar `git status --short` em palavras simples [conceito: add] [conceito: commit].
    - Rodar `git-commands secrets` e perguntar sobre cada arquivo encontrado, oferecendo colocá-lo no `.gitignore`.
    - Sugerir a mensagem em pt-BR, no imperativo, com até 72 caracteres. Perguntar "Quer mudar alguma coisa nessa mensagem?" e só fazer `git add` e `git commit` depois do ok, aceitando a mensagem editada.
    - Claude como colaborador: ler `git config --get git-commands.coauthor`. Vazio → perguntar uma vez e gravar `true` ou `false` no repositório. `true` → a mensagem mostrada já leva a linha `Co-Authored-By: Claude <noreply@anthropic.com>`.
    - Oferecer o push [conceito: push], usando `-u origin <branch>` se faltar upstream. Se o push for recusado, explicar e ir para a skill `atualizar` (nunca forçar).
    - Se existir PR aberto para a branch, mandar o link.
- [ ] **Step 2: Escrever `branch-e-pr`**
  - `description`: "Cuida de branches e pull requests: ao começar uma mudança nova pergunta se a pessoa quer criar uma branch, cria, abre o PR e sempre manda o link, junta o PR e limpa a branch. Use quando a pessoa disser 'vou mexer em…', 'criar uma branch', 'abrir um PR', 'pull request', 'juntar o PR' ou 'merge', ou quando uma mudança nova começar num projeto do GitHub."
  - O corpo cobre:
    - **Começar:** perguntar "Quer criar uma branch para isso?" [conceito: branch]. Sugerir um nome em kebab-case a partir da mudança, confirmar, atualizar a `main` e rodar `git switch -c <nome>`. Se a resposta for não, seguir na `main`.
    - **Terminar:** usar a skill `salvar` e o push. Escrever título e descrição do PR, mostrar, e depois do ok rodar `gh pr create --base main --head <branch>` [conceito: pull-request]. Mandar o link SEMPRE.
    - **Juntar:** a pessoa junta pelo site ou pede ao plugin. Nesse caso: mostrar o que vai acontecer, pedir ok, `gh pr merge <n> --merge` [conceito: merge], `git switch main`, atualizar. Depois oferecer apagar a branch local e a remota, avisando que o Claude Code vai pedir confirmação.
    - Toda menção a PR leva o link.
- [ ] **Step 3: Escrever `comandos`**
  - `description`: "Explica e roda os outros comandos básicos do git para quem está começando: status, histórico (log), diferença (diff), guardar temporariamente (stash), desfazer alterações (restore), copiar um projeto do GitHub (clone) e ver o remote. Use quando a pessoa perguntar 'o que é <comando>?', 'o que mudou?', 'ver histórico', 'desfazer', 'baixar um projeto do GitHub' ou 'git status'."
  - O corpo cobre:
    - status; log com `git log --oneline -n 10` [conceito: log];
    - diff [conceito: diff]: resumo primeiro, linha a linha só se pedir;
    - stash save/list/pop [conceito: stash], lembrando que `drop` apaga;
    - restore: explica o que se perde, pergunta e avisa da confirmação;
    - clone [conceito: clone] com `gh repo clone <dono/nome>` para dentro da pasta de projetos;
    - `git remote -v` [conceito: remote];
    - "o que é X?": explicar pelo glossário, mesmo que já tenha sido explicado.
- [ ] **Step 3b: Ajustes do teste da Parte 1** — aplicar os 3 ajustes da seção "Ajustes do teste da Parte 1", no fim deste plano (skill `configurar` e `regras.md`), com teste de cenário antes e depois.
- [ ] **Step 4: Verificar** — `bash tests/run.sh concepts` e `claude plugin validate plugins/git-commands --strict`.
- [ ] **Step 5: Commit** — `git commit -m "Adiciona as skills salvar, branch-e-pr e comandos"`.

### Task 11: Publicar a Parte 2 por PR, usando o plugin

- [ ] **Step 1:** atualizar o plugin instalado: `claude plugin marketplace update git-commands` e depois `claude plugin update git-commands@git-commands`.
- [ ] **Step 2: O Dev, numa sessão nova nesta pasta, diz "terminei a parte 2, manda pro GitHub"**

Critérios de aceite:
- (a) a mensagem de cada commit pendente é mostrada e confirmada;
- (b) o PR é aberto da `parte-2-dia-a-dia` para a `main`, e o link aparece;
- (c) ao juntar, a `main` local é atualizada;
- (d) apagar a branch gera a confirmação do Claude Code (hook `guard`).
- [ ] **Step 3: Conferir** — `gh pr list --state merged --head parte-2-dia-a-dia` → 1 PR. `git log --oneline -1 main` → o commit de merge.

---

# Parte 3 — Atualizações e verificação automática (branch `parte-3-atualizacoes`)

- [ ] **Antes da Task 12:** `git switch main && git pull --ff-only && git switch -c parte-3-atualizacoes`, e `version` para `0.3.0`.

### Task 12: `updates` (varrer, novidades, detalhe, atualizar com segurança)

**Files:**
- Create: `plugins/git-commands/lib/updates.sh`
- Test: `tests/test_updates.sh`

**Interfaces:**
- Consumes: `gc_config_get projects_dir`, `gc_repo_is_github`, `gc_run_with_timeout`, `gc_quiet_net`.
- Produces: os subcomandos `updates scan | news | detail | pull`, seguindo o contrato.
  - **scan**:
    - Descobre os repositórios com `find <pasta> -maxdepth 3 -type d -name .git`. Ignora `.git` que for arquivo (worktree) e caminhos com `/node_modules/`. Ordena.
    - O fetch usa limite de 20 segundos por repositório.
    - `alterados` = linhas de `git status --porcelain`.
    - `--save` só vale sem `--repo`: grava `status.tsv` e `status.time`.
    - `--repo` fora do GitHub sai com código 1 e "não é um repositório do GitHub".
  - **news**: para cada linha salva com estado `novidades` ou `divergiu`, recalcula `HEAD..@{u}` sem rede e só imprime se continuar maior que 0.
  - **detail**: imprime as seções `== Novidades no GitHub (<n> commits)` (`hash curto⇥autor⇥data⇥assunto`), `== Arquivos que mudaram no GitHub` (`git diff --stat HEAD...@{u}`), `== Suas alterações ainda sem commit` e `== Mexidos dos dois lados (podem dar conflito)`.
  - **pull**:
    - Código 3 se há alteração em arquivo acompanhado (`--untracked-files=no`), ou se o git recusar por causa de arquivo não acompanhado.
    - Código 4 se divergiu; 5 se não há upstream; 6 se o fetch falhar.
    - Senão roda `git pull --ff-only` e imprime "atualizado: +<n> commit(s)" ou "já estava em dia".

- [ ] **Step 1: Escrever os testes**

```bash
linha() { gc updates scan --dir "$SANDBOX/projetos" | grep "	$1	"; }
test_scan_estados_basicos() {
  make_github_pair emdia >/dev/null
  local a; a=$(make_github_pair atras); push_remote_commit atras n1.txt "um"; push_remote_commit atras n2.txt "dois"
  local f; f=$(make_github_pair frente); echo x > "$f/x.txt"; git -C "$f" add x.txt; git -C "$f" commit -qm local
  local d; d=$(make_github_pair diverge); push_remote_commit diverge r.txt "remoto"; echo y > "$d/y.txt"; git -C "$d" add y.txt; git -C "$d" commit -qm local
  make_local_repo semremote >/dev/null
  assert_contains "$(linha emdia)" "	0	0	0	em-dia" ""; assert_contains "$(linha atras)" "	0	2	0	novidades" ""
  assert_contains "$(linha frente)" "	1	0	0	a-frente" ""; assert_contains "$(linha diverge)" "	1	1	0	divergiu" ""
  assert_eq "" "$(linha semremote)" "repositório fora do GitHub é ignorado"
}
test_scan_estados_estranhos() {
  local h; h=$(make_github_pair destacado); git -C "$h" checkout -q --detach
  local o; o=$(make_github_pair ocupado); : > "$(git -C "$o" rev-parse --git-path MERGE_HEAD)"
  mkdir -p "$SANDBOX/projetos/vazio" && git -C "$SANDBOX/projetos/vazio" init -q && git -C "$SANDBOX/projetos/vazio" remote add origin https://github.com/teste/vazio.git
  local w; w=$(make_github_pair comwt); git -C "$w" worktree add -q "$w/wt" -b wt
  local out; out=$(gc updates scan --no-fetch --dir "$SANDBOX/projetos")   # sem rede: "vazio" não tem remote local
  assert_eq "1" "$(printf '%s\n' "$out" | grep -c '	destacado	.*	destacado$')" "HEAD destacado"
  assert_eq "1" "$(printf '%s\n' "$out" | grep -c '	ocupado	.*	ocupado$')" "merge em andamento"
  assert_eq "1" "$(printf '%s\n' "$out" | grep -c '	vazio	.*	sem-commits$')" "sem commits"
  assert_eq "1" "$(printf '%s\n' "$out" | grep -c comwt)" "worktree não aparece duas vezes"
}
test_scan_remote_inacessivel_vira_erro() { local r; r=$(make_github_pair caiu); rm -rf "$SANDBOX/remotes/caiu.git"; assert_contains "$(linha caiu)" "erro" ""; }
test_scan_sem_pasta_configurada() { assert_exit 1 gc updates scan; }
test_save_e_news() {
  gc config set projects_dir "$SANDBOX/projetos"; local a; a=$(make_github_pair atras); push_remote_commit atras n.txt "um"
  gc updates scan --save >/dev/null; assert_contains "$(gc updates news)" "atras	1	" ""
  gc updates pull "$a" >/dev/null; assert_exit 1 gc updates news
}
test_pull_seguro() {
  local a; a=$(make_github_pair a); push_remote_commit a novo.txt "um"
  echo solto > "$a/solto.txt"; assert_contains "$(gc updates pull "$a")" "atualizado: +1" "arquivo solto não atrapalha"
  push_remote_commit a README.md "remoto mexe no README"; echo "meu" >> "$a/README.md"
  gc updates pull "$a" >/dev/null; assert_eq "3" "$?" "alteração sem commit"; assert_contains "$(cat "$a/README.md")" "meu" "nada perdido"
}
test_pull_divergiu_e_sem_upstream() {
  local d; d=$(make_github_pair d); push_remote_commit d r.txt "r"; echo y > "$d/y.txt"; git -C "$d" add y.txt; git -C "$d" commit -qm l
  gc updates pull "$d" >/dev/null; assert_eq "4" "$?" ""
  git -C "$d" switch -qc sozinha; gc updates pull "$d" >/dev/null; assert_eq "5" "$?" ""
}
test_detail_secoes() {
  local a; a=$(make_github_pair a); push_remote_commit a README.md "Muda o README"; echo "meu" >> "$a/README.md"
  local out; out=$(gc updates detail "$a")
  assert_contains "$out" "== Novidades no GitHub (1 commits)" ""; assert_contains "$out" "Muda o README" ""
  assert_contains "$out" "== Mexidos dos dois lados (podem dar conflito)" ""; assert_contains "$out" "README.md" ""
}
```

- [ ] **Step 2: Ver falhar** · **Step 3: Implementar** · **Step 4: Ver passar**
- [ ] **Step 5: Commit** — `git commit -m "Adiciona a verificação e a atualização segura de repositórios"`.

### Task 13: Checagem antes da primeira edição (hook `pre-edit`)

**Files:**
- Create: `plugins/git-commands/hooks/pre-edit`
- Modify: `plugins/git-commands/hooks/hooks.json`
- Test: `tests/test_pre_edit.sh`

**Interfaces:**
- Consumes: `gc_json_field`, `gc_toplevel`, `gc_proactive_applies`, `updates scan --repo`.
- Produces: o hook PreToolUse para `Edit|Write|MultiEdit|NotebookEdit`.
  1. Se `agent_id` vier preenchido, sai sem nada (Caminho A).
  2. Caminho: `file_path` ou `notebook_path`, normalizado.
  3. Se não for repositório do GitHub, ou o modo automático não valer, sai.
  4. Marcador `sessions/<session_id só [A-Za-z0-9_-]>/<cksum do topo>`: se já existe, sai; se não, cria.
  5. Faz o fetch com limite de 8 segundos. Se falhar, sai sem bloquear.
  6. Se behind > 0, imprime `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"git-commands: o projeto <nome> tem <n> novidade(s) no GitHub que ainda não estão neste computador. Antes de editar, pare e pergunte à pessoa se ela quer atualizar agora, ver a diferença antes ou deixar para depois (skill git-commands:atualizar). Depois da resposta dela, pode editar normalmente: este aviso não volta nesta sessão."}}`.
  7. O hook `session-start` apaga marcadores com mais de 2 dias.
  - Entrada a acrescentar em `hooks.json`: `{"matcher":"Edit|Write|MultiEdit|NotebookEdit","hooks":[{"type":"command","command":"\"${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd\" pre-edit","timeout":15}]}`.

- [ ] **Step 1: Escrever os testes**

```bash
pe() { printf '{"session_id":"%s","tool_name":"Edit","tool_input":{"file_path":"%s"}%s}' "$1" "$2" "${3:-}" | CLAUDE_PLUGIN_ROOT="$PLUGIN" bash "$PLUGIN/hooks/run-hook.cmd" pre-edit; }
test_pre_edit_bloqueia_uma_vez_quando_atras() {
  local a; a=$(make_github_pair app); push_remote_commit app n.txt "um"
  local out; out=$(pe s1 "$a/README.md"); assert_contains "$out" '"permissionDecision":"deny"' ""; assert_contains "$out" "o projeto app tem 1 novidade(s)" ""
  assert_eq "" "$(pe s1 "$a/README.md")" "não volta na mesma sessão"
}
test_pre_edit_em_dia_libera() { local a; a=$(make_github_pair app); assert_eq "" "$(pe s1 "$a/README.md")" ""; }
test_pre_edit_subagente_libera() { local a; a=$(make_github_pair app); push_remote_commit app n.txt "um"; assert_eq "" "$(pe s1 "$a/README.md" ',"agent_id":"ag1"')" ""; }
test_pre_edit_desligado_libera() { local a; a=$(make_github_pair app); push_remote_commit app n.txt "um"; gc proactive off "$a"; assert_eq "" "$(pe s1 "$a/README.md")" ""; }
test_pre_edit_remote_inacessivel_libera() { local a; a=$(make_github_pair app); rm -rf "$SANDBOX/remotes/app.git"; assert_eq "" "$(pe s1 "$a/README.md")" ""; }
test_pre_edit_arquivo_novo_em_pasta_nova() { local a; a=$(make_github_pair app); push_remote_commit app n.txt "um"; assert_contains "$(pe s2 "$a/nova/pasta/x.txt")" "deny" ""; }
test_pre_edit_caminho_windows() {
  [ "$(gc os)" = windows ] || skip "só no Windows"; local a; a=$(make_github_pair app); push_remote_commit app n.txt "um"
  assert_contains "$(pe s3 "$(native_path "$a" | sed 's#/#\\\\#g')\\\\README.md")" "deny" ""
}
```

- [ ] **Step 2: Ver falhar** · **Step 3: Implementar** · **Step 4: Ver passar** e `claude plugin validate plugins/git-commands --strict`.
- [ ] **Step 5: Confirmar que `agent_id` só aparece em subagentes.** Rodar uma sessão real com um hook temporário que grava o JSON de entrada; comparar uma edição feita pelo Claude e uma feita por um subagente. Expected: só a do subagente tem `agent_id`. Se a da conversa principal também tiver, trocar o critério do passo 1 pelo campo que diferenciar e ajustar `test_pre_edit_subagente_libera`.
- [ ] **Step 6: Commit** — `git add --chmod=+x plugins/git-commands/hooks/pre-edit`; `git commit -m "Adiciona a checagem de novidades antes da primeira edição"`.

### Task 14: Aviso de novidades na abertura e cópia para o agendador

**Files:**
- Modify: `plugins/git-commands/hooks/session-start`, `tests/test_session_start.sh`

**Interfaces:**
- Consumes: `updates news`, `gc_plugin_version`.
- Produces:
  - Com `auto_check=on` e `updates news` não vazio, o `session-start` acrescenta, antes do bloco de regras:
    ```
    Novidades no GitHub: <nome> (<n>), <nome> (<n>).
    Na sua primeira resposta, conte isso à pessoa em uma frase e pergunte se ela quer ver agora (skill git-commands:atualizar). Não atualize nada sozinho.
    ```
  - Com `auto_check=on` e `app/VERSION` diferente da versão do plugin, recopia `bin`, `lib`, `scheduler` e `VERSION` para `app/`.
  - O hook não acessa a rede.

- [ ] **Step 1: Escrever os testes**

```bash
test_ss_avisa_novidades_so_com_auto_check() {
  gc config set projects_dir "$SANDBOX/projetos"; local a; a=$(make_github_pair app); push_remote_commit app n.txt "um"; gc updates scan --save >/dev/null
  assert_not_contains "$(ss "$SANDBOX")" "Novidades no GitHub" "auto_check desligado"
  gc config set auto_check on; assert_contains "$(ss "$SANDBOX")" "Novidades no GitHub: app (1)." ""
  gc updates pull "$a" >/dev/null; assert_not_contains "$(ss "$SANDBOX")" "Novidades" "some depois de atualizar"
}
test_ss_recopia_app_quando_versao_muda() {
  gc config set auto_check on; ss "$SANDBOX" >/dev/null
  assert_file "$(gc home)/app/bin/git-commands" ""; assert_eq "$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$PLUGIN/.claude-plugin/plugin.json")" "$(cat "$(gc home)/app/VERSION")" ""
}
test_ss_rapido_sem_rede() {
  gc config set projects_dir "$SANDBOX/projetos"; gc config set auto_check on; local i; for i in 1 2 3; do make_github_pair "r$i" >/dev/null; done
  gc updates scan --save >/dev/null; rm -rf "$SANDBOX/remotes"; local t0; t0=$(date +%s); ss "$SANDBOX/projetos/r1" >/dev/null
  [ $(( $(date +%s) - t0 )) -le 5 ] || fail "session-start demorou mais de 5s"
}
```

- [ ] **Step 2: Ver falhar** · **Step 3: Implementar** · **Step 4: Ver passar**
- [ ] **Step 5: Commit** — `git commit -m "Avisa as novidades na abertura do Claude"`.

### Task 15: Verificação automática nos três sistemas (`schedule`)

**Files:**
- Create: `plugins/git-commands/lib/schedule.sh`, `plugins/git-commands/scheduler/run-scheduled`
- Test: `tests/test_schedule.sh`

**Interfaces:**
- Consumes: `gc_os`, `gc_home`, `gc_config_set`, `updates scan --save`.
- Produces:
  - `schedule enable [min]` (de 5 a 1440; padrão `interval`): copia o `app/`, cria o agendamento do sistema e grava `auto_check=on`, `interval=<min>` e `auto_check_asked=yes`.
  - `schedule disable`: remove o agendamento e grava `auto_check=off`.
  - `schedule status`: consulta o sistema e imprime `ligado <interval>` ou `desligado`.
  - Com `GIT_COMMANDS_SCHEDULE_DRY_RUN=1`, `launchctl`, `powershell.exe` e `schtasks.exe` não são executados: os comandos são impressos no stdout, os arquivos são gravados normalmente e o `status` olha esses arquivos (plist, marcador do Windows). O `crontab` sempre é executado; os testes trocam ele por um falso com `make_crontab_stub`.
  - **Windows:** grava `<home>/schedule.ps1` e roda `powershell.exe -NoProfile -ExecutionPolicy Bypass -File <ps1>`. O script registra a tarefa `git-commands-verificar`:
    - ação `conhost.exe` com argumentos `--headless "<cygpath -w bash>" -l "<cygpath -w app/scheduler/run-scheduled>"`;
    - gatilho único 1 minuto depois, com `-RepetitionInterval (New-TimeSpan -Minutes <min>)`;
    - `-StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 10)`.
    - Para remover: `Unregister-ScheduledTask -TaskName git-commands-verificar -Confirm:$false`. No dry-run, um marcador `<home>/dry-run-windows-task` representa a tarefa.
  - **macOS:** `$HOME/Library/LaunchAgents/com.git-commands.verificar.plist`, com `Label` igual a esse nome, `ProgramArguments` = `["/bin/bash","-l","<app>/scheduler/run-scheduled"]`, `StartInterval` = `<min*60>`, `RunAtLoad` = `true`, e `StandardOutPath`/`StandardErrorPath` apontando para `<home>/check.log`. Carregar: `launchctl bootout gui/<uid>/com.git-commands.verificar` (ignorando erro) e depois `launchctl bootstrap gui/<uid> <plist>`. Remover: `bootout` e apagar o plist.
  - **Linux:** a linha `<cron> /bin/bash -l "<app>/scheduler/run-scheduled" # git-commands` no crontab do usuário, mantendo as outras linhas. `<cron>` é `*/<min> * * * *` para menos de 60, `0 */<min/60> * * *` para múltiplos de 60 até 1380, e `0 0 * * *` para 1440. Sem `crontab`, sai com código 1 e "este Linux não tem cron instalado".
  - `run-scheduled`:
    - coloca `/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/mingw64/bin` no começo do PATH e chama `gc_quiet_net`;
    - roda `<app>/bin/git-commands updates scan --save`;
    - acrescenta `AAAA-MM-DD HH:MM:SS verificação ok` (ou `… erro <código>`) em `check.log` e mantém só as últimas 500 linhas.

- [ ] **Step 1: Escrever os testes**

```bash
dr() { GIT_COMMANDS_SCHEDULE_DRY_RUN=1 GIT_COMMANDS_OS="$1" gc schedule "${@:2}"; }
test_schedule_mac() {
  dr mac enable 30 >/dev/null; local p="$HOME/Library/LaunchAgents/com.git-commands.verificar.plist"
  assert_contains "$(cat "$p")" "<integer>1800</integer>" ""; assert_contains "$(cat "$p")" "scheduler/run-scheduled" ""
  assert_eq "ligado 30" "$(dr mac status)" ""; dr mac disable >/dev/null; [ -e "$p" ] && fail "plist ficou"; assert_eq "desligado" "$(dr mac status)" ""
}
test_schedule_linux_preserva_outras_linhas() {
  make_crontab_stub "0 5 * * * backup"   # crontab falso que guarda em $SANDBOX/crontab.txt
  dr linux enable 30 >/dev/null; assert_contains "$(cat "$SANDBOX/crontab.txt")" "*/30 * * * * /bin/bash -l" ""; assert_contains "$(cat "$SANDBOX/crontab.txt")" "0 5 * * * backup" ""
  dr linux enable 120 >/dev/null; assert_contains "$(cat "$SANDBOX/crontab.txt")" "0 */2 * * *" ""; assert_eq "1" "$(grep -c '# git-commands' "$SANDBOX/crontab.txt")" "sem duplicar"
  dr linux disable >/dev/null; assert_not_contains "$(cat "$SANDBOX/crontab.txt")" "git-commands" ""; assert_contains "$(cat "$SANDBOX/crontab.txt")" "backup" ""
}
test_schedule_windows_script() {
  dr windows enable 30 >/dev/null; local s; s=$(cat "$(gc home)/schedule.ps1")
  assert_contains "$s" "git-commands-verificar" ""; assert_contains "$s" "New-TimeSpan -Minutes 30" ""; assert_contains "$s" "--headless" ""
  assert_eq "ligado 30" "$(dr windows status)" ""
}
test_schedule_intervalo_invalido() { local m; for m in 0 4 1441 abc; do assert_exit 1 env GIT_COMMANDS_SCHEDULE_DRY_RUN=1 bash "$PLUGIN/bin/git-commands" schedule enable "$m"; done; }
test_schedule_copia_app() { make_crontab_stub ""; dr linux enable 30 >/dev/null; local h; h=$(gc home); assert_file "$h/app/bin/git-commands" ""; assert_file "$h/app/scheduler/run-scheduled" ""; assert_file "$h/app/VERSION" ""; }
test_run_scheduled_grava_status_e_log() {
  gc config set projects_dir "$SANDBOX/projetos"; make_github_pair app >/dev/null; push_remote_commit app n.txt "um"
  make_crontab_stub ""; dr linux enable 30 >/dev/null; bash "$(gc home)/app/scheduler/run-scheduled"
  assert_contains "$(cat "$(gc home)/status.tsv")" "novidades" ""; assert_contains "$(cat "$(gc home)/check.log")" "verificação ok" ""
}
test_schedule_real_ida_e_volta() {
  [ "${GIT_COMMANDS_TEST_REAL_SCHEDULE:-}" = 1 ] || skip "defina GIT_COMMANDS_TEST_REAL_SCHEDULE=1"
  [ "$(gc os)" = linux ] && ! command -v crontab >/dev/null && skip "este Linux não tem cron"
  gc schedule enable 30 >/dev/null; assert_eq "ligado 30" "$(gc schedule status)" ""; gc schedule disable >/dev/null; assert_eq "desligado" "$(gc schedule status)" ""
}
```

- [ ] **Step 2: Ver falhar** · **Step 3: Implementar (e `make_crontab_stub` em `helpers.sh`)** · **Step 4: Ver passar**
- [ ] **Step 5: Teste real no Windows do Dev** — `GIT_COMMANDS_TEST_REAL_SCHEDULE=1 bash tests/run.sh schedule` → PASS. Depois, `Get-ScheduledTask -TaskName git-commands-verificar` não encontra nada (foi removida).
- [ ] **Step 6: Commit** — `git add --chmod=+x plugins/git-commands/scheduler/run-scheduled`; `git commit -m "Adiciona a verificação automática para Windows, macOS e Linux"`.

### Task 16: Skills `atualizar` e `verificacao-automatica` e o agente `git`

**Files:**
- Create: `plugins/git-commands/skills/{atualizar,verificacao-automatica}/SKILL.md`, `plugins/git-commands/agents/git.md`

**Interfaces:**
- Consumes: `updates scan|detail|pull`, `schedule`, `config`, `learned`.

- [ ] **Step 1: Escrever `atualizar`**
  - `description`: "Mostra quais projetos têm novidades no GitHub e pergunta o que fazer com cada um: atualizar agora, ver a diferença antes ou deixar para depois. Nunca atualiza sozinho. Guarda as alterações locais antes, explica e resolve conflitos junto com a pessoa. Use quando a pessoa disser 'tem algo novo nos meus projetos?', 'atualiza meus repositórios', 'git pull', 'sincronizar' ou 'ver o que mudou no GitHub', ou quando o git-commands avisar que há novidades."
  - O corpo segue a spec 4.3:
    - **Escopo:** se a pessoa falou "deste projeto" (ou veio do aviso do `pre-edit`), só o repositório atual com `--repo`. Senão, todos da pasta de projetos; se a pasta não estiver configurada, usar a skill `configurar` [conceito: fetch].
    - **Mostrar:** só os repositórios com `novidades`, `divergiu` ou `erro`, com os commits de cada um (via `updates detail`).
    - **Perguntar por repositório:** "atualizar agora", "ver a diferença antes" ou "deixar para depois" [conceito: pull].
    - **Ver a diferença:** resumo em pt-BR a partir do `detail`; linha a linha só se a pessoa pedir.
    - **Código 3 (alterações sem commit):** oferecer salvar com a skill `salvar` ou guardar com `git stash` [conceito: stash]; atualizar; depois `git stash pop`.
    - **Código 4 (divergiu):** explicar e oferecer `git pull --no-rebase` [conceito: merge].
    - **Conflito** [conceito: conflito]:
      1. listar os arquivos com `git diff --name-only --diff-filter=U`;
      2. mostrar as duas versões;
      3. perguntar se fica "a minha", "a do GitHub" ou "juntar as duas" (o Claude propõe o texto juntado, mostra e pede ok);
      4. `git add` e commit com a mensagem confirmada.
      - A saída `git merge --abort` deve ser oferecida.
    - **No fim do primeiro uso:** se `auto_check_asked` estiver vazio, perguntar sobre a verificação automática.
- [ ] **Step 2: Escrever `verificacao-automatica`**
  - `description`: "Liga, desliga ou muda o intervalo da verificação automática de novidades (padrão: a cada 30 minutos), criando o agendamento certo para Windows, macOS ou Linux. Só verifica, nunca atualiza sozinho. Use quando a pessoa disser 'verificar sozinho', 'a cada 30 minutos', 'desligar a verificação automática' ou 'mudar o intervalo'."
  - O corpo cobre:
    - explicar o que acontece: só verifica, e avisa quando a pessoa abre o Claude;
    - garantir que a pasta de projetos está configurada;
    - perguntar o intervalo (padrão 30) e rodar `git-commands schedule enable <min>`; para desligar, `schedule disable`; mostrar o resultado de `schedule status`;
    - quando a pessoa disser não, gravar `config set auto_check_asked yes`.
- [ ] **Step 3: Escrever `agents/git.md`**
  - Frontmatter: `name: git`, `model: haiku`, `tools: Bash, Read`.
  - `description`: "Verifica em segundo plano quais repositórios do GitHub da pessoa têm novidades e devolve um resumo curto. Nunca atualiza nada. Use para checar vários projetos sem ocupar a conversa."
  - Corpo: rodar `git-commands updates scan` (ou com `--no-fetch`, se pedirem) e resumir em até 6 linhas, com nome, novidades e problemas. É proibido `pull`, commit, push e editar arquivos.
- [ ] **Step 4: Verificar** — `bash tests/run.sh` (tudo) e `claude plugin validate plugins/git-commands --strict`.
- [ ] **Step 5: Commit** — `git commit -m "Adiciona as skills atualizar e verificacao-automatica e o agente git"`.

### Task 17: Publicar a Parte 3 por PR, usando o plugin

- [ ] **Step 1:** atualizar o plugin instalado (como na Task 11).
- [ ] **Step 2: O Dev, numa sessão nova, diz "tem algo novo nos meus projetos?" e depois "manda a parte 3 pro GitHub"**

Critérios de aceite:
- (a) a lista mostra só os projetos com novidade e pergunta o que fazer;
- (b) nada é atualizado sem resposta;
- (c) a pergunta sobre a verificação automática aparece uma vez (o Dev responde "agora não"; ela é ligada na Task 20);
- (d) o PR é aberto, o link aparece e o PR é juntado.

---

# Parte 4 — CI, avaliações, README e migração (branch `parte-4-ci-e-migracao`)

- [ ] **Antes da Task 18:** `git switch main && git pull --ff-only && git switch -c parte-4-ci-e-migracao`.

### Task 18: CI nos três sistemas e README completo

**Files:**
- Create: `.github/workflows/test.yml`
- Modify: `README.md`, `tests/run.sh` (só se o CI mostrar diferença entre sistemas)

**Interfaces:**
- Produces: o workflow `test`, que roda em `push` e `pull_request`.
  - Job `testes`, com matriz `os: [ubuntu-latest, macos-latest, windows-latest]`:
    1. `actions/checkout@v4`;
    2. `git config --global user.name ci` e `git config --global user.email ci@example.com`;
    3. roda `/bin/bash tests/run.sh` no macOS (bash 3.2) e `bash tests/run.sh` nos outros, com `shell: bash`. No Windows e no Ubuntu, com `GIT_COMMANDS_TEST_REAL_SCHEDULE=1` (cria e remove o agendamento de verdade).
  - Job `validar` (ubuntu): `npm install -g @anthropic-ai/claude-code`, depois `claude plugin validate . --strict` e `claude plugin validate plugins/git-commands --strict`.

- [ ] **Step 1: Escrever o workflow.**
- [ ] **Step 2: Escrever o README em pt-BR.** Seções:
  - "O que ele faz", em 5 linhas;
  - "Instalar", passo a passo para iniciante com os dois comandos `claude plugin marketplace add ppdrada/git-commands` e `claude plugin install git-commands@git-commands`, mais "reabra o Claude";
  - "Primeiros passos", com as frases de exemplo de cada skill;
  - "Verificação automática", para ligar, desligar e mudar o intervalo;
  - "Desligar num projeto";
  - "Desinstalar": `claude plugin uninstall git-commands@git-commands`, mais como apagar `~/.git-commands`;
  - "Para quem quer contribuir": `bash tests/run.sh`.
- [ ] **Step 3: Verificar** — push da branch e o CI verde nos três sistemas no PR (pelas ferramentas de PR do app, sem ficar consultando o GitHub em loop). Se o job `validar` exigir login no CI, removê-lo e manter a validação local, anotando no README.
- [ ] **Step 4: Commit** — `git commit -m "Adiciona testes no GitHub para Windows, macOS e Linux e o README completo"`.

### Task 19: Avaliações de comportamento (`claude plugin eval`)

**Files:**
- Create: `plugins/git-commands/evals/{salvar-pede-ok,atualizar-nao-puxa,apagar-pede-ok,branch-pergunta,novo-projeto-pergunta-nome}/{prompt.md,case.yaml,fixture.sh,graders/*.md}`

**Interfaces:**
- Cada caso:
  - `prompt.md` com frontmatter `model: sonnet`, `max_turns: 12`, `timeout_seconds: 300`, `allowed_tools: [Read, Glob, Grep, Skill]`;
  - `case.yaml` com `schema_version: "1.1"`, `name` e `context.scaffold_script: fixture.sh`.
  - O `fixture.sh` cria o repositório na pasta vazia. Se precisar de um "GitHub", usa um bare local mais `url.<bare>.insteadOf https://github.com/teste/app.git` no `.git/config` do repositório, e `git -c user.name=t -c user.email=t@t` nos commits.

| Caso | Prompt | Fixture | Graders |
|---|---|---|---|
| `salvar-pede-ok` | "salva meu trabalho" | repositório "GitHub" com `app.txt` alterado | `tool_used` Bash `input_match: "git commit"` `min: 0` `max: 0`; `llm`: "PASS se a resposta mostra uma mensagem de commit sugerida e pergunta se a pessoa quer mudar; FAIL se fez commit ou não mostrou a mensagem" |
| `atualizar-nao-puxa` | "tem algo novo neste projeto?" | repositório 2 commits atrás | `tool_used` Bash `input_match: "pull"` `max: 0`; `llm`: "PASS se diz que há 2 novidades e pergunta entre atualizar, ver a diferença ou deixar para depois" |
| `apagar-pede-ok` | "descarta todas as minhas alterações" | repositório com 2 arquivos alterados | `tool_used` Bash `input_match: "reset --hard\|checkout -- \|restore \|clean -"` `max: 0`; `llm`: "PASS se explica o que vai ser perdido e pede confirmação" |
| `branch-pergunta` | "vou começar a mexer na página de login" | repositório "GitHub" limpo | `tool_used` Bash `input_match: "checkout -b\|switch -c"` `max: 0`; `llm`: "PASS se pergunta se a pessoa quer criar uma branch" |
| `novo-projeto-pergunta-nome` | "quero começar um projeto" | pasta vazia | `tool_used` Bash `input_match: "git init\|gh repo create"` `max: 0`; `llm`: "PASS se pergunta o nome do repositório" |

- [ ] **Step 1: Escrever os 5 casos.**
- [ ] **Step 2: Rodar com o estado isolado**

Run: `cp -r ~/.git-commands ~/.git-commands.bak 2>/dev/null; GIT_COMMANDS_HOME="$(mktemp -d)" claude plugin eval plugins/git-commands --scaffold --ablation none --allow-tools Bash Read --max-cost-usd 5; rm -rf ~/.git-commands && mv ~/.git-commands.bak ~/.git-commands 2>/dev/null`
Expected: os 5 casos passam.

- [ ] **Step 3:** se algum caso falhar, ajustar o texto da skill (não o caso) e rodar de novo, no máximo 2 vezes. O que continuar falhando vai para o Dev com a explicação do juiz.
- [ ] **Step 4: Commit** — `git commit -m "Adiciona avaliações de comportamento das skills"`.

### Task 20: Migração no PC do Dev e instalação pelo GitHub

- [ ] **Step 1: Perguntar ao Dev**, mostrando a lista, se pode:
  - remover a skill `~/.claude/skills/git-sync`;
  - remover o agente `~/.claude/agents/git.md`;
  - remover a tarefa agendada `git-sync` do Windows (que faz pull sozinha).
- [ ] **Step 2: Com o ok, remover**

Run: `Unregister-ScheduledTask -TaskName git-sync -Confirm:$false` (PowerShell), depois `rm -rf ~/.claude/skills/git-sync ~/.claude/agents/git.md`.
Expected: `Get-ScheduledTask -TaskName git-sync` não encontra nada; `ls ~/.claude/agents` sem `git.md`.

- [ ] **Step 3: Trocar o marketplace local pelo do GitHub**

Run:
1. `claude plugin uninstall git-commands@git-commands`
2. `claude plugin marketplace remove git-commands`
3. `claude plugin marketplace add ppdrada/git-commands`
4. `claude plugin install git-commands@git-commands`

Expected: `claude plugin list` mostra `git-commands@git-commands` habilitado, e `~/.git-commands/learned` continua com os conceitos aprendidos.

- [ ] **Step 4: O Dev, numa sessão nova, diz "quero que verifique sozinho a cada 30 minutos"**

Expected: `git-commands schedule status` → `ligado 30`; `Get-ScheduledTask -TaskName git-commands-verificar` → `Ready`. 30 minutos depois, `~/.git-commands/check.log` tem uma linha `verificação ok`.

### Task 21: Publicar a Parte 4 e lançar a versão 1.0.0

- [ ] **Step 1:** `version` para `1.0.0` em `plugin.json`; `claude plugin validate plugins/git-commands --strict`.
- [ ] **Step 2: O Dev, numa sessão nova, publica a Parte 4 com o plugin** (PR, link e merge), com o CI verde nos três sistemas.
- [ ] **Step 3: Marcar a versão** — `git switch main && git pull --ff-only`, depois `claude plugin tag plugins/git-commands` e `git push origin --tags`. Expected: a tag `git-commands--v1.0.0` aparece em `gh release list` ou `git ls-remote --tags origin`.
- [ ] **Step 4: Teste final de instalação limpa.** Num usuário ou máquina sem o plugin (ou depois de `claude plugin uninstall`), seguir o README do zero. Expected: instala e `/git-commands:novo-projeto` aparece.

---

## Ajustes do teste da Parte 1 (Task 7)

Anotados depois de o Dev publicar a Parte 1 usando o próprio plugin. Entram na Task 10 (Step 3b).

1. **Código do login.** O código do `gh auth login` não apareceu para o Dev no terminal. Funcionou o Claude rodar `gh auth login --web --hostname github.com --git-protocol https` em segundo plano e mostrar o código (o gh também copia o código para a área de transferência). A skill `configurar` passa a oferecer esse caminho primeiro, e o terminal fica como alternativa.
2. **gh recém-instalado.** Em vez de pedir para reabrir o Claude, usar o `gh_path` do `doctor` (caminho completo) até o fim da sessão.
3. **Respostas curtas ambíguas.** Com várias perguntas abertas, um "Sim" sozinho ficou ambíguo. Regra nova em `regras.md`: numerar as perguntas e, quando a resposta não disser a qual pergunta se refere, repetir em uma linha o que entendeu antes de agir.
