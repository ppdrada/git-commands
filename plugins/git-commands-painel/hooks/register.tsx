// O painel do git-commands: mostra o que a verificação automática já gravou.
// Só lê (config, status.tsv, status.time e check.log): não usa a rede, não roda git e nunca atualiza nada.
import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import { atrasada, lerHora, resumir } from './resumo'
import type { Arquivos } from './resumo'
import { linhaDeStatus } from './textos'

const MINUTO = 60_000

const resumo = atom({ plugin: 'git-commands-painel', key: 'resumo' } as const, null)
const parada = atom({ plugin: 'git-commands-painel', key: 'parada' } as const, null)

/** A mesma pasta que o bash usa: GIT_COMMANDS_HOME, senão ~/.git-commands (no Windows, o HOME pode faltar). */
async function pastaDoGitCommands($: EngineInterface): Promise<string | undefined> {
  const propria = await $.env.get('GIT_COMMANDS_HOME')
  if (propria) return propria
  const casa = (await $.env.get('HOME')) || (await $.env.get('USERPROFILE'))
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

    const novo = resumir(arquivos, agora, desde)
    await update($, resumo, () => novo)

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
    return next(e)
  })

  // Só no fim das respostas da conversa principal, não das de um ajudante (subagente).
  on('turn.complete', async ($, e, next) => {
    const fim = await next(e)
    if (e.agentId === undefined) await atualizar($)
    return fim
  })
}
