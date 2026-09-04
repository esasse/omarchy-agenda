import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "Model.js" as Model

// Runs the `omarchy-agenda today --json` helper and keeps the day in memory.
// All the talking-to-Google lives in the helper; what is left here is the
// lifecycle: periodic poll, a clock for the countdowns, and the one-click
// actions.
Item {
  id: root

  property var settings: ({})
  property string helperPath: ""

  property var payload: ({})
  property var events: []
  property var errors: []
  property string date: ""
  property bool needsSetup: false
  property bool needsLogin: false
  property bool stale: false
  property bool loading: false
  property string lastError: ""
  property double lastFetch: 0
  property double nowTs: Date.now() / 1000

  readonly property int refreshIntervalSec: intSetting("refreshIntervalSec", 180, 30, 3600)
  readonly property int barLabelChars: intSetting("barLabelChars", 22, 6, 60)
  readonly property bool ready: helperPath !== ""

  readonly property var liveEvent: Model.liveEvent(events, nowTs)
  readonly property var nextEvent: Model.nextEvent(events, nowTs)
  readonly property var focusEvent: Model.focusEvent(events, nowTs)
  readonly property bool configured: !needsSetup && !needsLogin

  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  function intSetting(name, fallback, min, max) {
    var n = parseInt(String(setting(name, fallback)), 10)
    if (!isFinite(n)) n = fallback
    return Math.max(min, Math.min(max, n))
  }

  function refresh(force) {
    if (!ready || fetchProcess.running) return
    if (!force && lastFetch > 0 && (Date.now() / 1000 - lastFetch) < 20) return
    loading = true
    fetchProcess.command = ["python3", helperPath, "today", "--json"]
    fetchProcess.running = true
  }

  function apply(raw) {
    var parsed = null
    try {
      parsed = JSON.parse(String(raw || ""))
    } catch (e) {
      lastError = "invalid response from the helper"
      return
    }
    if (!parsed || typeof parsed !== "object") return

    payload = parsed
    events = parsed.events || []
    errors = parsed.errors || []
    date = String(parsed.date || "")
    needsSetup = parsed.needsSetup === true
    needsLogin = parsed.needsLogin === true
    stale = parsed.stale === true
    lastError = errors.length > 0 ? String(errors[0]) : ""
    lastFetch = Date.now() / 1000
    nowTs = Date.now() / 1000
  }

  // One click = join. With no video link, fall back to the event in Calendar,
  // which is the best "open this" a room-less appointment has.
  function activate(event) {
    if (!event) return
    if (event.joinUrl) openUrl(event.joinUrl)
    else if (event.htmlLink) openUrl(event.htmlLink)
  }

  function openInCalendar(event) {
    if (event && event.htmlLink) openUrl(event.htmlLink)
    else openUrl("https://calendar.google.com/calendar/r/day")
  }

  function openUrl(url) {
    if (!url) return
    Quickshell.execDetached(["omarchy-launch-browser", String(url)])
  }

  function runInTerminal(command) {
    Quickshell.execDetached(["omarchy-launch-floating-terminal-with-presentation", command])
  }

  function login() { runInTerminal("omarchy-agenda login") }
  function setup() { runInTerminal("omarchy-agenda setup") }

  Process {
    id: fetchProcess
    running: false
    command: []
    stdout: StdioCollector { id: fetchStdout; waitForEnd: true }
    stderr: StdioCollector { id: fetchStderr; waitForEnd: true }
    onExited: function(exitCode) {
      root.loading = false
      var out = String(fetchStdout.text || "")
      if (out.length > 0) {
        root.apply(out)
        return
      }
      var err = String(fetchStderr.text || "").replace(/\s+/g, " ").trim()
      root.lastError = err.length > 0 ? err.substring(0, 160)
                                      : "helper failed (exit code " + exitCode + ")"
    }
  }

  Timer {
    id: pollTimer
    interval: root.refreshIntervalSec * 1000
    repeat: true
    running: root.ready
    triggeredOnStart: true
    onTriggered: root.refresh(true)
  }

  // Keeps the countdowns ("in 12 min", "ends in 4 min") alive without hitting
  // the API, and refetches once the day has rolled over.
  Timer {
    interval: 15000
    repeat: true
    running: true
    onTriggered: {
      root.nowTs = Date.now() / 1000
      var today = Qt.formatDate(new Date(), "yyyy-MM-dd")
      if (root.date !== "" && root.date !== today) root.refresh(true)
    }
  }

  // A meeting going live: one extra API pass to pick up a link or room that
  // changed at the last minute.
  Timer {
    id: edgeTimer
    interval: 30000
    repeat: true
    running: root.ready && root.nextEvent !== null
    onTriggered: {
      var next = root.nextEvent
      if (!next) return
      var delta = next.startTs - (Date.now() / 1000)
      if (delta > 0 && delta < 90) root.refresh(true)
    }
  }
}
