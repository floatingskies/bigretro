# bigretro — Restaurador do Tema Fluent do BigLinux

> **Restaura a experiência clássica do tema Fluent do BigLinux no KDE Plasma 6+**
> *Código livre, desktop bonito, comunidade unida! 🐧*

O `bigretro` é um script Bash CLI que instala e configura automaticamente o pacote completo do **Fluent Theme** (por vinceliuice) no seu sistema, replicando a aparência original do BigLinux. Ele cuida de tudo: tema KDE, tema GTK/libadwaita, ícones, patch de ícones BigLinux, estilo Kvantum, wallpaper e decoração de janelas — tudo com backup completo, snapshot Timeshift e opção de desinstalação total.

---

## Índice

- [Avisos Importantes](#avisos-importantes)
- [Requisitos](#requisitos)
- [Download](#download)
- [Uso Rápido](#uso-rápido)
- [Modo Interativo](#modo-interativo)
- [Modo CLI (Linhas de Comando)](#modo-cli-linhas-de-comando)
- [Interface Zenity (Gráfica)](#interface-zenity-gráfica)
- [Componentes Instalados](#componentes-instalados)
- [Patch de Ícones BigLinux](#patch-de-ícones-biglinux)
- [Patch da Lixeira Colorida](#patch-da-lixeira-colorida)
- [Snapshot Timeshift](#snapshot-timeshift)
- [Sistema de Backup](#sistema-de-backup)
- [Como Desinstalar / Reverter](#como-desinstalar--reverter)
- [Status do Tema](#status-do-tema)
- [Solução de Problemas](#solução-de-problemas)
- [Estrutura dos Arquivos](#estrutura-dos-arquivos)
- [Créditos](#créditos)
- [Licença](#licença)

---

## Avisos Importantes

> ⚠️ **LEIA ANTES DE USAR!** Esses avisos são importantes pra você não se assustar durante o processo.

### 1. O shell do KDE Plasma vai reiniciar — e isso é normal!

Durante a instalação, o shell do KDE Plasma vai reiniciar **umas duas vezes**. Fica tranquilo, **ele volta sozinho!** Isso é o Plasma recarregando as configurações de tema, cores e decoração. É completamente normal e esperado.

### 2. Faça logoff e logon depois!

Depois que o script terminar, é **muito recomendado fazer logoff e logon** de novo. Isso garante que todas as mudanças peguem direitinho — especialmente o tema GTK, a variável de ambiente e os ícones. O script aplica tudo ao vivo, mas o logoff/logon é o toque final pra ficar perfeito.

### 3. Decoração de janelas (Aurorae) — ativação manual

O tema de decoração de janelas Fluent (Aurorae) **já é instalado** pelo script, mas o KDE Plasma exige que você ative manualmente:

**Configurações do Sistema → Aparência → Decoração de janelas → escolha "Fluent"**

É só selecionar lá, o tema já tá instaladinho! Isso é uma limitação do Plasma, não do script. Infelizmente não tem como ativar o Aurorae automaticamente sem causar problemas nos botões da janela.

### 4. Snapshot Timeshift — sua rede de segurança

Se o Timeshift estiver instalado, um **snapshot automático** é criado antes de qualquer modificação. Se algo der errado, é só restaurar:

```bash
sudo timeshift --restore
```

Se o Timeshift não estiver instalado, o script avisa e pergunta se você quer continuar mesmo assim. O backup do bigretro ainda protege suas configurações.

---

## Requisitos

| Item | Descrição |
|---|---|
| **Sistema** | KDE Plasma 6+ (recomendado) |
| **Shell** | Bash 4+ |
| **Obrigatórios** | `git`, `curl`, `kwriteconfig6`, `kreadconfig6` |
| **Recomendados** | `kvantummanager` (estilo Kvantum), `gtk-update-icon-cache` (cache de ícones), `timeshift` (snapshot), `zenity` (interface gráfica) |
| **Espaço em disco** | Mínimo de 500 MB livres |

Verifique se o pacote de ícones do BigLinux está instalado:

```bash
ls /usr/share/icons/bigicons-papient
```

Se o diretório não existir, o patch de ícones BigLinux será pulado automaticamente (o resto continua funcionando normalmente).

---

## Download

Baixe o script e dê permissão de execução:

```bash
chmod +x bigretro
```

O script pode ficar em qualquer diretório. Recomendação:

```bash
# Opção 1: Diretório atual
./bigretro --full --dark

# Opção 2: Mover para ~/.local/bin (acessível de qualquer lugar)
mkdir -p ~/.local/bin
mv bigretro ~/.local/bin/
bigretro --full --dark
```

> **Nota:** A partir da v2.0, não é mais necessário um script de desinstalação separado. Tudo é feito pelo `bigretro` com a flag `--uninstall`.

---

## Uso Rápido

Se você quer apenas instalar tudo de uma vez sem pensar muito:

```bash
# Instalar tudo em modo escuro (recomendado, igual ao BigLinux clássico)
./bigretro --full --dark

# Instalar tudo em modo claro
./bigretro --full --light

# Instalar tudo sem perguntar nada (totalmente automático)
./bigretro --full --dark -y

# Instalar tudo em modo CLI (sem interface Zenity)
./bigretro --cli --full --dark -y
```

Pronto. O tema será instalado, configurado e o Plasma será recarregado automaticamente. Lembre-se de fazer logoff/logon depois!

---

## Modo Interativo

Executar o script sem argumentos abre o **menu interativo guiado**, ideal para quem prefere escolher passo a passo:

```bash
./bigretro
```

Se o **Zenity** estiver instalado e você estiver em um ambiente gráfico, o menu interativo será exibido em uma interface gráfica (veja [Interface Zenity](#interface-zenity-gráfica)). Caso contrário, o menu é exibido no terminal.

O fluxo interativo faz o seguinte:

1. **Verifica dependências** — confere se `git`, `curl`, `kwriteconfig6` e `kreadconfig6` estão disponíveis.
2. **Confirmação inicial** — pergunta se você deseja prosseguir.
3. **Escolha do modo de cor** — Dark (escuro) 🌙 ou Light (claro) ☀️.
4. **Seleção de componentes** — você escolhe o que instalar:
   - `[1]` Tema KDE Plasma
   - `[2]` Tema GTK (libadwaita)
   - `[3]` Ícones Fluent + Patch BigLinux
   - `[4]` Estilo Kvantum
   - `[5]` Decoração Aurorae
   - `[6]` Wallpaper big-retro
   - `[F]` Tudo (Full) 🚀
5. **Patch de bigicons** — pergunta se deseja aplicar o patch de ícones do BigLinux.
6. **Resumo** — mostra tudo que será feito e pede confirmação final.
7. **Execução** — instala, aplica configurações e recarrega o Plasma.

---

## Modo CLI (Linhas de Comando)

Para automação, scripts ou quando você já sabe o que quer, use as flags diretamente:

### Instalação completa

```bash
./bigretro --full --dark          # Tudo em modo escuro
./bigretro --full --light         # Tudo em modo claro
./bigretro --full --dark -y       # Tudo, sem confirmações
./bigretro --cli --full --dark -y # Tudo, sem Zenity, sem confirmações
```

### Componentes individuais

```bash
# Apenas o tema KDE Plasma
./bigretro --kde --dark

# Apenas o tema GTK (libadwaita)
./bigretro --gtk --dark

# Apenas os ícones
./bigretro --icons --dark

# Apenas o estilo Kvantum (requer ícones ou tema KDE instalado antes)
./bigretro --kvantum --dark

# Apenas a decoração de janelas
./bigretro --aurorae --dark

# Apenas o wallpaper
./bigretro --wallpaper --dark

# Combinações livres
./bigretro --kde --gtk --icons --dark
./bigretro --kde --gtk --kvantum --light
./bigretro --kde --gtk --icons --kvantum --aurorae --wallpaper --dark
```

### Comportamento

```bash
# Pular o patch de ícones BigLinux
./bigretro --full --dark --no-patch

# Pular snapshot do Timeshift
./bigretro --full --dark --no-timeshift

# Forçar modo terminal (sem Zenity, mesmo com Zenity instalado)
./bigretro --cli --full --dark

# Ver o estado atual do tema
./bigretro --status

# Ajuda completa
./bigretro --help

# Versão
./bigretro --version
```

### Referência rápida de flags

| Flag | Descrição |
|---|---|
| `--full` | Instala e aplica todos os componentes |
| `--kde` | Instala e aplica o tema KDE Plasma |
| `--gtk` | Instala e aplica o tema GTK (libadwaita) |
| `--icons` | Instala ícones Fluent + patch bigicons + patch lixeira |
| `--kvantum` | Aplica estilo de widget Kvantum |
| `--aurorae` | Aplica tema de decoração de janelas Aurorae |
| `--wallpaper` | Aplica wallpaper big-retro |
| `--dark` | Usa variante escura |
| `--light` | Usa variante clara |
| `--no-patch` | Pula o patch de ícones bigicons-papient |
| `--no-timeshift` | Pula a criação de snapshot Timeshift |
| `--cli` | Força modo CLI (sem interface Zenity) |
| `-y`, `--yes` | Pula todas as confirmações |
| `--uninstall` | Desinstala e restaura configurações originais |
| `--purge` | Desinstala + remove todos os arquivos de tema |
| `--status` | Mostra o estado atual do tema |
| `-h`, `--help` | Mostra ajuda |
| `-v`, `--version` | Mostra versão |

> **Importante:** Ao usar componentes individuais via CLI, é obrigatório especificar `--dark` ou `--light`. Sem esses flags, o script exibirá uma mensagem de erro com instruções.

---

## Interface Zenity (Gráfica)

Se o **Zenity** estiver instalado e você estiver em um ambiente gráfico (com `DISPLAY` definido), o `bigretro` usa automaticamente a interface gráfica. Isso significa:

- **Diálogos de seleção** para modo de cor e componentes
- **Terminal embutido** — a instalação roda dentro de uma janela Zenity com fonte monospace, mostrando tudo em tempo real
- **Checkbox de confirmação** — "Entendi que preciso fazer logoff depois"
- **Avisos pós-instalação** em janela gráfica

### Forçar modo terminal

Se você quer usar o terminal mesmo com o Zenity instalado:

```bash
./bigretro --cli --full --dark
```

### Se o Zenity não estiver instalado

O script funciona normalmente no modo terminal. Nada muda. Para instalar o Zenity:

```bash
# Debian/Ubuntu/BigLinux
sudo apt install zenity

# Fedora
sudo dnf install zenity

# Arch Linux/Manjaro
sudo pacman -S zenity
```

---

## Componentes Instalados

O `bigretro` instala os seguintes componentes a partir dos repositórios oficiais do vinceliuice no GitHub:

### 1. Fluent-kde (Tema KDE Plasma)

- **Repositório:** [vinceliuice/Fluent-kde](https://github.com/vinceliuice/Fluent-kde)
- **Instalador:** `./install.sh` (padrão do repositório)
- **O que instala:** Esquemas de cores, tema de decoração Aurorae, look-and-feel completo do Plasma, tema Kvantum
- **Destino:** `~/.local/share/` (color-schemes, aurorae, plasma, wallpapers, Kvantum)

### 2. Fluent-gtk-theme (Tema GTK + libadwaita)

- **Repositório:** [vinceliuice/Fluent-gtk-theme](https://github.com/vinceliuice/Fluent-gtk-theme)
- **Instalador:** `./install.sh -l` (flag `-l` para libadwaita)
- **O que instala:** Temas GTK3 e GTK4 com suporte a libadwaita
- **Destino:** `~/.local/share/themes/Fluent*` ou `~/.themes/Fluent*`

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

### 5. Decoração Aurorae

- Instalado automaticamente pelo Fluent-kde em `~/.local/share/aurorae/themes/`
- O script aplica via `kwriteconfig6` no `kwinrc`
- **⚠️ Ativação manual necessária** — veja os [Avisos Importantes](#avisos-importantes)

### 6. Wallpaper big-retro

- Procurado automaticamente em `/usr/share/wallpapers/big-retro*`
- Copiado para `~/.local/share/wallpapers/big-retro/`
- Aplicado via `plasma-apply-wallpaperimage`, D-Bus ou `kwriteconfig6`

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

A estrutura de diretórios é **preservada** durante a cópia. Se o `rsync` estiver disponível, ele é usado automaticamente para maior eficiência.

### Desativar o patch

Se você não quiser aplicar o patch de ícones BigLinux:

```bash
# Modo CLI
./bigretro --full --dark --no-patch

# Modo interativo: responda "N" quando perguntar sobre o patch
```

---

## Patch da Lixeira Colorida

O `bigretro` também aplica um patch que torna o ícone da lixeira colorido no tema Fluent. Por padrão, o Fluent usa ícones monocromáticos/simbólicos para a lixeira, mas o BigLinux prefere a versão colorida.

### O que o patch faz

1. Procura o ícone `user-trash-full` (lixeira cheia, colorido) nos diretórios do tema Fluent
2. Copia para `symbolic/places/user-trash-symbolic.<ext>`
3. Copia para `symbolic/places/user-trash-full-symbolic.<ext>`

Isso faz com que o Plasma mostre a lixeira colorida na bandeja do sistema e no desktop, mantendo a aparência clássica do BigLinux.

Esse patch é aplicado automaticamente junto com os ícones e não pode ser desativado separadamente.

---

## Snapshot Timeshift

Antes de qualquer modificação no sistema, o `bigretro` cria automaticamente um **snapshot do Timeshift** (se o Timeshift estiver instalado e configurado).

### Como funciona

1. O script detecta se o Timeshift está disponível
2. Se sim, cria um snapshot com descrição: `bigretro-v2.0.0-pre-install-<timestamp>`
3. Se a criação falhar (ex: Timeshift não configurado), o script avisa e pergunta se quer continuar
4. Se o Timeshift não estiver instalado, o script também avisa, mas o backup do bigretro continua protegendo suas configurações

### Pular o snapshot

```bash
./bigretro --full --dark --no-timeshift
```

### Restaurar a partir do snapshot

Se algo der muito errado (o que é raro, mas precaução nunca é demais):

```bash
sudo timeshift --restore
```

### Instalar o Timeshift

Se você ainda não tem o Timeshift, recomendamos fortemente instalar:

```bash
# Debian/Ubuntu/BigLinux
sudo apt install timeshift

# Fedora
sudo dnf install timeshift

# Arch Linux/Manjaro
sudo pacman -S timeshift
```

Depois de instalar, configure com `sudo timeshift-gtk` ou `sudo timeshift --setup`.

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
| `set-theme.sh` | Script de ambiente XDG_DATA_DIRS |
| `aurorae_library` | Biblioteca de decoração de janelas |
| `aurorae_theme` | Tema de decoração de janelas |
| `kwinrc` | Configuração do KWin |
| `wallpaper_image` | Wallpaper atual |
| `plasmarc` | Configuração do Plasma |
| `flatpak_overrides.ini` | Overrides do Flatpak (se existir) |
| `backup_info` | Metadados (versão, timestamp, versão do Plasma, etc.) |

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

Existem dois níveis de desinstalação:

### Nível 1: Restaurar configurações (padrão)

Restaura todas as configurações para o estado anterior, mas **mantém os arquivos de tema** no disco:

```bash
./bigretro --uninstall
```

Isso faz o seguinte:
1. Cria snapshot Timeshift de segurança (se disponível)
2. Restaura o esquema de cores KDE do backup
3. Restaura o tema de ícones do backup
4. Restaura o estilo de widget do backup
5. Restaura kdeglobals completo
6. Restaura configurações GTK3, GTK4 e GTK2
7. Restaura configuração do Kvantum
8. Restaura variáveis de ambiente GTK do Plasma
9. Restaura configuração do KWin (Aurorae)
10. Restaura configuração do Flatpak (overrides)
11. Recarrega o Plasma

### Nível 2: Restaurar + remover arquivos (purge)

Além de restaurar tudo, **remove completamente** todos os arquivos do tema Fluent:

```bash
./bigretro --uninstall --purge
```

Remove adicionalmente:
- `~/.local/share/color-schemes/Fluent*.colors`
- `~/.themes/Fluent*`
- `~/.local/share/themes/Fluent*`
- `~/.local/share/icons/Fluent*`
- `~/.local/share/plasma/look-and-feel/*Fluent*`
- `~/.local/share/aurorae/themes/Fluent*`
- `~/.config/Kvantum/Fluent*`
- `~/.local/share/wallpapers/Fluent*`
- `~/.local/share/wallpapers/big-retro`
- `~/.config/gtkrc-2.0`
- `~/.config/plasma-workspace/env/gtk-theme.sh`
- `~/.config/plasma-workspace/env/set-theme.sh`
- Overrides do Flatpak

### Desinstalação sem backup

Se não houver backup disponível (por exemplo, se os backups foram apagados manualmente), o script:

1. Avisa que não encontrou backup
2. Pergunta se deseja continuar apenas removendo os arquivos de tema
3. Se sim, remove os arquivos com `--purge`
4. Define o esquema de cores para **BreezeLight** (padrão do KDE) como fallback

### Reinstalação após desinstalação

Você pode reinstalar o tema a qualquer momento:

```bash
./bigretro --full --dark
```

Os repositórios Git serão clonados novamente (ou atualizados se ainda existirem no diretório temporário).

---

## Status do Tema

Para verificar o estado atual do tema no seu sistema:

```bash
./bigretro --status
```

Saída exemplo:

```
  STATUS ATUAL DO TEMA

  KDE Plasma:              6.2.0
  Esquema de cores:       FluentDark  ✓
  Tema de ícones:         Fluent-dark  ✓
  Estilo de widget:       kvantum  ✓
  Tema Kvantum:           FluentDark  ✓

  GTK Themes disponíveis: Fluent-Dark, Fluent-Light

  GTK3 Theme:             Fluent-Dark  ✓
  GTK3 Icons:             Fluent-dark
  GTK4/libadwaita:        Fluent-Dark  ✓
  GTK4 Icons:             Fluent-dark

  Ícones BigLinux (big*): 142 disponíveis, 138 aplicados
  Lixeira colorida (patch): 2 ícone(s)

  Decoração Aurorae:       Fluent-dark  ✓
  Aurorae disponíveis:     Fluent-dark, Fluent-light
     (Dica: vai em Configurações → Aparência → Decoração de janelas)

  Wallpaper:              big-retro.jpg  ✓

  Timeshift:              disponível
  Backups existentes:      2
  Último backup:           20260429_143022
```

Os indicadores mostram se cada componente está usando um tema Fluent:
- `✓` = Componente usando Fluent
- `✗` = Componente usando outro tema

---

## Solução de Problemas

### "Outra instância do bigretro já está rodando"

O script usa um lock file para evitar execução concorrente. Se você tiver certeza que não há outra instância:

```bash
rm /tmp/bigretro-$(id -u).lock
```

### "Dependências obrigatórias ausentes"

Instale as dependências faltantes com o gerenciador de pacotes da sua distribuição:

```bash
# Debian/Ubuntu/BigLinux
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
# Debian/Ubuntu/BigLinux
sudo apt install kvantum

# Fedora
sudo dnf install kvantum

# Arch Linux/Manjaro
sudo pacman -S kvantum
```

### "Diretório de ícones BigLinux não encontrado"

Isso significa que o pacote `bigicons-papient` não está instalado. O patch de ícones BigLinux será pulado, mas o resto do tema funciona normalmente.

### "Espaço em disco insuficiente"

O script requer pelo menos 500 MB livres. Libere espaço e tente novamente.

### O Plasma não recarregou automaticamente

Faça manualmente:

```bash
# Opção 1: Recarregar pelo D-Bus
qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.refreshCurrentShell

# Opção 2: Reiniciar o plasmashell
systemctl --user restart plasma-plasmashell.service

# Opção 3: Reiniciar o KWin
# Atalho: Shift+Alt+F12

# Opção 4: Logout e login (sempre funciona)
```

### Apps GTK não estão com o tema Fluent

Algumas aplicações GTK podem precisar de um restart ou de configurar a variável de ambiente `GTK_THEME`. O script configura automaticamente `~/.config/plasma-workspace/env/gtk-theme.sh`. Após o primeiro login, as apps GTK devem pegar o tema. Se não:

```bash
# Verificar se a variável está configurada
cat ~/.config/plasma-workspace/env/gtk-theme.sh

# Aplicar manualmente na sessão atual
export GTK_THEME=Fluent-Dark
```

### Apps Flatpak não estão com o tema Fluent

O script configura automaticamente os overrides do Flatpak, mas pode ser necessário reiniciar os apps:

```bash
# Verificar overrides
flatpak override --user --show

# Se necessário, reconfigurar
./bigretro --gtk --dark
```

### A decoração de janelas não mudou

O tema Aurorae é instalado e aplicado pelo script, mas o KDE Plasma às vezes exige ativação manual:

**Configurações do Sistema → Aparência → Decoração de janelas → escolha "Fluent"**

Se ainda assim não funcionar, reinicie o KWin:

```bash
qdbus6 org.kde.KWin /KWin reconfigure
```

### Quero trocar de dark para light (ou vice-versa)

Basta executar novamente com o modo desejado:

```bash
./bigretro --full --light    # Troca para claro
./bigretro --full --dark     # Troca para escuro
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

### O script falhou ao clonar repositórios

O `bigretro` tenta até 3 vezes com delay de 5 segundos entre tentativas. Se mesmo assim falhar:

1. Verifique sua conexão com a internet
2. Tente clonar manualmente: `git clone https://github.com/vinceliuice/Fluent-kde.git`
3. Se estiver atrás de proxy, configure o git: `git config --global http.proxy <proxy>`
4. Execute novamente com `--no-timeshift` se o Timeshift estiver causando problemas

---

## Estrutura dos Arquivos

```
bigretro/
  bigretro                # Script principal (~1200 linhas)
  README.md               # Este arquivo
```

### Locais utilizados no sistema

```
~/.local/share/
  bigretro-backup/              # Backups das configurações
  color-schemes/Fluent*.colors  # Esquemas de cores
  themes/Fluent*/                # Temas GTK/libadwaita
  icons/Fluent*/                 # Ícones Fluent (+ patch big* + patch lixeira)
  plasma/look-and-feel/          # Look-and-Feel do Plasma
  aurorae/themes/Fluent*/        # Decoração de janelas
  wallpapers/big-retro/          # Wallpaper big-retro
  Kvantum/Fluent*/               # Temas Kvantum

~/.themes/
  Fluent*/                       # Temas GTK (alternativo)

~/.config/
  kdeglobals                     # Configurações globais do KDE
  kwinrc                         # Configuração do KWin (Aurorae)
  Kvantum/kvantum.kvconfig       # Configuração do Kvantum
  gtk-3.0/settings.ini           # Configuração GTK3
  gtk-4.0/settings.ini           # Configuração GTK4/libadwaita
  gtkrc-2.0                      # Configuração GTK2
  plasmarc                       # Configuração do Plasma (wallpaper)
  plasma-workspace/env/gtk-theme.sh  # Variável GTK_THEME
  plasma-workspace/env/set-theme.sh  # XDG_DATA_DIRS

/usr/share/icons/
  bigicons-papient/              # (Origem) Ícones do BigLinux

/usr/share/wallpapers/
  big-retro*                     # (Origem) Wallpaper do BigLinux

/tmp/bigretro-<uid>/
  Fluent-kde/                    # Clone temporário do repositório
  Fluent-gtk-theme/              # Clone temporário do repositório
  Fluent-icon-theme/             # Clone temporário do repositório
  install*.log                   # Logs de instalação
```

### Proteção e segurança

| Recurso | Descrição |
|---|---|
| **Lock file** | `/tmp/bigretro-<uid>.lock` — impede execução concorrente |
| **Timeshift** | Snapshot automático antes de modificações |
| **Backup** | Todas as configurações originais salvas com timestamp |
| **Retry** | Operações de rede tentam até 3x automaticamente |
| **Verificação de espaço** | Mínimo de 500 MB antes de instalar |
| **Preservação de logs** | Em caso de erro, logs são copiados para o diretório de backup |

---

## Créditos

- **Fluent Theme** por [vinceliuice](https://github.com/vinceliuice) — repositórios Fluent-kde, Fluent-gtk-theme e Fluent-icon-theme
- **bigicons-papient** — pacote de ícones do BigLinux
- **Kvantum** — engine de estilos de widget Qt
- **BigLinux Community** — comunidade que torna tudo possível ❤️

> *Código livre, desktop bonito, comunidade unida!*

---

## Licença

GPL-3.0
