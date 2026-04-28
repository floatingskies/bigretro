#!/usr/bin/env bash
# ============================================================================
#  bigretro-uninstall - Atalho para desinstalação do bigretro
# ============================================================================
#
#  Restaura o tema original do sistema, removendo o Fluent Theme.
#
#  Uso:
#    ./bigretro-uninstall              # Desinstala (restaura configs)
#    ./bigretro-uninstall --purge      # Desinstala + remove arquivos de tema
#    ./bigretro-uninstall --help       # Ajuda
#
#  Equivalente a:
#    ./bigretro.sh --uninstall [--purge]
# ============================================================================

# Encontrar o diretório do bigretro.sh (mesmo diretório deste script)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIGRETRO="$SCRIPT_DIR/bigretro.sh"

if [[ ! -f "$BIGRETRO" ]]; then
    echo "Erro: bigretro.sh não encontrado em $SCRIPT_DIR"
    echo "Certifique-se de que bigretro-uninstall está no mesmo diretório que bigretro.sh"
    exit 1
fi

# Executar bigretro.sh com --uninstall e repassar argumentos
exec bash "$BIGRETRO" --uninstall "$@"
