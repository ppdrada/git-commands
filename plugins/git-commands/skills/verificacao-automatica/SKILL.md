---
name: verificacao-automatica
description: Use quando a pessoa quer que os projetos sejam verificados sozinhos de tempos em tempos, quer ligar, desligar ou mudar o intervalo da verificação automática de novidades do GitHub, quer escolher onde ela procura os projetos (monitorar, parar de monitorar, ignorar ou voltar a mostrar uma pasta, ou ver quais pastas ela olha), quando um projeto não aparece na lista, quando a verificação automática deu erro ou parou de rodar, ou quando outra skill do git-commands perguntar sobre isso, com frases como "verificar sozinho", "a cada 30 minutos", "desligar a verificação automática", "mudar o intervalo", "monitorar a pasta X", "ignora a pasta X" ou "onde você procura meus projetos?".
---

# Verificação automática

Leia `${CLAUDE_PLUGIN_ROOT}/reference/regras.md` antes de qualquer passo.

## O que explicar antes de ligar

- O plugin cria um agendamento no próprio sistema (Agendador de Tarefas no Windows, launchd no Mac, cron no Linux). Ele funciona mesmo com o Claude fechado, enquanto o computador estiver ligado.
- Ele só **verifica** se há novidades no GitHub, sem mexer em nenhum arquivo. Quando a pessoa abrir o Claude, o plugin conta o que mudou e pergunta o que fazer.
- Ele acha os projetos sozinho, em mais de um lugar (seção abaixo): a pessoa não precisa guardar tudo numa pasta só.
- Não ofereça atualizar sozinho: o git-commands nunca atualiza nada sem a pessoa pedir.

## Onde ela procura

Ao explicar, diga a pasta do usuário com todas as letras (o caminho inteiro), para a pessoa saber de onde vêm os projetos. A verificação junta três lugares, sem repetir nenhum projeto:

| Lugar | O que entra | Até onde desce |
|---|---|---|
| A pasta do usuário | só os projetos da conta da pessoa no GitHub (o `origin` é dela) | 5 níveis |
| A pasta de projetos (`projects_dir`) | todos os repositórios do GitHub, de qualquer dono | 2 níveis |
| As pastas pedidas | todos os repositórios do GitHub, de qualquer dono | 2 níveis |

- **A pasta do usuário** é `C:\Users\<pessoa>` no Windows, `/Users/<pessoa>` no Mac e `/home/<pessoa>` no Linux. A linha `usuario` do `git-commands folders list` mostra a pasta exata. "5 níveis" quer dizer que `<usuário>/a/b/c/d/projeto` entra e mais fundo não. A busca nunca sai dela: outro disco, ou a `C:\` inteira, só entra se a pessoa pedir a pasta.
- **O que ela pula** na pasta do usuário: as pastas escondidas (o nome começa com `.`), `AppData` e `node_modules`. No Mac, pula também `Library` e as pastas Documentos, Mesa e Downloads (`Documents`, `Desktop` e `Downloads` no disco), porque o macOS não deixa tarefas em segundo plano lerem essas pastas. Um projeto que está numa delas só entra pela pasta de projetos ou como pasta pedida, e aí o macOS pode pedir a permissão da pessoa.
- **A conta da pessoa**: o login fica em `github_user`. O `doctor` e a própria verificação gravam sozinhos, lendo o login que o `gh` já guarda no computador (sem internet). Sem login no GitHub, a busca na pasta do usuário fica desligada, e valem só a pasta de projetos e as pastas pedidas. Projetos de uma organização ou de outra pessoa (o `origin` não é da conta dela) não são achados sozinhos: ficam na pasta de projetos, ou a pessoa pede a pasta deles.
- **A pasta de projetos** é onde nascem os projetos novos (skill `git-commands:novo-projeto`) e para onde vão os clones (skill `git-commands:comandos`). Ela é verificada esteja onde estiver, dentro ou fora da pasta do usuário.
- **Pastas ignoradas** (seção "Pedir, tirar e ignorar pastas") tiram da lista tudo o que está dentro delas, nos três lugares.
- A busca só lista pastas e lê o `origin` de cada projeto: não usa a internet nem lê arquivos. Ela tem um limite de tempo para cada etapa: 20 segundos para achar os projetos e mais 20 para conferir de quem eles são. Se uma etapa estourar, a verificação segue com o que achou e com os outros dois lugares.

## Ligar

1. Rode `git-commands folders list`: precisa haver onde procurar, ou seja, a linha `usuario` com `ok` (há login no GitHub), a linha `projetos` com `ok` ou alguma linha `pedida` com `ok`. A pasta de projetos não é obrigatória. Se nenhuma estiver `ok`, use a skill `git-commands:configurar` (login no GitHub ou pasta de projetos) ou peça uma pasta (seção "Pedir, tirar e ignorar pastas").
2. Conte em uma frase onde ela vai procurar (a pasta do usuário, com o caminho todo, e as outras pastas da lista), pergunte o intervalo (padrão: 30 minutos; aceita de 5 a 1440) e espere o ok.
3. Rode `git-commands schedule enable <minutos>` e mostre o resultado (`ligado <minutos>`). No Windows, a tarefa aparece no Agendador de Tarefas com o nome `git-commands-verificar`.

## Desligar, mudar ou ver como está

- Desligar: `git-commands schedule disable`.
- Mudar o intervalo: `git-commands schedule enable <novo intervalo>`.
- Ver como está: `git-commands schedule status`.

## Pedir, tirar e ignorar pastas

Cada pedido muda a configuração da pessoa: mostre o comando e espere o ok. Escreva a pasta pelo caminho completo e entre aspas (um nome com espaço, como `site - Cópia`, só funciona assim).

| A pessoa diz | Comando | O que acontece |
|---|---|---|
| "monitora a pasta X" | `git-commands folders add "<pasta>"` | a pasta entra nas pedidas: os repositórios do GitHub dela (até 2 níveis) passam a ser verificados, mesmo fora da pasta do usuário |
| "para de monitorar a pasta X" | `git-commands folders remove "<pasta>"` | a pasta sai das pedidas (os projetos dela só continuam na lista se outro lugar os achar) |
| "ignora a pasta X" | `git-commands folders ignore "<pasta>"` | a pasta e tudo o que está dentro dela somem da lista, em qualquer lugar. Serve para uma cópia velha ou de backup de um projeto, ou para um projeto antigo esquecido em Downloads |
| "volta a mostrar a pasta X" | `git-commands folders unignore "<pasta>"` | a pasta volta a aparecer |
| "onde você procura?" | `git-commands folders list` | só mostra onde ela procura (não muda nada, então não precisa de ok) |

- Para pedir ou ignorar, a pasta precisa existir. Se não existir, o comando responde `a pasta não existe` e nada muda.
- As mensagens mostram a pasta como ela fica gravada: o caminho real (no Windows, com `/`, como `C:/projetos`). Com `a pasta já estava na lista` ou `a pasta já estava ignorada`, nada mudou.
- Para tirar ou voltar a mostrar uma pasta que já não existe (apagada, disco desligado), escreva o caminho exatamente como o `folders list` mostra.
- Pedir uma pasta não muda onde nascem os projetos novos: isso é a pasta de projetos (skill `git-commands:configurar`).
- A mudança chega ao painel e ao aviso de novidades na próxima verificação. Para mostrar já o que ela acha, sem internet, rode `git-commands updates scan --no-fetch` (só lê, e a primeira coluna é a pasta de cada projeto).

Leia o `git-commands folders list` assim (uma linha por lugar: tipo, pasta e situação, separados por tab):
- `usuario`: a pasta do usuário. `ok`, ou `desligada` quando falta o login no GitHub (skill `git-commands:configurar`).
- `projetos`: a pasta de projetos. `ok`, `nao-encontrada` (a pasta sumiu) ou `nao-configurada` (sem pasta, o que não é problema se há login no GitHub).
- `pedida` e `ignorada`: uma linha por pasta. `ok`, ou `nao-encontrada` quando a pasta sumiu do disco.

## Um projeto não aparece

Rode `git-commands folders list` e veja, nesta ordem:
1. A pasta dele, ou uma pasta que a contém, está ignorada (linha `ignorada`)? Ofereça `folders unignore`.
2. Confira as regras de "Onde ela procura": ele precisa estar na pasta do usuário (até 5 níveis, fora das pastas que a busca pula, e com o `origin` na conta da pessoa) ou na pasta de projetos ou numa pasta pedida (até 2 níveis). Se não está (é de uma organização, está fundo demais, fica numa pasta que a busca pula ou fora da pasta do usuário), ofereça pedir a pasta dele: `folders add`.
3. Só entram projetos do GitHub: um projeto que ainda não está ligado a ele (sem `origin` do GitHub), ou que está em outro serviço, não aparece.
4. Se a busca avisou que parou no meio, veja a seção abaixo.

## Quando ela deu erro ou parou

O plugin avisa na abertura do Claude quando a verificação deu erro ou parou. Os avisos de pasta (`git-commands: aviso: ...`) não derrubam a verificação, e por isso o plugin não os avisa na abertura: eles ficam no fim do `check.log`, na pasta que o `git-commands home` mostra (`tail -n 20 "$(git-commands home)/check.log"`), e aparecem na tela quando se roda `git-commands updates scan`. Quando a pessoa pedir para conferir a verificação, olhe o `check.log` e rode `git-commands schedule status`. Conforme o caso, e sempre com o ok da pessoa:
- Erro "não há onde procurar projetos": não há login no GitHub, nem pasta de projetos que exista, nem pasta pedida que exista. Ofereça fazer o login ou escolher a pasta de projetos (skill `git-commands:configurar`), ou pedir uma pasta (`git-commands folders add "<pasta>"`).
- Aviso "a pasta de projetos não foi encontrada": a pasta foi apagada, renomeada ou está num disco desligado. A verificação seguiu com os outros lugares. Se é só o disco desligado, basta ligá-lo de novo; senão, escolha a pasta de novo (skill `git-commands:configurar`).
- Aviso "a pasta pedida não foi encontrada": o mesmo, para uma pasta pedida. Ofereça tirá-la da lista com `git-commands folders remove "<pasta>"`, escrevendo o caminho exatamente como o `folders list` mostra.
- Aviso "sem permissão para ler a pasta", no Mac: o macOS não deixa tarefas em segundo plano lerem Documentos, Mesa e Downloads. Ofereça mover os projetos de lá para `~/git` (mover um projeto não estraga o git dele). Se era a pasta de projetos, grave a pasta nova com `git-commands config set projects_dir "<pasta>"`; se era uma pasta pedida, tire-a da lista (`folders remove`) e peça a nova (`folders add`).
- Aviso "a busca na pasta do usuário passou de <N> segundos e parou no meio": a pasta do usuário é grande, tem muitos projetos ou o disco está lento. A verificação seguiu com o que achou, e os projetos que a busca não alcançou não aparecem desta vez. Se o aviso se repetir, ofereça pedir a pasta dos projetos que faltam (`git-commands folders add "<pasta>"`): as pastas pedidas são lidas à parte, só até 2 níveis, e não dependem dessa busca.
- "não roda há…": rode `git-commands schedule status`. Se disser `desligado`, ou `ligado` e mesmo assim parada, ligue de novo com `git-commands schedule enable <intervalo>`, que recria o agendamento. No Linux, se continuar parada, o serviço cron pode estar desligado (é comum no WSL): mostre `sudo service cron start` para a pessoa rodar.

## Se a pessoa não quiser

Grave `git-commands config set auto_check_asked yes`, para não perguntar de novo. Ela pode pedir depois, quando quiser.

## Erros comuns

| Erro | Certo |
|---|---|
| Fazer a verificação depender do Claude aberto (um loop na conversa) | Usar `git-commands schedule enable`, que usa o agendador do sistema |
| Oferecer atualizar os projetos sozinho | Só verificar; quem atualiza é a pessoa |
| Exigir a pasta de projetos para ligar | Basta ter onde procurar: login no GitHub (pasta do usuário), pasta de projetos ou pasta pedida (`git-commands folders list`) |
| Falar só "a sua pasta" sem dizer qual | Dizer o caminho inteiro, como a linha `usuario` do `folders list` mostra |
| Mexer na lista de pastas sem mostrar o comando e esperar o ok | Mostrar o comando e esperar o ok |
| Trocar `projects_dir` para monitorar mais uma pasta | Usar `folders add`: `projects_dir` é onde nascem os projetos novos |
| Tirar uma pasta que sumiu escrevendo o caminho de outro jeito | Escrever o caminho exatamente como o `folders list` mostra |
