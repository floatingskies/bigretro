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

readonly VERSION="1.0.0"
readonly SCRIPT_NAME="$(basename "$0")"
readonly BACKUP_BASE="${XDG_DATA_HOME:-$HOME/.local/share}/bigretro-backup"
readonly TEMP_BASE="/tmp/bigretro-$(id -u)"
readonly BIGICONS_SOURCE="/usr/share/icons/bigicons-papient"

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
    --icons              Instala ícones Fluent + patch bigicons
    --kvantum            Aplica estilo de widget Kvantum

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

    # Determinar variante de cor
    local color_answer="default"
    if [[ "$THEME_MODE" == "dark" ]]; then
        color_answer="dark"
    fi

    # Executar install.sh -l (libadwaita)
    # Fluxo: 1) destino (Enter) 2) variante de cor (default/dark/light)
    log_step "Executando install.sh -l do Fluent-gtk (color=$color_answer)..."
    if printf '\n%s\n' "$color_answer" | bash ./install.sh -l &>> "$WORK_DIR/install_gtk.log"; then
        log_success "Fluent GTK Theme (libadwaita) instalado."
    else
        log_error "Falha na instalação do Fluent GTK Theme."
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
#  DETECÇÃO DE TEMAS INSTALADOS
# ============================================================================

detect_installed_themes() {
    log_step "Detectando temas Fluent instalados..."

    local home_share="$HOME/.local/share"
    local config_kvantum="$HOME/.config/Kvantum"

    # --- Detectar Esquema de Cores KDE ---
    DETECTED_COLOR_SCHEME=""
    if [[ -d "$home_share/color-schemes" ]]; then
        for cs_file in "$home_share/color-schemes"/Fluent*.colors; do
            [[ -f "$cs_file" ]] || continue
            local cs_name
            cs_name="$(basename "$cs_file" .colors)"
            # Extrair nome de dentro do arquivo (campo Name=)
            local file_name
            file_name="$(grep -oP '^Name=\K.*' "$cs_file" 2>/dev/null | head -1)"
            file_name="${file_name:-$cs_name}"

            if [[ "$THEME_MODE" == "dark" ]]; then
                if [[ "$file_name" == *"Dark"* || "$cs_name" == *"Dark"* ]]; then
                    DETECTED_COLOR_SCHEME="$file_name"
                    break
                fi
            else
                if [[ "$file_name" != *"Dark"* && "$cs_name" != *"Dark"* ]]; then
                    DETECTED_COLOR_SCHEME="$file_name"
                    break
                fi
            fi
        done
    fi
    # Fallback: se não encontrou pelo modo, pegar qualquer Fluent
    if [[ -z "$DETECTED_COLOR_SCHEME" && -d "$home_share/color-schemes" ]]; then
        for cs_file in "$home_share/color-schemes"/Fluent*.colors; do
            [[ -f "$cs_file" ]] || continue
            DETECTED_COLOR_SCHEME="$(grep -oP '^Name=\K.*' "$cs_file" 2>/dev/null | head -1)"
            DETECTED_COLOR_SCHEME="${DETECTED_COLOR_SCHEME:-$(basename "$cs_file" .colors)}"
            break
        done
    fi

    # --- Detectar Tema de Ícones ---
    DETECTED_ICON_THEME=""
    if [[ -d "$home_share/icons" ]]; then
        for icon_dir in "$home_share/icons"/Fluent*; do
            [[ -d "$icon_dir" ]] || continue
            local icon_name
            icon_name="$(basename "$icon_dir")"

            if [[ "$THEME_MODE" == "dark" ]]; then
                if [[ "$icon_name" == *"dark"* || "$icon_name" == *"Dark"* ]]; then
                    DETECTED_ICON_THEME="$icon_name"
                    break
                fi
            else
                if [[ "$icon_name" != *"dark"* && "$icon_name" != *"Dark"* ]]; then
                    DETECTED_ICON_THEME="$icon_name"
                    break
                fi
            fi
        done
    fi
    if [[ -z "$DETECTED_ICON_THEME" && -d "$home_share/icons" ]]; then
        for icon_dir in "$home_share/icons"/Fluent*; do
            [[ -d "$icon_dir" ]] || continue
            DETECTED_ICON_THEME="$(basename "$icon_dir")"
            break
        done
    fi

    # --- Detectar Tema Kvantum ---
    DETECTED_KVANTUM_THEME=""
    if [[ -d "$config_kvantum" ]]; then
        for kv_dir in "$config_kvantum"/*/; do
            [[ -d "$kv_dir" ]] || continue
            local kv_name
            kv_name="$(basename "$kv_dir")"

            # Verificar se é um tema válido (tem arquivo .kvconfig dentro)
            if [[ ! -f "$kv_dir"/*.kvconfig && ! -f "$kv_dir"/*.svg ]]; then
                continue
            fi

            if [[ "$THEME_MODE" == "dark" ]]; then
                if [[ "$kv_name" == *"Dark"* || "$kv_name" == *"dark"* ]]; then
                    DETECTED_KVANTUM_THEME="$kv_name"
                    break
                fi
            else
                if [[ "$kv_name" != *"Dark"* && "$kv_name" != *"dark"* ]]; then
                    DETECTED_KVANTUM_THEME="$kv_name"
                    break
                fi
            fi
        done
    fi
    if [[ -z "$DETECTED_KVANTUM_THEME" && -d "$config_kvantum" ]]; then
        for kv_dir in "$config_kvantum"/*/; do
            [[ -d "$kv_dir" ]] || continue
            local kv_base
            kv_base="$(basename "$kv_dir")"
            if [[ "$kv_base" == "Fluent"* ]]; then
                DETECTED_KVANTUM_THEME="$kv_base"
                break
            fi
        done
    fi

    # --- Detectar Tema GTK ---
    DETECTED_GTK_THEME=""
    if [[ -d "$home_share/themes" ]]; then
        for gtk_dir in "$home_share/themes"/Fluent*; do
            [[ -d "$gtk_dir" ]] || continue
            local gtk_name
            gtk_name="$(basename "$gtk_dir")"

            # Verificar se é um tema GTK válido
            if [[ ! -d "$gtk_dir/gtk-3.0" && ! -d "$gtk_dir/gtk-4.0" ]]; then
                continue
            fi

            if [[ "$THEME_MODE" == "dark" ]]; then
                if [[ "$gtk_name" == *"Dark"* || "$gtk_name" == *"dark"* ]]; then
                    DETECTED_GTK_THEME="$gtk_name"
                    break
                fi
            else
                if [[ "$gtk_name" != *"Dark"* && "$gtk_name" != *"dark"* ]]; then
                    DETECTED_GTK_THEME="$gtk_name"
                    break
                fi
            fi
        done
    fi
    if [[ -z "$DETECTED_GTK_THEME" && -d "$home_share/themes" ]]; then
        for gtk_dir in "$home_share/themes"/Fluent*; do
            [[ -d "$gtk_dir" ]] || continue
            if [[ -d "$gtk_dir/gtk-3.0" || -d "$gtk_dir/gtk-4.0" ]]; then
                DETECTED_GTK_THEME="$(basename "$gtk_dir")"
                break
            fi
        done
    fi

    # Log dos resultados
    log_info "  Esquema de cores:  ${DETECTED_COLOR_SCHEME:-${C_RED}não detectado${C_RESET}}"
    log_info "  Tema de ícones:    ${DETECTED_ICON_THEME:-${C_RED}não detectado${C_RESET}}"
    log_info "  Tema Kvantum:      ${DETECTED_KVANTUM_THEME:-${C_RED}não detectado${C_RESET}}"
    log_info "  Tema GTK:          ${DETECTED_GTK_THEME:-${C_RED}não detectado${C_RESET}}"
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

    kwriteconfig6 --file kdeglobals --group General --key ColorScheme "$DETECTED_COLOR_SCHEME"
    log_success "Esquema de cores KDE definido: $DETECTED_COLOR_SCHEME"
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
        return 1
    fi

    local icon_theme="${DETECTED_ICON_THEME:-$DETECTED_GTK_THEME}"
    local gtk_dark=0
    if [[ "$THEME_MODE" == "dark" ]]; then
        gtk_dark=1
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

    # --- xsettingsd (usado por alguns ambientes) ---
    if has_cmd xsettingsd; then
        mkdir -p "$HOME/.config/xsettingsd"
        cat > "$HOME/.config/xsettingsd/xsettingsd.conf" <<EOF
Net/ThemeName "${DETECTED_GTK_THEME}"
Net/IconThemeName "${icon_theme}"
EOF
        log_info "xsettingsd configurado."
    fi
}

apply_kvantum_theme() {
    log_arrow "Aplicando estilo Kvantum..."

    if ! has_cmd kvantummanager; then
        log_warn "kvantummanager não encontrado. Pulando configuração de Kvantum."
        log_info "Instale o Kvantum com o gerenciador de pacotes da sua distribuição."
        return 0
    fi

    if [[ -z "$DETECTED_KVANTUM_THEME" ]]; then
        log_warn "Nenhum tema Kvantum Fluent detectado."
        log_info "O tema KDE ou GTK pode ter instalado um tema Kvantum separadamente."
        return 0
    fi

    # Definir tema Kvantum ativo
    kwriteconfig6 --file kdeglobals --group General --key widgetStyle "kvantum"
    log_info "Estilo de widget definido: Kvantum"

    # Configurar o tema Kvantum específico
    kvantummanager --set "$DETECTED_KVANTUM_THEME" 2>/dev/null || {
        # Fallback: escrever diretamente no kvantum.kvconfig
        mkdir -p "$HOME/.config/Kvantum"
        cat > "$HOME/.config/Kvantum/kvantum.kvconfig" <<EOF
[General]
theme=${DETECTED_KVANTUM_THEME}
EOF
    }
    log_success "Tema Kvantum aplicado: $DETECTED_KVANTUM_THEME"
}

# ============================================================================
#  RECARREGAMENTO DO PLASMA
# ============================================================================

reload_plasma() {
    log_arrow "Recarregando KDE Plasma para aplicar mudanças..."

    # Método 1: Usar qdbus6 (Plasma 6) ou qdbus (Plasma 5)
    if has_cmd qdbus6; then
        qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.refreshCurrentShell 2>/dev/null && {
            log_success "Plasma recarregado via qdbus6."
            return 0
        }
    fi

    if has_cmd qdbus; then
        qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.refreshCurrentShell 2>/dev/null && {
            log_success "Plasma recarregado via qdbus."
            return 0
        }
    fi

    # Método 2: Recarregar via dbus-send
    if has_cmd dbus-send; then
        dbus-send --session --dest=org.kde.plasmashell --type=method_call \
            /PlasmaShell org.kde.PlasmaShell.refreshCurrentShell 2>/dev/null && {
            log_success "Plasma recarregado via dbus-send."
            return 0
        }
    fi

    # Método 3: Reiniciar plasmashell via systemctl
    log_warn "Não foi possível recarregar via D-Bus. Tentando reiniciar plasmashell..."
    log_warn "Isso pode causar um breve flicker na tela."

    if systemctl --user restart plasma-plasmashell.service 2>/dev/null; then
        log_success "Plasma reiniciado via systemd."
        return 0
    fi

    log_warn "Não foi possível recarregar o Plasma automaticamente."
    log_info "Faça logout e login, ou reinicie a sessão do Plasma manualmente."
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

        # Temas GTK
        rm -rf "$HOME/.local/share/themes"/Fluent* 2>/dev/null
        log_info "Temas GTK Fluent removidos."

        # Temas de ícones
        rm -rf "$HOME/.local/share/icons"/Fluent* 2>/dev/null
        log_info "Temas de ícones Fluent removidos."

        # Look-and-Feel Plasma
        rm -rf "$HOME/.local/share/plasma/look-and-feel"/*Fluent* 2>/dev/null
        rm -rf "$HOME/.local/share/plasma/look-and-feel"/*fluent* 2>/dev/null
        log_info "Look-and-Feel Fluent removidos."

        # Temas Aurorae
        rm -rf "$HOME/.local/share/aurorae/themes"/Fluent* 2>/dev/null
        log_info "Temas Aurorae Fluent removidos."

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

    # GTK3
    printf '\n'
    if [[ -f "$HOME/.config/gtk-3.0/settings.ini" ]]; then
        local gtk3_theme gtk3_icons
        gtk3_theme="$(grep -oP 'gtk-theme-name=\K.*' "$HOME/.config/gtk-3.0/settings.ini" 2>/dev/null)"
        gtk3_icons="$(grep -oP 'gtk-icon-theme-name=\K.*' "$HOME/.config/gtk-3.0/settings.ini" 2>/dev/null)"
        local gtk3_indicator="$E_CROSS"
        [[ "$gtk3_theme" == *"Fluent"* ]] && gtk3_indicator="$E_CHECK"
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
        [[ "$gtk4_theme" == *"Fluent"* ]] && gtk4_indicator="$E_CHECK"
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
    printf '    %b[4]%b  Estilo Kvantum               %b[ON]%b\n\n' "$C_CYAN" "$C_RESET" "$C_GREEN" "$C_RESET"
    printf '    %b[5]%b  ── Tudo (Full) ──\n\n' "$C_YELLOW" "$C_RESET"
    printf '    %b[0]%b  Cancelar\n\n' "$C_RED" "$C_RESET"

    prompt "Sua escolha"

    case "$REPLY" in
        0) log_info "Operação cancelada."; exit 0 ;;
        1) APPLY_KDE=true ;;
        2) APPLY_GTK=true ;;
        3) APPLY_ICONS=true ;;
        4) APPLY_KVANTUM=true ;;
        5)
            APPLY_KDE=true
            APPLY_GTK=true
            APPLY_ICONS=true
            APPLY_KVANTUM=true
            ;;
        *)
            log_warn "Opção inválida. Usando padrão (tudo)."
            APPLY_KDE=true
            APPLY_GTK=true
            APPLY_ICONS=true
            APPLY_KVANTUM=true
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
