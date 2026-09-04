# esasse.agenda

Agenda do dia de **várias contas Google** na barra do Omarchy, com um clique
para entrar na reunião.

```
esasse.agenda/
├── manifest.json          plugin bar-widget do omarchy-shell
├── Panel.qml              rótulo na barra + popup da agenda
├── Service.qml            ciclo de vida: poll, relógio, ações
├── Model.js               formatação e derivações (rótulo, estados, textos)
├── bin/omarchy-agenda     helper Python (OAuth + Google Calendar API)
└── LICENSE                MIT
```

O QML nunca fala com o Google: ele só roda `omarchy-agenda today --json` e
desenha o resultado. O helper é stdlib pura — sem pip, sem AUR.

## Instalação

Numa máquina Omarchy nova:

```bash
omarchy plugin add https://github.com/esasse/omarchy-agenda.git --enable --yes
```

O widget entra na seção direita da barra; mova com
`omarchy bar move esasse.agenda --section <left|center|right>`.

O popup chama o helper pelo caminho absoluto dentro do próprio plugin
(`Qt.resolvedUrl`), então o painel funciona sem depender do `PATH` da shell.
Para usar o CLI no terminal — `setup`, `login`, `today`, `calendars` — crie o
symlink:

```bash
ln -sf ~/.config/omarchy/plugins/esasse.agenda/bin/omarchy-agenda \
       ~/.local/bin/omarchy-agenda
```

Se o plugin foi clonado com outro id, o caminho é
`~/.config/omarchy/plugins/<id>/bin/omarchy-agenda`.

Editar `Model.js` ou os `.qml` pede `omarchy restart shell`: o hot reload do
shell não reinstancia widgets da barra e deixa o `IpcHandler` antigo
registrado no alvo.

## Configuração (uma vez)

1. **Projeto** — <https://console.cloud.google.com/projectcreate>
   (conta Gmail pessoal: Organização = "Sem organização")
2. **API** — ative a
   [Google Calendar API](https://console.cloud.google.com/apis/library/calendar-json.googleapis.com)
   no projeto
3. **Consentimento** — <https://console.cloud.google.com/auth/overview>
   - "Começar": nome do app, e-mail de suporte, Público = **Externo**
   - em *Público*, **Publicar app**. Em modo "Teste" o Google expira a
     autorização a cada 7 dias; publicado, não expira — o preço é a tela
     "app não verificado" na primeira autorização (*Avançado > Acessar …*).
   - alternativa: deixar em Teste e listar cada conta em *Usuários de teste*
4. **Credencial** — *Credenciais > Criar credenciais > ID do cliente OAuth >
   App para computador > Criar > Fazer download do JSON*

```bash
omarchy-agenda setup --from ~/Downloads/client_secret_*.json
omarchy-agenda login    # repita para cada conta Google
```

`setup` sem argumento também acha o `client_secret_*.json` mais recente em
`~/Downloads` e pede confirmação — o secret nunca precisa ser digitado.

O painel abre esses dois comandos num terminal: clique em "Configurar acesso
ao Google" / "Conectar uma conta Google".

## Uso

Na barra:

| Ação | Efeito |
|---|---|
| clique esquerdo | abre/fecha o popup da agenda |
| clique do meio | entra na reunião em curso (ou na próxima) |
| clique direito | atualiza agora |
| hover | tooltip com a reunião de agora e a próxima |

No popup:

| Tecla | Efeito |
|---|---|
| ↑ / ↓ | navega |
| enter | entra na reunião selecionada |
| `j` | entra na reunião em curso / próxima |
| `r` | atualiza |
| `o` | abre o evento selecionado no Google Calendar |
| `l` | abre um terminal para conectar outra conta |
| esc | fecha |

Clicar em qualquer linha entra na chamada. Sem link de vídeo, o clique abre o
evento no Google Calendar. Links do Google saem com `authuser=<conta>`, então
a reunião abre na conta certa mesmo com várias logadas no navegador.

## CLI

```bash
omarchy-agenda today                  # agenda de hoje em texto
omarchy-agenda today --json           # o que o painel consome
omarchy-agenda today --date tomorrow  # amanhã (ou YYYY-MM-DD)
omarchy-agenda next                   # "14:30 Reunião" (bom para scripts)
omarchy-agenda accounts               # contas autorizadas
omarchy-agenda calendars              # agendas visíveis de cada conta
omarchy-agenda logout a@b.com         # remove e revoga no Google
```

## Ajustes

Em `~/.config/omarchy/shell.json`, na entrada do widget:

```json
{ "id": "esasse.agenda", "refreshIntervalSec": 180, "barLabelChars": 22 }
```

Em `~/.local/share/omarchy-agenda/config.json` (opcional):

```json
{
  "aliases": { "erick@empresa.com": "trabalho" },
  "ignore_calendars": ["pt-br.brazilian#holiday@group.v.calendar.google.com"],
  "hide_declined": false,
  "include_all_day": true
}
```

`aliases` renomeia a conta na linha de meta; `ignore_calendars` usa os ids que
`omarchy-agenda calendars` imprime.

## Estado local

`~/.local/share/omarchy-agenda/` (0700, arquivos 0600):

| Arquivo | Conteúdo |
|---|---|
| `client.json` | Client ID/secret do seu projeto |
| `accounts/<email>.json` | refresh token por conta |
| `tokens/<email>.json` | access token em cache (renovado sozinho) |
| `cache/<data>.json` | último dia buscado — é o que aparece sem rede |

## IPC

```bash
omarchy-shell esasse.agenda toggle    # abre/fecha o popup
omarchy-shell esasse.agenda refresh
omarchy-shell esasse.agenda join      # entra na reunião de agora/próxima
omarchy-shell esasse.agenda next      # devolve "14:30 Reunião"
```
