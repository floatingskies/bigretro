#!/usr/bin/env bash
# ============================================================================
#  bigretro - BigLinux Fluent Theme Restorer
#  Versão: 1.0.0
# ============================================================================
#
#  Restaura a experiência clássica do tema Fluent do BigLinux no KDE Plasma 6+
#
#  Funcionalidades:
#    - Instala Fluent-kde, Fluent-gtk-theme e Fluent-icon-theme (vinceliuice)
#    - Aplica patch de ícones big* do BigLinux (bigicons-papient)
#    - Configura automaticamente: tema KDE, GTK (libadwaita), ícones, Kvantum
#    - Backup completo das configurações anteriores
#    - Desinstalação total com restauração do estado original
#    - Modo interativo ou flags CLI para automação
#
#  Uso:
#    ./bigretro                        # Modo interativo (menu guiado)
#    ./bigretro --full --dark          # Aplica tudo em modo escuro
#    ./bigretro --full --light         # Aplica tudo em modo claro
#    ./bigretro --uninstall            # Desinstala e restaura
#    ./bigretro --status               # Mostra estado atual
#    ./bigretro --help                 # Ajuda completa
#
#  Autor:  BigLinux Community
#  Licença: GPL-3.0
# ============================================================================

set -euo pipefail

# ============================================================================
#  CONSTANTES E VERSÃO
# ============================================================================

readonly VERSION="1.3.0"
readonly SCRIPT_NAME="$(basename "$0")"
readonly BACKUP_BASE="${XDG_DATA_HOME:-$HOME/.local/share}/bigretro-backup"
readonly TEMP_BASE="/tmp/bigretro-$(id -u)"
readonly BIGICONS_SOURCE="/usr/share/icons/bigicons-papient"
readonly WALLPAPER_SOURCE="/usr/share/wallpapers/big-retro"
# Wallpapers também podem ser um arquivo diretamente em /usr/share/wallpapers/
readonly WALLPAPER_SEARCH_DIR="/usr/share/wallpapers"
readonly WALLPAPER_EXTENSIONS=(".jpg" ".jpeg" ".png" ".heic")

# Repositórios oficiais do vinceliuice no GitHub
readonly REPO_KDE="vinceliuice/Fluent-kde"
readonly REPO_GTK="vinceliuice/Fluent-gtk-theme"
readonly REPO_ICONS="vinceliuice/Fluent-icon-theme"

# URL do Fluent Icons na loja de temas do KDE
readonly KDE_STORE_URL="https://store.kde.org/p/1651982/"

# ============================================================================
#  VARIÁVEIS GLOBAIS DE ESTADO
# ============================================================================

THEME_MODE=""            # "dark" ou "light"
APPLY_KDE=false
APPLY_GTK=false
APPLY_ICONS=false
APPLY_KVANTUM=false
APPLY_AURORAE=false
APPLY_WALLPAPER=false
APPLY_PATCH=true         # Aplicar patch bigicons por padrão
SKIP_CONFIRM=false       # Modo não-interativo (-y/--yes)
UNINSTALL_MODE=false
STATUS_MODE=false
FULL_MODE=false
PURGE_MODE=false         # Remover arquivos de tema na desinstalação

# Temas detectados após instalação (preenchidos por detect_installed_themes)
DETECTED_COLOR_SCHEME=""
DETECTED_ICON_THEME=""
DETECTED_KVANTUM_THEME=""
DETECTED_GTK_THEME=""
DETECTED_AURORAE_THEME=""
DETECTED_WALLPAPER_FILE=""

# Diretório temporário de trabalho (criado sob demanda)
WORK_DIR=""

# ============================================================================
#  CORES E FORMATAÇÃO
# ============================================================================

if [[ -t 1 ]] && command -v tput &>/dev/null && [[ $(tput colors 2>/dev/null || echo 0) -ge 8 ]]; then
    readonly C_RESET="$(tput sgr0)"
    readonly C_BOLD="$(tput bold)"
    readonly C_WHITE="$(tput setaf 7)"
    readonly C_RED="$(tput setaf 1)"
    readonly C_GREEN="$(tput setaf 2)"
    readonly C_YELLOW="$(tput setaf 3)"
    readonly C_BLUE="$(tput setaf 4)"
    readonly C_CYAN="$(tput setaf 6)"
    readonly C_DIM="$(tput dim)"
else
    readonly C_RESET="" C_BOLD="" C_RED="" C_GREEN="" C_YELLOW=""
    readonly C_BLUE="" C_CYAN="" C_DIM="" C_WHITE=""
fi

# Emojis (seguros para terminais com suporte Unicode, fallback para ASCII)
if [[ "$(locale charmap 2>/dev/null)" == "UTF-8" ]]; then
    readonly E_OK="${C_GREEN}[OK]${C_RESET}"
    readonly E_FAIL="${C_RED}[FALHOU]${C_RESET}"
    readonly E_WARN="${C_YELLOW}[AVISO]${C_RESET}"
    readonly E_INFO="${C_BLUE}[INFO]${C_RESET}"
    readonly E_STEP="${C_CYAN}[...]${C_RESET}"
    readonly E_ARROW="${C_BOLD}==>${C_RESET}"
    readonly E_MOON="🌙"
    readonly E_SUN="☀️"
    readonly E_CHECK="✓"
    readonly E_CROSS="✗"
else
    readonly E_OK="${C_GREEN}[OK]${C_RESET}"
    readonly E_FAIL="${C_RED}[FAIL]${C_RESET}"
    readonly E_WARN="${C_YELLOW}[WARN]${C_RESET}"
    readonly E_INFO="${C_BLUE}[INFO]${C_RESET}"
    readonly E_STEP="${C_CYAN}[...]${C_RESET}"
    readonly E_ARROW="${C_BOLD}==>${C_RESET}"
    readonly E_MOON="(Dark)"
    readonly E_SUN="(Light)"
    readonly E_CHECK="+"
    readonly E_CROSS="x"
fi

# ============================================================================
#  FUNÇÕES AUXILIARES
# ============================================================================

# --- Logging ---

log_info()    { printf '%b %s\n' "$E_INFO"  "$*" 2>&1; }
log_success() { printf '%b %s\n' "$E_OK"    "$*" 2>&1; }
log_warn()    { printf '%b %s\n' "$E_WARN"  "$*" 2>&1; }
log_error()   { printf '%b %s\n' "$E_FAIL"  "$*" 2>&1; }
log_step()    { printf '%b %s\n' "$E_STEP"  "$*" 2>&1; }
log_arrow()   { printf '%b %s\n' "$E_ARROW" "$*" 2>&1; }

# Exibe mensagem e espera Enter
log_pause() {
    printf '%b %s' "$E_ARROW" "Pressione Enter para continuar..."
    read -r
}

# --- Confirmação ---

# Pergunta sim/não. Retorna 0 (sim) ou 1 (não).
# $1 = mensagem (opcional, padrão: "Continuar?")
confirm() {
    local msg="${1:-Continuar?}"
    if [[ "$SKIP_CONFIRM" == true ]]; then
        return 0
    fi
    printf '%b %s [s/N] ' "$E_ARROW" "$msg"
    local answer
    read -r answer
    [[ "$answer" =~ ^[sSyY]$ ]]
}

# Pergunta e exige resposta. Retorna a resposta em $REPLY.
prompt() {
    local msg="$1"
    local default="${2:-}"
    if [[ -n "$default" ]]; then
        printf '%b %s [%s] ' "$E_ARROW" "$msg" "$default"
    else
        printf '%b %s ' "$E_ARROW" "$msg"
    fi
    read -r REPLY
    REPLY="${REPLY:-$default}"
}

# --- Utilitários ---

# Garante que WORK_DIR existe
ensure_work_dir() {
    if [[ -z "$WORK_DIR" || ! -d "$WORK_DIR" ]]; then
        WORK_DIR="$(mktemp -d "${TEMP_BASE}.XXXXXX")"
        trap 'rm -rf "$WORK_DIR" 2>/dev/null' EXIT
    fi
}

# Executa comando silenciosamente, logando resultado
run_quiet() {
    local desc="$1"; shift
    log_step "$desc..."
    if "$@" &>/dev/null; then
        log_success "$desc"
        return 0
    else
        log_error "Falha em: $desc"
        return 1
    fi
}

# Executa comando mostrando saída em caso de erro
run_catch() {
    local desc="$1"; shift
    log_step "$desc..."
    if "$@" &>> "$WORK_DIR/install.log"; then
        log_success "$desc"
        return 0
    else
        log_error "Falha em: $desc (veja $WORK_DIR/install.log)"
        return 1
    fi
}

# Verifica se comando existe
has_cmd() { command -v "$1" &>/dev/null; }

# Verifica se estamos rodando em KDE Plasma
is_plasma() {
    [[ "${XDG_CURRENT_DESKTOP:-}" == *"KDE"* ]] || has_cmd plasmashell
}

# Obtém versão do Plasma (major.minor)
get_plasma_version() {
    if has_cmd plasmashell; then
        plasmashell --version 2>/dev/null | grep -oP '\d+\.\d+' | head -1 || echo "desconhecida"
    elif has_cmd kf6-config; then
        kf6-config --version 2>/dev/null | grep -oP '\d+\.\d+' | head -1 || echo "desconhecida"
    else
        echo "não detectada"
    fi
}

# ============================================================================
#  BANNER E AJUDA
# ============================================================================

show_banner() {
    printf '\n'
    printf '%b%b╔══════════════════════════════════════════════════════════════╗%b\n' "$C_BOLD" "$C_CYAN" "$C_RESET"
    printf '%b%b║                                                              ║%b\n' "$C_BOLD" "$C_CYAN" "$C_RESET"
    printf '%b%b║            %b  bigretro %b- BigLinux Fluent Theme Restorer  %b║%b\n' "$C_BOLD" "$C_CYAN" "$C_WHITE" "$C_CYAN" "$C_RESET" "$C_RESET"
    printf '%b%b║                      %bversão %-6s                        %b║%b\n' "$C_BOLD" "$C_CYAN" "$C_DIM" "$VERSION" "$C_RESET" "$C_RESET"
    printf '%b%b║                      %bKDE Plasma 6+%b                      %b║%b\n' "$C_BOLD" "$C_CYAN" "$C_DIM" "$C_RESET" "$C_RESET" "$C_RESET"
    printf '%b%b║                                                              ║%b\n' "$C_BOLD" "$C_CYAN" "$C_RESET"
    printf '%b%b╚══════════════════════════════════════════════════════════════╝%b\n' "$C_BOLD" "$C_CYAN" "$C_RESET"
    printf '\n'
}

show_help() {
    show_banner
    cat <<EOF
${C_BOLD}RESTAURA O TEMA FLUENT CLÁSSICO DO BIGLINUX${C_RESET}

Este script instala e configura automaticamente o Fluent Theme completo
no KDE Plasma 6+, incluindo:

  ${C_BOLD}•${C_RESET} Tema KDE Plasma ${C_DIM}(Fluent-kde)${C_RESET}
  ${C_BOLD}•${C_RESET} Tema GTK + libadwaita ${C_DIM}(Fluent-gtk-theme)${C_RESET}
  ${C_BOLD}•${C_RESET} Ícones Fluent ${C_DIM}(Fluent-icon-theme, KDE Store)${C_RESET}
  ${C_BOLD}•${C_RESET} Patch de ícones BigLinux ${C_DIM}(bigicons-papient big*)${C_RESET}
  ${C_BOLD}•${C_RESET} Estilo de widget Kvantum ${C_DIM}(Fluent / FluentDark)${C_RESET}
  ${C_BOLD}•${C_RESET} Backup completo + desinstalação com restauração

${C_BOLD}MODO DE USO:${C_RESET}
  ${C_DIM}./bigretro${C_RESET}                          ${C_DIM}# Modo interativo${C_RESET}
  ${C_DIM}./bigretro --full --dark${C_RESET}           ${C_DIM}# Tudo, modo escuro${C_RESET}
  ${C_DIM}./bigretro --full --light${C_RESET}          ${C_DIM}# Tudo, modo claro${C_RESET}
  ${C_DIM}./bigretro --uninstall${C_RESET}             ${C_DIM}# Restaurar original${C_RESET}
  ${C_DIM}./bigretro --status${C_RESET}                ${C_DIM}# Ver estado atual${C_RESET}

${C_BOLD}OPÇÕES:${C_RESET}
  ${C_BOLD}Componentes:${C_RESET}
    --full               Aplica todos os componentes
    --kde                Instala e aplica o tema KDE Plasma
    --gtk                Instala e aplica o tema GTK (libadwaita)
    --icons              Instala ícones Fluent + patch bigicons + lixeira
    --kvantum            Aplica estilo de widget Kvantum
    --aurorae            Aplica tema de decoração de janelas Aurorae
    --wallpaper          Aplica wallpaper big-retro

  ${C_BOLD}Modo de cor:${C_RESET}
    --dark               Utiliza variante escura
    --light              Utiliza variante clara

  ${C_BOLD}Desinstalação:${C_RESET}
    --uninstall          Desinstala o tema e restaura configurações
    --purge              Desinstala e remove todos os arquivos de tema

  ${C_BOLD}Comportamento:${C_RESET}
    --no-patch           Pula o patch de ícones bigicons-papient
    -y, --yes            Pula todas as confirmações (modo automático)
    --status             Mostra o estado atual do tema
    -h, --help           Mostra esta ajuda
    -v, --version        Mostra a versão

${C_BOLD}COMPONENTES DO PATCH:${C_RESET}
  Todos os ícones cujo nome começa com ${C_DIM}big${C_RESET} (${C_DIM}big*${C_RESET}) de ${C_DIM}${BIGICONS_SOURCE}/${C_RESET}
  são copiados para ${C_DIM}~/.local/share/icons/Fluent-*/${C_RESET}
  preservando a estrutura de diretórios, complementando o tema Fluent.

  Isso inclui ${C_DIM}big-*${C_RESET}, ${C_DIM}big_*${C_RESET}, ${C_DIM}biglinux*${C_RESET}, ${C_DIM}bigdesktop*${C_RESET}
  e qualquer outro ícone do tema BigLinux que comece com \"big\".

${C_BOLD}BACKUP:${C_RESET}
  Antes de qualquer alteração, as configurações originais são salvas em:
  ${C_DIM}${BACKUP_BASE}/<timestamp>/${C_RESET}

${C_BOLD}EXEMPLOS:${C_RESET}
  ${C_DIM}./bigretro --full --dark -y${C_RESET}
    Instala tudo em modo escuro sem perguntar.

  ${C_DIM}./bigretro --kde --gtk --dark${C_RESET}
    Instala apenas o tema KDE e GTK em modo escuro.

  ${C_DIM}./bigretro --icons --light${C_RESET}
    Instala apenas os ícones em modo claro.

  ${C_DIM}./bigretro --uninstall --purge${C_RESET}
    Remove completamente o tema e restaura original.

EOF
}

show_version() {
    printf '%s %s\n' "$SCRIPT_NAME" "$VERSION"
}

# ============================================================================
#  VERIFICAÇÃO DE DEPENDÊNCIAS
# ============================================================================

check_dependencies() {
    log_step "Verificando dependências..."
    local missing=()
    local optional=()

    # Dependências obrigatórias
    for cmd in git curl; do
        if ! has_cmd "$cmd"; then
            missing+=("$cmd")
        fi
    done

    # Dependências para KDE (obrigatórias se estamos em Plasma)
    if is_plasma; then
        for cmd in kwriteconfig6 kreadconfig6; do
            if ! has_cmd "$cmd"; then
                missing+=("$cmd")
            fi
        done
    fi

    # Dependências opcionais
    if ! has_cmd kvantummanager; then
        optional+=("kvantum (kvantummanager) - necessário para estilo Kvantum")
    fi
    if ! has_cmd gtk-update-icon-cache; then
        optional+=("gtk-update-icon-cache - recomendado para cache de ícones")
    fi
    if ! has_cmd rsync; then
        optional+=("rsync - recomendado para cópia de ícones eficiente")
    fi

    # Relatar
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Dependências obrigatórias ausentes: ${missing[*]}"
        log_info "Instale com o gerenciador de pacotes da sua distribuição."
        if has_cmd apt; then
            log_info "  sudo apt install ${missing[*]}"
        elif has_cmd dnf; then
            log_info "  sudo dnf install ${missing[*]}"
        elif has_cmd pacman; then
            log_info "  sudo pacman -S ${missing[*]}"
        elif has_cmd zypper; then
            log_info "  sudo zypper install ${missing[*]}"
        fi
        return 1
    fi

    if [[ ${#optional[@]} -gt 0 ]]; then
        log_warn "Dependências opcionais ausentes:"
        for opt in "${optional[@]}"; do
            log_warn "  - $opt"
        done
    fi

    # Verificar ambiente Plasma
    if ! is_plasma; then
        log_warn "KDE Plasma não detectado. O script pode não funcionar corretamente."
        if ! confirm "Deseja continuar mesmo assim?"; then
            exit 0
        fi
    else
        local plasma_ver
        plasma_ver="$(get_plasma_version)"
        log_info "KDE Plasma $plasma_ver detectado."
    fi

    log_success "Dependências verificadas."
    return 0
}

# ============================================================================
#  SISTEMA DE BACKUP
# ============================================================================

create_backup() {
    local ts
    ts="$(date +%Y%m%d_%H%M%S)"
    local backup_dir="$BACKUP_BASE/$ts"

    log_arrow "Criando backup das configurações atuais..."
    mkdir -p "$backup_dir"

    # --- KDE Settings ---
    # Esquema de cores
    local color_scheme
    color_scheme="$(kreadconfig6 --file kdeglobals --group General --key ColorScheme 2>/dev/null | tr -d '[:space:]' || true)"
    echo "${color_scheme:-}" > "$backup_dir/kde_color_scheme"

    # Tema de ícones
    local icon_theme
    icon_theme="$(kreadconfig6 --file kdeglobals --group Icons --key Theme 2>/dev/null | tr -d '[:space:]' || true)"
    echo "${icon_theme:-}" > "$backup_dir/kde_icon_theme"

    # Estilo de widget
    local widget_style
    widget_style="$(kreadconfig6 --file kdeglobals --group General --key widgetStyle 2>/dev/null | tr -d '[:space:]' || true)"
    echo "${widget_style:-}" > "$backup_dir/kde_widget_style"

    # Copiar kdeglobals completo
    if [[ -f "$HOME/.config/kdeglobals" ]]; then
        cp "$HOME/.config/kdeglobals" "$backup_dir/kdeglobals"
    fi

    # --- GTK Settings ---
    # GTK3
    if [[ -f "$HOME/.config/gtk-3.0/settings.ini" ]]; then
        cp "$HOME/.config/gtk-3.0/settings.ini" "$backup_dir/gtk3_settings.ini"
    fi
    # GTK4
    if [[ -f "$HOME/.config/gtk-4.0/settings.ini" ]]; then
        cp "$HOME/.config/gtk-4.0/settings.ini" "$backup_dir/gtk4_settings.ini"
    fi
    # GTK2 (raro, mas possível)
    if [[ -f "$HOME/.config/gtkrc-2.0" ]]; then
        cp "$HOME/.config/gtkrc-2.0" "$backup_dir/gtkrc-2.0"
    fi

    # --- Kvantum Settings ---
    if [[ -f "$HOME/.config/Kvantum/kvantum.kvconfig" ]]; then
        cp "$HOME/.config/Kvantum/kvantum.kvconfig" "$backup_dir/kvantum.kvconfig"
    fi

    # --- Plasma Environment ---
    if [[ -f "$HOME/.config/plasma-workspace/env/gtk-theme.sh" ]]; then
        cp "$HOME/.config/plasma-workspace/env/gtk-theme.sh" "$backup_dir/gtk-theme.sh"
    fi

    # --- Aurorae / Decoração de janelas ---
    local aurorae_lib aurorae_theme
    aurorae_lib="$(kreadconfig6 --file kwinrc --group org.kde.kdecoration2 --key library 2>/dev/null | tr -d '[:space:]' || true)"
    aurorae_theme="$(kreadconfig6 --file kwinrc --group org.kde.kdecoration2 --key theme 2>/dev/null | tr -d '[:space:]' || true)"
    echo "${aurorae_lib:-}" > "$backup_dir/aurorae_library"
    echo "${aurorae_theme:-}" > "$backup_dir/aurorae_theme"
    if [[ -f "$HOME/.config/kwinrc" ]]; then
        cp "$HOME/.config/kwinrc" "$backup_dir/kwinrc"
    fi

    # --- Wallpaper ---
    local current_wallpaper
    current_wallpaper="$(kreadconfig6 --file plasma-org.kde.plasma.desktop-appletsrc --group ContainmentActions --key Image 2>/dev/null | tr -d '[:space:]' || true)"
    if [[ -z "$current_wallpaper" ]]; then
        current_wallpaper="$(kreadconfig6 --file plasmarc --group PlasmaViews --group2 Desktop --group3 Background --key Image 2>/dev/null | tr -d '[:space:]' || true)"
    fi
    echo "${current_wallpaper:-}" > "$backup_dir/wallpaper_image"
    if [[ -f "$HOME/.config/plasmarc" ]]; then
        cp "$HOME/.config/plasmarc" "$backup_dir/plasmarc"
    fi

    # --- Metadados do backup ---
    cat > "$backup_dir/backup_info" <<BACKUP_EOF
bigretro_backup_version=$VERSION
timestamp=$ts
plasma_version=$(get_plasma_version)
color_scheme=$color_scheme
icon_theme=$icon_theme
widget_style=$widget_style
BACKUP_EOF

    log_success "Backup criado em: $backup_dir"
}

restore_backup() {
    local backup_dir=""

    # Encontrar o backup mais recente
    if [[ -d "$BACKUP_BASE" ]]; then
        backup_dir="$(ls -1d "$BACKUP_BASE"/*/ 2>/dev/null | sort -r | head -1)"
    fi

    if [[ -z "$backup_dir" || ! -d "$backup_dir" ]]; then
        log_warn "Nenhum backup encontrado em $BACKUP_BASE"
        log_info "Não é possível restaurar as configurações anteriores."
        confirm "Deseja continuar apenas removendo os temas instalados?" || exit 0
        return 0
    fi

    # Remover barra final
    backup_dir="${backup_dir%/}"

    log_arrow "Restaurando backup de: $backup_dir"

    # --- Restaurar KDE Settings ---
    local color_scheme icon_theme widget_style
    color_scheme="$(cat "$backup_dir/kde_color_scheme" 2>/dev/null | tr -d '[:space:]')"
    icon_theme="$(cat "$backup_dir/kde_icon_theme" 2>/dev/null | tr -d '[:space:]')"
    widget_style="$(cat "$backup_dir/kde_widget_style" 2>/dev/null | tr -d '[:space:]')"

    if [[ -n "$color_scheme" ]]; then
        kwriteconfig6 --file kdeglobals --group General --key ColorScheme "$color_scheme"
        log_info "Esquema de cores restaurado: $color_scheme"
    else
        # Sem esquema anterior, definir Breeze como fallback
        kwriteconfig6 --file kdeglobals --group General --key ColorScheme "BreezeLight"
        log_info "Esquema de cores restaurado para padrão (BreezeLight)"
    fi

    if [[ -n "$icon_theme" ]]; then
        kwriteconfig6 --file kdeglobals --group Icons --key Theme "$icon_theme"
        log_info "Tema de ícones restaurado: $icon_theme"
    fi

    if [[ -n "$widget_style" ]]; then
        kwriteconfig6 --file kdeglobals --group General --key widgetStyle "$widget_style"
        log_info "Estilo de widget restaurado: $widget_style"
    fi

    # Restaurar kdeglobals completo (substitui valores individuais)
    if [[ -f "$backup_dir/kdeglobals" ]]; then
        cp "$backup_dir/kdeglobals" "$HOME/.config/kdeglobals"
        log_info "kdeglobals restaurado (backup completo)"
    fi

    # --- Restaurar GTK Settings ---
    if [[ -f "$backup_dir/gtk3_settings.ini" ]]; then
        mkdir -p "$HOME/.config/gtk-3.0"
        cp "$backup_dir/gtk3_settings.ini" "$HOME/.config/gtk-3.0/settings.ini"
        log_info "Configuração GTK3 restaurada"
    elif [[ -f "$HOME/.config/gtk-3.0/settings.ini" ]]; then
        # Remover configuração que o bigretro inseriu, se houver
        rm -f "$HOME/.config/gtk-3.0/settings.ini"
    fi

    if [[ -f "$backup_dir/gtk4_settings.ini" ]]; then
        mkdir -p "$HOME/.config/gtk-4.0"
        cp "$backup_dir/gtk4_settings.ini" "$HOME/.config/gtk-4.0/settings.ini"
        log_info "Configuração GTK4 restaurada"
    elif [[ -f "$HOME/.config/gtk-4.0/settings.ini" ]]; then
        rm -f "$HOME/.config/gtk-4.0/settings.ini"
    fi

    if [[ -f "$backup_dir/gtkrc-2.0" ]]; then
        cp "$backup_dir/gtkrc-2.0" "$HOME/.config/gtkrc-2.0"
        log_info "Configuração GTK2 restaurada"
    fi

    # --- Restaurar Kvantum ---
    if [[ -f "$backup_dir/kvantum.kvconfig" ]]; then
        mkdir -p "$HOME/.config/Kvantum"
        cp "$backup_dir/kvantum.kvconfig" "$HOME/.config/Kvantum/kvantum.kvconfig"
        log_info "Configuração Kvantum restaurada"
    fi

    # --- Restaurar Plasma Environment ---
    if [[ -f "$backup_dir/gtk-theme.sh" ]]; then
        mkdir -p "$HOME/.config/plasma-workspace/env"
        cp "$backup_dir/gtk-theme.sh" "$HOME/.config/plasma-workspace/env/gtk-theme.sh"
        log_info "Variável de ambiente GTK restaurada"
    elif [[ -f "$HOME/.config/plasma-workspace/env/gtk-theme.sh" ]]; then
        rm -f "$HOME/.config/plasma-workspace/env/gtk-theme.sh"
    fi

    # --- Restaurar Aurorae / Decoração de janelas ---
    if [[ -f "$backup_dir/kwinrc" ]]; then
        cp "$backup_dir/kwinrc" "$HOME/.config/kwinrc"
        log_info "Configuração Aurorae/kwinrc restaurada"
    fi

    # --- Restaurar Wallpaper ---
    if [[ -f "$backup_dir/plasmarc" ]]; then
        cp "$backup_dir/plasmarc" "$HOME/.config/plasmarc"
        log_info "Configuração plasmarc restaurada"
    fi

    log_success "Configurações originais restauradas com sucesso!"
}

# ============================================================================
#  INSTALAÇÃO DOS TEMAS
# ============================================================================

clone_repo() {
    local repo="$1"
    local dest_dir="$2"

    if [[ -d "$dest_dir" ]]; then
        log_step "Repositório já clonado em $dest_dir, atualizando..."
        git -C "$dest_dir" pull --quiet --ff-only 2>/dev/null || {
            log_warn "Falha ao atualizar, re-clonando..."
            rm -rf "$dest_dir"
            git clone --quiet --depth 1 "https://github.com/${repo}.git" "$dest_dir"
        }
    else
        log_step "Clonando $repo..."
        git clone --quiet --depth 1 "https://github.com/${repo}.git" "$dest_dir"
    fi
}

# --- Instalar Tema KDE Plasma ---

install_kde_theme() {
    log_arrow "Instalando Fluent KDE Plasma Theme..."
    ensure_work_dir
    local clone_dir="$WORK_DIR/Fluent-kde"

    clone_repo "$REPO_KDE" "$clone_dir" || {
        log_error "Falha ao clonar $REPO_KDE"
        return 1
    }

    cd "$clone_dir"

    # Determinar resposta para dark/light
    local dark_answer="n"
    if [[ "$THEME_MODE" == "dark" ]]; then
        dark_answer="y"
    fi

    # Executar install.sh com respostas automáticas
    # Fluxo típico: 1) destino (Enter=vazio/default) 2) dark version? (y/n)
    log_step "Executando install.sh do Fluent-kde (dark=$dark_answer)..."
    if printf '\n%s\n' "$dark_answer" | bash ./install.sh &>> "$WORK_DIR/install_kde.log"; then
        log_success "Fluent KDE Theme instalado."
    else
        log_error "Falha na instalação do Fluent KDE Theme."
        log_info "Verifique o log: $WORK_DIR/install_kde.log"
        return 1
    fi

    cd "$OLDPWD"
}

# --- Instalar Tema GTK + libadwaita ---

install_gtk_theme() {
    log_arrow "Instalando Fluent GTK Theme (libadwaita)..."
    ensure_work_dir
    local clone_dir="$WORK_DIR/Fluent-gtk-theme"

    clone_repo "$REPO_GTK" "$clone_dir" || {
        log_error "Falha ao clonar $REPO_GTK"
        return 1
    }

    cd "$clone_dir"

    # Determinar argumentos de cor para o install.sh
    # O Fluent-gtk-theme suporta: -c dark, -c light, ou sem flag (default)
    local gtk_install_flags="-l"
    if [[ "$THEME_MODE" == "dark" ]]; then
        gtk_install_flags="-l -c dark"
    elif [[ "$THEME_MODE" == "light" ]]; then
        gtk_install_flags="-l -c light"
    fi

    # Executar install.sh com flags corretas
    log_step "Executando install.sh $gtk_install_flags do Fluent-gtk..."
    if bash ./install.sh $gtk_install_flags &>> "$WORK_DIR/install_gtk.log"; then
        log_success "Fluent GTK Theme (libadwaita) instalado."
    else
        log_error "Falha na instalacao do Fluent GTK Theme."
        log_info "Verifique o log: $WORK_DIR/install_gtk.log"
        return 1
    fi

    cd "$OLDPWD"
}

# --- Instalar Ícones Fluent ---

install_icon_theme() {
    log_arrow "Instalando Fluent Icon Theme..."
    log_info "Fonte: $KDE_STORE_URL (via GitHub: $REPO_ICONS)"
    ensure_work_dir
    local clone_dir="$WORK_DIR/Fluent-icon-theme"

    clone_repo "$REPO_ICONS" "$clone_dir" || {
        log_error "Falha ao clonar $REPO_ICONS"
        return 1
    }

    cd "$clone_dir"

    # Determinar variante
    local color_answer="default"
    if [[ "$THEME_MODE" == "dark" ]]; then
        color_answer="dark"
    fi

    # Executar install.sh
    log_step "Executando install.sh do Fluent-icon-theme (color=$color_answer)..."
    if printf '\n%s\n' "$color_answer" | bash ./install.sh &>> "$WORK_DIR/install_icons.log"; then
        log_success "Fluent Icon Theme instalado."
    else
        log_error "Falha na instalação do Fluent Icon Theme."
        log_info "Verifique o log: $WORK_DIR/install_icons.log"
        return 1
    fi

    cd "$OLDPWD"
}

# ============================================================================
#  PATCH BIGICONS-PAPIENT
# ============================================================================

patch_bigicons() {
    if [[ "$APPLY_PATCH" != true ]]; then
        log_info "Patch de bigicons desativado (--no-patch)."
        return 0
    fi

    log_arrow "Aplicando patch de ícones BigLinux (bigicons-papient)..."

    # Verificar diretório de origem
    if [[ ! -d "$BIGICONS_SOURCE" ]]; then
        log_warn "Diretório de ícones BigLinux não encontrado: $BIGICONS_SOURCE"
        log_warn "O patch de ícones será pulado. Verifique se o pacote bigicons-papient está instalado."
        return 0
    fi

    # Contar ícones big* disponíveis (tudo que envolve big)
    local big_count
    big_count="$(find "$BIGICONS_SOURCE" -type f -name 'big*' 2>/dev/null | wc -l)"

    if [[ "$big_count" -eq 0 ]]; then
        log_warn "Nenhum ícone big* encontrado em $BIGICONS_SOURCE"
        return 0
    fi

    log_info "Encontrados $big_count ícones big* para patch."

    # Encontrar diretórios de temas Fluent em ~/.local/share/icons/
    local fluent_dirs=()
    local dest_base="$HOME/.local/share/icons"

    if [[ ! -d "$dest_base" ]]; then
        log_error "Diretório de ícones do usuário não existe: $dest_base"
        return 1
    fi

    for theme_dir in "$dest_base"/Fluent*; do
        if [[ -d "$theme_dir" ]]; then
            fluent_dirs+=("$theme_dir")
        fi
    done

    if [[ ${#fluent_dirs[@]} -eq 0 ]]; then
        log_warn "Nenhum diretório de tema Fluent encontrado em $dest_base"
        log_warn "Certifique-se de que o Fluent Icon Theme foi instalado antes do patch."
        return 0
    fi

    # Aplicar patch em cada diretório de tema Fluent
    local total_copied=0
    for theme_dir in "${fluent_dirs[@]}"; do
        local theme_name
        theme_name="$(basename "$theme_dir")"
        log_step "Aplicando patch em: $theme_name"

        # Copiar todos os ícones big* mantendo estrutura de diretórios
        local copied=0
        while IFS= read -r -d '' icon_file; do
            local icon_basename
            icon_basename="$(basename "$icon_file")"

            # Pular o arquivo index.theme para não sobrescrever o original
            if [[ "$icon_basename" == "index.theme" ]]; then
                continue
            fi

            local rel_path="${icon_file#$BIGICONS_SOURCE/}"
            local dest_path="$theme_dir/$rel_path"
            local dest_dirname
            dest_dirname="$(dirname "$dest_path")"

            mkdir -p "$dest_dirname"
            cp -f "$icon_file" "$dest_path"
            ((copied++)) || true
        done < <(find "$BIGICONS_SOURCE" -type f -name 'big*' -print0 2>/dev/null)

        log_info "  $theme_name: $copied ícones copiados"
        total_copied=$((total_copied + copied))
    done

    # Atualizar caches de ícones
    log_step "Atualizando caches de ícones..."
    for theme_dir in "${fluent_dirs[@]}"; do
        if has_cmd gtk-update-icon-cache; then
            gtk-update-icon-cache -f -t "$theme_dir" 2>/dev/null || true
        fi
    done

    log_success "Patch aplicado: $total_copied ícones big* copiados para ${#fluent_dirs[@]} tema(s)."
}

# ============================================================================
#  PATCH ÍCONE DA LIXEIRA COLORIDO
# ============================================================================

patch_trash_icons() {
    log_arrow "Aplicando patch de ícone colorido da lixeira..."

    # Encontrar diretórios de temas Fluent em ~/.local/share/icons/
    local fluent_dirs=()
    local dest_base="$HOME/.local/share/icons"

    if [[ ! -d "$dest_base" ]]; then
        log_warn "Diretório de ícones do usuário não existe: $dest_base"
        return 0
    fi

    for theme_dir in "$dest_base"/Fluent*; do
        if [[ -d "$theme_dir" ]]; then
            fluent_dirs+=("$theme_dir")
        fi
    done

    if [[ ${#fluent_dirs[@]} -eq 0 ]]; then
        log_warn "Nenhum diretório de tema Fluent encontrado em $dest_base"
        return 0
    fi

    local total_patched=0

    for theme_dir in "${fluent_dirs[@]}"; do
        local theme_name
        theme_name="$(basename "$theme_dir")"
        local patched=0

        # Buscar o ícone user-trash-full nos diretórios de tamanho (scalable, 48, 64, etc)
        # em places/ — este é o ícone colorido da lixeira cheia
        local trash_full_source=""
        for size_dir in "$theme_dir"/scalable/places "$theme_dir"/48x48/places "$theme_dir"/64x64/places "$theme_dir"/places; do
            for ext in .svg .png .png.xz; do
                if [[ -f "$size_dir/user-trash-full${ext}" ]]; then
                    trash_full_source="$size_dir/user-trash-full${ext}"
                    break 2
                fi
            done
        done

        if [[ -z "$trash_full_source" ]]; then
            # Tentar wildcard para encontrar qualquer user-trash-full
            trash_full_source="$(find "$theme_dir" -type f -name 'user-trash-full.*' -print -quit 2>/dev/null || true)"
            trash_full_source="${trash_full_source%%$'\n'*}"
        fi

        if [[ -z "$trash_full_source" || ! -f "$trash_full_source" ]]; then
            log_info "  $theme_name: ícone user-trash-full não encontrado, pulando"
            continue
        fi

        # Determinar a extensão do ícone fonte
        local icon_ext
        icon_ext="${trash_full_source##*.}"

        # Diretório destino para symbolic
        local symbolic_places="$theme_dir/symbolic/places"
        mkdir -p "$symbolic_places"

        # Copiar como user-trash-symbolic.<ext>
        if [[ ! -f "$symbolic_places/user-trash-symbolic.${icon_ext}" ]]; then
            cp -f "$trash_full_source" "$symbolic_places/user-trash-symbolic.${icon_ext}"
            ((patched++)) || true
        fi

        # Copiar como user-trash-full-symbolic.<ext>
        if [[ ! -f "$symbolic_places/user-trash-full-symbolic.${icon_ext}" ]]; then
            cp -f "$trash_full_source" "$symbolic_places/user-trash-full-symbolic.${icon_ext}"
            ((patched++)) || true
        fi

        if [[ "$patched" -gt 0 ]]; then
            log_info "  $theme_name: $patched ícone(s) de lixeira colorido(s) aplicado(s) em symbolic/places/"
            total_patched=$((total_patched + patched))
        fi
    done

    # Atualizar caches de ícones
    if [[ "$total_patched" -gt 0 ]]; then
        log_step "Atualizando caches de ícones..."
        for theme_dir in "${fluent_dirs[@]}"; do
            if has_cmd gtk-update-icon-cache; then
                gtk-update-icon-cache -f -t "$theme_dir" 2>/dev/null || true
            fi
        done
        log_success "Patch da lixeira aplicado: $total_patched ícone(s) em ${#fluent_dirs[@]} tema(s)."
    else
        log_warn "Nenhum ícone de lixeira colorido aplicado."
    fi
}

# ============================================================================
#  DETECÇÃO DE TEMAS INSTALADOS
# ============================================================================

detect_installed_themes() {
    log_step "Detectando temas Fluent instalados..."

    local home_share="$HOME/.local/share"
    local config_kvantum="$HOME/.config/Kvantum"

    # --- Detectar Esquema de Cores KDE (case-insensitive) ---
    DETECTED_COLOR_SCHEME=""
    if [[ -d "$home_share/color-schemes" ]]; then
        local cs_lower_mode="$THEME_MODE"
        [[ -n "$cs_lower_mode" ]] && cs_lower_mode="$(echo "$cs_lower_mode" | tr '[:upper:]' '[:lower:]')"

        while IFS= read -r -d '' cs_file; do
            local cs_name
            cs_name="$(basename "$cs_file" .colors)"
            local file_name
            file_name="$(grep -oP '^Name=\K.*' "$cs_file" 2>/dev/null | head -1)"
            file_name="${file_name:-$cs_name}"
            local file_name_lower
            file_name_lower="$(echo "$file_name" | tr '[:upper:]' '[:lower:]')"
            local cs_name_lower
            cs_name_lower="$(echo "$cs_name" | tr '[:upper:]' '[:lower:]')"

            if [[ "$cs_lower_mode" == "dark" ]]; then
                if [[ "$file_name_lower" == *"dark"* || "$cs_name_lower" == *"dark"* ]]; then
                    DETECTED_COLOR_SCHEME="$file_name"
                    break
                fi
            else
                if [[ "$file_name_lower" != *"dark"* && "$cs_name_lower" != *"dark"* ]]; then
                    DETECTED_COLOR_SCHEME="$file_name"
                    break
                fi
            fi
        done < <(find "$home_share/color-schemes" -maxdepth 1 -type f -iname 'Fluent*.colors' -print0 2>/dev/null | sort -z)
    fi
    # Fallback: qualquer Fluent
    if [[ -z "$DETECTED_COLOR_SCHEME" && -d "$home_share/color-schemes" ]]; then
        local cs_fb
        cs_fb="$(find "$home_share/color-schemes" -maxdepth 1 -type f -iname 'Fluent*.colors' -print -quit 2>/dev/null)"
        if [[ -n "$cs_fb" ]]; then
            DETECTED_COLOR_SCHEME="$(grep -oP '^Name=\K.*' "$cs_fb" 2>/dev/null | head -1)"
            DETECTED_COLOR_SCHEME="${DETECTED_COLOR_SCHEME:-$(basename "$cs_fb" .colors)}"
        fi
    fi

    # --- Detectar Tema de Ícones (case-insensitive) ---
    DETECTED_ICON_THEME=""
    if [[ -d "$home_share/icons" ]]; then
        local icon_lower_mode="$THEME_MODE"
        [[ -n "$icon_lower_mode" ]] && icon_lower_mode="$(echo "$icon_lower_mode" | tr '[:upper:]' '[:lower:]')"

        while IFS= read -r -d '' icon_dir; do
            local icon_name
            icon_name="$(basename "$icon_dir")"
            local icon_name_lower
            icon_name_lower="$(echo "$icon_name" | tr '[:upper:]' '[:lower:]')"

            if [[ "$icon_lower_mode" == "dark" ]]; then
                if [[ "$icon_name_lower" == *"dark"* ]]; then
                    DETECTED_ICON_THEME="$icon_name"
                    break
                fi
            else
                if [[ "$icon_name_lower" != *"dark"* ]]; then
                    DETECTED_ICON_THEME="$icon_name"
                    break
                fi
            fi
        done < <(find "$home_share/icons" -maxdepth 1 -type d -iname 'Fluent*' -print0 2>/dev/null | sort -z)
    fi
    if [[ -z "$DETECTED_ICON_THEME" && -d "$home_share/icons" ]]; then
        local icon_fb
        icon_fb="$(find "$home_share/icons" -maxdepth 1 -type d -iname 'Fluent*' -print -quit 2>/dev/null)"
        DETECTED_ICON_THEME="$(basename "${icon_fb:-}" 2>/dev/null)"
    fi

    # --- Detectar Tema Kvantum (case-insensitive, multiplos caminhos) ---
    DETECTED_KVANTUM_THEME=""
    local kv_search_paths=(
        "$config_kvantum"
        "$HOME/.local/share/Kvantum"
        "/usr/share/Kvantum"
    )

    for kv_base in "${kv_search_paths[@]}"; do
        [[ -z "$DETECTED_KVANTUM_THEME" ]] || break
        [[ -d "$kv_base" ]] || continue

        local kv_lower_mode="$THEME_MODE"
        [[ -n "$kv_lower_mode" ]] && kv_lower_mode="$(echo "$kv_lower_mode" | tr '[:upper:]' '[:lower:]')"

        while IFS= read -r -d '' kv_dir; do
            local kv_name
            kv_name="$(basename "$kv_dir")"
            local kv_name_lower
            kv_name_lower="$(echo "$kv_name" | tr '[:upper:]' '[:lower:]')"

            # Verificar se é um tema válido (tem arquivo .kvconfig ou .svg dentro)
            [[ -f "$kv_dir"/*.kvconfig || -f "$kv_dir"/*.svg ]] || continue

            if [[ "$kv_lower_mode" == "dark" ]]; then
                if [[ "$kv_name_lower" == *"dark"* ]]; then
                    DETECTED_KVANTUM_THEME="$kv_name"
                    break
                fi
            else
                if [[ "$kv_name_lower" != *"dark"* ]]; then
                    DETECTED_KVANTUM_THEME="$kv_name"
                    break
                fi
            fi
        done < <(find "$kv_base" -maxdepth 1 -type d -iname 'Fluent*' -print0 2>/dev/null | sort -z)
    done
    # Fallback: qualquer Fluent* em qualquer caminho Kvantum
    if [[ -z "$DETECTED_KVANTUM_THEME" ]]; then
        for kv_base in "${kv_search_paths[@]}"; do
            [[ -d "$kv_base" ]] || continue
            local kv_fb
            kv_fb="$(find "$kv_base" -maxdepth 1 -type d -iname 'Fluent*' -print -quit 2>/dev/null)"
            if [[ -n "$kv_fb" ]]; then
                DETECTED_KVANTUM_THEME="$(basename "$kv_fb" 2>/dev/null)"
                break
            fi
        done
    fi

    # --- Detectar Tema GTK (case-insensitive, busca em ~/.themes e ~/.local/share/themes) ---
    DETECTED_GTK_THEME=""
    local gtk_search_paths=("$HOME/.themes" "$home_share/themes")

    for gtk_base in "${gtk_search_paths[@]}"; do
        [[ -z "$DETECTED_GTK_THEME" ]] || break
        [[ -d "$gtk_base" ]] || continue

        local gtk_lower_mode="$THEME_MODE"
        [[ -n "$gtk_lower_mode" ]] && gtk_lower_mode="$(echo "$gtk_lower_mode" | tr '[:upper:]' '[:lower:]')"

        while IFS= read -r -d '' gtk_dir; do
            local gtk_name
            gtk_name="$(basename "$gtk_dir")"
            local gtk_name_lower
            gtk_name_lower="$(echo "$gtk_name" | tr '[:upper:]' '[:lower:]')"

            # Verificar se é um tema GTK válido (tem gtk-3.0 ou gtk-4.0 ou gtk-2.0)
            [[ -d "$gtk_dir/gtk-3.0" || -d "$gtk_dir/gtk-4.0" || -d "$gtk_dir/gtk-2.0" ]] || continue

            # Mapear nomes conhecidos: Fluent-Dark, Fluent-Light, Fluent, etc.
            if [[ "$gtk_lower_mode" == "dark" ]]; then
                # Prioridade: nomes com "Dark" exato, depois qualquer com "dark"
                if [[ "$gtk_name_lower" == "fluent-dark" ]]; then
                    DETECTED_GTK_THEME="$gtk_name"
                    break 2
                elif [[ "$gtk_name_lower" == *"dark"* ]]; then
                    DETECTED_GTK_THEME="$gtk_name"
                    break 2
                fi
            else
                # Prioridade: nomes com "Light" exato, depois sem "dark"
                if [[ "$gtk_name_lower" == "fluent-light" ]]; then
                    DETECTED_GTK_THEME="$gtk_name"
                    break 2
                elif [[ "$gtk_name_lower" != *"dark"* ]]; then
                    DETECTED_GTK_THEME="$gtk_name"
                    break 2
                fi
            fi
        done < <(find "$gtk_base" -maxdepth 1 -type d -iname 'Fluent*' -print0 2>/dev/null | sort -z)
    done

    # Fallback 1: qualquer Fluent* com subdiretório gtk em ~/.themes
    if [[ -z "$DETECTED_GTK_THEME" && -d "$HOME/.themes" ]]; then
        while IFS= read -r -d '' gtk_dir; do
            if [[ -d "$gtk_dir/gtk-3.0" || -d "$gtk_dir/gtk-4.0" || -d "$gtk_dir/gtk-2.0" ]]; then
                DETECTED_GTK_THEME="$(basename "$gtk_dir")"
                break
            fi
        done < <(find "$HOME/.themes" -maxdepth 1 -type d -iname 'Fluent*' -print0 2>/dev/null | sort -z)
    fi

    # Fallback 2: qualquer Fluent* com subdiretório gtk em ~/.local/share/themes
    if [[ -z "$DETECTED_GTK_THEME" && -d "$home_share/themes" ]]; then
        while IFS= read -r -d '' gtk_dir; do
            if [[ -d "$gtk_dir/gtk-3.0" || -d "$gtk_dir/gtk-4.0" || -d "$gtk_dir/gtk-2.0" ]]; then
                DETECTED_GTK_THEME="$(basename "$gtk_dir")"
                break
            fi
        done < <(find "$home_share/themes" -maxdepth 1 -type d -iname 'Fluent*' -print0 2>/dev/null | sort -z)
    fi

    # Fallback 3: buscar recursivamente (temas instalados pelo script do vinceliuice)
    if [[ -z "$DETECTED_GTK_THEME" ]]; then
        for gtk_base in "${gtk_search_paths[@]}"; do
            [[ -d "$gtk_base" ]] || continue
            local found_gtk
            found_gtk="$(find "$gtk_base" -maxdepth 2 -type d \( -name 'gtk-3.0' -o -name 'gtk-4.0' \) -print -quit 2>/dev/null)"
            if [[ -n "$found_gtk" ]]; then
                local parent_dir
                parent_dir="$(dirname "$found_gtk")"
                local parent_name
                parent_name="$(basename "$parent_dir")"
                local parent_name_lower
                parent_name_lower="$(echo "$parent_name" | tr '[:upper:]' '[:lower:]')"
                if [[ "$parent_name_lower" == *"fluent"* ]]; then
                    DETECTED_GTK_THEME="$parent_name"
                    break
                fi
            fi
        done
    fi

    # --- Detectar Tema Aurorae (case-insensitive, múltiplos caminhos) ---
    DETECTED_AURORAE_THEME=""
    local aurorae_search_paths=(
        "$HOME/.local/share/aurorae/themes"
        "/usr/share/aurorae/themes"
    )

    for aurorae_base in "${aurorae_search_paths[@]}"; do
        [[ -z "$DETECTED_AURORAE_THEME" ]] || break
        [[ -d "$aurorae_base" ]] || continue

        local aur_lower_mode="$THEME_MODE"
        [[ -n "$aur_lower_mode" ]] && aur_lower_mode="$(echo "$aur_lower_mode" | tr '[:upper:]' '[:lower:]')"

        while IFS= read -r -d '' aur_dir; do
            local aur_name
            aur_name="$(basename "$aur_dir")"
            local aur_name_lower
            aur_name_lower="$(echo "$aur_name" | tr '[:upper:]' '[:lower:]')"

            # Verificar se é um tema Aurorae válido (tem metadata.desktop ou arquivo rc)
            [[ -f "$aur_dir/metadata.desktop" || -f "$aur_dir"/decor*.rc || -d "$aur_dir" ]] || continue

            if [[ "$aur_lower_mode" == "dark" ]]; then
                # Prioridade: Fluent-Dark exato, depois qualquer com dark
                if [[ "$aur_name_lower" == "fluent-dark" || "$aur_name_lower" == "fluentdark" ]]; then
                    DETECTED_AURORAE_THEME="$aur_name"
                    break 2
                elif [[ "$aur_name_lower" == *"dark"* ]]; then
                    DETECTED_AURORAE_THEME="$aur_name"
                    break 2
                fi
            else
                # Prioridade: Fluent-Light exato, depois sem dark
                if [[ "$aur_name_lower" == "fluent-light" || "$aur_name_lower" == "fluentlight" ]]; then
                    DETECTED_AURORAE_THEME="$aur_name"
                    break 2
                elif [[ "$aur_name_lower" != *"dark"* ]]; then
                    DETECTED_AURORAE_THEME="$aur_name"
                    break 2
                fi
            fi
        done < <(find "$aurorae_base" -maxdepth 1 -type d -iname 'Fluent*' -print0 2>/dev/null | sort -z)
    done

    # Fallback: qualquer Fluent* em qualquer caminho aurorae
    if [[ -z "$DETECTED_AURORAE_THEME" ]]; then
        for aurorae_base in "${aurorae_search_paths[@]}"; do
            [[ -d "$aurorae_base" ]] || continue
            local aur_fb
            aur_fb="$(find "$aurorae_base" -maxdepth 1 -type d -iname 'Fluent*' -print -quit 2>/dev/null)"
            if [[ -n "$aur_fb" ]]; then
                DETECTED_AURORAE_THEME="$(basename "$aur_fb" 2>/dev/null)"
                break
            fi
        done
    fi

    # Fallback: buscar recursivamente (busca mais profunda)
    if [[ -z "$DETECTED_AURORAE_THEME" ]]; then
        for aurorae_base in "${aurorae_search_paths[@]}"; do
            [[ -d "$aurorae_base" ]] || continue
            local aur_deep
            aur_deep="$(find "$aurorae_base" -maxdepth 2 -type d -iname '*Fluent*' -print -quit 2>/dev/null)"
            if [[ -n "$aur_deep" ]]; then
                DETECTED_AURORAE_THEME="$(basename "$aur_deep" 2>/dev/null)"
                break
            fi
        done
    fi

    # --- Detectar Wallpaper big-retro (case-insensitive, arquivo ou diretório) ---
    DETECTED_WALLPAPER_FILE=""

    # Caso 1: big-retro é um arquivo direto (ex: /usr/share/wallpapers/big-retro.jpg)
    for ext in jpg jpeg png heic; do
        local wp_candidate
        wp_candidate="${WALLPAPER_SOURCE}.${ext}"
        if [[ -f "$wp_candidate" ]]; then
            DETECTED_WALLPAPER_FILE="$wp_candidate"
            break
        fi
        # Também tentar com case diferente
        wp_candidate="${WALLPAPER_SOURCE}.$(echo "$ext" | tr '[:lower:]' '[:upper:]')"
        if [[ -f "$wp_candidate" ]]; then
            DETECTED_WALLPAPER_FILE="$wp_candidate"
            break
        fi
    done

    # Caso 2: big-retro é um diretório com imagens dentro
    if [[ -z "$DETECTED_WALLPAPER_FILE" && -d "$WALLPAPER_SOURCE" ]]; then
        local found
        found="$(find "$WALLPAPER_SOURCE" -maxdepth 3 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.heic' \) -print -quit 2>/dev/null)"
        if [[ -n "$found" && -f "$found" ]]; then
            DETECTED_WALLPAPER_FILE="$found"
        fi
    fi

    # Caso 3: Procurar qualquer arquivo big-retro* em /usr/share/wallpapers/ (case-insensitive)
    if [[ -z "$DETECTED_WALLPAPER_FILE" && -d "$WALLPAPER_SEARCH_DIR" ]]; then
        local found_wild
        found_wild="$(find "$WALLPAPER_SEARCH_DIR" -maxdepth 1 -type f -iname 'big-retro.*' -print -quit 2>/dev/null)"
        if [[ -n "$found_wild" && -f "$found_wild" ]]; then
            DETECTED_WALLPAPER_FILE="$found_wild"
        fi
        # Também procurar dentro de subdiretórios big-retro/
        if [[ -z "$DETECTED_WALLPAPER_FILE" ]]; then
            found_wild="$(find "$WALLPAPER_SEARCH_DIR" -maxdepth 2 -type f -iname 'big-retro*' \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.heic' \) -print -quit 2>/dev/null)"
            if [[ -n "$found_wild" && -f "$found_wild" ]]; then
                DETECTED_WALLPAPER_FILE="$found_wild"
            fi
        fi
    fi

    # Caso 4: Procurar qualquer arquivo com "big" + "retro" no nome
    if [[ -z "$DETECTED_WALLPAPER_FILE" && -d "$WALLPAPER_SEARCH_DIR" ]]; then
        local found_generic
        found_generic="$(find "$WALLPAPER_SEARCH_DIR" -maxdepth 3 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.heic' \) -iname '*big*retro*' -print -quit 2>/dev/null)"
        if [[ -n "$found_generic" && -f "$found_generic" ]]; then
            DETECTED_WALLPAPER_FILE="$found_generic"
        fi
    fi

    # Log dos resultados
    log_info "  Esquema de cores:  ${DETECTED_COLOR_SCHEME:-${C_RED}não detectado${C_RESET}}"
    log_info "  Tema de ícones:    ${DETECTED_ICON_THEME:-${C_RED}não detectado${C_RESET}}"
    log_info "  Tema Kvantum:      ${DETECTED_KVANTUM_THEME:-${C_RED}não detectado${C_RESET}}"
    log_info "  Tema GTK:          ${DETECTED_GTK_THEME:-${C_RED}não detectado${C_RESET}}"
    log_info "  Tema Aurorae:      ${DETECTED_AURORAE_THEME:-${C_RED}não detectado${C_RESET}}"
    log_info "  Wallpaper:         ${DETECTED_WALLPAPER_FILE:-${C_RED}não detectado${C_RESET}}"

    # Debug: listar o que foi realmente instalado (útil para diagnóstico)
    local _debug_missing=false
    [[ -z "$DETECTED_GTK_THEME" ]] && _debug_missing=true
    [[ -z "$DETECTED_AURORAE_THEME" ]] && _debug_missing=true
    [[ -z "$DETECTED_WALLPAPER_FILE" ]] && _debug_missing=true

    if [[ "$_debug_missing" == true ]]; then
        log_info "  [Debug] Conteúdo real dos diretórios:"
        # GTK em ~/.themes
        if [[ -d "$HOME/.themes" ]]; then
            log_info "    ~/.themes/          $(find "$HOME/.themes" -maxdepth 1 -type d -iname 'Fluent*' -exec basename {} \; 2>/dev/null | tr '\n' ', ' | sed 's/, $//')"
        else
            log_info "    ~/.themes/          ${C_DIM}diretório não existe${C_RESET}"
        fi
        # GTK em ~/.local/share/themes
        if [[ -d "$home_share/themes" ]]; then
            log_info "    ~/.local/share/themes/  $(find "$home_share/themes" -maxdepth 1 -type d -iname 'Fluent*' -exec basename {} \; 2>/dev/null | tr '\n' ', ' | sed 's/, $//')"
        else
            log_info "    ~/.local/share/themes/  ${C_DIM}diretório não existe${C_RESET}"
        fi
        # Aurorae em todos os caminhos
        for _aur_dbg in "${aurorae_search_paths[@]}"; do
            if [[ -d "$_aur_dbg" ]]; then
                log_info "    $_aur_dbg/  $(find "$_aur_dbg" -maxdepth 1 -type d -iname 'Fluent*' -exec basename {} \; 2>/dev/null | tr '\n' ', ' | sed 's/, $//')"
            else
                log_info "    $_aur_dbg/  ${C_DIM}diretório não existe${C_RESET}"
            fi
        done
        # Wallpaper
        if [[ -f "$WALLPAPER_SOURCE" ]]; then
            log_info "    wallpaper (arquivo)  $WALLPAPER_SOURCE ${C_GREEN}existe como arquivo${C_RESET}"
        elif [[ -d "$WALLPAPER_SOURCE" ]]; then
            log_info "    wallpaper/      $(find "$WALLPAPER_SOURCE" -maxdepth 3 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.heic' \) -exec basename {} \; 2>/dev/null | tr '\n' ', ' | sed 's/, $//')"
        else
            log_info "    wallpaper/      ${C_YELLOW}caminho $WALLPAPER_SOURCE não existe (nem como arquivo nem como diretório)${C_RESET}"
            # Listar wallpapers disponíveis para diagnóstico
            if [[ -d "$WALLPAPER_SEARCH_DIR" ]]; then
                log_info "    wallpapers disponíveis: $(find "$WALLPAPER_SEARCH_DIR" -maxdepth 1 -type f -iname '*big*' -exec basename {} \; 2>/dev/null | tr '\n' ', ' | sed 's/, $//')"
                log_info "    subdirs big*: $(find "$WALLPAPER_SEARCH_DIR" -maxdepth 1 -type d -iname '*big*' -exec basename {} \; 2>/dev/null | tr '\n' ', ' | sed 's/, $//')"
            fi
        fi
    fi
}

# ============================================================================
#  APLICAÇÃO DAS CONFIGURAÇÕES
# ============================================================================

apply_kde_theme() {
    log_arrow "Aplicando tema KDE Plasma..."

    if [[ -z "$DETECTED_COLOR_SCHEME" ]]; then
        log_warn "Nenhum esquema de cores Fluent detectado para aplicar."
        return 1
    fi

    # 1. Definir esquema de cores
    kwriteconfig6 --file kdeglobals --group General --key ColorScheme "$DETECTED_COLOR_SCHEME"
    log_info "Esquema de cores KDE definido: $DETECTED_COLOR_SCHEME"

    # 2. Garantir que o widgetStyle esteja correto (Kvantum para Fluent)
    local kvantum_style="kvantum"
    if [[ "$THEME_MODE" == "dark" ]]; then
        kvantum_style="kvantum-dark"
    fi
    kwriteconfig6 --file kdeglobals --group General --key widgetStyle "$kvantum_style"
    log_info "Widget style definido: $kvantum_style"

    # 3. Aplicar Look-and-Feel se disponivel
    local lookandfeel_name=""
    if [[ "$THEME_MODE" == "dark" ]]; then
        lookandfeel_name="Fluent-Dark"
    else
        lookandfeel_name="Fluent-Light"
    fi

    # Buscar Look-and-Feel disponiveis
    local laf_found=""
    for laf_dir in "$HOME/.local/share/plasma/look-and-feel" "/usr/share/plasma/look-and-feel"; do
        [[ -d "$laf_dir" ]] || continue
        laf_found="$(find "$laf_dir" -maxdepth 1 -type d -iname "*Fluent*${THEME_MODE:-}*" -print -quit 2>/dev/null)"
        [[ -z "$laf_found" ]] && laf_found="$(find "$laf_dir" -maxdepth 1 -type d -iname '*Fluent*' -print -quit 2>/dev/null)"
        [[ -n "$laf_found" ]] && break
    done

    if [[ -n "$laf_found" ]]; then
        laf_found="$(basename "$laf_found")"
        kwriteconfig6 --file kdeglobals --group General --key LookAndFeelPackage "$laf_found"
        # NAO definir Aurorae library aqui! Se ativarmos o library sem um tema valido,
        # os botoes da janela somem. A funcao apply_aurorae_theme() cuida disso.
        log_info "Look-and-Feel definido: $laf_found"
    fi

    log_success "Tema KDE Plasma aplicado: $DETECTED_COLOR_SCHEME"
}

apply_icon_theme() {
    log_arrow "Aplicando tema de ícones..."

    if [[ -z "$DETECTED_ICON_THEME" ]]; then
        log_warn "Nenhum tema de ícones Fluent detectado para aplicar."
        return 1
    fi

    kwriteconfig6 --file kdeglobals --group Icons --key Theme "$DETECTED_ICON_THEME"
    log_success "Tema de ícones definido: $DETECTED_ICON_THEME"
}

apply_gtk_theme() {
    log_arrow "Aplicando tema GTK (libadwaita)..."

    if [[ -z "$DETECTED_GTK_THEME" ]]; then
        log_warn "Nenhum tema GTK Fluent detectado para aplicar."
        log_info "Verifique se o tema GTK foi instalado corretamente."
        log_info "Caminhos verificados: ~/.themes/ e ~/.local/share/themes/"
        return 1
    fi

    local icon_theme="${DETECTED_ICON_THEME:-$DETECTED_GTK_THEME}"
    local gtk_dark=0
    if [[ "$THEME_MODE" == "dark" ]]; then
        gtk_dark=1
    fi

    # Determinar onde o tema GTK está instalado para referência
    local gtk_theme_path=""
    for _gtk_check in "$HOME/.themes/$DETECTED_GTK_THEME" "$HOME/.local/share/themes/$DETECTED_GTK_THEME"; do
        if [[ -d "$_gtk_check" ]]; then
            gtk_theme_path="$_gtk_check"
            break
        fi
    done

    # Tenta determinar o caminho real (case-insensitive)
    if [[ -z "$gtk_theme_path" ]]; then
        for _gtk_base in "$HOME/.themes" "$HOME/.local/share/themes"; do
            [[ -d "$_gtk_base" ]] || continue
            gtk_theme_path="$(find "$_gtk_base" -maxdepth 1 -type d -iname "${DETECTED_GTK_THEME}" -print -quit 2>/dev/null)"
            [[ -n "$gtk_theme_path" ]] && break
        done
    fi

    # --- GTK3 ---
    mkdir -p "$HOME/.config/gtk-3.0"
    cat > "$HOME/.config/gtk-3.0/settings.ini" <<EOF
[Settings]
gtk-theme-name=${DETECTED_GTK_THEME}
gtk-icon-theme-name=${icon_theme}
gtk-application-prefer-dark-theme=${gtk_dark}
gtk-button-images=1
gtk-menu-images=1
gtk-toolbar-style=GTK_TOOLBAR_BOTH_HORIZ
EOF
    log_info "GTK3 configurado: $DETECTED_GTK_THEME"

    # --- GTK4 / libadwaita ---
    mkdir -p "$HOME/.config/gtk-4.0"
    cat > "$HOME/.config/gtk-4.0/settings.ini" <<EOF
[Settings]
gtk-theme-name=${DETECTED_GTK_THEME}
gtk-icon-theme-name=${icon_theme}
gtk-application-prefer-dark-theme=${gtk_dark}
EOF
    log_info "GTK4/libadwaita configurado: $DETECTED_GTK_THEME"

    # --- Variável de ambiente para apps libadwaita no Plasma ---
    mkdir -p "$HOME/.config/plasma-workspace/env"
    cat > "$HOME/.config/plasma-workspace/env/gtk-theme.sh" <<'ENVEOF'
#!/bin/sh
# Configurado automaticamente pelo bigretro
export GTK_THEME=$(grep gtk-theme-name "$HOME/.config/gtk-4.0/settings.ini" 2>/dev/null | cut -d= -f2)
ENVEOF
    chmod +x "$HOME/.config/plasma-workspace/env/gtk-theme.sh"
    log_info "Variável de ambiente GTK configurada para Plasma"

    # --- GTK2 (gtkrc-2.0) ---
    cat > "$HOME/.config/gtkrc-2.0" <<EOF
# Configurado automaticamente pelo bigretro
gtk-theme-name="${DETECTED_GTK_THEME}"
gtk-icon-theme-name="${icon_theme}"
EOF
    log_info "GTK2 configurado: $DETECTED_GTK_THEME"

    # --- xsettingsd (usado por alguns ambientes) ---
    if has_cmd xsettingsd; then
        mkdir -p "$HOME/.config/xsettingsd"
        cat > "$HOME/.config/xsettingsd/xsettingsd.conf" <<EOF
Net/ThemeName "${DETECTED_GTK_THEME}"
Net/IconThemeName "${icon_theme}"
EOF
        log_info "xsettingsd configurado."
    fi

    # --- Configuração para Flatpak (GTK3 + GTK4/libadwaita) ---
    if has_cmd flatpak; then
        log_step "Configurando temas GTK para aplicativos Flatpak..."

        # 1. Liberar acesso ao ~/.config/gtk-3.0 e gtk-4.0 (onde estao os settings.ini)
        #    Tambem liberar ~/.local/share/themes e ~/.local/share/icons para arquivos de tema
        flatpak override --user --filesystem=xdg-config/gtk-3.0:ro 2>/dev/null || true
        flatpak override --user --filesystem=xdg-config/gtk-4.0:ro 2>/dev/null || true
        flatpak override --user --filesystem=xdg-data/themes:ro 2>/dev/null || true
        flatpak override --user --filesystem=xdg-data/icons:ro 2>/dev/null || true
        log_info "Flatpak: acesso liberado a xdg-config/gtk-3.0, xdg-config/gtk-4.0, xdg-data/themes, xdg-data/icons"

        # 2. Se o tema GTK esta em ~/.themes (nao acessivel nativamente pelo Flatpak),
        #    criar link simbolico em ~/.local/share/themes para o Flatpak encontrar
        local _fp_theme_in_local_share=false
        for _fp_check in "$HOME/.local/share/themes/$DETECTED_GTK_THEME" "$HOME/.local/share/themes/$(echo "$DETECTED_GTK_THEME" | tr '[:upper:]' '[:lower:]')"; do
            if [[ -d "$_fp_check" ]]; then
                _fp_theme_in_local_share=true
                break
            fi
        done

        if [[ "$_fp_theme_in_local_share" == false ]]; then
            # Buscar o tema em ~/.themes
            local _fp_src=""
            for _fp_base in "$HOME/.themes"; do
                [[ -d "$_fp_base" ]] || continue
                _fp_src="$(find "$_fp_base" -maxdepth 1 -type d -iname "${DETECTED_GTK_THEME}" -print -quit 2>/dev/null)"
                [[ -n "$_fp_src" ]] && break
            done
            if [[ -n "$_fp_src" ]]; then
                mkdir -p "$HOME/.local/share/themes"
                local _fp_link="$HOME/.local/share/themes/$DETECTED_GTK_THEME"
                if [[ ! -e "$_fp_link" ]]; then
                    ln -sf "$_fp_src" "$_fp_link"
                    log_info "Link simbolico criado: $_fp_link -> $_fp_src"
                fi
            fi
        fi

        # 3. Definir GTK_THEME globalmente para TODOS os Flatpaks
        local _fp_gtk_theme_name="$DETECTED_GTK_THEME"
        if flatpak override --user --env=GTK_THEME="$_fp_gtk_theme_name" 2>/dev/null; then
            log_info "Flatpak: GTK_THEME=$_fp_gtk_theme_name definido globalmente."
        else
            log_warn "Falha ao definir GTK_THEME global para Flatpaks via 'flatpak override'."
        fi

        # 4. Definir ICON_THEME para Flatpaks
        if [[ -n "$icon_theme" ]]; then
            if flatpak override --user --env=ICON_THEME="$icon_theme" 2>/dev/null; then
                log_info "Flatpak: ICON_THEME=$icon_theme definido globalmente."
            fi
        fi

        # 5. Escrever settings.ini em cada app Flatpak instalado (garantia adicional)
        local flatpak_gtk_dir="$HOME/.var/app/"
        if [[ -d "$flatpak_gtk_dir" ]]; then
            local _fp_count=0
            while IFS= read -r -d '' _fp_app; do
                [[ "$(basename "$_fp_app")" == "." ]] && continue

                # GTK3 settings.ini
                local _fp_gtk3="$_fp_app/config/gtk-3.0"
                mkdir -p "$_fp_gtk3"
                cat > "$_fp_gtk3/settings.ini" <<EOF
[Settings]
gtk-theme-name=${DETECTED_GTK_THEME}
gtk-icon-theme-name=${icon_theme}
gtk-application-prefer-dark-theme=${gtk_dark}
gtk-button-images=1
gtk-menu-images=1
gtk-toolbar-style=GTK_TOOLBAR_BOTH_HORIZ
EOF

                # GTK4 settings.ini (libadwaita)
                local _fp_gtk4="$_fp_app/config/gtk-4.0"
                mkdir -p "$_fp_gtk4"
                cat > "$_fp_gtk4/settings.ini" <<EOF
[Settings]
gtk-theme-name=${DETECTED_GTK_THEME}
gtk-icon-theme-name=${icon_theme}
gtk-application-prefer-dark-theme=${gtk_dark}
EOF

                ((_fp_count++)) || true
            done < <(find "$flatpak_gtk_dir" -maxdepth 1 -type d -print0 2>/dev/null)
            if [[ "$_fp_count" -gt 0 ]]; then
                log_info "Flatpak: settings.ini escrito em $_fp_count app(s) (GTK3 + GTK4)."
            fi
        fi

        log_success "Configuracao Flatpak concluida (xdg-config/gtk-3.0 + gtk-4.0)."
    fi

    # --- Garantir que o XDG_DATA_DIRS inclui ~/.local/share (para GTK descobrir temas) ---
    if [[ -f "$HOME/.config/plasma-workspace/env/set-theme.sh" ]]; then
        : # já existe
    else
        mkdir -p "$HOME/.config/plasma-workspace/env"
        cat > "$HOME/.config/plasma-workspace/env/set-theme.sh" <<'SETEOF'
#!/bin/sh
# Garante que GTK encontre temas instalados pelo usuário
export XDG_DATA_DIRS="$HOME/.local/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
SETEOF
        chmod +x "$HOME/.config/plasma-workspace/env/set-theme.sh"
        log_info "XDG_DATA_DIRS configurado para descoberta de temas GTK."
    fi
}

apply_kvantum_theme() {
    log_arrow "Aplicando estilo Kvantum..."

    # Definir estilo de widget Kvantum
    # Em modo dark, usar kvantum-dark; em modo light, usar kvantum
    local kvantum_style="kvantum"
    if [[ "$THEME_MODE" == "dark" ]]; then
        kvantum_style="kvantum-dark"
    fi

    # 1. Sempre definir o widgetStyle no kdeglobals (essencial!)
    kwriteconfig6 --file kdeglobals --group General --key widgetStyle "$kvantum_style"
    log_info "Estilo de widget definido: $kvantum_style"

    # 2. Determinar qual tema Kvantum usar
    local kv_theme="$DETECTED_KVANTUM_THEME"

    # Se não detectou via detect_installed_themes, tentar buscar agora
    if [[ -z "$kv_theme" ]]; then
        # Buscar em múltiplos caminhos
        local kv_search_paths=(
            "$HOME/.config/Kvantum"
            "$HOME/.local/share/Kvantum"
            "/usr/share/Kvantum"
        )
        local kv_mode_suffix=""
        [[ "$THEME_MODE" == "dark" ]] && kv_mode_suffix="dark"

        for kv_base in "${kv_search_paths[@]}"; do
            [[ -d "$kv_base" ]] || continue
            while IFS= read -r -d '' kv_dir; do
                local kv_name
                kv_name="$(basename "$kv_dir")"
                local kv_name_lower
                kv_name_lower="$(echo "$kv_name" | tr '[:upper:]' '[:lower:]')"

                # Verificar se é válido (tem .kvconfig ou .svg dentro)
                [[ -f "$kv_dir"/*.kvconfig || -f "$kv_dir"/*.svg ]] || continue

                if [[ -n "$kv_mode_suffix" ]]; then
                    # Modo dark: priorizar nomes com "dark"
                    if [[ "$kv_name_lower" == *"dark"* ]]; then
                        kv_theme="$kv_name"
                        break
                    fi
                else
                    # Modo light: priorizar nomes SEM "dark"
                    if [[ "$kv_name_lower" != *"dark"* ]]; then
                        kv_theme="$kv_name"
                        break
                    fi
                fi
            done < <(find "$kv_base" -maxdepth 1 -type d -iname 'Fluent*' -print0 2>/dev/null | sort -z)
            [[ -n "$kv_theme" ]] && break
        done

        # Fallback: qualquer tema Fluent em qualquer caminho
        if [[ -z "$kv_theme" ]]; then
            for kv_base in "${kv_search_paths[@]}"; do
                [[ -d "$kv_base" ]] || continue
                local kv_any
                kv_any="$(find "$kv_base" -maxdepth 1 -type d -iname 'Fluent*' -print -quit 2>/dev/null)"
                if [[ -n "$kv_any" ]]; then
                    kv_theme="$(basename "$kv_any")"
                    break
                fi
            done
        fi
    fi

    # 3. Escrever diretamente no kvantum.kvconfig (SEM abrir kvantummanager GUI)
    if [[ -n "$kv_theme" ]]; then
        mkdir -p "$HOME/.config/Kvantum"
        cat > "$HOME/.config/Kvantum/kvantum.kvconfig" <<EOF
[General]
theme=${kv_theme}
EOF
        log_success "Tema Kvantum aplicado: $kv_theme (widget style: $kvantum_style)"
    else
        log_warn "Nenhum tema Kvantum Fluent encontrado em nenhum caminho."
        log_warn "O widget style foi definido como '$kvantum_style' (apenas estrutura, sem tema)."
        log_info "Verifique se o Fluent-kde foi instalado corretamente."
    fi
}

apply_aurorae_theme() {
    log_arrow "Aplicando tema Aurorae (decoracao de janelas)..."

    local aur_theme="$DETECTED_AURORAE_THEME"
    local aurorae_search_paths=(
        "$HOME/.local/share/aurorae/themes"
        "/usr/share/aurorae/themes"
    )

    # Se não detectou, tentar buscar agora de forma agressiva
    if [[ -z "$aur_theme" ]]; then
        log_info "Buscando temas Aurorae Fluent disponiveis..."

        # Nomes esperados para cada modo
        local expected_names=()
        if [[ "$THEME_MODE" == "dark" ]]; then
            expected_names=("Fluent-Dark" "FluentDark" "Fluent-dark" "FluentDarkRound" "Fluent-Dark-Round")
        else
            expected_names=("Fluent" "Fluent-Light" "FluentLight" "FluentRound" "Fluent-Light-Round")
        fi

        # Tentar cada nome esperado em cada caminho
        for exp_name in "${expected_names[@]}"; do
            [[ -n "$aur_theme" ]] && break
            for aur_base in "${aurorae_search_paths[@]}"; do
                [[ -d "$aur_base" ]] || continue
                # Busca case-insensitive
                local found
                found="$(find "$aur_base" -maxdepth 2 -type d -iname "${exp_name}" -print -quit 2>/dev/null)"
                if [[ -n "$found" ]]; then
                    aur_theme="$(basename "$found")"
                    break
                fi
            done
        done

        # Fallback: qualquer diretório Fluent* em qualquer caminho Aurorae
        if [[ -z "$aur_theme" ]]; then
            for aur_base in "${aurorae_search_paths[@]}"; do
                [[ -d "$aur_base" ]] || continue
                local any_fluent
                any_fluent="$(find "$aur_base" -maxdepth 1 -type d -iname 'Fluent*' -print -quit 2>/dev/null)"
                if [[ -n "$any_fluent" ]]; then
                    aur_theme="$(basename "$any_fluent")"
                    break
                fi
            done
        fi

        # Fallback final: buscar recursivamente (pode estar em subdiretório)
        if [[ -z "$aur_theme" ]]; then
            for aur_base in "${aurorae_search_paths[@]}"; do
                [[ -d "$aur_base" ]] || continue
                local deep_find
                deep_find="$(find "$aur_base" -maxdepth 3 -type d -iname '*Fluent*' -print -quit 2>/dev/null)"
                if [[ -n "$deep_find" ]]; then
                    aur_theme="$(basename "$deep_find")"
                    break
                fi
            done
        fi
    fi

    # Se AINDA não encontrou, listar o que existe para debug
    if [[ -z "$aur_theme" ]]; then
        log_warn "Nenhum tema Aurorae Fluent encontrado."
        log_info "Caminhos verificados:"
        for _p in "${aurorae_search_paths[@]}"; do
            if [[ -d "$_p" ]]; then
                local _contents
                _contents="$(find "$_p" -maxdepth 2 -type d -iname '*Fluent*' 2>/dev/null | tr '\n' ', ')"
                log_info "  $_p/  ->  ${_contents:-vazio}"
            else
                log_info "  $_p/  ->  nao existe"
            fi
        done
        log_info "O Fluent-kde pode nao ter instalado os temas Aurorae."
        log_info "Tente executar novamente com --kde para reinstalar."
        return 0
    fi

    # Verificar se o tema realmente existe no filesystem (case-insensitive)
    local aurorae_found_path=""
    for aur_base in "${aurorae_search_paths[@]}"; do
        [[ -d "$aur_base" ]] || continue
        aurorae_found_path="$(find "$aur_base" -maxdepth 3 -type d -iname "${aur_theme}" -print -quit 2>/dev/null)"
        [[ -n "$aurorae_found_path" ]] && break
    done

    if [[ -z "$aurorae_found_path" ]]; then
        log_warn "Tema Aurorae '$aur_theme' encontrado pelo nome mas o diretorio nao existe no filesystem."
        return 0
    fi

    log_info "Tema Aurorae encontrado em: $aurorae_found_path"

    # Definir tema de decoracao de janelas via kwinrc
    kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key library "org.kde.kwin.aurorae"
    kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key theme "$aur_theme"

    # Tambem garantir que o ButtonsOnRight esta correto para Fluent (botoes a direita)
    kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key ButtonsOnRight "true"

    log_success "Tema Aurorae aplicado: $aur_theme (botoes a direita)"
    # NOTA: O reload do KWin e feito pela funcao reload_plasma() no final,
    # evitando recarregamentos duplicados que podem causar flicker.
}

apply_wallpaper() {
    log_arrow "Aplicando wallpaper big-retro..."

    if [[ -z "$DETECTED_WALLPAPER_FILE" ]]; then
        log_warn "Wallpaper big-retro nao encontrado."
        log_info "Caminhos verificados:"
        log_info "  - Arquivo: /usr/share/wallpapers/big-retro.{jpg,jpeg,png,heic}"
        log_info "  - Diretorio: /usr/share/wallpapers/big-retro/"
        log_info "  - Busca: /usr/share/wallpapers/ (big-retro*)"
        log_info "O wallpaper nao sera alterado."
        return 0
    fi

    # Verificar se o arquivo de wallpaper realmente existe
    if [[ ! -f "$DETECTED_WALLPAPER_FILE" ]]; then
        log_error "Arquivo de wallpaper nao encontrado: $DETECTED_WALLPAPER_FILE"
        return 1
    fi

    local wp_file="$DETECTED_WALLPAPER_FILE"
    local wp_filename
    wp_filename="$(basename "$wp_file")"
    local wp_uri
    wp_uri="$(realpath "$wp_file" 2>/dev/null || echo "$wp_file")"

    # Normalizar para file:// URI
    if [[ "$wp_uri" != file://* ]]; then
        wp_uri="file://$wp_uri"
    fi

    log_info "Wallpaper encontrado: $wp_file"

    # Metodo 1: plasma-apply-wallpaperimage (preferido no Plasma 6)
    if has_cmd plasma-apply-wallpaperimage; then
        if plasma-apply-wallpaperimage "$wp_file" 2>/dev/null; then
            log_success "Wallpaper aplicado via plasma-apply-wallpaperimage: $wp_filename"
            return 0
        fi
        log_warn "plasma-apply-wallpaperimage falhou, tentando metodos alternativos..."
    fi

    # Metodo 2: Configurar o wallpaper como plugin de imagem nativo do Plasma
    # Criar estrutura de wallpaper no diretorio do usuario se necessario
    local user_wallpaper_dir="$HOME/.local/share/wallpapers/big-retro"
    mkdir -p "$user_wallpaper_dir/contents/images"

    # Copiar a imagem para o diretorio correto do Plasma
    if [[ ! -f "$user_wallpaper_dir/contents/images/$wp_filename" ]]; then
        cp -f "$wp_file" "$user_wallpaper_dir/contents/images/$wp_filename"
        log_info "Wallpaper copiado para $user_wallpaper_dir/contents/images/"
    fi

    # Criar metadata.desktop necessario para o Plasma detectar o wallpaper
    if [[ ! -f "$user_wallpaper_dir/metadata.desktop" ]]; then
        cat > "$user_wallpaper_dir/metadata.desktop" <<METAEOF
[Desktop Entry]
Name=big-retro
Comment=BigLinux Retro Wallpaper

X-KDE-PluginInfo-Name=big-retro
X-KDE-PluginInfo-Author=BigLinux
X-KDE-PluginInfo-Category=
X-KDE-PluginInfo-Depends=
X-KDE-PluginInfo-Email=
X-KDE-PluginInfo-EnabledByDefault=true
X-KDE-PluginInfo-License=LGPLv2+
X-KDE-PluginInfo-Version=1.0
X-KDE-PluginInfo-Website=

[Wallpaper]
defaultFileSuffix=.jpg
defaultHeight=1080
defaultWidth=1920

[Settings]
Image=file://$user_wallpaper_dir/contents/images/$wp_filename
METAEOF
        log_info "metadata.desktop criado."
    fi

    # Metodo 3: Aplicar via D-Bus (configura o wallpaper em todos os desktops)
    if has_cmd qdbus6; then
        qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript \
            "var allDesktops = desktops(); for (i=0;i<allDesktops.length;i++) { d = allDesktops[i]; d.wallpaperPlugin = 'org.kde.image'; d.currentConfigGroup = Array('Wallpaper', 'org.kde.image', 'General'); d.writeConfig('Image', 'file://$user_wallpaper_dir/contents/images/$wp_filename'); }" 2>/dev/null && {
            log_success "Wallpaper aplicado via D-Bus: $wp_filename"
            return 0
        }
    fi

    if has_cmd qdbus; then
        qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript \
            "var allDesktops = desktops(); for (i=0;i<allDesktops.length;i++) { d = allDesktops[i]; d.wallpaperPlugin = 'org.kde.image'; d.currentConfigGroup = Array('Wallpaper', 'org.kde.image', 'General'); d.writeConfig('Image', 'file://$user_wallpaper_dir/contents/images/$wp_filename'); }" 2>/dev/null && {
            log_success "Wallpaper aplicado via D-Bus: $wp_filename"
            return 0
        }
    fi

    # Metodo 4: Fallback via kwriteconfig6
    kwriteconfig6 --file plasmarc --group PlasmaViews --group2 Desktop --group3 Background --key Image "file://$user_wallpaper_dir/contents/images/$wp_filename"

    log_success "Wallpaper big-retro aplicado: $wp_filename (via plasmarc)"
    log_info "Reinicie a sessao Plasma se o wallpaper nao aparecer imediatamente."
}

# ============================================================================
#  RECARREGAMENTO DO PLASMA
# ============================================================================

reload_plasma() {
    log_arrow "Aplicando mudancas ao vivo (sem reiniciar)..."
    local _any_success=false

    # --- 1. Recarregar KWin (decoracao de janelas, esquema de cores, Aurorae) ---
    if has_cmd qdbus6; then
        qdbus6 org.kde.KWin /KWin reconfigure 2>/dev/null && _any_success=true
        sleep 0.3
        qdbus6 org.kde.KWin /KWin reloadConfig 2>/dev/null && _any_success=true
    fi
    if has_cmd qdbus; then
        qdbus org.kde.KWin /KWin reconfigure 2>/dev/null && _any_success=true
        sleep 0.3
        qdbus org.kde.KWin /KWin reloadConfig 2>/dev/null && _any_success=true
    fi
    if has_cmd dbus-send; then
        dbus-send --session --dest=org.kde.KWin --type=method_call /KWin org.kde.KWin.reconfigure 2>/dev/null && _any_success=true
        sleep 0.3
        dbus-send --session --dest=org.kde.KWin --type=method_call /KWin org.kde.KWin.reloadConfig 2>/dev/null && _any_success=true
    fi

    # --- 2. Reconfigurar PlasmaShell (interface grafica, paineis, icones) ---
    if has_cmd qdbus6; then
        # Aplicar esquema de cores ao vivo
        qdbus6 org.kde.KWin /KWin org.kde.KWin.showDebugConsole false 2>/dev/null || true
        # Refresh do PlasmaShell
        qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.refreshCurrentShell 2>/dev/null && _any_success=true
        # Atualizar cache de icones do KDE
        qdbus6 org.kde.KIconThemes /KIconThemes org.kde.KIconThemes.refreshIcons 2>/dev/null || true
    fi
    if has_cmd qdbus; then
        qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.refreshCurrentShell 2>/dev/null && _any_success=true
        qdbus org.kde.KIconThemes /KIconThemes org.kde.KIconThemes.refreshIcons 2>/dev/null || true
    fi

    # --- 3. Recarregar Kvantum via D-Bus (SEM abrir GUI) ---
    # Escrever no kvconfig e notificar via D-Bus
    if has_cmd qdbus6; then
        qdbus6 org.kde.KWin /KWin reconfigure 2>/dev/null || true
    fi
    # NAO usar kvantummanager --reset ou --set pois abre a GUI

    # --- 4. Atualizar caches de icones ---
    if has_cmd gtk-update-icon-cache; then
        for _icon_dir in "$HOME/.local/share/icons"/Fluent*; do
            [[ -d "$_icon_dir" ]] || continue
            gtk-update-icon-cache -f -t "$_icon_dir" 2>/dev/null || true
        done
    fi
    # Reconstruir o cache de servico do KDE
    if has_cmd kbuildsycoca6; then
        kbuildsycoca6 2>/dev/null || true
    fi

    # --- 5. Sinalizar reconfiguracao geral do Plasma (desktops, wallpaper) ---
    if has_cmd qdbus6; then
        qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript \
            'desktops().forEach(function(d) { d.currentConfigGroup = Array("General"); d.reloadConfig(); });' 2>/dev/null || true
    fi

    # --- 6. Reiniciar PlasmaShell se necessario (ultima opcao, MAS sem logout) ---
    # Pequena pausa para os reloads acima tomarem efeito
    sleep 0.5

    if [[ "$_any_success" == true ]]; then
        log_success "Mudancas aplicadas ao vivo. Os temas ja devem estar visiveis."
    else
        log_warn "Nao foi possivel recarregar completamente via D-Bus."
    fi
    log_info "Se algo nao apareceu, pressione Shift+Alt+F12 (reiniciar KWin)"
    log_info "ou Ctrl+Alt+Esc (reiniciar PlasmaShell)."
}

# ============================================================================
#  DESINSTALAÇÃO
# ============================================================================

uninstall_theme() {
    show_banner
    printf '%b%b  MODO DE DESINSTALAÇÃO%b\n\n' "$C_BOLD" "$C_YELLOW" "$C_RESET"

    log_arrow "Desinstalando bigretro e restaurando configurações originais..."

    # 1. Restaurar backup
    restore_backup

    # 2. Remover arquivos de tema (se --purge)
    if [[ "$PURGE_MODE" == true ]]; then
        log_arrow "Removendo arquivos de tema Fluent..."

        # Esquemas de cores
        rm -f "$HOME/.local/share/color-schemes"/Fluent*.colors 2>/dev/null
        log_info "Esquemas de cores Fluent removidos."

        # Temas GTK (em ambos os caminhos)
        rm -rf "$HOME/.themes"/Fluent* 2>/dev/null
        rm -rf "$HOME/.local/share/themes"/Fluent* 2>/dev/null
        log_info "Temas GTK Fluent removidos."

        # Limpar configurações GTK criadas pelo bigretro
        rm -f "$HOME/.config/gtkrc-2.0" 2>/dev/null
        rm -f "$HOME/.config/plasma-workspace/env/gtk-theme.sh" 2>/dev/null
        rm -f "$HOME/.config/plasma-workspace/env/set-theme.sh" 2>/dev/null

        # Limpar overrides do Flatpak (GTK_THEME, ICON_THEME)
        if has_cmd flatpak; then
            flatpak override --user --reset 2>/dev/null || true
            log_info "Overrides do Flatpak restaurados ao padrao."
        fi

        # Temas de ícones
        rm -rf "$HOME/.local/share/icons"/Fluent* 2>/dev/null
        log_info "Temas de ícones Fluent removidos."

        # Look-and-Feel Plasma
        rm -rf "$HOME/.local/share/plasma/look-and-feel"/*Fluent* 2>/dev/null
        rm -rf "$HOME/.local/share/plasma/look-and-feel"/*fluent* 2>/dev/null
        log_info "Look-and-Feel Fluent removidos."

        # Temas Aurorae (APENAS do usuario, nunca de /usr/share)
        rm -rf "$HOME/.local/share/aurorae/themes"/Fluent* 2>/dev/null
        log_info "Temas Aurorae Fluent removidos (apenas ~/.local/share)."

        # Kvantum themes
        rm -rf "$HOME/.config/Kvantum"/Fluent* 2>/dev/null
        rm -rf "$HOME/.config/Kvantum"/FluentDark* 2>/dev/null
        log_info "Temas Kvantum Fluent removidos."

        # Wallpapers
        rm -rf "$HOME/.local/share/wallpapers"/Fluent* 2>/dev/null
        log_info "Wallpapers Fluent removidos."

        log_success "Todos os arquivos de tema Fluent foram removidos."
    else
        log_info "Arquivos de tema preservados (use --purge para remover)."
    fi

    # 3. Recarregar Plasma
    if is_plasma; then
        reload_plasma
    fi

    printf '\n'
    log_success "Desinstalação concluída com sucesso!"
    printf '\n'
    log_info "Sistema restaurado ao estado anterior à instalação do bigretro."
    if [[ "$PURGE_MODE" != true ]]; then
        log_info "Para remover completamente os arquivos de tema, execute:"
        log_info "  $SCRIPT_NAME --uninstall --purge"
    fi
    printf '\n'
}

# ============================================================================
#  STATUS
# ============================================================================

show_status() {
    show_banner

    printf '%b%b  STATUS ATUAL DO TEMA%b\n\n' "$C_BOLD" "$C_CYAN" "$C_RESET"

    # Plasma
    local plasma_ver
    plasma_ver="$(get_plasma_version)"
    printf '  %bKDE Plasma:%b              %s\n' "$C_BOLD" "$C_RESET" "$plasma_ver"

    # Esquema de cores
    local current_cs
    current_cs="$(kreadconfig6 --file kdeglobals --group General --key ColorScheme 2>/dev/null | tr -d '[:space:]')"
    local cs_indicator="$E_CROSS"
    [[ "$current_cs" == *"Fluent"* ]] && cs_indicator="$E_CHECK"
    printf '  %bEsquema de cores:%b       %s  %s\n' "$C_BOLD" "$C_RESET" "${current_cs:-não definido}" "$cs_indicator"

    # Tema de ícones
    local current_icons
    current_icons="$(kreadconfig6 --file kdeglobals --group Icons --key Theme 2>/dev/null | tr -d '[:space:]')"
    local icons_indicator="$E_CROSS"
    [[ "$current_icons" == *"Fluent"* ]] && icons_indicator="$E_CHECK"
    printf '  %bTema de ícones:%b         %s  %s\n' "$C_BOLD" "$C_RESET" "${current_icons:-não definido}" "$icons_indicator"

    # Estilo de widget
    local current_widget
    current_widget="$(kreadconfig6 --file kdeglobals --group General --key widgetStyle 2>/dev/null | tr -d '[:space:]')"
    local widget_indicator="$E_CROSS"
    [[ "$current_widget" == *"kvantum"* || "$current_widget" == *"Kvantum"* ]] && widget_indicator="$E_CHECK"
    printf '  %bEstilo de widget:%b       %s  %s\n' "$C_BOLD" "$C_RESET" "${current_widget:-não definido}" "$widget_indicator"

    # Kvantum
    if [[ -f "$HOME/.config/Kvantum/kvantum.kvconfig" ]]; then
        local kv_theme
        kv_theme="$(grep -oP 'theme=\K.*' "$HOME/.config/Kvantum/kvantum.kvconfig" 2>/dev/null | head -1)"
        local kv_indicator="$E_CROSS"
        [[ "$kv_theme" == *"Fluent"* ]] && kv_indicator="$E_CHECK"
        printf '  %bTema Kvantum:%b           %s  %s\n' "$C_BOLD" "$C_RESET" "${kv_theme:-não definido}" "$kv_indicator"
    else
        printf '  %bTema Kvantum:%b           não configurado\n' "$C_BOLD" "$C_RESET"
    fi

    # GTK Themes disponiveis nos dois caminhos
    local _gtk_found_list=""
    for _gtk_s in "$HOME/.themes" "$HOME/.local/share/themes"; do
        [[ -d "$_gtk_s" ]] || continue
        for _gtk_d in "$_gtk_s"/Fluent*; do
            [[ -d "$_gtk_d" ]] || continue
            [[ -d "$_gtk_d/gtk-3.0" || -d "$_gtk_d/gtk-4.0" ]] || continue
            _gtk_found_list="${_gtk_found_list}$(basename "$_gtk_d"), "
        done
    done
    if [[ -n "$_gtk_found_list" ]]; then
        _gtk_found_list="${_gtk_found_list%, }"
        printf '  %bGTK Themes disponiveis:%b %s\n' "$C_BOLD" "$C_RESET" "$_gtk_found_list"
    else
        printf '  %bGTK Themes disponiveis:%b nenhum encontrado\n' "$C_BOLD" "$C_RESET"
    fi
    printf '\n'

    # GTK3
    if [[ -f "$HOME/.config/gtk-3.0/settings.ini" ]]; then
        local gtk3_theme gtk3_icons
        gtk3_theme="$(grep -oP 'gtk-theme-name=\K.*' "$HOME/.config/gtk-3.0/settings.ini" 2>/dev/null)"
        gtk3_icons="$(grep -oP 'gtk-icon-theme-name=\K.*' "$HOME/.config/gtk-3.0/settings.ini" 2>/dev/null)"
        local gtk3_indicator="$E_CROSS"
        [[ "$gtk3_theme" == *"Fluent"* || "$gtk3_theme" == *"fluent"* ]] && gtk3_indicator="$E_CHECK"
        printf '  %bGTK3 Theme:%b             %s  %s\n' "$C_BOLD" "$C_RESET" "${gtk3_theme:-não definido}" "$gtk3_indicator"
        printf '  %bGTK3 Icons:%b             %s\n' "$C_BOLD" "$C_RESET" "${gtk3_icons:-não definido}"
    else
        printf '  %bGTK3:%b                   não configurado\n' "$C_BOLD" "$C_RESET"
    fi

    # GTK4
    if [[ -f "$HOME/.config/gtk-4.0/settings.ini" ]]; then
        local gtk4_theme gtk4_icons
        gtk4_theme="$(grep -oP 'gtk-theme-name=\K.*' "$HOME/.config/gtk-4.0/settings.ini" 2>/dev/null)"
        gtk4_icons="$(grep -oP 'gtk-icon-theme-name=\K.*' "$HOME/.config/gtk-4.0/settings.ini" 2>/dev/null)"
        local gtk4_indicator="$E_CROSS"
        [[ "$gtk4_theme" == *"Fluent"* || "$gtk4_theme" == *"fluent"* ]] && gtk4_indicator="$E_CHECK"
        printf '  %bGTK4/libadwaita:%b        %s  %s\n' "$C_BOLD" "$C_RESET" "${gtk4_theme:-não definido}" "$gtk4_indicator"
        printf '  %bGTK4 Icons:%b             %s\n' "$C_BOLD" "$C_RESET" "${gtk4_icons:-não definido}"
    else
        printf '  %bGTK4/libadwaita:%b        não configurado\n' "$C_BOLD" "$C_RESET"
    fi

    # Bigicons patch
    printf '\n'
    local bigicons_count=0
    if [[ -d "$BIGICONS_SOURCE" ]]; then
        bigicons_count="$(find "$BIGICONS_SOURCE" -type f -name 'big*' 2>/dev/null | wc -l)"
    fi
    local patched_count=0
    if [[ -d "$HOME/.local/share/icons" ]]; then
        patched_count="$(find "$HOME/.local/share/icons/Fluent"* -type f -name 'big*' 2>/dev/null | wc -l)"
    fi
    printf '  %bÍcones BigLinux (big*):%b  %d disponíveis, %d aplicados\n' "$C_BOLD" "$C_RESET" "$bigicons_count" "$patched_count"

    # Trash icon patch
    local trash_patched=0
    if [[ -d "$HOME/.local/share/icons" ]]; then
        trash_patched="$(find "$HOME/.local/share/icons/Fluent"*/symbolic/places -type f -name 'user-trash*-symbolic.*' 2>/dev/null | wc -l)"
    fi
    printf '  %bLixeira colorida (patch):%b %d ícone(s)\n' "$C_BOLD" "$C_RESET" "$trash_patched"

    # Aurorae
    local current_aurorae
    current_aurorae="$(kreadconfig6 --file kwinrc --group org.kde.kdecoration2 --key theme 2>/dev/null | tr -d '[:space:]')"
    local aurorae_indicator="$E_CROSS"
    [[ "$current_aurorae" == *"Fluent"* || "$current_aurorae" == *"fluent"* ]] && aurorae_indicator="$E_CHECK"
    printf '  %bDecoração Aurorae:%b       %s  %s\n' "$C_BOLD" "$C_RESET" "${current_aurorae:-não definido}" "$aurorae_indicator"

    # Aurorae themes disponíveis
    local _aur_found_list=""
    for _aur_s in "$HOME/.local/share/aurorae/themes" "/usr/share/aurorae/themes"; do
        [[ -d "$_aur_s" ]] || continue
        for _aur_d in "$_aur_s"/Fluent*; do
            [[ -d "$_aur_d" ]] || continue
            _aur_found_list="${_aur_found_list}$(basename "$_aur_d") (${_aur_s##*/}), "
        done
    done
    if [[ -n "$_aur_found_list" ]]; then
        _aur_found_list="${_aur_found_list%, }"
        printf '  %bAurorae disponíveis:%b     %s\n' "$C_BOLD" "$C_RESET" "$_aur_found_list"
    fi

    # Wallpaper
    local current_wp
    current_wp="$(kreadconfig6 --file plasmarc --group PlasmaViews --group2 Desktop --group3 Background --key Image 2>/dev/null | tr -d '[:space:]')"
    local wp_indicator="$E_CROSS"
    [[ "$current_wp" == *"big-retro"* ]] && wp_indicator="$E_CHECK"
    printf '  %bWallpaper:%b              %s  %s\n' "$C_BOLD" "$C_RESET" "$( [[ -n "$current_wp" ]] && echo "$(basename "${current_wp#file://}" 2>/dev/null)" || echo "não definido" )" "$wp_indicator"

    # Backup
    printf '\n'
    if [[ -d "$BACKUP_BASE" ]]; then
        local backup_count
        backup_count="$(ls -1d "$BACKUP_BASE"/*/ 2>/dev/null | wc -l)"
        printf '  %bBackups existentes:%b      %d\n' "$C_BOLD" "$C_RESET" "$backup_count"
        local latest_backup
        latest_backup="$(ls -1d "$BACKUP_BASE"/*/ 2>/dev/null | sort -r | head -1)"
        if [[ -n "$latest_backup" ]]; then
            printf '  %bÚltimo backup:%b         %s\n' "$C_BOLD" "$C_RESET" "$(basename "${latest_backup%/}")"
        fi
    else
        printf '  %bBackups existentes:%b      nenhum\n' "$C_BOLD" "$C_RESET"
    fi

    printf '\n'
}

# ============================================================================
#  MODO INTERATIVO
# ============================================================================

# Pergunta ao usuário se quer modo dark ou light
ask_theme_mode() {
    printf '\n'
    printf '  %bSelecione o modo de cor:%b\n\n' "$C_BOLD" "$C_RESET"
    printf '    %b[1]%b  %s  Dark (Escuro)\n' "$C_CYAN" "$C_RESET" "$E_MOON"
    printf '    %b[2]%b  %s  Light (Claro)\n\n' "$C_CYAN" "$C_RESET" "$E_SUN"

    local choice
    while true; do
        prompt "Sua escolha" "1"
        case "$REPLY" in
            1) THEME_MODE="dark";  break ;;
            2) THEME_MODE="light"; break ;;
            *) log_warn "Opção inválida. Digite 1 ou 2." ;;
        esac
    done
    printf '\n'
    log_info "Modo selecionado: ${C_BOLD}$THEME_MODE${C_RESET}"
}

# Menu de seleção de componentes
ask_components() {
    local sel_kde=true sel_gtk=true sel_icons=true sel_kvantum=true

    printf '\n'
    printf '  %bSelecione os componentes:%b\n\n' "$C_BOLD" "$C_RESET"
    printf '    %b[1]%b  Tema KDE Plasma              %b[ON]%b\n' "$C_CYAN" "$C_RESET" "$C_GREEN" "$C_RESET"
    printf '    %b[2]%b  Tema GTK (libadwaita)        %b[ON]%b\n' "$C_CYAN" "$C_RESET" "$C_GREEN" "$C_RESET"
    printf '    %b[3]%b  Ícones Fluent + Patch Big    %b[ON]%b\n' "$C_CYAN" "$C_RESET" "$C_GREEN" "$C_RESET"
    printf '    %b[4]%b  Estilo Kvantum               %b[ON]%b\n' "$C_CYAN" "$C_RESET" "$C_GREEN" "$C_RESET"
    printf '    %b[5]%b  Decoração Aurorae            %b[ON]%b\n' "$C_CYAN" "$C_RESET" "$C_GREEN" "$C_RESET"
    printf '    %b[6]%b  Wallpaper big-retro          %b[ON]%b\n\n' "$C_CYAN" "$C_RESET" "$C_GREEN" "$C_RESET"
    printf '    %b[F]%b  ── Tudo (Full) ──\n\n' "$C_YELLOW" "$C_RESET"
    printf '    %b[0]%b  Cancelar\n\n' "$C_RED" "$C_RESET"

    prompt "Sua escolha"

    case "$REPLY" in
        0) log_info "Operação cancelada."; exit 0 ;;
        1) APPLY_KDE=true ;;
        2) APPLY_GTK=true ;;
        3) APPLY_ICONS=true ;;
        4) APPLY_KVANTUM=true ;;
        5) APPLY_AURORAE=true ;;
        6) APPLY_WALLPAPER=true ;;
        [Ff])
            APPLY_KDE=true
            APPLY_GTK=true
            APPLY_ICONS=true
            APPLY_KVANTUM=true
            APPLY_AURORAE=true
            APPLY_WALLPAPER=true
            ;;
        *)
            log_warn "Opção inválida. Usando padrão (tudo)."
            APPLY_KDE=true
            APPLY_GTK=true
            APPLY_ICONS=true
            APPLY_KVANTUM=true
            APPLY_AURORAE=true
            APPLY_WALLPAPER=true
            ;;
    esac
}

# Menu interativo principal
interactive_menu() {
    show_banner
    printf '  %bBem-vindo ao bigretro!%b\n' "$C_BOLD" "$C_RESET"
    printf '  Este assistente restaurará o tema Fluent do BigLinux.\n\n'

    # Verificar dependências
    check_dependencies || exit 1

    printf '\n'
    if ! confirm "Deseja prosseguir com a instalação?"; then
        printf '\n  Operação cancelada pelo usuário.\n\n'
        exit 0
    fi

    # Perguntar modo de cor
    ask_theme_mode

    # Perguntar componentes
    ask_components

    # Confirmar patch de bigicons
    if [[ "$APPLY_ICONS" == true && -d "$BIGICONS_SOURCE" ]]; then
        APPLY_PATCH=true
        if ! confirm "Aplicar patch de ícones BigLinux (bigicons-papient)?"; then
            APPLY_PATCH=false
        fi
    fi

    # Resumo
    printf '\n'
    printf '  %bResumo da instalação:%b\n' "$C_BOLD" "$C_RESET"
    printf '  ─────────────────────────────────────\n'
    printf '  Modo de cor:     %s\n' "$( [[ "$THEME_MODE" == "dark" ]] && echo "$E_MOON Dark" || echo "$E_SUN Light" )"
    printf '  Tema KDE:        %s\n' "$( [[ "$APPLY_KDE" == true ]] && echo "$E_CHECK Sim" || echo "$E_CROSS Não" )"
    printf '  Tema GTK:        %s\n' "$( [[ "$APPLY_GTK" == true ]] && echo "$E_CHECK Sim" || echo "$E_CROSS Não" )"
    printf '  Ícones Fluent:   %s\n' "$( [[ "$APPLY_ICONS" == true ]] && echo "$E_CHECK Sim" || echo "$E_CROSS Não" )"
    printf '  Patch BigIcons:  %s\n' "$( [[ "$APPLY_PATCH" == true ]] && echo "$E_CHECK Sim" || echo "$E_CROSS Não" )"
    printf '  Estilo Kvantum:  %s\n' "$( [[ "$APPLY_KVANTUM" == true ]] && echo "$E_CHECK Sim" || echo "$E_CROSS Não" )"
    printf '  Decoração Aurorae: %s\n' "$( [[ "$APPLY_AURORAE" == true ]] && echo "$E_CHECK Sim" || echo "$E_CROSS Não" )"
    printf '  Wallpaper big-retro: %s\n' "$( [[ "$APPLY_WALLPAPER" == true ]] && echo "$E_CHECK Sim" || echo "$E_CROSS Não" )"
    printf '  ─────────────────────────────────────\n\n'

    if ! confirm "Confirmar instalação?"; then
        printf '\n  Operação cancelada pelo usuário.\n\n'
        exit 0
    fi

    # Executar instalação
    run_installation
}

# ============================================================================
#  EXECUÇÃO DA INSTALAÇÃO
# ============================================================================

run_installation() {
    printf '\n'
    log_arrow "${C_BOLD}Iniciando instalação do bigretro...${C_RESET}"
    printf '\n'

    ensure_work_dir
    mkdir -p "$WORK_DIR"

    # 1. Criar backup
    create_backup

    # 2. Instalar componentes selecionados
    local install_errors=0

    if [[ "$APPLY_KDE" == true ]]; then
        printf '\n'
        if ! install_kde_theme; then
            ((install_errors++)) || true
        fi
    fi

    if [[ "$APPLY_GTK" == true ]]; then
        printf '\n'
        if ! install_gtk_theme; then
            ((install_errors++)) || true
        fi
    fi

    if [[ "$APPLY_ICONS" == true ]]; then
        printf '\n'
        if ! install_icon_theme; then
            ((install_errors++)) || true
        fi

        # Aplicar patch bigicons
        if [[ "$APPLY_PATCH" == true ]]; then
            printf '\n'
            patch_bigicons || true
        fi

        # Aplicar patch ícone lixeira colorido
        printf '\n'
        patch_trash_icons || true
    fi

    # 3. Detectar temas instalados
    printf '\n'
    detect_installed_themes

    # 4. Aplicar configurações
    if [[ "$APPLY_KDE" == true ]]; then
        printf '\n'
        apply_kde_theme || ((install_errors++)) || true
    fi

    if [[ "$APPLY_ICONS" == true ]]; then
        printf '\n'
        apply_icon_theme || ((install_errors++)) || true
    fi

    if [[ "$APPLY_GTK" == true ]]; then
        printf '\n'
        apply_gtk_theme || ((install_errors++)) || true
    fi

    if [[ "$APPLY_KVANTUM" == true ]]; then
        printf '\n'
        apply_kvantum_theme || true
    fi

    if [[ "$APPLY_AURORAE" == true ]]; then
        printf '\n'
        apply_aurorae_theme || true
    fi

    if [[ "$APPLY_WALLPAPER" == true ]]; then
        printf '\n'
        apply_wallpaper || true
    fi

    # 5. Recarregar Plasma
    if is_plasma; then
        printf '\n'
        reload_plasma
    fi

    # 6. Resultado final
    printf '\n'
    printf '  %b═══════════════════════════════════════════════%b\n' "$C_CYAN" "$C_RESET"
    if [[ "$install_errors" -eq 0 ]]; then
        printf '  %b  Instalação concluída com sucesso!%b\n' "$C_GREEN" "$C_RESET"
    else
        printf '  %b  Instalação concluída com %d erro(s).%b\n' "$C_YELLOW" "$install_errors" "$C_RESET"
    fi
    printf '  %b═══════════════════════════════════════════════%b\n' "$C_CYAN" "$C_RESET"
    printf '\n'
    log_info "Para desfazer, execute:  $SCRIPT_NAME --uninstall"
    log_info "Para verificar:          $SCRIPT_NAME --status"
    log_info "Para reinstalar:         $SCRIPT_NAME --full --$THEME_MODE"
    printf '\n'

    if [[ "$install_errors" -gt 0 ]]; then
        log_warn "Revise os logs em: $WORK_DIR/"
    fi

    # 7. Aviso final (tudo ja foi aplicado ao vivo)
    printf '\n'
    log_info "Todas as mudancas foram aplicadas ao vivo."
    log_info "Se algo nao apareceu corretamente, pressione Ctrl+Alt+Esc"
    log_info "para reiniciar apenas o PlasmaShell, ou feche a sessao e abra novamente."
    printf '\n'
}

# ============================================================================
#  PARSE DE ARGUMENTOS
# ============================================================================

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --full)
                FULL_MODE=true
                APPLY_KDE=true
                APPLY_GTK=true
                APPLY_ICONS=true
                APPLY_KVANTUM=true
                APPLY_AURORAE=true
                APPLY_WALLPAPER=true
                shift
                ;;
            --kde)
                APPLY_KDE=true
                shift
                ;;
            --gtk)
                APPLY_GTK=true
                shift
                ;;
            --icons)
                APPLY_ICONS=true
                shift
                ;;
            --kvantum)
                APPLY_KVANTUM=true
                shift
                ;;
            --aurorae)
                APPLY_AURORAE=true
                shift
                ;;
            --wallpaper)
                APPLY_WALLPAPER=true
                shift
                ;;
            --dark)
                THEME_MODE="dark"
                shift
                ;;
            --light)
                THEME_MODE="light"
                shift
                ;;
            --no-patch)
                APPLY_PATCH=false
                shift
                ;;
            --uninstall)
                UNINSTALL_MODE=true
                shift
                ;;
            --purge)
                PURGE_MODE=true
                shift
                ;;
            --status)
                STATUS_MODE=true
                shift
                ;;
            -y|--yes)
                SKIP_CONFIRM=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                show_version
                exit 0
                ;;
            *)
                log_error "Opção desconhecida: $1"
                log_info "Use --help para ver as opções disponíveis."
                exit 1
                ;;
        esac
    done
}

# ============================================================================
#  VALIDAÇÃO
# ============================================================================

validate_args() {
    # Se está em modo de desinstalação, não precisa validar mais nada
    if [[ "$UNINSTALL_MODE" == true ]]; then
        return 0
    fi

    # Se está em modo de status, não precisa validar mais nada
    if [[ "$STATUS_MODE" == true ]]; then
        return 0
    fi

    # Se não há nenhum componente selecionado e não é modo interativo,
    # mostrar erro
    if [[ "$APPLY_KDE" == false && "$APPLY_GTK" == false && \
          "$APPLY_ICONS" == false && "$APPLY_KVANTUM" == false && \
          "$APPLY_AURORAE" == false && "$APPLY_WALLPAPER" == false && \
          "$FULL_MODE" == false ]]; then
        return 1  # Entrará no modo interativo
    fi

    # Se há componentes selecionados mas não há modo de cor definido
    if [[ -z "$THEME_MODE" ]]; then
        log_error "Especifique --dark ou --light junto com os componentes."
        log_info "Exemplo: $SCRIPT_NAME --full --dark"
        log_info "Ou execute sem argumentos para o modo interativo."
        exit 1
    fi

    return 0
}

# ============================================================================
#  PONTO DE ENTRADA PRINCIPAL
# ============================================================================

main() {
    parse_args "$@"

    # Ações especiais (não precisam de modo interativo)
    if [[ "$STATUS_MODE" == true ]]; then
        show_status
        exit 0
    fi

    if [[ "$UNINSTALL_MODE" == true ]]; then
        uninstall_theme
        exit 0
    fi

    # Se não há argumentos, ou os argumentos são incompletos, ir para interativo
    if validate_args; then
        # Modo não-interativo (CLI)
        show_banner
        printf '  %bModo automático (CLI)%b\n\n' "$C_BOLD" "$C_RESET"
        check_dependencies || exit 1
        run_installation
    else
        # Modo interativo (menu guiado)
        interactive_menu
    fi
}

main "$@"
