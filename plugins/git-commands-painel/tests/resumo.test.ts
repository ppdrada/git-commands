import { expect, test } from 'claude-code/testing'

import {
  assinatura,
  atrasada,
  lerConfig,
  lerErro,
  lerHora,
  lerProjetos,
  ordenarParaOPainel,
  resumir,
  temNovidadeNova,
} from '../hooks/resumo'
import type { Projeto } from '../types'

const MINUTO = 60_000
const AGORA = 1_793_006_349_000 + 5 * MINUTO

function projeto(nome: string, estado: string, novos = 0, seus = 0): Projeto {
  return { caminho: `C:/git/${nome}`, nome, branch: 'main', estado, novos, seus }
}

function arquivos(mudancas: { config?: string; tsv?: string; time?: string; log?: string } = {}) {
  return {
    config: 'auto_check=on\ninterval=30\n',
    tsv: 'C:/git/site\tsite\tmain\t0\t3\t0\tnovidades\nC:/git/api\tapi\tmain\t0\t0\t0\tem-dia\n',
    time: `${(AGORA - 5 * MINUTO) / 1000}\n`,
    log: '2026-10-26 06:19:09 verificação ok\n',
    ...mudancas,
  }
}

test('lerConfig entende auto_check e interval, com 30 de padrão', () => {
  expect(lerConfig('auto_check=on\ninterval=45\n')).toEqual({ ligada: true, intervalo: 45 })
  expect(lerConfig('auto_check=off\n')).toEqual({ ligada: false, intervalo: 30 })
  expect(lerConfig('auto_check=on\ninterval=abc').intervalo).toBe(30)
  expect(lerConfig('interval=0').intervalo).toBe(30)
  expect(lerConfig(undefined)).toEqual({ ligada: false, intervalo: 30 })
})

test('lerProjetos lê o status.tsv e pula linhas quebradas', () => {
  expect(lerProjetos('C:/git/site\tsite\tmain\t1\t3\t2\tdivergiu\r\nquebrada\tsó\n')).toEqual([
    { caminho: 'C:/git/site', nome: 'site', branch: 'main', estado: 'divergiu', novos: 3, seus: 1 },
  ])
  expect(lerProjetos('C:/git/x\tx\tmain\tx\t?\t0\tem-dia\n')[0]).toMatchObject({ novos: 0, seus: 0 })
  expect(lerProjetos('')).toEqual([])
  expect(lerProjetos(undefined)).toEqual([])
})

test('lerHora lê o status.time em milissegundos', () => {
  expect(lerHora('1793006349\n')).toBe(1_793_006_349_000)
  expect(lerHora('x')).toBeNull()
  expect(lerHora(undefined)).toBeNull()
})

test('lerErro devolve o motivo da última verificação com erro', () => {
  expect(lerErro('2026-10-26 05:49:07 erro 1\n2026-10-26 06:19:09 verificação ok\n')).toBeNull()
  expect(
    lerErro('git-commands: a pasta de projetos não existe: /x\n2026-10-26 06:49:07 erro 1\n'),
  ).toBe('a pasta de projetos não existe: /x')
  expect(lerErro('2026-10-26 06:19:09 verificação ok\n2026-10-26 06:49:07 erro 3\n')).toBe('código 3')
  expect(lerErro(undefined)).toBeNull()
})

test('resumir: desligada, erro, esperando, parada e ok', () => {
  expect(resumir(arquivos({ config: 'auto_check=off\n' }), AGORA, null).situacao).toBe('desligada')

  const comErro = resumir(arquivos({ log: 'git-commands: sem permissão\n2026-10-26 06:49:07 erro 1\n' }), AGORA, null)
  expect(comErro.situacao).toBe('erro')
  expect(comErro.motivo).toBe('sem permissão')

  // O agendador do macOS e o do Linux não rodam o que perderam dormindo: a folga é 1 intervalo + 5 min.
  expect(resumir(arquivos(), AGORA, AGORA - 34 * MINUTO).situacao).toBe('esperando')
  expect(resumir(arquivos(), AGORA, AGORA - 35 * MINUTO).situacao).toBe('parada')
  const deHoraEmHora = arquivos({ config: 'auto_check=on\ninterval=60\n' })
  expect(resumir(deHoraEmHora, AGORA, AGORA - 64 * MINUTO).situacao).toBe('esperando')
  expect(resumir(deHoraEmHora, AGORA, AGORA - 65 * MINUTO).situacao).toBe('parada')
  expect(resumir(arquivos({ tsv: undefined }), AGORA, null).situacao).toBe('esperando')

  const ok = resumir(arquivos(), AGORA, null)
  expect(ok).toEqual({
    situacao: 'ok',
    projetos: [
      { caminho: 'C:/git/site', nome: 'site', branch: 'main', estado: 'novidades', novos: 3, seus: 0 },
      { caminho: 'C:/git/api', nome: 'api', branch: 'main', estado: 'em-dia', novos: 0, seus: 0 },
    ],
    verificadoEm: AGORA - 5 * MINUTO,
    motivo: null,
    intervalo: 30,
    visto: AGORA,
  })
})

test('sem a pasta do git-commands, a verificação está desligada', () => {
  const r = resumir({}, AGORA, null)
  expect(r.situacao).toBe('desligada')
  expect(r.projetos).toEqual([])
  expect(r.verificadoEm).toBeNull()
})

test('atrasada depois de 3 intervalos', () => {
  const desde = (min: number) => arquivos({ time: `${(AGORA - min * MINUTO) / 1000}\n` })
  expect(atrasada(desde(90), AGORA)).toBe(false)
  expect(atrasada(desde(91), AGORA)).toBe(true)
  expect(atrasada(arquivos({ time: undefined }), AGORA)).toBe(true)
  expect(atrasada(arquivos({ config: 'auto_check=on\ninterval=60\n', time: `${(AGORA - 150 * MINUTO) / 1000}` }), AGORA)).toBe(false)
})

test('temNovidadeNova só quando algum projeto ganhou commits', () => {
  const antes = { 'C:/git/site': 3 }
  expect(temNovidadeNova(antes, [projeto('site', 'novidades', 3)])).toBe(false)
  expect(temNovidadeNova(antes, [projeto('site', 'novidades', 4)])).toBe(true)
  expect(temNovidadeNova(antes, [projeto('site', 'novidades', 3), projeto('api', 'divergiu', 1, 1)])).toBe(true)
  expect(temNovidadeNova(antes, [])).toBe(false)
})

test('assinatura e ordenarParaOPainel', () => {
  expect(
    assinatura([projeto('site', 'novidades', 3), projeto('blog', 'em-dia'), projeto('api', 'divergiu', 1, 2), projeto('velho', 'novidades', 0)]),
  ).toBe('C:/git/site:3|C:/git/api:1')
  expect(assinatura([projeto('blog', 'em-dia')])).toBe('')

  const ordem = ordenarParaOPainel([projeto('a', 'em-dia'), projeto('b', 'erro'), projeto('c', 'novidades', 2)])
  expect(ordem.map(p => p.nome)).toEqual(['c', 'b', 'a'])
})
