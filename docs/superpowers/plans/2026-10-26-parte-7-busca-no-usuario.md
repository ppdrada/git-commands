# git-commands — Parte 7: os projetos do usuário inteiro — Plano de construção

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** a verificação automática encontra sozinha todos os projetos da conta do GitHub da pessoa na pasta do usuário, junta a pasta de projetos e as pastas que a pessoa pedir, pula as que ela mandou ignorar, e o painel mostra onde cada projeto está.

**Architecture:** um arquivo novo, `lib/folders.sh`, monta a lista de projetos a partir de três fontes:
- a busca no usuário (`gc_home_repos`);
- a pasta de projetos;
- as pastas pedidas.

Ele tira as pastas ignoradas e as repetições, e cuida do subcomando `git-commands folders`. O `updates scan` sem `--dir` passa a usar essa lista; o `doctor` e o `ssh status` também. Em `common.sh` entram o dono de um endereço do GitHub (`gc_github_owner`) e o caminho real de uma pasta (`gc_real_dir`). No painel, o resumo ganha a pasta do usuário, e cada linha de projeto mostra a pasta dele em cinza.

**Tech Stack:** bash (compatível com 3.2), git, GitHub CLI (`gh`, só a leitura local do login), mod do Claude Code em TypeScript (`claude plugin test`), GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-10-26-parte-7-busca-no-usuario-design.md`. Os designs anteriores continuam valendo.

## Global Constraints

- Bash compatível com 3.2: sem arrays associativos, sem `mapfile`, sem `${x,,}`, regex com `[[ $x =~ $re ]]` e a regex numa variável. **Sem `case` dentro de `$(...)`.** Hooks e executor agendado sem heredoc; o `run-hook.cmd` só com ASCII.
- Dependências: bash, git, utilitários POSIX e o `gh` só para `gh config get -h github.com user`, que lê o login guardado no computador, sem rede. Nada de jq, python ou node no plugin principal.
- **A busca não usa a rede.** Ela só lista pastas e lê `remote.origin.url`; nunca lê arquivos dos projetos.
- Raiz da busca: `$HOME` e só ele (no Windows, `C:\Users\<pessoa>`). Pula pastas escondidas, `AppData` e `node_modules`; no Mac, também `Library`, `Desktop`, `Documents` e `Downloads`. Até 5 níveis: `~/a/b/c/d/projeto` entra.
- Estado em `${GIT_COMMANDS_HOME:-$HOME/.git-commands}`: chave nova `github_user` no `config`, e arquivos novos `folders` (pastas pedidas) e `ignored` (pastas ignoradas), uma pasta por linha.
- No Windows, todo caminho gravado ou comparado passa por `gc_real_dir` (forma `C:/...`), e a comparação de caminhos não diferencia maiúsculas.
- O painel continua só lendo: não usa a rede, não roda git, nunca atualiza nada.
- Textos para a pessoa em pt-BR simples; subcomandos em ASCII. Fim de linha LF; executáveis com modo 100755.
- Versões: `git-commands` 1.2.0 e `git-commands-painel` 0.2.0.
- Mensagens de commit em pt-BR, no imperativo, terminando com `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Branch `parte-7-busca-no-usuario`. **Nada vai para o GitHub sem o Dev mandar** (push, PR, merge, tag).
- Documentação pública sem nomes de pessoas nem de projetos pessoais ("Dev", "projeto").

## Review Focus

1. **Caminhos do Windows em duas formas.** No Git Bash o `$HOME` é `/c/Users/...` e o config guarda `C:/...`. O esperado é que o mesmo projeto, achado pela busca e pela pasta de projetos, apareça uma vez só, e que ignorar funcione com qualquer das formas. Teste: `test_lista_sem_repeticao_entre_fontes` (Tarefa 4).
2. **Nomes de pasta com espaço, acento e apóstrofo** (`site - Cópia`, `D'Avila`) em pedir e ignorar: o esperado é funcionar igual. Teste: `test_folders_nomes_com_espaco_e_acento` (Tarefa 2).
3. **Pasta do usuário muito grande ou lenta:** o esperado é a busca parar no limite de tempo, a verificação seguir com o que já achou e terminar bem. Teste: `test_busca_lenta_para_no_limite` (Tarefa 3).
4. **Endereço do `origin` com o dono em maiúsculas**, com `.git` no fim ou sem, em SSH pela porta 443: o esperado é reconhecer o dono do mesmo jeito. Teste: `test_dono_do_endereco` (Tarefa 1).
5. **Quem atualiza de uma versão antiga** (sem `github_user`): com o `gh` logado, a busca liga sozinha na primeira verificação; sem `gh` ou sem login, nada quebra e a pasta de projetos continua verificada. Testes: `test_github_user_vem_do_gh` e `test_sem_conta_nao_busca_no_usuario` (Tarefas 1 e 4).

---

## Estrutura de arquivos

```
plugins/git-commands/
  lib/common.sh       gc_github_owner, gc_real_dir, github_user em GC_CONFIG_KEYS
  lib/folders.sh      NOVO: arquivos folders/ignored, gc_cmd_folders, gc_github_user,
                      gc_home_repos, gc_all_repos
  lib/updates.sh      gc_updates_scan sem --dir usa gc_all_repos
  lib/doctor.sh       github_user, folders, folders_missing, ignored
  lib/ssh.sh          ssh status conta a lista nova
  bin/git-commands    "folders" na lista de subcomandos
  skills/verificacao-automatica/SKILL.md  onde procura, pedir, tirar, ignorar e os avisos novos
  skills/atualizar/SKILL.md e skills/configurar/SKILL.md  texto da lista nova
  .claude-plugin/plugin.json  1.2.0
plugins/git-commands-painel/
  types/index.d.ts    Resumo.casa
  hooks/resumo.ts     resumir(..., casa)
  hooks/textos.ts     pastaDoProjeto
  hooks/register.tsx  casa no resumo; linha do painel com a pasta em cinza
  .claude-plugin/plugin.json  0.2.0
tests/helpers.sh      stub do gh com "config get ... user"; make_repo_at
tests/test_folders.sh NOVO
tests/test_updates.sh, test_doctor.sh, test_ssh.sh   testes novos e a ordem das chaves do doctor
README.md             verificação automática, pastas, painel, comandos, contribuir
```

---

### Task 1: O dono do endereço e a conta da pessoa

**Files:**
- Modify: `plugins/git-commands/lib/common.sh`
- Create: `plugins/git-commands/lib/folders.sh` (só `gc_github_user` nesta tarefa)
- Modify: `tests/helpers.sh`
- Test: `tests/test_common.sh`, `tests/test_folders.sh` (novo)

**Interfaces:**
- Produces, em `common.sh`:
  - `GC_CONFIG_KEYS` com `github_user` no fim; padrão vazio.
  - `gc_github_owner <url>`: imprime o dono, em minúsculas, de um endereço do GitHub e sai com 0. Formatos aceitos:
    - `https://github.com/DONO/repo(.git)`, com ou sem `www.` e usuário;
    - `git@github.com:DONO/repo`;
    - `ssh://git@ssh.github.com:443/DONO/repo` e `ssh://git@github.com/DONO/repo`;
    - `git://github.com/DONO/repo`.

    Para qualquer outro endereço, sai com 1 e não imprime nada.
  - `gc_real_dir <pasta>`: imprime o caminho real de uma pasta que existe (`cd` e `pwd -W` no Git Bash, que dá `C:/...`; `pwd -P` nos outros sistemas) e sai com 0. Se a pasta não existe, sai com 1.
- Produces, em `folders.sh`: `gc_github_user`, que imprime o login da pessoa.
  - Usa `github_user` do config.
  - Se ele estiver vazio, pergunta ao `gh` da máquina (`gc_gh_bin`), com `gh config get -h github.com user` dentro de `gc_run_with_timeout 10`, sem rede, e grava o resultado com `gc_config_set`.
  - Sem `gh` ou sem login, não imprime nada e sai com 0.
- Produces, em `helpers.sh`:
  - o stub do `gh` responde `config get` com o login quando o último argumento é `user`: `${STUB_GH_USER-tester}` (vazio quando `STUB_GH_USER=` vazio), e com o protocolo nos outros casos, como hoje;
  - `make_repo_at <caminho> <dono> [<nome>]` cria um repositório com um commit no caminho e `origin` em `https://github.com/<dono>/<nome>.git` (o nome padrão é o último pedaço do caminho), sem remoto de verdade. Ele imprime o caminho.

- [ ] **Step 1: Write the failing tests**
  - `test_dono_do_endereco` (`test_common.sh`): `https://github.com/PPDRADA/site.git`, `https://www.github.com/ppdrada/site`, `git@github.com:ppdrada/site.git`, `ssh://git@ssh.github.com:443/ppdrada/site.git` e `git://github.com/ppdrada/site` dão `ppdrada`. `https://gitlab.com/ppdrada/site`, `https://gitlab.com/github.com/x` e `qualquer coisa` saem com 1.
  - `test_caminho_real_da_pasta` (`test_common.sh`): `gc_real_dir "$SANDBOX/home"` igual a `gc_real_dir "$SANDBOX/home/"`; pasta que não existe sai com 1. No Windows, a saída começa com letra de unidade (`[A-Za-z]:/`).
  - `test_github_user_vem_do_gh` (`test_folders.sh`): com `GIT_COMMANDS_GH="$SANDBOX/stub/gh"` e `STUB_GH_USER=ppdrada`, `gc_github_user` imprime `ppdrada` e `gc config get github_user` passa a ser `ppdrada`. Com `STUB_GH_USER=` vazio, imprime vazio e não grava. Com `GIT_COMMANDS_GH=/nao/existe`, imprime vazio. Com `github_user` já gravado, não chama o `gh` (o stub anota cada chamada num arquivo, que continua vazio).
  - `test_doctor_ssh_e_protocolo` (o que já existe) continua passando com o stub novo.

- [ ] **Step 2: Run to verify they fail** — `bash tests/run.sh common` e `bash tests/run.sh folders`. Expected: FAIL nos três testes novos.

- [ ] **Step 3: Implement** as funções e o stub como nas Interfaces. As regexes ficam em variáveis, no estilo de `gc_is_github_url`. Para minúsculas, `tr 'A-Z' 'a-z'`.

- [ ] **Step 4: Run** — `bash tests/run.sh`. Expected: todos passam (ou pulados pelos motivos de sempre).

- [ ] **Step 5: Commit** — `git commit -m "Dono do endereço do GitHub e login da pessoa sem rede"`

### Task 2: Pastas pedidas e ignoradas (`git-commands folders`)

**Files:**
- Modify: `plugins/git-commands/lib/folders.sh`
- Modify: `plugins/git-commands/bin/git-commands` (lista de subcomandos do `gc_usage`)
- Test: `tests/test_folders.sh`

**Interfaces:**
- Consumes: `gc_real_dir`, `gc_home`, `gc_config_get` (Tarefa 1).
- Produces:
  - Arquivos `$(gc_home)/folders` e `$(gc_home)/ignored`, uma pasta por linha, sempre na forma de `gc_real_dir`. Gravação por arquivo temporário e `mv`.
  - `gc_folders_lines <arquivo>`: imprime as pastas do arquivo, sem linhas vazias.
  - `gc_cmd_folders add|remove|ignore|unignore|list`. Mensagens exatas:

| Comando | Saída e código |
|---|---|
| `add <pasta>` | `pasta pedida: <pasta>` (0); já na lista: `a pasta já estava na lista: <pasta>` (0); não existe: `git-commands: a pasta não existe: <pasta>` no stderr (1) |
| `remove <pasta>` | `pasta tirada da lista: <pasta>` (0); fora da lista: `git-commands: a pasta não está na lista: <pasta>` (1) |
| `ignore <pasta>` | `pasta ignorada: <pasta>` (0); já ignorada: `a pasta já estava ignorada: <pasta>` (0); não existe: o mesmo erro do `add` (1) |
| `unignore <pasta>` | `a pasta volta a aparecer: <pasta>` (0); fora da lista: `git-commands: a pasta não está ignorada: <pasta>` (1) |
| `list` | uma linha por fonte, separada por tab (abaixo) |

    Em `remove` e `unignore`, a pasta é comparada pela forma de `gc_real_dir` quando ela existe, senão pelo texto com `gc_norm_path`. A comparação não diferencia maiúsculas no Windows.

    Linhas do `list`, nesta ordem, cada uma com `tipo<TAB>pasta<TAB>situação`:
    - `usuario`, a pasta do usuário: `ok`, ou `desligada` sem `github_user`;
    - `projetos`, a pasta de projetos: `ok`, `nao-encontrada` ou `nao-configurada` (com pasta vazia);
    - uma linha `pedida` por pasta pedida: `ok` ou `nao-encontrada`;
    - uma linha `ignorada` por pasta ignorada: `ok` ou `nao-encontrada`.

    Sem argumento ou com um subcomando desconhecido: `uso: git-commands folders add <pasta> | remove <pasta> | ignore <pasta> | unignore <pasta> | list` no stderr (1).

- [ ] **Step 1: Write the failing tests** (`tests/test_folders.sh`)
  - `test_folders_pedir_e_tirar`: `add` de uma pasta do sandbox → `pasta pedida:`, e o `list` tem a linha `pedida` com `ok`. Um segundo `add` → `já estava`. `remove` → `tirada`. Um segundo `remove` sai com 1.
  - `test_folders_ignorar_e_voltar`: o mesmo com `ignore` e `unignore`.
  - `test_folders_pasta_que_nao_existe`: `add` e `ignore` de uma pasta inexistente saem com 1 e a mensagem tem `não existe`. Uma pasta pedida apagada depois aparece no `list` como `nao-encontrada`.
  - `test_folders_nomes_com_espaco_e_acento`: `site - Cópia` e `D'Avila` funcionam em `add`, `ignore`, `list` e `remove`.
  - `test_folders_lista_as_fontes`: sem `github_user`, a primeira linha é `usuario<TAB><home><TAB>desligada`. Com `gc config set github_user teste`, ela termina em `ok`. A linha `projetos` mostra `nao-configurada` sem pasta e `ok` com `"$SANDBOX/projetos"`.
  - `test_folders_uso`: sem argumento, sai com 1 e mostra `uso: git-commands folders`.

- [ ] **Step 2: Run to verify they fail** — `bash tests/run.sh folders`. Expected: FAIL nos testes novos.

- [ ] **Step 3: Implement** `gc_cmd_folders` e `gc_folders_lines`, e acrescente `folders` à lista do `gc_usage`.

- [ ] **Step 4: Run** — `bash tests/run.sh`. Expected: todos passam.

- [ ] **Step 5: Commit** — `git commit -m "git-commands folders: pastas pedidas e ignoradas"`

### Task 3: A busca na pasta do usuário

**Files:**
- Modify: `plugins/git-commands/lib/folders.sh`
- Test: `tests/test_folders.sh`

**Interfaces:**
- Consumes: `gc_real_dir`, `gc_github_owner`, `gc_os`, `gc_run_with_timeout` (Tarefa 1).
- Produces: `gc_home_repos <login>`, que imprime, um por linha, os repositórios dentro de `$HOME` cujo `origin` tem o dono `<login>`, sem diferenciar maiúsculas. A raiz vem de `gc_real_dir "$HOME"`. Ele sai com 0, mesmo quando a busca estoura o tempo, e então imprime no stderr: `git-commands: aviso: a busca na pasta do usuário passou de <N> segundos e parou no meio`.
  - **Algoritmo** (as regras de pular valem pelo nome da pasta, nunca pelo caminho, porque a pasta do usuário de um teste pode estar dentro de uma `AppData`):
    1. Liste as entradas diretas da raiz que são pastas, menos:
       - as escondidas (nome começando com `.`);
       - `AppData` e `node_modules`;
       - no Mac (`gc_os` = `mac`), também `Library`, `Desktop`, `Documents` e `Downloads`.
    2. Para cada uma, `find <pasta> -maxdepth 5 \( -name '.*' ! -name .git -o -name node_modules \) -prune -o -type d -name .git -print -prune` (o `.git` de `~/a/b/c/d/projeto` fica na profundidade 5 contando de `~/a`; só conta o `.git` que é pasta, porque o de um worktree ou de um submódulo é um arquivo, e esses não são projetos à parte). Tire o `/.git` do fim.
    3. Mantenha só os que têm `gc_github_owner "$(git -C <repo> config --get remote.origin.url)"` igual ao login.
  - **Limite de tempo:** os passos 1 e 2 rodam juntos dentro de `gc_run_with_timeout`, com a saída num arquivo temporário. O limite é `${GIT_COMMANDS_SEARCH_SECS:-20}` segundos. Esse nome de variável só serve para os testes e não vai para o README.

- [ ] **Step 1: Write the failing tests** (`tests/test_folders.sh`; HOME do sandbox; os repositórios são feitos com `make_repo_at`, dono `teste` e login `teste`)
  - `test_busca_acha_os_projetos_da_conta`: acha `~/Documents/a` e `~/a/b/c/d/projeto`. Não acha:
    - `~/a/b/c/d/e/fundo` (fundo demais);
    - `~/.claude/plugins/marketplaces/x` (escondida);
    - `~/AppData/Local/x`;
    - `~/Documents/node_modules/x`;
    - `~/Documents/outro`, de dono `outra-conta`;
    - um repositório sem `origin`.
  - `test_busca_no_mac_pula_as_pastas_protegidas`: com `GIT_COMMANDS_OS=mac`, `~/Documents/a` e `~/Library/x` ficam de fora e `~/projetos/b` entra. Com `GIT_COMMANDS_OS=linux`, `~/Documents/a` entra.
  - `test_busca_com_dono_em_maiusculas`: `origin` em `https://github.com/TESTE/c.git` entra com o login `teste`.
  - `test_busca_lenta_para_no_limite`: um `find` falso no PATH, que dorme 5 s antes de chamar o de verdade, com `GIT_COMMANDS_SEARCH_SECS=1`. O `gc_home_repos teste` termina em menos de 4 s, sai com 0 e o stderr tem `parou no meio`.

- [ ] **Step 2: Run to verify they fail** — `bash tests/run.sh folders`. Expected: FAIL nos testes novos.

- [ ] **Step 3: Implement** `gc_home_repos` como no algoritmo.

- [ ] **Step 4: Run** — `bash tests/run.sh`. Expected: todos passam.

- [ ] **Step 5: Commit** — `git commit -m "Busca dos projetos da conta na pasta do usuário"`

### Task 4: A lista completa e a verificação

**Files:**
- Modify: `plugins/git-commands/lib/folders.sh`
- Modify: `plugins/git-commands/lib/updates.sh` (`gc_updates_scan`)
- Test: `tests/test_folders.sh`, `tests/test_updates.sh`

**Interfaces:**
- Consumes: `gc_github_user`, `gc_home_repos`, `gc_folders_lines`, `gc_real_dir` (Tarefas 1 a 3) e `gc_updates_repos` (já existe: até 2 níveis, só GitHub).
- Produces: `gc_all_repos`. Ele imprime a lista ordenada (`LC_ALL=C sort -u`, depois de passar cada caminho por `gc_real_dir`), juntando:
  - `gc_home_repos` com o login, quando `gc_github_user` não for vazio;
  - `gc_updates_repos` da pasta de projetos;
  - `gc_updates_repos` de cada pasta pedida;

  e tirando todo repositório que fica numa pasta ignorada ou dentro dela. A comparação é por prefixo de caminho mais `/` e não diferencia maiúsculas no Windows.

  Cada fonte que falta ou não dá para ler vira um aviso no stderr, e as outras continuam:
  - `git-commands: aviso: a pasta de projetos não foi encontrada: <pasta>`;
  - `git-commands: aviso: a pasta pedida não foi encontrada: <pasta>`;
  - `git-commands: aviso: sem permissão para ler a pasta: <pasta>`.

  Ele sai com 0 se ao menos uma fonte foi lida. Se nenhuma foi (sem login, sem pasta de projetos que exista e sem pasta pedida que exista), sai com 1 e imprime: `git-commands: não há onde procurar projetos: configure a pasta de projetos (skill configurar), faça login no GitHub ou peça uma pasta (git-commands folders add <pasta>)`.
- Muda: `gc_updates_scan` sem `--dir` e sem `--repo` usa `gc_all_repos`. Os avisos vão para o stderr: o executor agendado já os põe no `check.log`, e a última linha continua sendo `verificação ok`. Com `--dir`, nada muda: os mesmos erros de hoje.

- [ ] **Step 1: Write the failing tests**
  - `test_lista_junta_as_tres_fontes` (`test_folders.sh`):
    - login `teste` com `~/Documents/a`;
    - pasta de projetos `"$SANDBOX/projetos"` com `make_github_pair app` (dono `teste`) e um repositório de dono `outra-conta`;
    - pasta pedida `"$SANDBOX/fora"` com um repositório de dono `outra-conta`.

    A lista tem os 4, e o de `outra-conta` dentro da pasta de projetos entra, porque nas pastas escolhidas o dono não importa.
  - `test_lista_sem_repeticao_entre_fontes`: a pasta de projetos é `~/Documents`, gravada na forma do Git Bash (`$HOME/Documents`), e a busca no usuário também acha `~/Documents/a`. Ele aparece uma vez só.
  - `test_ignorada_some_de_todas_as_fontes`: ignorar `~/Documents/a - Cópia` tira esse repositório da busca. Ignorar uma pasta dentro da pasta de projetos e uma pasta pedida tira os repositórios de lá.
  - `test_pasta_que_falta_nao_para_a_lista`: com uma pasta pedida apagada e a pasta de projetos inexistente, a lista ainda traz a busca no usuário, sai com 0 e o stderr tem os dois avisos.
  - `test_sem_fonte_nenhuma_da_erro`: sem login (`GIT_COMMANDS_GH=/nao/existe`), sem pasta de projetos e sem pastas pedidas, sai com 1 e mostra `não há onde procurar projetos`.
  - `test_sem_conta_nao_busca_no_usuario`: sem login e com a pasta de projetos, a lista traz só ela, mesmo com `~/Documents/a` existindo.
  - `test_scan_usa_a_lista` (`test_updates.sh`): `gc updates scan --no-fetch` sem `--dir` mostra os projetos das três fontes. `gc updates scan --no-fetch --dir "$SANDBOX/projetos"` mostra só os da pasta.
  - Os testes que já existem para `updates scan --save` continuam passando, com pasta de projetos e sem login.
  - `test_scan_sem_pasta_configurada` (já existe) passa a rodar com `GIT_COMMANDS_GH=/nao/existe`, para o `gh` logado da máquina não ligar a busca, e a esperar `não há onde procurar projetos`. Essa mensagem também contém "pasta de projetos".

- [ ] **Step 2: Run to verify they fail** — `bash tests/run.sh folders` e `bash tests/run.sh updates`. Expected: FAIL nos testes novos.

- [ ] **Step 3: Implement** `gc_all_repos` e a troca em `gc_updates_scan`. Nos testes novos, `GIT_COMMANDS_GH` aponta sempre para o stub ou para `/nao/existe`, para o `gh` da máquina nunca entrar.

- [ ] **Step 4: Run** — `bash tests/run.sh`. Expected: todos passam.

- [ ] **Step 5: Commit** — `git commit -m "A verificação junta a pasta do usuário, a de projetos e as pastas pedidas"`

### Task 5: `doctor` e `ssh status`

**Files:**
- Modify: `plugins/git-commands/lib/doctor.sh`, `plugins/git-commands/lib/ssh.sh`
- Test: `tests/test_doctor.sh`, `tests/test_ssh.sh`

**Interfaces:**
- Consumes: `gc_github_user`, `gc_all_repos`, `gc_folders_lines`.
- Produces:
  - O `doctor` grava `github_user` quando o `gh_user` da API vier preenchido e for diferente do config. Ele mostra, logo depois de `projects_dir=`:
    - `github_user=`, de `gc_github_user`;
    - `folders=` (quantas pastas pedidas);
    - `folders_missing=` (quantas não existem);
    - `ignored=` (quantas ignoradas).
  - O `ssh status` conta `projetos_https` e `projetos_ssh` sobre `gc_all_repos`, e não mais só sobre a pasta de projetos. Se `gc_all_repos` sair com 1, as contagens ficam 0.

- [ ] **Step 1: Write the failing tests**
  - `test_doctor_chaves_na_ordem` passa a esperar `... projects_dir github_user folders folders_missing ignored auto_check ...`.
  - `test_doctor_conta_as_pastas`: com uma pasta pedida que existe, uma apagada e uma ignorada, o doctor mostra `folders=2`, `folders_missing=1` e `ignored=1`.
  - `test_doctor_grava_o_login`: com o stub logado (`api user` responde `tester`), `gc config get github_user` vira `tester`.
  - `test_ssh_status_conta_os_projetos_do_usuario`: com login `teste`, `~/a` com `origin` em `git@github.com:teste/a.git` e `~/b` em HTTPS, o resultado mostra `projetos_ssh=1` e `projetos_https=1`, sem pasta de projetos.

- [ ] **Step 2: Run to verify they fail** — `bash tests/run.sh doctor` e `bash tests/run.sh ssh`. Expected: FAIL nos testes novos e no de ordem.

- [ ] **Step 3: Implement.**

- [ ] **Step 4: Run** — `bash tests/run.sh`. Expected: todos passam.

- [ ] **Step 5: Commit** — `git commit -m "doctor e ssh status com a lista nova de projetos"`

### Task 6: O painel mostra a pasta de cada projeto (0.2.0)

**Files:**
- Modify: `plugins/git-commands-painel/types/index.d.ts`, `hooks/resumo.ts`, `hooks/textos.ts`, `hooks/register.tsx`, `.claude-plugin/plugin.json` (0.2.0)
- Test: `plugins/git-commands-painel/tests/*.test.ts(x)`

**Interfaces:**
- Produces:
  - `Resumo.casa: string | null`, a pasta do usuário, vinda de `HOME` ou, sem ele, de `USERPROFILE`.
  - `resumir(arquivos, agora, paradaDesde, casa: string | null = null): Resumo`.
  - `pastaDoProjeto(caminho: string, casa: string | null): string`, em `textos.ts`. Ela devolve a pasta onde o projeto está, terminada no separador:
    - o separador é `\` quando o caminho tem letra de unidade (`C:/...` ou `/c/...` do Git Bash) e `/` nos outros casos;
    - dentro da casa, conta a partir dela (`Documents\`, `Documents\git\`);
    - direto na casa, devolve `''`;
    - fora da casa, devolve o caminho inteiro da pasta (`C:\git\`).

    A comparação aceita `\` e `/` e, no Windows, não diferencia maiúsculas. `/c/Users/...` vale como `C:/Users/...`.
  - Na linha do painel, um `Box` com dois `Text`: primeiro `pastaDoProjeto(...)` com `dimColor`, quando não for vazia, e depois o texto de sempre, `<nome> (<branch>): <rótulo>`, na cor do estado.

- [ ] **Step 1: Write the failing tests**
  - `pastaDoProjeto` (`textos.test.ts`), com casa `C:\Users\pessoa`:
    - `C:/Users/pessoa/Documents/site` → `Documents\`;
    - `C:/Users/pessoa/Documents/git/api` → `Documents\git\`;
    - `C:/Users/pessoa/site` → `''`;
    - `C:/git/site` → `C:\git\`;
    - `/c/Users/pessoa/Documents/site` → `Documents\`;
    - `c:/users/PESSOA/Documents/site` → `Documents\`.

    Com casa `/Users/pessoa` e caminho `/Users/pessoa/projetos/site`, devolve `projetos/`. Com casa `null`, devolve o caminho inteiro da pasta.
  - `resumir` copia `casa` para o resumo.
  - No painel (`painel.test.tsx`), com `HOME` `/casa` e caminhos `/casa/Documents/site` e `/casa/Documents/git/api`, as linhas trazem `Documents/` e `Documents/git/` em `Text`s com `dimColor`, ao lado de `site (main): com novidades (3)` e `api (main): em dia`. Os testes de lista que já existem passam a esperar a pasta antes de cada projeto.

- [ ] **Step 2: Run to verify they fail** — `claude plugin test plugins/git-commands-painel`. Expected: FAIL nos testes novos.

- [ ] **Step 3: Implement**, e mude a versão do painel para 0.2.0.

- [ ] **Step 4: Run** — `claude plugin test plugins/git-commands-painel` e `claude plugin validate plugins/git-commands-painel --strict`. Expected: PASS.

- [ ] **Step 5: Commit** — `git commit -m "Painel: a pasta de cada projeto em cinza"`

### Task 7: Skills, README e versão 1.2.0

**Files:**
- Modify:
  - `plugins/git-commands/skills/verificacao-automatica/SKILL.md`, `skills/atualizar/SKILL.md` e `skills/configurar/SKILL.md`;
  - `plugins/git-commands/.claude-plugin/plugin.json` (1.2.0);
  - `README.md`.

- [ ] **Step 1: Skills**
  - **`verificacao-automatica`:**
    - uma seção "Onde ela procura", que fala da pasta do usuário com todas as letras (no Windows, `C:\Users\<pessoa>`), dos filtros, do limite de 5 níveis e da pasta de projetos;
    - pedidos "monitorar a pasta X" (`folders add`), "parar de monitorar" (`folders remove`), "ignora a pasta X" (`folders ignore`) e "volta a mostrar a pasta X" (`folders unignore`), cada um mostrando o comando e esperando o ok;
    - `git-commands folders list` para "onde você procura?";
    - os avisos novos (pasta não encontrada, sem permissão, busca que parou no meio) e o erro "não há onde procurar projetos".

    No passo "Ligar", a pasta de projetos deixa de ser obrigatória quando há `github_user` ou pastas pedidas.
  - **`atualizar`:** o `updates scan` olha os projetos da pasta do usuário, da pasta de projetos e das pastas pedidas.
  - **`configurar`:** depois do login, o `doctor` grava o login da pessoa, e a busca no usuário liga sozinha.
- [ ] **Step 2: README**
  - **"Verificação automática":**
    - onde ela procura, com a pasta do usuário dita com todas as letras;
    - os filtros e o limite de 5 níveis;
    - pedir, tirar e ignorar pastas, com os comandos;
    - o aviso do Mac: Mesa, Documentos e Downloads ficam de fora da busca e entram só como pasta pedida.
  - **"Painel (opcional)":** a pasta em cinza.
  - **"Comandos do git-commands":** a linha do `git-commands folders`.
  - **"Para quem quer contribuir":** o `lib/folders.sh`.
- [ ] **Step 3: Versão** 1.2.0 no `plugin.json` do git-commands.
- [ ] **Step 4: Verify** — os três `claude plugin validate ... --strict`. Expected: passam.
- [ ] **Step 5: Commit** — `git commit -m "Skills e README com a busca no usuário, pastas pedidas e ignoradas; versão 1.2.0"`

### Task 8: Revisão final, publicação e a pasta de projetos do Dev (cada passo com o ok do Dev)

- [ ] **Step 1: Verificar tudo**:
  - `bash tests/run.sh`;
  - `claude plugin test plugins/git-commands-painel`;
  - os três `validate --strict`;
  - uma verificação de verdade sem gravar (`git-commands updates scan --no-fetch`), mostrando ao Dev os projetos que ela acha no computador dele.
- [ ] **Step 2: Revisão** da branch inteira por um revisor novo, e correção do que ele achar.
- [ ] **Step 3: Publicação**, com o ok do Dev em cada passo:
  - o push;
  - o PR, com título e descrição mostrados antes e o link;
  - o merge;
  - as tags `git-commands--v1.2.0` e `git-commands-painel--v0.2.0`.
- [ ] **Step 4: Depois de instalar a 1.2.0** e com `github_user=` preenchido no `doctor`, oferecer ao Dev voltar a pasta de projetos para `Documents\git` (`git-commands config set projects_dir ...`), que passa a ser só o lugar dos projetos novos.
