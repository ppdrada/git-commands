---
name: verificacao-automatica
description: Use quando a pessoa quer que os projetos sejam verificados sozinhos de tempos em tempos, quer ligar, desligar ou mudar o intervalo da verificação automática de novidades do GitHub, quando a verificação automática deu erro ou parou de rodar, ou quando outra skill do git-commands perguntar sobre isso, com frases como "verificar sozinho", "a cada 30 minutos", "desligar a verificação automática" ou "mudar o intervalo".
---

# Verificação automática

Leia `${CLAUDE_PLUGIN_ROOT}/reference/regras.md` antes de qualquer passo.

## O que explicar antes de ligar

- O plugin cria um agendamento no próprio sistema (Agendador de Tarefas no Windows, launchd no Mac, cron no Linux). Ele funciona mesmo com o Claude fechado, enquanto o computador estiver ligado.
- Ele só **verifica** se há novidades no GitHub, sem mexer em nenhum arquivo. Quando a pessoa abrir o Claude, o plugin conta o que mudou e pergunta o que fazer.
- Não ofereça atualizar sozinho: o git-commands nunca atualiza nada sem a pessoa pedir.

## Ligar

1. Rode `git-commands config get projects_dir`. Se vier vazio, use a skill `git-commands:configurar` para escolher a pasta de projetos.
2. Pergunte o intervalo (padrão: 30 minutos; aceita de 5 a 1440) e espere o ok.
3. Rode `git-commands schedule enable <minutos>` e mostre o resultado (`ligado <minutos>`). No Windows, a tarefa aparece no Agendador de Tarefas com o nome `git-commands-verificar`.

## Desligar, mudar ou ver como está

- Desligar: `git-commands schedule disable`.
- Mudar o intervalo: `git-commands schedule enable <novo intervalo>`.
- Ver como está: `git-commands schedule status`.

## Quando ela deu erro ou parou

O plugin avisa na abertura do Claude. Conforme o aviso, e sempre com o ok da pessoa:
- "sem permissão para ler a pasta de projetos", no Mac: o macOS não deixa tarefas em segundo plano lerem Documentos, Mesa e Downloads. Ofereça mover a pasta de projetos para `~/git` (mover um projeto não estraga o git dele) e gravar a pasta nova com `git-commands config set projects_dir "<pasta>"`.
- "a pasta de projetos não existe" ou "não está configurada": escolha a pasta de novo (skill `git-commands:configurar`).
- "não roda há…": rode `git-commands schedule status`. Se disser `desligado`, ou `ligado` e mesmo assim parada, ligue de novo com `git-commands schedule enable <intervalo>`, que recria o agendamento. No Linux, se continuar parada, o serviço cron pode estar desligado (é comum no WSL): mostre `sudo service cron start` para a pessoa rodar.

## Se a pessoa não quiser

Grave `git-commands config set auto_check_asked yes`, para não perguntar de novo. Ela pode pedir depois, quando quiser.

## Erros comuns

| Erro | Certo |
|---|---|
| Fazer a verificação depender do Claude aberto (um loop na conversa) | Usar `git-commands schedule enable`, que usa o agendador do sistema |
| Oferecer atualizar os projetos sozinho | Só verificar; quem atualiza é a pessoa |
| Ligar sem a pasta de projetos configurada | Configurar a pasta antes |
