// O painel do git-commands: mostra o que a verificação automática já gravou.
// Só lê (config, status.tsv, status.time e check.log): não usa a rede, não roda git e nunca atualiza nada.
import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import type { Resumo } from '../types'
import {
  atrasada,
  comNovidades,
  entradas,
  lerHora,
  ordenarParaOPainel,
  podarEscondidas,
  resumir,
  temNovidadeAMostrar,
  temNovidadeNova,
} from './resumo'
import type { Arquivos } from './resumo'
import {
  cabecalhoDoPainel,
  corDoEstado,
  linhaDeStatus,
  linhaForaDaVerificacao,
  listaDeNovidades,
  pastaDoProjeto,
  PERGUNTA,
  rotuloDoEstado,
} from './textos'

const MINUTO = 60_000
const PAINEL = 'painel'

const resumo = atom({ plugin: 'git-commands-painel', key: 'resumo' } as const, null)
const parada = atom({ plugin: 'git-commands-painel', key: 'parada' } as const, null)
const escondidas = atom({ plugin: 'git-commands-painel', key: 'escondidas' } as const, null)
const avisado = atom({ plugin: 'git-commands-painel', key: 'avisado' } as const, null)

/** A pasta do usuário: o HOME ou, sem ele (no Windows, o HOME pode faltar), o USERPROFILE. */
async function pastaDoUsuario($: EngineInterface): Promise<string | null> {
  return (await $.env.get('HOME')) || (await $.env.get('USERPROFILE')) || null
}

/** A mesma pasta que o bash usa: GIT_COMMANDS_HOME, senão ~/.git-commands. */
async function pastaDoGitCommands($: EngineInterface): Promise<string | undefined> {
  const propria = await $.env.get('GIT_COMMANDS_HOME')
  if (propria) return propria
  const casa = await pastaDoUsuario($)
  return casa ? `${casa}/.git-commands` : undefined
}

async function lerTexto($: EngineInterface, caminho: string): Promise<string | undefined> {
  try {
    return await $.fs.read(caminho)
  } catch {
    return undefined
  }
}

async function lerArquivos($: EngineInterface): Promise<Arquivos> {
  const pasta = await pastaDoGitCommands($)
  if (pasta === undefined) return {}
  const [config, tsv, time, log] = await Promise.all(
    ['config', 'status.tsv', 'status.time', 'check.log'].map(nome => lerTexto($, `${pasta}/${nome}`)),
  )
  return { config, tsv, time, log }
}

/** O aviso rápido: só quando uma verificação nova traz commits que ainda não tinham aparecido. */
async function avisarNovidades($: EngineInterface, novo: Resumo): Promise<void> {
  const antes = await read($, avisado)
  const ehNova = antes !== null && novo.verificadoEm !== antes.verificadoEm
  if (ehNova && novo.situacao === 'ok' && temNovidadeNova(antes.novos, novo.projetos)) {
    $.ui.toast(`Novidades no GitHub: ${listaDeNovidades(novo.projetos)}`)
  }
  const novos = Object.fromEntries(comNovidades(novo.projetos).map(p => [p.caminho, p.novos]))
  const depois = { verificadoEm: novo.verificadoEm, novos }
  if (JSON.stringify(antes) !== JSON.stringify(depois)) await update($, avisado, () => depois)
}

let ultimaLinha: string | undefined

async function atualizar($: EngineInterface): Promise<void> {
  try {
    const arquivos = await lerArquivos($)
    const agora = await $.clock.now()

    // Atrasada há pouco pode ser o computador que acabou de acordar: conta desde quando, por status.time.
    const verificadoEm = lerHora(arquivos.time)
    const antes = await read($, parada)
    const desde = atrasada(arquivos, agora) ? (antes?.verificadoEm === verificadoEm ? antes.desde : agora) : null
    const depois = desde === null ? null : { verificadoEm, desde }
    if (JSON.stringify(antes) !== JSON.stringify(depois)) await update($, parada, () => depois)

    const novo = resumir(arquivos, agora, desde, await pastaDoUsuario($))
    await update($, resumo, () => novo)
    await avisarNovidades($, novo)

    const ocultas = await read($, escondidas)
    if (ocultas !== null) {
      const podadas = podarEscondidas(ocultas, novo.projetos)
      if (podadas.length !== ocultas.length) await update($, escondidas, () => podadas)
    }

    const linha = linhaDeStatus(novo)
    if (linha !== ultimaLinha) {
      $.ui.status(linha)
      ultimaLinha = linha
    }
  } catch {
    // O painel nunca atrapalha a conversa: o que falhar agora é tentado de novo no próximo minuto.
  }
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await atualizar($)
    $.clock.every(MINUTO, () => {
      void atualizar($)
    })
    // Sem o /painel (outro plugin já tem um, por exemplo), a linha de status e a faixa continuam.
    try {
      await $.command.register({ name: 'painel', description: 'Mostra o estado dos seus projetos do GitHub (git-commands)' })
    } catch {}
    return next(e)
  })

  // Só no fim das respostas da conversa principal, não das de um ajudante (subagente).
  on('turn.complete', async ($, e, next) => {
    const fim = await next(e)
    if (e.agentId === undefined) await atualizar($)
    return fim
  })

  // A faixa acima da caixa de mensagem: só com novidades, e some até chegar uma que ainda não foi escondida.
  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const atual = await read($, resumo)
    const valeMostrar = atual?.situacao === 'ok' || atual?.situacao === 'esperando'
    if (e.props.hasSurvey || atual === null || !valeMostrar) return next(e)
    if (!temNovidadeAMostrar(atual.projetos, (await read($, escondidas)) ?? [])) return next(e)

    const { Box, Button, Text } = $.ui.resolve(e)
    const desenhadas = entradas(atual.projetos)
    const esconder = () => update($, escondidas, antes => [...new Set([...(antes ?? []), ...desenhadas])])
    const verAgora = async () => {
      await esconder()
      void $.prompt.submit({ text: PERGUNTA })
    }
    return (
      <Box gap={1} flexWrap="wrap">
        <Text>Novidades no GitHub: {listaDeNovidades(atual.projetos)}</Text>
        <Button key="ver" label="Ver agora" variant="primary" onPress={verAgora} />
        <Button key="depois" label="Depois" onPress={esconder} />
      </Box>
    )
  })

  on('command.run', { command: 'painel' }, async $ => {
    await atualizar($)
    const aberto = await $.ui.open({ id: PAINEL, title: 'git-commands' })
    return aberto.isPlaced ? {} : { text: 'Não deu para abrir o painel aqui.' }
  })

  // O painel ao lado da conversa: todos os projetos, os que pedem atenção primeiro.
  on('ui.render', { component: 'Pane', requestId: PAINEL }, async ($, e) => {
    const { Box, Text } = $.ui.resolve(e)
    const atual = await read($, resumo)
    if (atual === null) return <Text dimColor>Lendo o estado dos projetos…</Text>

    const semProjetos = atual.verificadoEm !== null && atual.situacao !== 'desligada' && atual.projetos.length === 0
    return (
      <Box flexDirection="column" gap={1}>
        <Text dimColor>{cabecalhoDoPainel(atual)}</Text>
        {atual.foraDaVerificacao > 0 && <Text color="warning">{linhaForaDaVerificacao(atual.foraDaVerificacao)}</Text>}
        {atual.projetos.length > 0 && (
          <Box flexDirection="column">
            {ordenarParaOPainel(atual.projetos).map(p => {
              // A pasta vai em cinza, antes do nome e com um espaço entre os dois (o gap).
              // Direto na pasta do usuário ela é vazia e some, e a linha fica só com o nome.
              const pasta = pastaDoProjeto(p.caminho, atual.casa)
              return (
                <Box gap={1}>
                  {pasta !== '' && <Text dimColor>{pasta}</Text>}
                  <Text color={corDoEstado(p.estado)}>
                    {p.nome} ({p.branch}): {rotuloDoEstado(p)}
                  </Text>
                </Box>
              )
            })}
          </Box>
        )}
        {semProjetos && <Text dimColor>Nenhum projeto do GitHub encontrado.</Text>}
        {comNovidades(atual.projetos).length > 0 && (
          <Text dimColor>Para ver e atualizar, peça ao Claude: "{PERGUNTA}"</Text>
        )}
      </Box>
    )
  })
}
