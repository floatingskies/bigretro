# bigretro — Restaurador do Tema Fluent do BigLinux

> **Restaura a experiência clássica do tema Fluent do BigLinux no KDE Plasma 6+**

O `bigretro` é um script Bash CLI que instala e configura automaticamente o pacote completo do **Fluent Theme** (por vinceliuice) no seu sistema, replicando a aparência original do BigLinux. Ele cuida de tudo: tema KDE, tema GTK/libadwaita, ícones, patch de ícones BigLinux e estilo Kvantum — tudo com backup completo e opção de desinstalação total.

---

## Índice

- [Requisitos](#requisitos)
- [Download](#download)
- [Uso Rápido](#uso-rápido)
- [Modo Interativo](#modo-interativo)
- [Modo CLI (Linhas de Comando)](#modo-cli-linhas-de-comando)
- [Componentes Instalados](#componentes-instalados)
- [Patch de Ícones BigLinux](#patch-de-ícones-biglinux)
- [Sistema de Backup](#sistema-de-backup)
- [Como Desinstalar / Reverter](#como-desinstalar--reverter)
- [Status do Tema](#status-do-tema)
- [Solução de Problemas](#solução-de-problemas)
- [Estrutura dos Arquivos](#estrutura-dos-arquivos)

---

## Requisitos

| Item | Descrição |
|---|---|
| **Sistema** | KDE Plasma 6+ (recomendado) |
| **Shell** | Bash 4+ |
| **Obrigatórios** | `git`, `curl`, `kwriteconfig6`, `kreadconfig6` |
| **Opcionais** | `kvantummanager` (para estilo Kvantum), `gtk-update-icon-cache` (cache de ícones) |

Verifique se o pacote de ícones do BigLinux está instalado:
```bash
ls /usr/share/icons/bigicons-papient
```

Se o diretório não existir, o patch de ícones BigLinux será pulado automaticamente (o resto continua funcionando).

---

## Download

Baixe os dois arquivos e dê permissão de execução:

```bash
chmod +x bigretro.sh bigretro-uninstall.sh
```

Os scripts podem ficar em qualquer diretório. Recomendação:

```bash
# Opção 1: Diretório atual
./bigretro.sh --full --dark

# Opção 2: Mover para ~/.local/bin (para acessar de qualquer lugar)
mkdir -p ~/.local/bin
mv bigretro.sh bigretro-uninstall.sh ~/.local/bin/
bigretro --full --dark
```

---

## Uso Rápido

Se você quer apenas instalar tudo de uma vez sem pensar muito:

```bash
# Instalar tudo em modo escuro (recomendado, igual ao BigLinux clássico)
./bigretro.sh --full --dark

# Instalar tudo em modo claro
./bigretro.sh --full --light

# Instalar tudo sem perguntar nada (totalmente automático)
./bigretro.sh --full --dark -y
```

Pronto. O tema será instalado, configurado e o Plasma será recarregado automaticamente.

---

## Modo Interativo

Executar o script sem argumentos abre o **menu interativo guiado**, ideal para quem prefere escolher passo a passo:

```bash
./bigretro.sh
```

O fluxo interativo faz o seguinte:

1. **Verifica dependências** — confere se `git`, `curl`, `kwriteconfig6` e `kreadconfig6` estão disponíveis.
2. **Confirmação inicial** — pergunta se você deseja prosseguir.
3. **Escolha do modo de cor** — Dark (escuro) ou Light (claro).
4. **Seleção de componentes** — você escolhe o que instalar:
   - `[1]` Tema KDE Plasma
   - `[2]` Tema GTK (libadwaita)
   - `[3]` Ícones Fluent + Patch BigLinux
   - `[4]` Estilo Kvantum
   - `[5]` Tudo (Full)
5. **Patch de bigicons** — pergunta se deseja aplicar o patch de ícones do BigLinux.
6. **Resumo** — mostra tudo que será feito e pede confirmação final.
7. **Execução** — instala, aplica configurações e recarrega o Plasma.

---

## Modo CLI (Linhas de Comando)

Para automação, scripts ou quando você já sabe o que quer, use as flags diretamente:

### Instalação completa

```bash
./bigretro.sh --full --dark          # Tudo em modo escuro
./bigretro.sh --full --light         # Tudo em modo claro
./bigretro.sh --full --dark -y       # Tudo, sem confirmações
```

### Componentes individuais

```bash
# Apenas o tema KDE Plasma
./bigretro.sh --kde --dark

# Apenas o tema GTK (libadwaita)
./bigretro.sh --gtk --dark

# Apenas os ícones
./bigretro.sh --icons --dark

# Apenas o estilo Kvantum (requer ícones ou tema KDE instalado antes)
./bigretro.sh --kvantum --dark

# Combinações livres
./bigretro.sh --kde --gtk --icons --dark
./bigretro.sh --kde --gtk --kvantum --light
```

### Comportamento

```bash
# Pular o patch de ícones BigLinux
./bigretro.sh --full --dark --no-patch

# Ver o estado atual do tema
./bigretro.sh --status

# Ajuda completa
./bigretro.sh --help

# Versão
./bigretro.sh --version
```

### Referência rápida de flags

| Flag | Descrição |
|---|---|
| `--full` | Instala e aplica todos os componentes |
| `--kde` | Instala e aplica o tema KDE Plasma |
| `--gtk` | Instala e aplica o tema GTK (libadwaita) |
| `--icons` | Instala ícones Fluent + patch bigicons |
| `--kvantum` | Aplica estilo de widget Kvantum |
| `--dark` | Usa variante escura |
| `--light` | Usa variante clara |
| `--no-patch` | Pula o patch de ícones bigicons-papient |
| `-y`, `--yes` | Pula todas as confirmações |
| `--uninstall` | Desinstala e restaura configurações originais |
| `--purge` | Desinstala + remove todos os arquivos de tema |
| `--status` | Mostra o estado atual do tema |
| `-h`, `--help` | Mostra ajuda |
| `-v`, `--version` | Mostra versão |

> **Importante:** Ao usar componentes individuais via CLI, é obrigatório especificar `--dark` ou `--light`. Sem esses flags, o script exibirá uma mensagem de erro com instruções.

---

## Componentes Instalados

O `bigretro` instala os seguintes componentes a partir dos repositórios oficiais do vinceliuice no GitHub:

### 1. Fluent-kde (Tema KDE Plasma)

- **Repositório:** [vinceliuice/Fluent-kde](https://github.com/vinceliuice/Fluent-kde)
- **Instalador:** `./install.sh` (padrão do repositório)
- **O que instala:** Esquemas de cores, tema de decoração Aurorae, look-and-feel completo do Plasma
- **Destino:** `~/.local/share/` (color-schemes, aurorae, plasma, wallpapers)

### 2. Fluent-gtk-theme (Tema GTK + libadwaita)

- **Repositório:** [vinceliuice/Fluent-gtk-theme](https://github.com/vinceliuice/Fluent-gtk-theme)
- **Instalador:** `./install.sh -l` (flag `-l` para libadwaita)
- **O que instala:** Temas GTK3 e GTK4 com suporte a libadwaita
- **Destino:** `~/.local/share/themes/Fluent*`

### 3. Fluent-icon-theme (Ícones Fluent)

- **Repositório:** [vinceliuice/Fluent-icon-theme](https://github.com/vinceliuice/Fluent-icon-theme)
- **Também disponível na:** [KDE Store](https://store.kde.org/p/1651982/)
- **Instalador:** `./install.sh` (padrão do repositório)
- **O que instala:** Conjunto completo de ícones Fluent em variantes dark/light
- **Destino:** `~/.local/share/icons/Fluent*`

### 4. Estilo Kvantum

- Instalado automaticamente junto com o Fluent-kde
- O `bigretro` configura o Kvantum como estilo de widget padrão e seleciona o tema `Fluent` ou `FluentDark`
- **Requer:** `kvantummanager` instalado no sistema

---

## Patch de Ícones BigLinux

O BigLinux inclui um pacote de ícones personalizado chamado **bigicons-papient**, instalado em `/usr/share/icons/bigicons-papient`. Este pacote contém ícones exclusivos do BigLinux cujos nomes começam com `big`.

O `bigretro` aplica um **patch** que copia **todos esses ícones** para dentro dos diretórios do tema Fluent, complementando os ícones padrão com os ícones exclusivos do BigLinux.

### O que é copiado

O glob `big*` captura **todos os arquivos** cujo nome começa com `big`, incluindo:

- `big-*` (ex: `big-linux.svg`, `big-control-center.svg`)
- `big_*` (ex: `big_linux_logo.png`)
- `biglinux*` (ex: `biglinux-start.svg`)
- `bigdesktop*` (ex: `bigdesktop-settings.png`)
- Qualquer outro arquivo que comece com `big`

Arquivos como `index.theme` são **ignorados** para não sobrescrever a configuração original do tema Fluent.

### Origem e destino

| Origem | Destino |
|---|---|
| `/usr/share/icons/bigicons-papient/big*` | `~/.local/share/icons/Fluent-*/` |
| `/usr/share/icons/bigicons-papient/big*` | `~/.local/share/icons/Fluent-dark-*/` |
| `/usr/share/icons/bigicons-papient/big*` | `~/.local/share/icons/Fluent-Dark-*/` |

A estrutura de diretórios é **preservada** durante a cópia.

### Desativar o patch

Se você não quiser aplicar o patch de ícones BigLinux:

```bash
# Modo CLI
./bigretro.sh --full --dark --no-patch

# Modo interativo: responda "N" quando perguntar sobre o patch
```

---

## Sistema de Backup

Antes de **qualquer** alteração nas configurações do sistema, o `bigretro` cria um backup completo em:

```
~/.local/share/bigretro-backup/<timestamp>/
```

### O que é salvo no backup

| Arquivo | Descrição |
|---|---|
| `kde_color_scheme` | Esquema de cores KDE atual |
| `kde_icon_theme` | Tema de ícones KDE atual |
| `kde_widget_style` | Estilo de widget atual (ex: Breeze) |
| `kdeglobals` | Cópia completa do arquivo kdeglobals |
| `gtk3_settings.ini` | Configuração GTK3 |
| `gtk4_settings.ini` | Configuração GTK4/libadwaita |
| `gtkrc-2.0` | Configuração GTK2 (se existir) |
| `kvantum.kvconfig` | Configuração do Kvantum |
| `gtk-theme.sh` | Variável de ambiente GTK do Plasma |
| `backup_info` | Metadados (versão, timestamp, etc.) |

### Múltiplos backups

Cada execução cria um backup com timestamp único. Os backups **não são sobrescritos**:

```
~/.local/share/bigretro-backup/
  20260429_143022/
  20260429_150530/
  20260501_091200/
```

A desinstalação sempre restaura a partir do **backup mais recente**.

---

## Como Desinstalar / Reverter

Existem três níveis de desinstalação, do mais conservador ao mais completo:

### Nível 1: Restaurar configurações (padrão)

Restaura todas as configurações para o estado anterior, mas **mantém os arquivos de tema** no disco:

```bash
./bigretro.sh --uninstall
```

Isso faz o seguinte:
1. Restaura o esquema de cores KDE do backup
2. Restaura o tema de ícones do backup
3. Restaura o estilo de widget do backup
4. Restaura kdeglobals completo
5. Restaura configurações GTK3, GTK4 e GTK2
6. Restaura configuração do Kvantum
7. Restaura variável de ambiente GTK do Plasma
8. Recarrega o Plasma

### Nível 2: Restaurar + remover arquivos (purge)

Além de restaurar tudo, **remove completamente** todos os arquivos do tema Fluent:

```bash
./bigretro.sh --uninstall --purge
```

Remove adicionalmente:
- `~/.local/share/color-schemes/Fluent*.colors`
- `~/.local/share/themes/Fluent*`
- `~/.local/share/icons/Fluent*`
- `~/.local/share/plasma/look-and-feel/*Fluent*`
- `~/.local/share/aurorae/themes/Fluent*`
- `~/.config/Kvantum/Fluent*`
- `~/.local/share/wallpapers/Fluent*`

### Nível 3: Atalho de desinstalação

O arquivo `bigretro-uninstall.sh` é um atalho conveniente que equivale a `./bigretro.sh --uninstall`:

```bash
./bigretro-uninstall.sh                # Restaurar configurações
./bigretro-uninstall.sh --purge        # Restaurar + remover tudo
```

### Desinstalação sem backup

Se não houver backup disponível (por exemplo, se os backups foram apagados manualmente), o script:

1. Avisa que não encontrou backup
2. Pergunta se deseja continuar apenas removendo os arquivos de tema
3. Se sim, remove os arquivos com `--purge`
4. Define o esquema de cores para **BreezeLight** (padrão do KDE) como fallback

### Reinstalação após desinstalação

Você pode reinstalar o tema a qualquer momento:

```bash
./bigretro.sh --full --dark
```

Os repositórios Git no `/tmp` serão reutilizados se ainda existirem (ou atualizados automaticamente).

---

## Status do Tema

Para verificar o estado atual do tema no seu sistema:

```bash
./bigretro.sh --status
```

Saída exemplo:

```
  KDE Plasma:              6.2.0
  Esquema de cores:       FluentDark  ✓
  Tema de ícones:         Fluent-dark  ✓
  Estilo de widget:       kvantum  ✓
  Tema Kvantum:           FluentDark  ✓

  GTK3 Theme:             Fluent-Dark  ✓
  GTK3 Icons:             Fluent-dark
  GTK4/libadwaita:        Fluent-Dark  ✓
  GTK4 Icons:             Fluent-dark

  Ícones BigLinux (big*): 142 disponíveis, 138 aplicados

  Backups existentes:      2
  Último backup:           20260429_143022
```

Os indicadores mostram se cada componente está usando um tema Fluent:
- `✓` = Componente usando Fluent
- `✗` = Componente usando outro tema

---

## Solução de Problemas

### "Dependências obrigatórias ausentes"

Instale as dependências faltantes com o gerenciador de pacotes da sua distribuição:

```bash
# Debian/Ubuntu/Mint
sudo apt install git curl

# Fedora
sudo dnf install git curl

# Arch Linux/Manjaro
sudo pacman -S git curl

# openSUSE
sudo zypper install git curl
```

### "kvantummanager não encontrado"

O Kvantum é opcional, mas recomendado. Sem ele, o estilo de widget não será alterado:

```bash
# Debian/Ubuntu/Mint
sudo apt install kvantum

# Fedora
sudo dnf install kvantum

# Arch Linux/Manjaro
sudo pacman -S kvantum
```

### "Diretório de ícones BigLinux não encontrado"

Isso significa que o pacote `bigicons-papient` não está instalado. O patch de ícones BigLinux será pulado, mas o resto do tema funciona normalmente.

### O Plasma não recarregou automaticamente

Faça manualmente:
```bash
# Opção 1: Recarregar pelo D-Bus
qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.refreshCurrentShell

# Opção 2: Reiniciar o plasmashell
systemctl --user restart plasma-plasmashell.service

# Opção 3: Logout e login (sempre funciona)
```

### Apps GTK não estão com o tema Fluent

Algumas aplicações GTK podem precisar de um restart ou de configurar a variável de ambiente `GTK_THEME`. O script configura automaticamente `~/.config/plasma-workspace/env/gtk-theme.sh`. Após o primeiro login, as apps GTK devem pegar o tema. Se não:

```bash
# Verificar se a variável está configurada
cat ~/.config/plasma-workspace/env/gtk-theme.sh

# Aplicar manualmente na sessão atual
export GTK_THEME=Fluent-Dark
```

### Quero trocar de dark para light (ou vice-versa)

Basta executar novamente com o modo desejado:

```bash
./bigretro.sh --full --light    # Troca para claro
./bigretro.sh --full --dark     # Troca para escuro
```

Um novo backup será criado antes da alteração.

### Apagar backups antigos

```bash
# Ver backups existentes
ls ~/.local/share/bigretro-backup/

# Apagar backup específico
rm -rf ~/.local/share/bigretro-backup/20260429_143022/

# Apagar todos os backups
rm -rf ~/.local/share/bigretro-backup/
```

---

## Estrutura dos Arquivos

```
bigretro/
  bigretro.sh               # Script principal (~780 linhas)
  bigretro-uninstall.sh     # Atalho de desinstalação
  README.md                 # Este arquivo
```

### Locais utilizados no sistema

```
~/.local/share/
  bigretro-backup/              # Backups das configurações
  color-schemes/Fluent*.colors  # Esquemas de cores
  themes/Fluent*/                # Temas GTK/libadwaita
  icons/Fluent*/                 # Ícones Fluent (+ patch big*)
  plasma/look-and-feel/          # Look-and-Feel do Plasma
  aurorae/themes/Fluent*/        # Decoração de janelas
  wallpapers/Fluent*/            # Papéis de parede

~/.config/
  kdeglobals                     # Configurações globais do KDE
  Kvantum/kvantum.kvconfig       # Configuração do Kvantum
  gtk-3.0/settings.ini           # Configuração GTK3
  gtk-4.0/settings.ini           # Configuração GTK4/libadwaita
  plasma-workspace/env/gtk-theme.sh  # Variável GTK_THEME

/usr/share/icons/
  bigicons-papient/              # (Origem) Ícones do BigLinux
```

---

## Créditos

- **Fluent Theme** por [vinceliuice](https://github.com/vinceliuice) — repositórios Fluent-kde, Fluent-gtk-theme e Fluent-icon-theme
- **bigicons-papient** — pacote de ícones do BigLinux
- **Kvantum** — engine de estilos de widget Qt

---

## Licença

GPL-3.0
