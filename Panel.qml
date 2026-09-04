import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Today's agenda in the bar: the label shows the meeting in progress or the
// next one, and the popup lists the whole day with one click per row to join
// the call.
Panel {
  id: root
  moduleName: "esasse.agenda"
  ipcTarget: "esasse.agenda"
  manageIpc: false

  // The helper lives inside the plugin, so the path comes from the QML rather
  // than from a PATH the shell may not have inherited.
  readonly property string helperPath: String(Qt.resolvedUrl("bin/omarchy-agenda")).replace(/^file:\/\//, "")

  readonly property bool vertical: bar ? bar.vertical : false
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color accent: Color.accent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  property int rowIndex: 0
  property bool cursorActive: false

  readonly property var rows: agenda.events
  readonly property bool hasRows: rows.length > 0
  readonly property var selectedEvent: hasRows && rowIndex >= 0 && rowIndex < rows.length
    ? rows[rowIndex] : null
  readonly property bool live: agenda.liveEvent !== null

  // The bar has to tell the truth before there is an account too: "clear"
  // with the OAuth setup still pending would be a lie.
  readonly property string barLabel: !agenda.configured
    ? "󰃭 connect"
    : Model.barLabel(agenda.events, agenda.nowTs, agenda.barLabelChars)

  function ensureCursor() {
    if (!hasRows) { rowIndex = 0; return }
    if (rowIndex >= rows.length) rowIndex = rows.length - 1
    if (rowIndex < 0) rowIndex = 0
  }

  // Opening the panel should land on the meeting that matters now, not on the
  // first one of the day — someone opening it at 3pm wants the 3pm one.
  function focusCurrentRow() {
    var target = Model.focusEvent(rows, agenda.nowTs)
    if (!target) { rowIndex = Math.max(0, rows.length - 1); return }
    for (var i = 0; i < rows.length; i++) {
      if (rows[i].id === target.id && rows[i].account === target.account) {
        rowIndex = i
        return
      }
    }
    rowIndex = 0
  }

  function moveCursor(dx, dy) {
    cursorActive = true
    ensureCursor()
    if (dy === 0 || !hasRows) return
    rowIndex = Math.max(0, Math.min(rows.length - 1, rowIndex + dy))
    scrollCursorIntoView()
  }

  function setRowCursor(index) {
    cursorActive = true
    rowIndex = index
  }

  function activateCursor() {
    if (!agenda.configured) {
      if (agenda.needsSetup) agenda.setup()
      else agenda.login()
      root.close()
      return
    }
    if (!selectedEvent) return
    agenda.activate(selectedEvent)
    root.close()
  }

  function joinFocused() {
    var target = Model.focusEvent(agenda.events, agenda.nowTs)
    if (target) agenda.activate(target)
  }

  function scrollItemIntoView(item) {
    if (!panelFlick || !item) return
    Qt.callLater(function() {
      if (!item) return
      var margin = Style.space(6)
      var point = item.mapToItem(panelFlick.contentItem, 0, 0)
      var top = point.y
      var bottom = top + item.height
      var viewTop = panelFlick.contentY
      var viewBottom = viewTop + panelFlick.height
      var maxY = Math.max(0, panelFlick.contentHeight - panelFlick.height)
      if (top < viewTop + margin) panelFlick.contentY = Math.max(0, top - margin)
      else if (bottom > viewBottom - margin) panelFlick.contentY = Math.min(maxY, bottom + margin - panelFlick.height)
    })
  }

  function scrollCursorIntoView() {
    if (rowColumn && rowIndex >= 0 && rowIndex < rowColumn.children.length)
      scrollItemIntoView(rowColumn.children[rowIndex])
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onOpenedChanged: if (opened) {
    cursorActive = false
    if (panelFlick) panelFlick.contentY = 0
    agenda.refresh(false)
    focusCurrentRow()
    Qt.callLater(function() {
      keyCatcher.forceActiveFocus()
      root.scrollCursorIntoView()
    })
  }

  Service {
    id: agenda
    settings: root.settings
    helperPath: root.helperPath
  }

  Connections {
    target: agenda
    function onEventsChanged() {
      root.ensureCursor()
      if (!root.cursorActive) root.focusCurrentRow()
    }
  }

  IpcHandler {
    target: root.ipcTarget

    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { agenda.refresh(true); return "ok" }
    function join(): string { root.joinFocused(); return "ok" }
    function next(): string {
      var e = agenda.nextEvent
      return e ? Model.timeLabel(e) + " " + e.title : "no meetings left today"
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.vertical ? "󰃭" : root.barLabel
    labelVisible: true
    active: root.live
    hasVisualContent: text !== ""
    fontSize: root.vertical ? Style.bar.iconFont : Style.font.body
    fixedWidth: root.vertical ? Style.bar.iconSlot : -1
    horizontalMargin: root.vertical ? 0 : 8.5
    tooltipText: Model.tooltip(agenda.payload, agenda.events, agenda.nowTs)

    onPressed: function(b) {
      if (b === Qt.RightButton) agenda.refresh(true)
      else if (b === Qt.MiddleButton) root.joinFocused()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(420))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(560))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (!root.cursorActive) { root.cursorActive = true; return }
        root.moveCursor(dx, dy)
      }
      onActivateRequested: root.activateCursor()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        var key = String(t || "").toLowerCase()
        if (key === "r") agenda.refresh(true)
        else if (key === "j") root.joinFocused()
        else if (key === "o") { agenda.openInCalendar(root.selectedEvent); root.close() }
        else if (key === "l") { agenda.login(); root.close() }
      }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: column
          width: panelFlick.width
          spacing: Style.space(12)

          PanelHero {
            id: hero
            width: parent.width
            title: "Today"
            meta: Model.heroMeta(agenda.payload, agenda.nowTs)
            detail: Model.dateLabel(agenda.date)
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconComponent: Component {
              Text {
                text: root.live ? "󰕧" : "󰃭"
                color: root.live ? root.urgent : root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.display
              }
            }
            trailingControl: Component {
              PanelActionButton {
                iconText: "󰑐"
                tooltipText: "Refresh (r)"
                foreground: root.foreground
                fontFamily: root.fontFamily
                enabled: !agenda.loading
                opacity: agenda.loading ? 0.4 : 1.0
                onClicked: agenda.refresh(true)
              }
            }
          }

          Text {
            visible: agenda.lastError !== "" || agenda.stale
            width: parent.width
            text: agenda.stale ? "No network — showing the last saved data." : agenda.lastError
            color: agenda.stale ? root.dim : root.urgent
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          SetupCard {
            visible: !agenda.configured
            width: parent.width
          }

          PanelSeparator {
            visible: agenda.configured
            foreground: root.foreground
          }

          Column {
            visible: agenda.configured
            width: parent.width
            spacing: Style.space(10)

            PanelSectionHeader {
              text: "TODAY'S SCHEDULE"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Text {
              visible: !root.hasRows
              width: parent.width
              text: agenda.loading ? "Loading…" : "Nothing scheduled today."
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              horizontalAlignment: Text.AlignHCenter
            }

            Column {
              id: rowColumn
              visible: root.hasRows
              width: parent.width
              spacing: Style.space(4)

              Repeater {
                model: root.rows

                EventRow {
                  required property var modelData
                  required property int index
                  width: rowColumn.width
                  event: modelData
                  rowIndex: index
                }
              }
            }
          }

          Row {
            visible: agenda.configured
            width: parent.width
            spacing: Style.space(10)

            Text {
              text: "enter join · j next · r refresh · o in Calendar"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
              width: parent.width
            }
          }
        }
      }
    }
  }

  // -------------------------------------------------------------- components

  component EventRow: CursorSurface {
    id: eventRow
    property var event: null
    property int rowIndex: 0

    readonly property string state: Model.state(event, agenda.nowTs)
    readonly property bool isLive: state === "live"
    readonly property bool isPast: state === "past"
    readonly property bool joinable: Model.isJoinable(event, agenda.nowTs)
    readonly property bool declined: Model.declined(event)

    hasCursor: root.cursorActive && root.rowIndex === rowIndex
    current: isLive
    foreground: root.foreground
    accent: isLive ? root.urgent : root.accent
    opacity: isPast || declined ? 0.45 : 1.0

    implicitHeight: rowContent.implicitHeight + Style.spacing.rowPaddingX

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: root.setRowCursor(eventRow.rowIndex)
      onClicked: {
        agenda.activate(eventRow.event)
        root.close()
      }
    }

    RowLayout {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      spacing: Style.space(8)

      // A stripe in the source calendar's color: with several accounts in one
      // list, it says where the appointment came from before you read a word.
      Rectangle {
        Layout.alignment: Qt.AlignVCenter
        Layout.preferredWidth: Style.space(3)
        Layout.preferredHeight: rowContent.implicitHeight
        radius: width / 2
        color: eventRow.event && eventRow.event.color ? eventRow.event.color : root.accent
        opacity: eventRow.isLive ? 1.0 : 0.75
      }

      ColumnLayout {
        Layout.alignment: Qt.AlignVCenter
        Layout.preferredWidth: Style.space(42)
        spacing: 0

        Text {
          text: eventRow.event && eventRow.event.allDay ? "all" : Model.hm(eventRow.event ? eventRow.event.start : "")
          color: eventRow.isLive ? root.urgent : root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
        }

        Text {
          text: eventRow.event && eventRow.event.allDay ? "day" : Model.hm(eventRow.event ? eventRow.event.end : "")
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }
      }

      ColumnLayout {
        id: rowContent
        Layout.fillWidth: true
        spacing: Style.space(1)

        Text {
          Layout.fillWidth: true
          text: eventRow.event ? eventRow.event.title : ""
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          font.strikeout: eventRow.declined
          elide: Text.ElideRight
        }

        Text {
          Layout.fillWidth: true
          text: Model.metaLine(eventRow.event)
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }

      Text {
        visible: !eventRow.isPast
        text: Model.relative(eventRow.event, agenda.nowTs)
        color: eventRow.isLive ? root.urgent : root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        Layout.alignment: Qt.AlignVCenter
      }

      PanelActionButton {
        visible: eventRow.joinable
        iconText: Model.joinGlyph(eventRow.event ? eventRow.event.joinKind : "")
        tooltipText: "Join " + Model.joinName(eventRow.event ? eventRow.event.joinKind : "")
        foreground: eventRow.isLive ? root.urgent : root.foreground
        fontFamily: root.fontFamily
        Layout.alignment: Qt.AlignVCenter
        onHovered: function(on) { if (on) root.setRowCursor(eventRow.rowIndex) }
        onClicked: {
          agenda.activate(eventRow.event)
          root.close()
        }
      }
    }
  }

  component SetupCard: CursorSurface {
    id: setupCard

    hasCursor: root.cursorActive
    foreground: root.foreground
    implicitHeight: setupContent.implicitHeight + Style.spacing.rowPaddingX

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: root.cursorActive = true
      onClicked: {
        if (agenda.needsSetup) agenda.setup()
        else agenda.login()
        root.close()
      }
    }

    RowLayout {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      spacing: Style.space(8)

      Text {
        text: "󰌋"
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.heading
        Layout.alignment: Qt.AlignVCenter
      }

      ColumnLayout {
        id: setupContent
        Layout.fillWidth: true
        spacing: Style.space(1)

        Text {
          Layout.fillWidth: true
          text: agenda.needsSetup ? "Set up Google access" : "Connect a Google account"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
        }

        Text {
          Layout.fillWidth: true
          text: agenda.needsSetup ? "opens a terminal running omarchy-agenda setup"
                                  : "opens a terminal running omarchy-agenda login"
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }
      }
    }
  }
}
