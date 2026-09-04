// Formatacao e derivacoes da agenda. Sem estado: recebe o payload do helper
// (omarchy-agenda today --json) e devolve o que a UI precisa desenhar.

var SOON_SEC = 10 * 60          // "começa em breve"
var GRACE_SEC = 5 * 60          // reunião ainda "entrável" após o fim

function hm(iso) {
  var s = String(iso || "")
  return s.length >= 16 ? s.substring(11, 16) : ""
}

function timeLabel(event) {
  if (!event) return ""
  return event.allDay ? "dia inteiro" : hm(event.start)
}

function rangeLabel(event) {
  if (!event) return ""
  if (event.allDay) return "dia inteiro"
  return hm(event.start) + "–" + hm(event.end)
}

function shortTitle(title, max) {
  var t = String(title || "").replace(/\s+/g, " ").trim()
  if (!max || t.length <= max) return t
  return t.substring(0, Math.max(1, max - 1)) + "…"
}

function duration(seconds) {
  var mins = Math.max(0, Math.round(seconds / 60))
  if (mins < 60) return mins + " min"
  var hours = Math.floor(mins / 60)
  var rest = mins % 60
  return rest === 0 ? hours + "h" : hours + "h" + (rest < 10 ? "0" + rest : rest)
}

// "em 25 min" / "agora" / "ha 10 min", sempre relativo ao início do evento.
function relative(event, nowTs) {
  if (!event) return ""
  if (event.allDay) return "hoje"
  var delta = event.startTs - nowTs
  if (delta > 30) return "em " + duration(delta)
  if (event.endTs > nowTs) return "agora"
  return "há " + duration(nowTs - event.startTs)
}

// past | live | soon | future — dita cor e destaque da linha.
function state(event, nowTs) {
  if (!event) return "future"
  if (event.allDay) return "future"
  if (nowTs >= event.startTs && nowTs < event.endTs) return "live"
  if (nowTs >= event.endTs) return "past"
  if (event.startTs - nowTs <= SOON_SEC) return "soon"
  return "future"
}

function isJoinable(event, nowTs) {
  if (!event || !event.joinUrl) return false
  if (event.allDay) return true
  return nowTs < event.endTs + GRACE_SEC
}

function declined(event) {
  return !!event && event.myStatus === "declined"
}

// Reunião acontecendo agora (a que termina primeiro, se houver sobreposição).
function liveEvent(events, nowTs) {
  var list = events || []
  var best = null
  for (var i = 0; i < list.length; i++) {
    var e = list[i]
    if (e.allDay || declined(e)) continue
    if (nowTs >= e.startTs && nowTs < e.endTs) {
      if (!best || e.endTs < best.endTs) best = e
    }
  }
  return best
}

function nextEvent(events, nowTs) {
  var list = events || []
  for (var i = 0; i < list.length; i++) {
    var e = list[i]
    if (e.allDay || declined(e)) continue
    if (e.startTs > nowTs) return e
  }
  return null
}

// O que o clique do meio na barra (e o Enter no painel vazio) deve abrir:
// a reunião em curso ganha da próxima.
function focusEvent(events, nowTs) {
  var live = liveEvent(events, nowTs)
  if (live) return live
  return nextEvent(events, nowTs)
}

function remaining(events, nowTs) {
  var list = events || []
  var count = 0
  for (var i = 0; i < list.length; i++) {
    var e = list[i]
    if (e.allDay || declined(e)) continue
    if (e.endTs > nowTs) count += 1
  }
  return count
}

// Texto compacto da barra. Em barra vertical só o ícone sobra.
function barLabel(events, nowTs, maxChars) {
  var live = liveEvent(events, nowTs)
  if (live) {
    return "󰕧 " + shortTitle(live.title, maxChars) + " · " + duration(live.endTs - nowTs)
  }
  var next = nextEvent(events, nowTs)
  if (next) {
    var label = "󰃭 " + hm(next.start) + " " + shortTitle(next.title, maxChars)
    if (next.startTs - nowTs <= SOON_SEC) label += " · " + duration(next.startTs - nowTs)
    return label
  }
  var pending = (events || []).length
  return pending > 0 ? "󰃭 fim do dia" : "󰃭 livre"
}

function heroMeta(payload, nowTs) {
  if (!payload) return "carregando…"
  if (payload.needsSetup) return "configuração pendente"
  if (payload.needsLogin) return "nenhuma conta conectada"
  var events = payload.events || []
  if (events.length === 0) return "nada agendado"
  var left = remaining(events, nowTs)
  var meetings = 0
  for (var i = 0; i < events.length; i++) if (events[i].joinUrl) meetings += 1
  var parts = [events.length + (events.length === 1 ? " evento" : " eventos")]
  if (meetings > 0) parts.push(meetings + (meetings === 1 ? " reunião" : " reuniões"))
  var live = liveEvent(events, nowTs)
  var next = nextEvent(events, nowTs)
  if (live) parts.push("agora até " + hm(live.end))
  else if (next) parts.push("próxima " + relative(next, nowTs))
  else if (left === 0) parts.push("encerrado")
  return parts.join(" · ")
}

function dateLabel(isoDate) {
  var months = ["janeiro", "fevereiro", "março", "abril", "maio", "junho",
                "julho", "agosto", "setembro", "outubro", "novembro", "dezembro"]
  var weekdays = ["domingo", "segunda", "terça", "quarta", "quinta", "sexta", "sábado"]
  var parts = String(isoDate || "").split("-")
  if (parts.length !== 3) return ""
  var d = new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]))
  return weekdays[d.getDay()] + ", " + d.getDate() + " de " + months[d.getMonth()]
}

function joinGlyph(kind) {
  switch (String(kind || "")) {
  case "meet": return "󰕧"
  case "zoom": return "󰕧"
  case "teams": return "󰕧"
  case "webex": return "󰕧"
  default: return "󰖟"
  }
}

function joinName(kind) {
  switch (String(kind || "")) {
  case "meet": return "Google Meet"
  case "zoom": return "Zoom"
  case "teams": return "Teams"
  case "webex": return "Webex"
  case "whereby": return "Whereby"
  case "jitsi": return "Jitsi"
  case "chime": return "Chime"
  case "slack": return "Slack"
  case "": return ""
  default: return "videochamada"
  }
}

function statusMark(event) {
  if (!event) return ""
  switch (String(event.myStatus || "")) {
  case "declined": return "recusado"
  case "tentative": return "talvez"
  case "needsAction": return "sem resposta"
  default: return ""
  }
}

// Linha secundária da reunião: conta, agenda quando difere, sala/local,
// status de participação e recorrência.
function metaLine(event) {
  if (!event) return ""
  var bits = [event.accountLabel || event.account]
  if (event.calendar && event.calendar !== event.account && !event.primary) bits.push(event.calendar)
  var join = joinName(event.joinKind)
  if (join) bits.push(join)
  else if (event.location) bits.push(shortTitle(event.location, 28))
  var mark = statusMark(event)
  if (mark) bits.push(mark)
  if (event.attendeeCount > 1) bits.push(event.attendeeCount + " pessoas")
  return bits.join(" · ")
}

function tooltip(payload, events, nowTs) {
  var lines = []
  var live = liveEvent(events, nowTs)
  var next = nextEvent(events, nowTs)
  if (live) lines.push("Agora: " + live.title + " (termina em " + duration(live.endTs - nowTs) + ")")
  if (next) lines.push("Depois: " + hm(next.start) + " " + next.title + " (" + relative(next, nowTs) + ")")
  if (lines.length === 0) lines.push("Sem reuniões pendentes hoje")
  if (payload && payload.stale) lines.push("(dados em cache — sem rede)")
  return lines.join("\n")
}
