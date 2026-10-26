// Lê os arquivos que a verificação automática do git-commands grava e monta o resumo.
// Só funções puras: quem lê do disco é o register.tsx.
import type { Projeto, Resumo, Situacao } from '../types'

/** Quanto tempo a verificação pode ficar atrasada antes de virar "parada" (o computador pode ter acabado de acordar). */
export const GRACA_MS = 300_000
export const INTERVALO_PADRAO = 30

const MINUTO = 60_000
const COM_NOVIDADES = new Set(['novidades', 'divergiu'])

/** O texto de cada arquivo da pasta do git-commands; undefined quando ele não existe. */
export type Arquivos = { config?: string; tsv?: string; time?: string; log?: string }

function linhas(texto: string | undefined): string[] {
  return (texto ?? '').split('\n').map(linha => linha.replace(/\r$/, ''))
}

function inteiro(texto: string | undefined): number {
  const n = Number(texto)
  return Number.isInteger(n) ? n : 0
}

/** Como o bash: vale a última linha de cada opção. */
export function lerConfig(texto?: string): { ligada: boolean; intervalo: number } {
  let ligada = false
  let intervalo: string | undefined
  for (const linha of linhas(texto)) {
    if (linha.startsWith('auto_check=')) ligada = linha === 'auto_check=on'
    if (linha.startsWith('interval=')) intervalo = linha.slice('interval='.length)
  }
  const minutos = /^\d+$/.test(intervalo ?? '') ? Number(intervalo) : 0
  return { ligada, intervalo: minutos >= 1 ? minutos : INTERVALO_PADRAO }
}

/** Uma linha por projeto: caminho, nome, branch, à frente, atrás, alterados e estado, separados por tab. */
export function lerProjetos(texto?: string): Projeto[] {
  const projetos: Projeto[] = []
  for (const linha of linhas(texto)) {
    const c = linha.split('\t')
    if (c.length < 7) continue
    projetos.push({
      caminho: c[0] ?? '',
      nome: c[1] ?? '',
      branch: c[2] ?? '',
      estado: c[6] ?? '',
      novos: inteiro(c[4]),
      seus: inteiro(c[3]),
    })
  }
  return projetos
}

/** O status.time guarda segundos; o resumo usa milissegundos. */
export function lerHora(texto?: string): number | null {
  const segundos = (texto ?? '').trim()
  return /^\d+$/.test(segundos) ? Number(segundos) * 1000 : null
}

/** Quando a última verificação deu erro ("erro <N>"), o motivo que ela deixou na linha de antes. */
export function lerErro(texto?: string): string | null {
  const cheias = linhas(texto).filter(linha => linha.trim() !== '')
  const codigo = cheias.at(-1)?.match(/ erro (\d+)$/)
  if (!codigo) return null
  const antes = cheias.at(-2)
  return antes?.startsWith('git-commands: ') ? antes.slice('git-commands: '.length) : `código ${codigo[1]}`
}

/** Sem status.time, ou com ele mais velho que 3 intervalos. */
export function atrasada(arquivos: Arquivos, agora: number): boolean {
  const verificadoEm = lerHora(arquivos.time)
  return verificadoEm === null || agora - verificadoEm > 3 * lerConfig(arquivos.config).intervalo * MINUTO
}

/** `paradaDesde`: desde quando a verificação está atrasada, ou null quando não está. */
export function resumir(arquivos: Arquivos, agora: number, paradaDesde: number | null): Resumo {
  const { ligada, intervalo } = lerConfig(arquivos.config)
  const motivo = lerErro(arquivos.log)
  let situacao: Situacao = 'ok'
  if (!ligada) situacao = 'desligada'
  else if (motivo !== null) situacao = 'erro'
  else if (paradaDesde !== null) situacao = agora - paradaDesde >= GRACA_MS ? 'parada' : 'esperando'
  else if (arquivos.tsv === undefined) situacao = 'esperando'
  return {
    situacao,
    projetos: lerProjetos(arquivos.tsv),
    verificadoEm: lerHora(arquivos.time),
    motivo,
    intervalo,
    visto: agora,
  }
}

export function comNovidades(projetos: readonly Projeto[]): Projeto[] {
  return projetos.filter(p => COM_NOVIDADES.has(p.estado) && p.novos > 0)
}

/** Identifica a lista de novidades: muda quando entra um projeto ou chegam mais commits. */
export function assinatura(projetos: readonly Projeto[]): string {
  return comNovidades(projetos)
    .map(p => `${p.caminho}:${p.novos}`)
    .join('|')
}

export function temNovidadeNova(antes: Readonly<Record<string, number>>, projetos: readonly Projeto[]): boolean {
  return comNovidades(projetos).some(p => p.novos > (antes[p.caminho] ?? 0))
}

/** Primeiro os que têm novidades, depois os outros estados, por último os em dia. */
export function ordenarParaOPainel(projetos: readonly Projeto[]): Projeto[] {
  const grupo = (p: Projeto) => (COM_NOVIDADES.has(p.estado) ? 0 : p.estado === 'em-dia' ? 2 : 1)
  return [...projetos].sort((a, b) => grupo(a) - grupo(b))
}
