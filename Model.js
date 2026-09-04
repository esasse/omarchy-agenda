// Formatting and derivations for the agenda. Stateless: it takes the helper's
// payload (omarchy-agenda today --json) and returns what the UI has to draw.

var SOON_SEC = 10 * 60          // "starting soon"
var GRACE_SEC = 5 * 60          // a meeting is still joinable after it ends

function hm(iso) {
  var s = String(iso || "")
  return s.length >= 16 ? s.substring(11, 16) : ""
}

function timeLabel(event) {
  if (!event) return ""
  return event.allDay ? "all day" : hm(event.start)
}

function rangeLabel(event) {
  if (!event) return ""
  if (event.allDay) return "all day"
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

// "in 25 min" / "now" / "10 min ago", always relative to the event's start.
function relative(event, nowTs) {
  if (!event) return ""
  if (event.allDay) return "today"
  var delta = event.startTs - nowTs
  if (delta > 30) return "in " + duration(delta)
  if (event.endTs > nowTs) return "now"
  return duration(nowTs - event.startTs) + " ago"
}

// past | live | soon | future — drives the row's color and emphasis.
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

// The meeting happening right now (the one ending first, when they overlap).
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

// What a middle click on the bar (and Enter on an empty panel) should open:
// the meeting in progress wins over the next one.
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

// Compact bar text. On a vertical bar only the icon survives.
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
  return pending > 0 ? "󰃭 day's done" : "󰃭 clear"
}

function heroMeta(payload, nowTs) {
  if (!payload) return "loading…"
  if (payload.needsSetup) return "setup pending"
  if (payload.needsLogin) return "no account connected"
  var events = payload.events || []
  if (events.length === 0) return "nothing scheduled"
  var left = remaining(events, nowTs)
  var meetings = 0
  for (var i = 0; i < events.length; i++) if (events[i].joinUrl) meetings += 1
  var parts = [events.length + (events.length === 1 ? " event" : " events")]
  if (meetings > 0) parts.push(meetings + (meetings === 1 ? " meeting" : " meetings"))
  var live = liveEvent(events, nowTs)
  var next = nextEvent(events, nowTs)
  if (live) parts.push("now until " + hm(live.end))
  else if (next) parts.push("next " + relative(next, nowTs))
  else if (left === 0) parts.push("all done")
  return parts.join(" · ")
}

function dateLabel(isoDate) {
  var months = ["January", "February", "March", "April", "May", "June",
                "July", "August", "September", "October", "November", "December"]
  var weekdays = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday",
                  "Friday", "Saturday"]
  var parts = String(isoDate || "").split("-")
  if (parts.length !== 3) return ""
  var d = new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]))
  return weekdays[d.getDay()] + ", " + months[d.getMonth()] + " " + d.getDate()
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
  default: return "video call"
  }
}

function statusMark(event) {
  if (!event) return ""
  switch (String(event.myStatus || "")) {
  case "declined": return "declined"
  case "tentative": return "tentative"
  case "needsAction": return "no reply"
  default: return ""
  }
}

// A meeting's second line: account, calendar when it differs, room/location,
// RSVP status and guest count.
function metaLine(event) {
  if (!event) return ""
  var bits = [event.accountLabel || event.account]
  if (event.calendar && event.calendar !== event.account && !event.primary) bits.push(event.calendar)
  var join = joinName(event.joinKind)
  if (join) bits.push(join)
  else if (event.location) bits.push(shortTitle(event.location, 28))
  var mark = statusMark(event)
  if (mark) bits.push(mark)
  if (event.attendeeCount > 1) bits.push(event.attendeeCount + " guests")
  return bits.join(" · ")
}

function tooltip(payload, events, nowTs) {
  var lines = []
  var live = liveEvent(events, nowTs)
  var next = nextEvent(events, nowTs)
  if (live) lines.push("Now: " + live.title + " (ends in " + duration(live.endTs - nowTs) + ")")
  if (next) lines.push("Next: " + hm(next.start) + " " + next.title + " (" + relative(next, nowTs) + ")")
  if (lines.length === 0) lines.push("No meetings left today")
  if (payload && payload.stale) lines.push("(cached — no network)")
  return lines.join("\n")
}
