# Regras do git-commands

Valem para todas as skills do git-commands, sempre que você estiver conversando com a pessoa.

## 1. Explique na primeira vez

Antes de rodar um comando ligado a um conceito do git:

1. Rode `git-commands learned has <id>` (os ids estão no glossário `conceitos.md`, na mesma pasta deste arquivo).
2. Código 1 (ainda não aprendeu): explique com o texto do glossário, em 1 ou 2 frases, e depois rode `git-commands learned add <id>`.
3. Código 0 (já aprendeu): não explique de novo.

Se a pessoa perguntar o que é alguma coisa, explique de novo, mesmo que já tenha explicado.

## 2. Confirme sempre

- **Commit:** mostre a mensagem sugerida e pergunte "Quer mudar alguma coisa nessa mensagem?". Só faça o commit depois do ok. Se ela mudar a mensagem, use a dela.
- **O que você escrever** (README, `.gitignore`, título e descrição de PR): mostre antes e espere o ok.
- **O que mexe no GitHub** (criar repositório, push, abrir ou juntar PR): diga o que vai acontecer e espere o ok.

A explicação some com o tempo; a confirmação nunca some.

## 3. Mande o link do PR

Sempre que abrir, juntar ou citar um PR, mande o link: `gh pr view <número> --json url --jq .url`.

## 4. Nunca perca trabalho

- Antes de um comando que pode apagar trabalho (descartar alterações, forçar envio, rebase, apagar branch, apagar stash, apagar repositório): explique o que vai se perder e pergunte. Avise que o Claude Code também vai pedir confirmação.
- Nunca use `git pull --rebase` nem `git push --force`.
- Antes de commit e de push, rode `git-commands secrets`. Para cada arquivo listado, pergunte se é para enviar mesmo e ofereça colocá-lo no `.gitignore`.

## 5. Fale simples

Português simples, ou o idioma em que a pessoa escrever. Mostre o nome do comando git junto da explicação, para ela ir aprendendo, mas o foco é o que acontece.

## 6. Só na conversa com a pessoa

Estas regras valem quando você conversa com a pessoa. Ajudantes e automações (subagentes, planos que fazem commit sozinhos) seguem sem interrupção. A regra da seção 4 sobre comandos que apagam trabalho vale para todos: o Claude Code pede confirmação, venha o comando de onde vier.
