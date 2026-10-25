# git-commands

Plugin do Claude Code que faz git e GitHub por você, ensinando enquanto faz. Feito para quem está começando.

## O que ele faz

- Começa um projeto do zero e coloca no GitHub, passo a passo.
- Salva o seu trabalho (commit) e envia para o GitHub (push), sempre mostrando a mensagem antes e pedindo ok.
- Cria branches e pull requests, e sempre manda o link do PR.
- Avisa quando os seus projetos têm novidades no GitHub e pergunta antes de atualizar. Se der conflito, resolve com você.
- Explica cada conceito na primeira vez e pede confirmação antes de qualquer comando que possa apagar trabalho.

## Instalar

1. Instale o [Claude Code](https://code.claude.com/docs/en/setup).
2. Abra o terminal e rode estes dois comandos:

   ```
   claude plugin marketplace add ppdrada/git-commands
   ```

   ```
   claude plugin install git-commands@git-commands
   ```

   No Claude Code 2.1.275 ou mais novo, também dá para instalar num passo só, dentro do Claude: `/plugin install git-commands --marketplace ppdrada/git-commands`.
3. Feche e abra o Claude de novo.
4. Confira: `claude plugin list` deve mostrar `git-commands@git-commands` ligado.

O plugin usa o git e o GitHub CLI (`gh`). Se faltar algum dos dois, ele mesmo explica como instalar e guia o login no GitHub.

## Primeiros passos

Fale com o Claude do seu jeito. Por exemplo:

| Você diz | O que o plugin faz |
|---|---|
| "configura o git e o GitHub no meu PC" | instala o que falta e guia o login (`configurar`) |
| "quero começar um projeto" | cria o repositório e coloca no GitHub (`novo-projeto`) |
| "salva meu trabalho e manda pro GitHub" | faz o commit e o push, mostrando a mensagem antes (`salvar`) |
| "vou começar a mexer na página de login" | pergunta se você quer uma branch e, no fim, abre o PR (`branch-e-pr`) |
| "tem algo novo nos meus projetos?" | mostra as novidades e pergunta o que fazer (`atualizar`) |
| "o que é um commit?" | explica, mesmo que já tenha explicado antes (`comandos`) |

Também dá para chamar direto: `/git-commands:novo-projeto`, `/git-commands:salvar` e assim por diante.

## Verificação automática

O plugin pode procurar novidades nos seus projetos sozinho, de tempos em tempos (o padrão é a cada 30 minutos). Ele usa o agendador do próprio sistema: Agendador de Tarefas no Windows, launchd no macOS e cron no Linux, então funciona mesmo com o Claude fechado. Ele só verifica, nunca atualiza nada sozinho. Quando você abrir o Claude, ele conta o que mudou.

- Ligar: "quero que você verifique meus projetos a cada 30 minutos"
- Mudar o intervalo: "verifica a cada 15 minutos"
- Desligar: "desliga a verificação automática"

## Desligar num projeto

Num projeto do GitHub, o plugin entra em ação sozinho: traz as regras dele quando o Claude abre e confere as novidades antes da primeira edição. Para desligar só num projeto, diga "desliga o git-commands neste projeto" (ou rode `git-commands proactive off` dentro dele). Para desligar em todos, `git-commands proactive off --all`.

## Segurança

- Comandos que podem apagar trabalho (forçar envio, descartar alterações, apagar branch, stash ou repositório) sempre pedem a sua confirmação, venham de onde vierem.
- O plugin avisa antes de mandar para o GitHub arquivos com cara de senha ou chave (`.env`, chaves privadas, tokens).
- O login no GitHub é sempre feito por você, no navegador. Nunca cole senhas, tokens ou códigos no chat.

## Desinstalar

Se a verificação automática estiver ligada, desligue antes ("desliga a verificação automática"). Depois:

```
claude plugin uninstall git-commands@git-commands
```

O progresso (conceitos já explicados e configurações) fica na pasta `~/.git-commands`. Apague essa pasta se quiser começar do zero.

## Para quem quer contribuir

- Testes: `bash tests/run.sh` (ou `bash tests/run.sh <parte do nome>` para rodar só alguns).
- No GitHub, os testes rodam em Windows, macOS (com o bash 3.2) e Linux a cada envio.
- Validação: `claude plugin validate plugins/git-commands --strict`.
- O design e o plano de construção estão em `docs/superpowers/`.

## Licença

MIT
