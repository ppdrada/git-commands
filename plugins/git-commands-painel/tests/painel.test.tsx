import type { On } from 'claude-code'
import { expect, mock, test } from 'claude-code/testing'
import type { Engine, FoundElement } from 'claude-code/testing'

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
  /** se a tela consegue mostrar o painel */
  abre: boolean
  /** se o Claude aceita registrar o /painel */
  registra: boolean
  /** escritas, rede e comandos: o painel nunca pode pedir nenhum */
  proibidos: string[]
}

/**
 * Os hooks do teste fazem o papel do Claude embaixo do mod. Ficam registrados antes da primeira
 * chamada em `$`. O caminho chega absoluto do sistema (no Windows, `C:\casa\...`), então o
 * arquivo é reconhecido pelas duas últimas partes do caminho.
 */
function mundo(on: On, inicio: Arquivos): Mundo {
  const m: Mundo = {
    arquivos: inicio,
    lidos: [],
    status: [],
    avisos: [],
    perguntas: [],
    abertos: [],
    abre: true,
    registra: true,
    proibidos: [],
  }
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
  on('command.register', (_, e) => (m.registra ? { value: { command: e.name } } : { deny: 'já existe um /painel' }))
  on('ui.open', (_, e) => {
    m.abertos.push(e.id)
    return { value: m.abre ? { isPlaced: true } : { isPlaced: false, reason: 'no-surface' } }
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

// Depois de acordar, o agendador do macOS e o do Linux só rodam no próximo intervalo.
test('a verificação só fica parada depois de um intervalo e 5 minutos atrasada', async ($, on) => {
  const relogio = mock.clock(on, { now: AGORA })
  mock.env(on, { HOME: '/casa' })
  const m = mundo(on, arquivos({ 'status.tsv': EM_DIA, 'status.time': segundos(AGORA - 4 * HORA) }))

  await abrir($)
  expect(m.status.at(-1)).toBe('git-commands: esperando a verificação')

  await relogio.advance(34 * MINUTO)
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

const DUAS_NOVIDADES = 'C:/git/site\tsite\tmain\t0\t3\t0\tnovidades\nC:/git/api\tapi\tmain\t0\t1\t0\tnovidades\n'
const TELAS = ['terminal', 'desktop', 'vscode', 'mobile'] as const

const FAIXA = {
  plugin: 'git-commands-painel',
  component: 'AbovePrompt',
  props: { hasSurvey: false, isWorking: false, maxRows: 10, bodyColumns: 80, scroll: { offset: 0, bodyRows: 9 }, view: {} },
} as const

test('a faixa aparece só quando há novidades, em todas as telas', async ($, on) => {
  mock.clock(on, { now: AGORA })
  mock.env(on, { HOME: '/casa' })
  const m = mundo(on, arquivos({ 'status.tsv': DUAS_NOVIDADES }))
  await abrir($)

  for (const surface of TELAS) {
    const ui = await $.ui.mount({ ...FAIXA, surface })
    expect((await ui.find({ type: 'Text', text: /Novidades/ }))?.text).toBe('Novidades no GitHub: site (3), api (1)')
    await ui.unmount()
  }

  m.arquivos['status.tsv'] = EM_DIA
  await $.turn.complete(fimDaResposta())
  const ui = await $.ui.mount({ ...FAIXA, surface: 'desktop' })
  expect(await ui.find({ type: 'Text', text: /Novidades/ })).toBeUndefined()
  expect((await ui.find({ type: 'Text', text: /engine/ }))?.text).toBe('engine')
  await ui.unmount()
})

test('Ver agora manda a pergunta e esconde a faixa', async ($, on) => {
  mock.clock(on, { now: AGORA })
  mock.env(on, { HOME: '/casa' })
  const m = mundo(on, arquivos({ 'status.tsv': DUAS_NOVIDADES }))
  await abrir($)

  const ui = await $.ui.mount({ ...FAIXA, surface: 'desktop' })
  await ui.press({ key: 'ver' })

  expect(m.perguntas).toEqual(['tem algo novo nos meus projetos?'])
  expect(await ui.find({ type: 'Text', text: /Novidades/ })).toBeUndefined()
  await ui.unmount()
})

test('Depois esconde a faixa até a lista mudar', async ($, on) => {
  const relogio = mock.clock(on, { now: AGORA })
  mock.env(on, { HOME: '/casa' })
  const m = mundo(on, arquivos({ 'status.tsv': DUAS_NOVIDADES }))
  await abrir($)

  const ui = await $.ui.mount({ ...FAIXA, surface: 'desktop' })
  await ui.press({ key: 'depois' })
  expect(await ui.find({ type: 'Text', text: /Novidades/ })).toBeUndefined()

  await relogio.advance(MINUTO)
  expect(await ui.find({ type: 'Text', text: /Novidades/ })).toBeUndefined()

  m.arquivos['status.tsv'] = DUAS_NOVIDADES.replace('\t0\t3\t0\t', '\t0\t4\t0\t')
  await relogio.advance(MINUTO)
  expect((await ui.find({ type: 'Text', text: /Novidades/ }))?.text).toBe('Novidades no GitHub: site (4), api (1)')
  expect(m.perguntas).toEqual([])
  await ui.unmount()
})

test('a faixa dá lugar a uma pesquisa', async ($, on) => {
  mock.clock(on, { now: AGORA })
  mock.env(on, { HOME: '/casa' })
  mundo(on, arquivos({ 'status.tsv': DUAS_NOVIDADES }))
  await abrir($)

  const ui = await $.ui.mount({ ...FAIXA, props: { ...FAIXA.props, hasSurvey: true }, surface: 'desktop' })
  expect(await ui.find({ type: 'Text', text: /Novidades/ })).toBeUndefined()
  expect((await ui.find({ type: 'Text', text: /engine/ }))?.text).toBe('engine')
  await ui.unmount()
})

test('aviso rápido só quando uma verificação nova traz novidade', async ($, on) => {
  const relogio = mock.clock(on, { now: AGORA })
  mock.env(on, { HOME: '/casa' })
  const m = mundo(on, arquivos({ 'status.tsv': DUAS_NOVIDADES }))

  await abrir($)
  expect(m.avisos).toEqual([])

  m.arquivos['status.time'] = segundos(relogio.now())
  await relogio.advance(MINUTO)
  expect(m.avisos).toEqual([])

  m.arquivos['status.tsv'] = DUAS_NOVIDADES.replace('\t0\t1\t0\t', '\t0\t2\t0\t')
  m.arquivos['status.time'] = segundos(relogio.now())
  await relogio.advance(MINUTO)
  expect(m.avisos).toEqual(['Novidades no GitHub: site (3), api (2)'])

  await relogio.advance(MINUTO)
  expect(m.avisos.length).toBe(1)
})

const PAINEL = {
  plugin: 'git-commands-painel',
  component: 'Pane',
  requestId: 'painel',
  props: {
    title: 'git-commands',
    isFocused: false,
    bodyColumns: 60,
    placement: 'dock',
    scroll: { offset: 0, bodyRows: 20 },
    view: {},
  },
} as const

const PAINEL_PEDIDO = {
  command: 'painel',
  args: '',
  origin: { kind: 'composer' },
  presentation: { isFullscreen: false, columns: 120 },
} as const

test('/painel abre o painel com o estado de cada projeto, em todas as telas', async ($, on) => {
  mock.clock(on, { now: AGORA })
  mock.env(on, { HOME: '/casa' })
  const m = mundo(on, arquivos({ 'status.tsv': `C:/git/api\tapi\tmain\t0\t0\t0\tem-dia\n${COM_NOVIDADES.split('\n')[0]}\n` }))
  await abrir($)

  expect(await $.command.run(PAINEL_PEDIDO)).toEqual({})
  expect(m.abertos).toEqual(['painel'])

  // Os projetos estão fora da pasta do usuário (/casa): a pasta aparece inteira antes de cada um.
  for (const surface of TELAS) {
    const ui = await $.ui.mount({ ...PAINEL, surface })
    expect((await ui.findAll({ type: 'Text' })).map(t => t.text)).toEqual([
      'Última verificação há 5 minutos. Ela roda a cada 30 minutos.',
      'C:\\git\\',
      'site (main): com novidades (3)',
      'C:\\git\\',
      'api (main): em dia',
      'Para ver e atualizar, peça ao Claude: "tem algo novo nos meus projetos?"',
    ])
    await ui.unmount()
  }
})

const NA_CASA =
  '/casa/Documents/site\tsite\tmain\t0\t3\t0\tnovidades\n/casa/Documents/git/api\tapi\tmain\t0\t0\t0\tem-dia\n'

/** Os filhos do Box da lista de projetos: o único Box em coluna sem `gap`. */
function filhosDaLista(caixas: FoundElement[]) {
  return caixas.find(b => b.props.flexDirection === 'column' && b.props.gap === undefined)?.children
}

test('o painel mostra em cinza a pasta de cada projeto, contada a partir da pasta do usuário', async ($, on) => {
  mock.clock(on, { now: AGORA })
  mock.env(on, { HOME: '/casa' })
  mundo(on, arquivos({ 'status.tsv': NA_CASA }))
  await abrir($)
  await $.command.run(PAINEL_PEDIDO)

  for (const surface of TELAS) {
    const ui = await $.ui.mount({ ...PAINEL, surface })
    const textos = await ui.findAll({ type: 'Text' })
    expect(textos.map(t => t.text)).toEqual([
      'Última verificação há 5 minutos. Ela roda a cada 30 minutos.',
      'Documents/',
      'site (main): com novidades (3)',
      'Documents/git/',
      'api (main): em dia',
      'Para ver e atualizar, peça ao Claude: "tem algo novo nos meus projetos?"',
    ])
    // A pasta vai em cinza e o texto do projeto fica só na cor do estado.
    expect(textos.find(t => t.text === 'Documents/')?.props).toEqual({ dimColor: true })
    expect(textos.find(t => t.text === 'Documents/git/')?.props).toEqual({ dimColor: true })
    expect(textos.find(t => t.text === 'site (main): com novidades (3)')?.props).toEqual({ color: 'warning' })
    expect(textos.find(t => t.text === 'api (main): em dia')?.props).toEqual({ color: 'success' })
    // Cada projeto é um Box com dois Text, primeiro a pasta e depois o projeto, com um espaço entre os dois.
    expect(filhosDaLista(await ui.findAll({ type: 'Box' }))).toMatchObject([
      {
        type: 'Box',
        props: { gap: 1 },
        children: [{ type: 'Text', children: ['Documents/'] }, { type: 'Text', props: { color: 'warning' } }],
      },
      {
        type: 'Box',
        props: { gap: 1 },
        children: [{ type: 'Text', children: ['Documents/git/'] }, { type: 'Text', props: { color: 'success' } }],
      },
    ])
    await ui.unmount()
  }
})

test('um projeto direto na pasta do usuário aparece sem pasta na frente', async ($, on) => {
  mock.clock(on, { now: AGORA })
  mock.env(on, { HOME: '/casa' })
  const tsv = '/srv/projetos/api\tapi\tmain\t0\t2\t0\tnovidades\n/casa/blog\tblog\tmain\t0\t0\t0\tem-dia\n'
  mundo(on, arquivos({ 'status.tsv': tsv }))
  await abrir($)
  await $.command.run(PAINEL_PEDIDO)

  const ui = await $.ui.mount({ ...PAINEL, surface: 'desktop' })
  expect((await ui.findAll({ type: 'Text' })).map(t => t.text)).toEqual([
    'Última verificação há 5 minutos. Ela roda a cada 30 minutos.',
    '/srv/projetos/',
    'api (main): com novidades (2)',
    'blog (main): em dia',
    'Para ver e atualizar, peça ao Claude: "tem algo novo nos meus projetos?"',
  ])
  expect(filhosDaLista(await ui.findAll({ type: 'Box' }))).toMatchObject([
    { type: 'Box', props: { gap: 1 }, children: [{ props: { dimColor: true } }, { props: { color: 'warning' } }] },
    { type: 'Box', props: { gap: 1 }, children: [{ props: { color: 'success' } }] },
  ])
  await ui.unmount()
})

// A pasta do usuário é a mesma que o painel já lê: o HOME ou, sem ele, o USERPROFILE.
// O GIT_COMMANDS_HOME só muda a pasta do estado: nas linhas com um USERPROFILE do Windows ele a mantém num
// caminho que qualquer sistema aceita, e a pasta do usuário continua vindo só do HOME ou do USERPROFILE.
const ESTADO = '/outra/.git-commands'
const CASAS = [
  {
    quem: 'HOME',
    variaveis: { HOME: '/casa', USERPROFILE: 'C:\\Users\\perfil' },
    caminho: '/casa/Documents/site',
    pasta: 'Documents/',
  },
  {
    quem: 'USERPROFILE',
    variaveis: { GIT_COMMANDS_HOME: ESTADO, USERPROFILE: 'C:\\Users\\pessoa' },
    caminho: 'C:/Users/pessoa/Documents/site',
    pasta: 'Documents\\',
  },
  {
    quem: 'USERPROFILE com HOME vazio',
    variaveis: { GIT_COMMANDS_HOME: ESTADO, HOME: '', USERPROFILE: 'C:\\Users\\pessoa' },
    caminho: 'C:/Users/pessoa/Documents/site',
    pasta: 'Documents\\',
  },
  {
    quem: 'HOME com GIT_COMMANDS_HOME',
    variaveis: { GIT_COMMANDS_HOME: ESTADO, HOME: '/casa' },
    caminho: '/casa/Documents/site',
    pasta: 'Documents/',
  },
] as const

for (const { quem, variaveis, caminho, pasta } of CASAS) {
  test(`o painel conta a pasta a partir da pasta do usuário (${quem})`, async ($, on) => {
    mock.clock(on, { now: AGORA })
    mock.env(on, variaveis)
    mundo(on, arquivos({ 'status.tsv': `${caminho}\tsite\tmain\t0\t3\t0\tnovidades\n` }))
    await abrir($)
    await $.command.run(PAINEL_PEDIDO)

    const ui = await $.ui.mount({ ...PAINEL, surface: 'desktop' })
    expect((await ui.findAll({ type: 'Text' })).map(t => t.text)).toEqual([
      'Última verificação há 5 minutos. Ela roda a cada 30 minutos.',
      pasta,
      'site (main): com novidades (3)',
      'Para ver e atualizar, peça ao Claude: "tem algo novo nos meus projetos?"',
    ])
    await ui.unmount()
  })
}

test('o painel explica quando a verificação está desligada', async ($, on) => {
  mock.clock(on, { now: AGORA })
  mock.env(on, { HOME: '/casa' })
  mundo(on, {})
  await abrir($)
  await $.command.run(PAINEL_PEDIDO)

  const ui = await $.ui.mount({ ...PAINEL, surface: 'desktop' })
  expect((await ui.findAll({ type: 'Text' })).map(t => t.text)).toEqual([
    'A verificação automática está desligada. Para ligar, peça ao Claude: "quero que verifique meus projetos sozinho".',
  ])
  await ui.unmount()
})

test('sem projetos do GitHub, o painel diz isso', async ($, on) => {
  mock.clock(on, { now: AGORA })
  mock.env(on, { HOME: '/casa' })
  mundo(on, arquivos({ 'status.tsv': '\n' }))
  await abrir($)
  await $.command.run(PAINEL_PEDIDO)

  const ui = await $.ui.mount({ ...PAINEL, surface: 'terminal' })
  expect((await ui.findAll({ type: 'Text' })).map(t => t.text)).toEqual([
    'Última verificação há 5 minutos. Ela roda a cada 30 minutos.',
    'Nenhum projeto do GitHub encontrado.',
  ])
  await ui.unmount()
})

const FORA_DA_VERIFICACAO =
  'git-commands: aviso: projeto fora da verificação por conter configuração que roda programas: C:/git/mau — para incluir, rode git-commands folders add C:/git/mau\n2026-10-26 06:19:09 verificação ok\n'

test('o painel avisa os projetos deixados de fora por segurança, sem virar erro', async ($, on) => {
  mock.clock(on, { now: AGORA })
  mock.env(on, { HOME: '/casa' })
  const m = mundo(on, arquivos({ 'check.log': FORA_DA_VERIFICACAO }))
  await abrir($)

  // Segue verde: a linha de status não vira erro.
  expect(m.status.at(-1)).toBe('git-commands: 1 com novidades')

  await $.command.run(PAINEL_PEDIDO)
  const ui = await $.ui.mount({ ...PAINEL, surface: 'desktop' })
  const linha = await ui.find({ type: 'Text', text: /fora da verificação/ })
  expect(linha?.text).toBe('1 projeto fora da verificação por segurança — veja o check.log ou use git-commands folders add')
  expect(linha?.props).toEqual({ color: 'warning' })
  await ui.unmount()
})

test('sem exclusões, o painel não mostra a linha de fora da verificação', async ($, on) => {
  mock.clock(on, { now: AGORA })
  mock.env(on, { HOME: '/casa' })
  mundo(on, arquivos())
  await abrir($)
  await $.command.run(PAINEL_PEDIDO)

  const ui = await $.ui.mount({ ...PAINEL, surface: 'desktop' })
  expect(await ui.find({ type: 'Text', text: /fora da verificação/ })).toBeUndefined()
  await ui.unmount()
})

test('quando não dá para abrir, o comando diz isso', async ($, on) => {
  mock.clock(on, { now: AGORA })
  mock.env(on, { HOME: '/casa' })
  const m = mundo(on, arquivos())
  m.abre = false
  await abrir($)

  expect(await $.command.run(PAINEL_PEDIDO)).toEqual({ text: 'Não deu para abrir o painel aqui.' })
})

test('a faixa continua enquanto espera a verificação e some quando ela para', async ($, on) => {
  const relogio = mock.clock(on, { now: AGORA })
  mock.env(on, { HOME: '/casa' })
  const m = mundo(on, arquivos({ 'status.tsv': DUAS_NOVIDADES, 'status.time': segundos(AGORA - 4 * HORA) }))
  await abrir($)

  expect(m.status.at(-1)).toBe('git-commands: 2 com novidades')
  const ui = await $.ui.mount({ ...FAIXA, surface: 'desktop' })
  expect((await ui.find({ type: 'Text', text: /Novidades/ }))?.text).toBe('Novidades no GitHub: site (3), api (1)')

  await relogio.advance(35 * MINUTO)
  expect(m.status.at(-1)).toBe('git-commands: verificação parada')
  expect(await ui.find({ type: 'Text', text: /Novidades/ })).toBeUndefined()
  await ui.unmount()
})

test('a faixa não volta quando um projeto sai da lista', async ($, on) => {
  const relogio = mock.clock(on, { now: AGORA })
  mock.env(on, { HOME: '/casa' })
  const m = mundo(on, arquivos({ 'status.tsv': DUAS_NOVIDADES }))
  await abrir($)

  const ui = await $.ui.mount({ ...FAIXA, surface: 'desktop' })
  await ui.press({ key: 'ver' })

  // A pessoa atualiza o api e deixa o site para depois: o updates pull refaz a linha do api.
  m.arquivos['status.tsv'] = DUAS_NOVIDADES.replace('\t0\t1\t0\tnovidades', '\t0\t0\t0\tem-dia')
  await $.turn.complete(fimDaResposta())
  expect(await ui.find({ type: 'Text', text: /Novidades/ })).toBeUndefined()

  // Mais tarde, o api ganha um commit novo: isso ninguém tinha visto ainda.
  m.arquivos['status.tsv'] = DUAS_NOVIDADES
  await relogio.advance(MINUTO)
  expect((await ui.find({ type: 'Text', text: /Novidades/ }))?.text).toBe('Novidades no GitHub: site (3), api (1)')
  await ui.unmount()
})

test('logo depois de ligar a verificação, o painel espera a primeira', async ($, on) => {
  mock.clock(on, { now: AGORA })
  mock.env(on, { HOME: '/casa' })
  const m = mundo(on, { config: 'auto_check=on\ninterval=30\n', 'status.time': segundos(AGORA - 30_000) })
  await abrir($)
  await $.command.run(PAINEL_PEDIDO)

  expect(m.status.at(-1)).toBe('git-commands: esperando a verificação')
  const ui = await $.ui.mount({ ...PAINEL, surface: 'desktop' })
  expect((await ui.findAll({ type: 'Text' })).map(t => t.text)).toEqual(['Esperando a primeira verificação.'])
  await ui.unmount()
})

test('se o /painel for recusado, a linha de status continua', async ($, on) => {
  const relogio = mock.clock(on, { now: AGORA })
  mock.env(on, { HOME: '/casa' })
  const m = mundo(on, arquivos())
  m.registra = false
  await abrir($)

  expect(m.status.at(-1)).toBe('git-commands: 1 com novidades')
  m.arquivos['status.tsv'] = EM_DIA
  await relogio.advance(MINUTO)
  expect(m.status.at(-1)).toBe('git-commands: em dia')
})
