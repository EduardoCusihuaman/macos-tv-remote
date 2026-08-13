#!/bin/zsh
set -euo pipefail

echo "Esto borra el viejo CLI Python y sus certificados."
echo "Hacelo SOLO después de comprobar que la app + widget nativos funcionan."
read "answer?Continuar? [y/N] "
[[ "$answer" == [yY] ]] || exit 0

rm -f "$HOME/.local/bin/tvctl"
rm -rf "$HOME/.local/share/tvctl"

echo "✅ tvctl/Python removidos."
echo "La app nativa conserva su copia del certificado dentro del build."
