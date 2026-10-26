// O contrato do $.state do git-commands-painel: o que ele guarda durante a sessão.

/** Um projeto como a última verificação gravou no status.tsv. */
export type Projeto = {
  caminho: string
  nome: string
  branch: string
  /** em-dia, novidades, divergiu, a-frente, sem-upstream, ocupado, destacado, sem-commits ou erro */
  estado: string
  /** commits do GitHub que ainda não estão no computador */
  novos: number
  /** commits do computador que ainda não foram para o GitHub */
  seus: number
}

/** Como está a verificação automática. */
export type Situacao = 'desligada' | 'erro' | 'esperando' | 'parada' | 'ok'

export type Resumo = {
  situacao: Situacao
  projetos: Projeto[]
  /** quando a última verificação terminou, em milissegundos */
  verificadoEm: number | null
  /** por que a última verificação deu erro */
  motivo: string | null
  /** de quantos em quantos minutos a verificação roda */
  intervalo: number
  /** quando este resumo foi feito, em milissegundos */
  visto: number
}

declare module 'claude-code' {
  interface PluginState {
    'git-commands-painel': {
      resumo: Resumo | null
      /** as novidades ("caminho:commits") que o "Depois" ou o "Ver agora" esconderam */
      escondidas: string[] | null
      /** a última verificação e as novidades de cada projeto que o aviso rápido já viu */
      avisado: { verificadoEm: number | null; novos: Record<string, number> } | null
      /** desde quando a verificação parece atrasada, para aquele status.time */
      parada: { verificadoEm: number | null; desde: number } | null
    }
  }
}
