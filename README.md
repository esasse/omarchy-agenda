# esasse.agenda

Today's agenda from **several Google accounts** in the Omarchy bar, with one
click to join the meeting.

```
esasse.agenda/
├── manifest.json          omarchy-shell bar-widget plugin
├── Panel.qml              bar label + agenda popup
├── Service.qml            lifecycle: poll, clock, actions
├── Model.js               formatting and derivations (label, states, text)
├── bin/omarchy-agenda     Python helper (OAuth + Google Calendar API)
├── docs/index.html        project page (GitHub Pages)
└── LICENSE                MIT
```

The QML never talks to Google: it only runs `omarchy-agenda today --json` and
draws the result. The helper is pure stdlib — no pip, no AUR.

## Install

On a fresh Omarchy machine:

```bash
omarchy plugin add https://github.com/esasse/omarchy-agenda.git --enable --yes
```

The widget lands in the bar's right section; move it with
`omarchy bar move esasse.agenda --section <left|center|right>`.

The popup calls the helper by an absolute path inside the plugin itself
(`Qt.resolvedUrl`), so the panel does not depend on the shell's `PATH`. To use
the CLI in a terminal — `setup`, `login`, `today`, `calendars` — create the
symlink:

```bash
ln -sf ~/.config/omarchy/plugins/esasse.agenda/bin/omarchy-agenda \
       ~/.local/bin/omarchy-agenda
```

If the plugin was cloned under a different id, the path is
`~/.config/omarchy/plugins/<id>/bin/omarchy-agenda`.

Editing `Model.js` or the `.qml` files needs `omarchy restart shell`: the
shell's hot reload does not re-instantiate bar widgets, and it leaves the old
`IpcHandler` registered on the target.

### Optional keybinding

The panel opens by clicking the widget. To open it from the keyboard, add a
binding to `~/.config/hypr/bindings.lua` — it lives in your Hyprland config,
not in the plugin, so it does not travel with `omarchy plugin add`:

```lua
o.bind("SUPER + A", "Agenda", "omarchy-shell esasse.agenda toggle")
```

`SUPER + A` is free on a stock Omarchy (`SUPER+CTRL+A` is Audio,
`SUPER+SHIFT+A` is ChatGPT). Check yours with
`omarchy menu keybindings --print`, and reload with `hyprctl reload`.

## Setup (once)

1. **Project** — <https://console.cloud.google.com/projectcreate>
   (personal Gmail account: Organization = "No organization")
2. **API** — enable the
   [Google Calendar API](https://console.cloud.google.com/apis/library/calendar-json.googleapis.com)
   on that project
3. **Consent** — <https://console.cloud.google.com/auth/overview>
   - "Get started": app name, support email, Audience = **External**
   - under *Audience*, click **Publish app**. In "Testing" mode Google expires
     the authorization every 7 days; published, it does not expire — the price
     is the "app not verified" screen on the first authorization
     (*Advanced > Go to …*).
   - alternative: keep it in Testing and list each account under *Test users*
4. **Credential** — *Credentials > Create credentials > OAuth client ID >
   Desktop app > Create > Download JSON*

```bash
omarchy-agenda setup --from ~/Downloads/client_secret_*.json
omarchy-agenda login    # repeat for each Google account
```

`setup` with no arguments also finds the most recent `client_secret_*.json` in
`~/Downloads` and asks for confirmation — the secret never has to be typed.

The panel opens both commands in a terminal for you: click "Set up Google
access" / "Connect a Google account".

## Usage

In the bar:

| Action | Effect |
|---|---|
| left click | opens/closes the agenda popup |
| middle click | joins the meeting in progress (or the next one) |
| right click | refreshes now |
| hover | tooltip with the current and the next meeting |

In the popup:

| Key | Effect |
|---|---|
| ↑ / ↓ | move |
| enter | join the selected meeting |
| `j` | join the current / next meeting |
| `r` | refresh |
| `o` | open the selected event in Google Calendar |
| `l` | open a terminal to connect another account |
| esc | close |

Clicking any row joins the call. With no video link, the click opens the event
in Google Calendar. Google links carry `authuser=<account>`, so the meeting
opens under the right account even with several signed in to the browser.

## CLI

```bash
omarchy-agenda today                  # today's agenda as text
omarchy-agenda today --json           # what the panel consumes
omarchy-agenda today --date tomorrow  # tomorrow (or YYYY-MM-DD)
omarchy-agenda next                   # "14:30 Meeting" (handy for scripts)
omarchy-agenda accounts               # authorized accounts
omarchy-agenda calendars              # each account's visible calendars
omarchy-agenda logout a@b.com         # remove and revoke at Google
```

## Settings

In `~/.config/omarchy/shell.json`, on the widget's entry:

```json
{ "id": "esasse.agenda", "refreshIntervalSec": 180, "barLabelChars": 22 }
```

In `~/.local/share/omarchy-agenda/config.json` (optional):

```json
{
  "aliases": { "erick@company.com": "work" },
  "ignore_calendars": ["pt-br.brazilian#holiday@group.v.calendar.google.com"],
  "hide_declined": false,
  "include_all_day": true
}
```

`aliases` renames the account on the meta line; `ignore_calendars` takes the
ids that `omarchy-agenda calendars` prints.

## Local state

`~/.local/share/omarchy-agenda/` (0700, files 0600):

| File | Contents |
|---|---|
| `client.json` | your project's Client ID/secret |
| `accounts/<email>.json` | refresh token per account |
| `tokens/<email>.json` | cached access token (renewed automatically) |
| `cache/<date>.json` | last fetched day — what shows up with no network |

## IPC

```bash
omarchy-shell esasse.agenda toggle    # open/close the popup
omarchy-shell esasse.agenda refresh
omarchy-shell esasse.agenda join      # join the current / next meeting
omarchy-shell esasse.agenda next      # returns "14:30 Meeting"
```
