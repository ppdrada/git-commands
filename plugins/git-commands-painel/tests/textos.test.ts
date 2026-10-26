import { expect, test } from 'claude-code/testing'

import {
  cabecalhoDoPainel,
  corDoEstado,
  haQuanto,
  linhaDeStatus,
  listaDeNovidades,
  PERGUNTA,
  rotuloDoEstado,
} from '../hooks/textos'
import type { Projeto, Resumo } from '../types'

const MINUTO = 60_000
const HORA = 60 * MINUTO
const AGORA = 1_793_006_349_000

function projeto(nome: string, estado: string, novos = 0, seus = 0): Projeto {
  return { caminho: `C:/git/${nome}`, nome, branch: 'main', estado, novos, seus }
}

function resumo(mudancas: Partial<Resumo> = {}): Resumo {
  return {
    situacao: 'ok',
    projetos: [],
    verificadoEm: AGORA - 5 * MINUTO,
    motivo: null,
    intervalo: 30,
    visto: AGORA,
    ...mudancas,
  }
}

test('linha de status para cada situação', () => {
  expect(linhaDeStatus(resumo({ situacao: 'desligada' }))).toBe('git-commands: verificação desligada')
  expect(linhaDeStatus(resumo({ situacao: 'erro' }))).toBe('git-commands: verificação com erro')
  expect(linhaDeStatus(resumo({ situacao: 'esperando' }))).toBe('git-commands: esperando a verificação')
  expect(linhaDeStatus(resumo({ situacao: 'parada' }))).toBe('git-commands: verificação parada')
  expect(
    linhaDeStatus(resumo({ projetos: [projeto('site', 'novidades', 3), projeto('api', 'divergiu', 1, 1)] })),
  ).toBe('git-commands: 2 com novidades')
  expect(linhaDeStatus(resumo({ projetos: [projeto('site', 'novidades', 3), projeto('api', 'em-dia')] }))).toBe(
    'git-commands: 1 com novidades',
  )
  expect(linhaDeStatus(resumo({ projetos: [projeto('api', 'em-dia'), projeto('blog', 'a-frente', 0, 2)] }))).toBe(
    'git-commands: em dia',
  )
})

test('projetos com erro não aparecem como em dia', () => {
  expect(linhaDeStatus(resumo({ projetos: [projeto('site', 'erro'), projeto('api', 'erro')] }))).toBe(
    'git-commands: 2 com erro',
  )
  expect(linhaDeStatus(resumo({ projetos: [projeto('site', 'novidades', 3), projeto('api', 'erro')] }))).toBe(
    'git-commands: 1 com novidades',
  )
})

test('rótulo de cada estado do status.tsv', () => {
  expect(rotuloDoEstado(projeto('a', 'em-dia'))).toBe('em dia')
  expect(rotuloDoEstado(projeto('a', 'novidades', 3))).toBe('com novidades (3)')
  expect(rotuloDoEstado(projeto('a', 'divergiu', 3, 1))).toBe('divergiu: 3 do GitHub e 1 seu')
  expect(rotuloDoEstado(projeto('a', 'divergiu', 3, 2))).toBe('divergiu: 3 do GitHub e 2 seus')
  expect(rotuloDoEstado(projeto('a', 'a-frente', 0, 1))).toBe('1 commit para enviar')
  expect(rotuloDoEstado(projeto('a', 'a-frente', 0, 4))).toBe('4 commits para enviar')
  expect(rotuloDoEstado(projeto('a', 'sem-upstream'))).toBe('sem upstream: a branch ainda não está no GitHub')
  expect(rotuloDoEstado(projeto('a', 'ocupado'))).toBe('ocupado: no meio de um merge ou rebase')
  expect(rotuloDoEstado(projeto('a', 'destacado'))).toBe('HEAD destacado: fora de uma branch')
  expect(rotuloDoEstado(projeto('a', 'sem-commits'))).toBe('ainda sem commits')
  expect(rotuloDoEstado(projeto('a', 'erro'))).toBe('erro: não deu para falar com o GitHub')
  expect(rotuloDoEstado(projeto('a', 'outra-coisa'))).toBe('outra-coisa')
})

test('cor de cada estado', () => {
  expect(corDoEstado('novidades')).toBe('warning')
  expect(corDoEstado('divergiu')).toBe('warning')
  expect(corDoEstado('erro')).toBe('error')
  expect(corDoEstado('ocupado')).toBe('error')
  expect(corDoEstado('em-dia')).toBe('success')
  expect(corDoEstado('a-frente')).toBeUndefined()
})

test('a lista de novidades mostra 3 e conta o resto', () => {
  expect(listaDeNovidades([projeto('site', 'novidades', 3), projeto('blog', 'em-dia'), projeto('api', 'divergiu', 1, 1)])).toBe(
    'site (3), api (1)',
  )
  const oito = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'].map((nome, i) => projeto(nome, 'novidades', i + 1))
  expect(listaDeNovidades(oito)).toBe('a (1), b (2), c (3) e mais 5')
})

test('haQuanto em minutos, horas e dias', () => {
  expect(haQuanto(30_000)).toBe('há menos de 1 minuto')
  expect(haQuanto(MINUTO)).toBe('há 1 minuto')
  expect(haQuanto(119 * MINUTO)).toBe('há 119 minutos')
  expect(haQuanto(120 * MINUTO)).toBe('há 2 horas')
  expect(haQuanto(47 * HORA)).toBe('há 47 horas')
  expect(haQuanto(48 * HORA)).toBe('há 2 dias')
})

test('cabeçalho do painel para cada situação', () => {
  const pedir = 'Peça ao Claude para conferir a verificação automática.'
  expect(cabecalhoDoPainel(resumo())).toBe('Última verificação há 5 minutos. Ela roda a cada 30 minutos.')
  expect(cabecalhoDoPainel(resumo({ situacao: 'desligada' }))).toBe(
    'A verificação automática está desligada. Para ligar, peça ao Claude: "quero que verifique meus projetos sozinho".',
  )
  expect(cabecalhoDoPainel(resumo({ situacao: 'erro', motivo: 'sem permissão' }))).toBe(
    `A última verificação deu erro: sem permissão. ${pedir}`,
  )
  expect(cabecalhoDoPainel(resumo({ situacao: 'parada', verificadoEm: AGORA - 3 * HORA }))).toBe(
    `A verificação não roda há 3 horas (o normal é a cada 30 minutos). ${pedir}`,
  )
  expect(cabecalhoDoPainel(resumo({ situacao: 'parada', verificadoEm: null }))).toBe(
    `A verificação automática ainda não rodou (o normal é a cada 30 minutos). ${pedir}`,
  )
  expect(cabecalhoDoPainel(resumo({ situacao: 'esperando', verificadoEm: null }))).toBe('Esperando a primeira verificação.')
  expect(cabecalhoDoPainel(resumo({ situacao: 'esperando', verificadoEm: AGORA - 4 * HORA }))).toBe(
    'Esperando a próxima verificação. A última foi há 4 horas.',
  )
})

test('a pergunta do Ver agora aciona a skill atualizar', () => {
  expect(PERGUNTA).toBe('tem algo novo nos meus projetos?')
})
