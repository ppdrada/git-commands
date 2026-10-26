# Glossário do git-commands

Cada seção abaixo é um conceito. Na primeira vez que o conceito aparece para a pessoa, o plugin explica com este texto e depois registra com `git-commands learned add <id>`. O id é o título da seção.

## repositorio
git init é criar ou inicializar um novo repositório Git em um diretório do seu computador. O repositório é a pasta do projeto junto com o histórico de todas as versões salvas.

## git-config
O `git config` guarda o seu nome e o seu e-mail no git. Eles aparecem em cada commit, para mostrar quem fez cada mudança.

## commit
Um commit é um ponto salvo na história do projeto, como uma foto de como os arquivos estavam naquele momento. Cada commit tem uma mensagem curta dizendo o que mudou.

## add
O `git add` escolhe quais alterações vão entrar no próximo commit. É como separar o que vai aparecer na foto antes de tirar.

## readme
O README é o arquivo de apresentação do projeto: é a primeira coisa que aparece na página do repositório no GitHub. Ele conta o que é o projeto e como usar.

## gitignore
O `.gitignore` é a lista de arquivos que o git deve ignorar, como senhas, arquivos temporários e pastas geradas automaticamente. Arquivos dessa lista não entram nos próximos commits; se um deles já estava no git, é preciso tirá-lo com `git rm --cached`.

## remote
O remote é o endereço da cópia do projeto no GitHub. O nome padrão dele é `origin`.

## push
O `git push` envia os seus commits do computador para o GitHub. Depois disso, eles ficam guardados lá e outras pessoas podem ver.

## pull
O `git pull` traz para o seu computador os commits novos que estão no GitHub e junta essas novidades com a sua cópia.

## fetch
O `git fetch` só pergunta ao GitHub o que há de novo, sem mexer nos seus arquivos. É assim que o plugin descobre se existem novidades.

## branch
Uma branch é como um rascunho do projeto: você mexe à vontade sem estragar a versão principal (a `main`). Se ficar bom, junta de volta; se não, é só jogar fora.

## merge
O merge junta as mudanças de uma branch em outra, por exemplo, de um rascunho de volta na `main`.

## conflito
Um conflito acontece quando você e outra pessoa mudaram a mesma parte de um arquivo e o git não sabe qual versão manter. Aí é preciso escolher: a sua, a outra ou uma mistura das duas.

## pull-request
Um pull request (PR) é um pedido, feito no GitHub, para juntar uma branch na `main`. Ele mostra tudo o que mudou antes de juntar, e outras pessoas podem comentar.

## clone
O `git clone` baixa um projeto do GitHub para o seu computador, com todo o histórico.

## stash
O `git stash` guarda por um tempo as alterações que ainda não estão num commit e deixa os arquivos limpos. Depois, o `git stash pop` traz tudo de volta.

## log
O `git log` mostra o histórico de commits: quem fez, quando e a mensagem de cada um.

## diff
O `git diff` mostra exatamente o que mudou nos arquivos: as linhas que saíram e as que entraram.

## publico-privado
Um repositório público pode ser visto por qualquer pessoa na internet. Um privado só aparece para você e para quem você convidar.

## chave-ssh
Uma chave SSH é um par de arquivos: a parte privada fica só no seu computador, como a chave da sua casa; a parte pública vai para o GitHub, como a fechadura. Com ela, o git fala com o GitHub sem login, e a senha da chave protege a parte privada se alguém pegar o arquivo.
