import type { On } from 'claude-code'
import { expect, mock, test } from 'claude-code/testing'
import type { Engine } from 'claude-code/testing'

const MINUTO = 60_000
const HORA = 60 * MINUTO
const AGORA = 1_793_006_349_000

const COM_NOVIDADES = 'C:/git/site\tsite\tmain\t0\t3\t0\tnovidades\nC:/git/api\tapi\tmain\t0\t0\t0\tem-dia\n'
const EM_DIA = 'C:/git/site\tsite\tmain\t0\t0\t0\tem-dia\nC:/git/api\tapi\tmain\t0\t0\t0\tem-dia\n'

const segundos = (ms: number) => `${Math.floor(ms / 1000)}\n`

/** Os arquivos da pasta do git-commands, pelo nome; o que não está aqui não existe. */
type Arquivos = Record<string, string | undefined>

function arquivos(mudancas: Arquivos = {}): Arquivos {
  return {
    config: 'auto_check=on\ninterval=30\n',
    'status.tsv': COM_NOVIDADES,
    'status.time': segundos(AGORA - 5 * MINUTO),
    'check.log': '2026-10-26 06:19:09 verificação ok\n',
    ...mudancas,
  }
}

type Mundo = {
  arquivos: Arquivos
  lidos: string[]
  status: (string | undefined)[]
  avisos: string[]
  perguntas: string[]
  abertos: string[]
  /** escritas, rede e comandos: o painel nunca pode pedir nenhum */
  proibidos: string[]
}

/**
 * Os hooks do teste fazem o papel do Claude embaixo do mod. Ficam registrados antes da primeira
 * chamada em `$`. O caminho chega absoluto do sistema (no Windows, `C:\casa\...`), então o
 * arquivo é reconhecido pelas duas últimas partes do caminho.
 */
function mundo(on: On, inicio: Arquivos): Mundo {
  const m: Mundo = { arquivos: inicio, lidos: [], status: [], avisos: [], perguntas: [], abertos: [], proibidos: [] }
  on('fs.read', (_, e) => {
    m.lidos.push(e.path)
    const partes = e.path.split(/[\\/]/)
    const texto = partes.at(-2) === '.git-commands' ? m.arquivos[partes.at(-1) ?? ''] : undefined
    if (texto === undefined) throw new Error(`ENOENT: ${e.path}`)
    return { value: texto }
  })
  on('ui.status', (_, e) => {
    m.status.push(e.text)
    return { value: undefined }
  })
  on('ui.toast', (_, e) => {
    m.avisos.push(e.text)
    return { value: undefined }
  })
  on('command.register', (_, e) => ({ value: { command: e.name } }))
  on('ui.open', (_, e) => {
    m.abertos.push(e.id)
    return { value: { isPlaced: true } }
  })
  on('prompt.submit', (_, e) => {
    m.perguntas.push(e.text)
    return { text: e.text }
  })
  on('session.start', (_, e) => ({ cwd: e.cwd }))
  on('turn.complete', (_, e) => ({ text: e.answer }))
  on('ui.render', ($, e) => {
    const { Text } = $.ui.resolve(e)
    return <Text>engine</Text>
  })
  on('fs.write', (_, e) => {
    m.proibidos.push(`fs.write ${e.path}`)
    return { deny: 'o painel só lê' }
  })
  on('http.fetch', (_, e) => {
    m.proibidos.push(`http.fetch ${e.url}`)
    return { deny: 'o painel não usa a rede' }
  })
  on('process.run', (_, e) => {
    m.proibidos.push(`process.run ${e.argv.join(' ')}`)
    return { deny: 'o painel não roda comandos' }
  })
  on('env.set', (_, e) => {
    m.proibidos.push(`env.set ${e.name}`)
    return { deny: 'o painel não muda o ambiente' }
  })
  return m
}

const abrir = ($: Engine) => $.session.start({ cwd: '/', surface: 'desktop', isInteractive: true })

function fimDaResposta(agentId?: string) {
  return { answer: 'ok', durationMs: 5, isAborted: false, turnId: `t-${agentId ?? 'principal'}`, reason: 'answer' as const, agentId }
}

test('ao abrir a sessão, a linha de status conta os projetos com novidades', async ($, on) => {
  mock.clock(on, { now: AGORA })
  mock.env(on, { HOME: '/casa' })
  const m = mundo(on, arquivos())

  await abrir($)

  expect(m.status.at(-1)).toBe('git-commands: 1 com novidades')
})

test('atualiza no fim de cada resposta da conversa', async ($, on) => {
  mock.clock(on, { now: AGORA })
  mock.env(on, { HOME: '/casa' })
  const m = mundo(on, arquivos())
  await abrir($)

  m.arquivos['status.tsv'] = EM_DIA
  await $.turn.complete(fimDaResposta('ajudante-1'))
  expect(m.status.at(-1)).toBe('git-commands: 1 com novidades')

  await $.turn.complete(fimDaResposta())
  expect(m.status.at(-1)).toBe('git-commands: em dia')
})

test('atualiza a cada minuto', async ($, on) => {
  const relogio = mock.clock(on, { now: AGORA })
  mock.env(on, { HOME: '/casa' })
  const m = mundo(on, arquivos())
  await abrir($)

  m.arquivos['status.tsv'] = EM_DIA
  await relogio.advance(MINUTO)

  expect(m.status.at(-1)).toBe('git-commands: em dia')
})

test('a verificação só fica parada depois de 5 minutos atrasada', async ($, on) => {
  const relogio = mock.clock(on, { now: AGORA })
  mock.env(on, { HOME: '/casa' })
  const m = mundo(on, arquivos({ 'status.tsv': EM_DIA, 'status.time': segundos(AGORA - 4 * HORA) }))

  await abrir($)
  expect(m.status.at(-1)).toBe('git-commands: esperando a verificação')

  await relogio.advance(4 * MINUTO)
  expect(m.status.at(-1)).toBe('git-commands: esperando a verificação')

  await relogio.advance(MINUTO)
  expect(m.status.at(-1)).toBe('git-commands: verificação parada')

  m.arquivos['status.time'] = segundos(relogio.now())
  await relogio.advance(MINUTO)
  expect(m.status.at(-1)).toBe('git-commands: em dia')
})

const PASTAS = [
  { variaveis: { GIT_COMMANDS_HOME: '/outra/pasta', HOME: '/casa' }, pasta: 'outra' },
  { variaveis: { HOME: '/casa', USERPROFILE: '/perfil' }, pasta: 'casa' },
  { variaveis: { USERPROFILE: '/perfil' }, pasta: 'perfil' },
] as const

for (const { variaveis, pasta } of PASTAS) {
  test(`lê a pasta do GIT_COMMANDS_HOME, do HOME ou do USERPROFILE (${Object.keys(variaveis).join(', ')})`, async ($, on) => {
    mock.clock(on, { now: AGORA })
    mock.env(on, variaveis)
    const m = mundo(on, {})

    await abrir($)

    expect(m.lidos.length).toBe(4)
    expect(m.lidos.filter(caminho => caminho.includes(pasta)).length).toBe(4)
  })
}

test('só lê: nunca escreve, nunca usa a rede e nunca roda comandos', async ($, on) => {
  const relogio = mock.clock(on, { now: AGORA })
  mock.env(on, { HOME: '/casa' })
  const m = mundo(on, arquivos())

  await abrir($)
  await $.turn.complete(fimDaResposta())
  await relogio.advance(2 * MINUTO)

  expect(m.lidos.length).toBeGreaterThan(0)
  expect(m.proibidos).toEqual([])
})
