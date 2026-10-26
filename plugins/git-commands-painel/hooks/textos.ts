// Todos os textos e cores que o painel mostra, em português simples.
import type { Projeto, Resumo } from '../types'
import { comNovidades } from './resumo'

/** O que o "Ver agora" manda: é a frase que aciona a skill atualizar do git-commands. */
export const PERGUNTA = 'tem algo novo nos meus projetos?'

const PEDIR_CONFERIR = 'Peça ao Claude para conferir a verificação automática.'

function plural(n: number, um: string, varios: string): string {
  return `${n} ${n === 1 ? um : varios}`
}

export function linhaDeStatus(resumo: Resumo): string {
  switch (resumo.situacao) {
    case 'desligada':
      return 'git-commands: verificação desligada'
    case 'erro':
      return 'git-commands: verificação com erro'
    case 'parada':
      return 'git-commands: verificação parada'
  }
  // Esperando a verificação, as novidades da última continuam valendo (o Claude também conta delas).
  const novidades = comNovidades(resumo.projetos).length
  if (novidades > 0) return `git-commands: ${novidades} com novidades`
  if (resumo.situacao === 'esperando') return 'git-commands: esperando a verificação'
  // Sem internet, todos ficam com erro: não dá para dizer que estão em dia.
  const erros = resumo.projetos.filter(p => p.estado === 'erro').length
  if (erros > 0) return `git-commands: ${erros} com erro`
  return 'git-commands: em dia'
}

export function rotuloDoEstado(projeto: Projeto): string {
  switch (projeto.estado) {
    case 'em-dia':
      return 'em dia'
    case 'novidades':
      return `com novidades (${projeto.novos})`
    case 'divergiu':
      return `divergiu: ${projeto.novos} do GitHub e ${plural(projeto.seus, 'seu', 'seus')}`
    case 'a-frente':
      return `${plural(projeto.seus, 'commit', 'commits')} para enviar`
    case 'sem-upstream':
      return 'sem upstream: a branch ainda não está no GitHub'
    case 'ocupado':
      return 'ocupado: no meio de um merge ou rebase'
    case 'destacado':
      return 'HEAD destacado: fora de uma branch'
    case 'sem-commits':
      return 'ainda sem commits'
    case 'erro':
      return 'erro: não deu para falar com o GitHub'
    default:
      return projeto.estado
  }
}

export function corDoEstado(estado: string): 'warning' | 'error' | 'success' | undefined {
  if (estado === 'novidades' || estado === 'divergiu') return 'warning'
  if (estado === 'erro' || estado === 'ocupado') return 'error'
  if (estado === 'em-dia') return 'success'
  return undefined
}

/** "site (3), api (1)": até 3 nomes, para a faixa e o aviso continuarem curtos. */
export function listaDeNovidades(projetos: readonly Projeto[]): string {
  const lista = comNovidades(projetos)
  const nomes = lista
    .slice(0, 3)
    .map(p => `${p.nome} (${p.novos})`)
    .join(', ')
  return lista.length > 3 ? `${nomes} e mais ${lista.length - 3}` : nomes
}

/** Os mesmos cortes do aviso de verificação parada do git-commands. */
export function haQuanto(ms: number): string {
  const segundos = Math.floor(ms / 1000)
  if (segundos < 60) return 'há menos de 1 minuto'
  if (segundos < 7200) return `há ${plural(Math.floor(segundos / 60), 'minuto', 'minutos')}`
  if (segundos < 172_800) return `há ${Math.floor(segundos / 3600)} horas`
  return `há ${Math.floor(segundos / 86_400)} dias`
}

export function cabecalhoDoPainel(resumo: Resumo): string {
  const ultima = resumo.verificadoEm === null ? null : haQuanto(resumo.visto - resumo.verificadoEm)
  const normal = `o normal é a cada ${resumo.intervalo} minutos`
  switch (resumo.situacao) {
    case 'desligada':
      return 'A verificação automática está desligada. Para ligar, peça ao Claude: "quero que verifique meus projetos sozinho".'
    case 'erro':
      return `A última verificação deu erro${resumo.motivo ? `: ${resumo.motivo}` : ''}. ${PEDIR_CONFERIR}`
    case 'parada':
      return ultima === null
        ? `A verificação automática ainda não rodou (${normal}). ${PEDIR_CONFERIR}`
        : `A verificação não roda ${ultima} (${normal}). ${PEDIR_CONFERIR}`
    case 'esperando':
      return ultima === null ? 'Esperando a primeira verificação.' : `Esperando a próxima verificação. A última foi ${ultima}.`
    case 'ok':
      return `${ultima === null ? '' : `Última verificação ${ultima}. `}Ela roda a cada ${resumo.intervalo} minutos.`
  }
}
