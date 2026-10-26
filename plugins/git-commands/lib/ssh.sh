# ssh: a chave SSH do GitHub (git-commands ssh ...). Nunca lê nem mostra a parte privada da
# chave e nunca recebe a senha dela: só a parte pública (.pub) é lida.

# Caminho da chave privada cujo .pub existe, na ordem id_ed25519, id_ecdsa, id_rsa (código 1 se
# não houver nenhuma).
gc_ssh_key() {
  local n
  for n in id_ed25519 id_ecdsa id_rsa; do
    [ -f "$HOME/.ssh/$n.pub" ] && { printf '%s\n' "$HOME/.ssh/$n"; return 0; }
  done
  return 1
}
