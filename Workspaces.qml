import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "simon.workspaces-per-monitor"

  // Finds the monitor connector name (e.g. "DP-2", "HDMI-A-2") this bar surface is on
  readonly property var barWindow: root.QsWindow ? root.QsWindow.window : null
  readonly property string screenName: barWindow && barWindow.screen ? String(barWindow.screen.name || "") : ""

  function intSetting(key, fallback) {
    var v = Math.floor(Number(root.setting(key, fallback)))
    return isFinite(v) ? Math.min(99, Math.max(0, v)) : fallback
  }

  function boolSetting(key, fallback) {
    var v = root.setting(key, fallback)
    return typeof v === "boolean" ? v : fallback
  }

  readonly property int maxWorkspaceId: intSetting("maxWorkspaceId", 10)
  readonly property bool showNumberAlways: boolSetting("showNumberAlways", true)
  readonly property bool deduplicateIcons: boolSetting("deduplicateIcons", false)
  readonly property int iconSpacing: intSetting("iconSpacing", 4)
  readonly property int maxIconsPerWorkspace: intSetting("maxIconsPerWorkspace", 0)

  // Only shows workspaces assigned to the screen this bar is rendered on
  readonly property var workspaceIds: {
    var mine = root.screenName
    var values = Hyprland.workspaces.values
    var ids = []

    for (var i = 0; i < values.length; i++) {
      var workspace = values[i]
      var id = workspace.id
      if (id <= 0 || (root.maxWorkspaceId > 0 && id > root.maxWorkspaceId) || ids.indexOf(id) !== -1) continue

      if (mine) {
        var monitor = workspace.monitor
        if (!monitor || String(monitor.name || "") !== mine) continue
      }

      ids.push(id)
    }

    ids.sort(function(left, right) { return left - right })
    return ids
  }

  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i]
    }
    return null
  }

  // Window list snapshot straight from hyprctl clients
  property var wsWindows: ({})

  function applyClients(jsonText) {
    var arr
    try {
      arr = JSON.parse(String(jsonText || "[]"))
    } catch (e) {
      return
    }
    if (!(arr instanceof Array)) return

    var map = {}
    for (var i = 0; i < arr.length; i++) {
      var c = arr[i]
      if (!c || c.hidden === true || !c.workspace || !(c.workspace.id > 0)) continue
      var id = c.workspace.id
      if (!(id in map)) map[id] = []
      map[id].push({ cls: String(c.class || ""), title: String(c.title || "") })
    }
    root.wsWindows = map
  }

  Timer {
    id: clientRefreshTimer
    interval: 100
    repeat: false
    onTriggered: clientsProc.running = true
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (event.name === "openwindow" || event.name === "windowtitlev2" || event.name === "activewindow" ||
          event.name === "closewindow" || event.name === "movewindow" || event.name === "moveworkspacev2") {
        clientRefreshTimer.restart()
      }
    }
  }

  Process {
    id: clientsProc
    command: ["hyprctl", "-j", "clients"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyClients(text)
    }
  }

  Component.onCompleted: clientsProc.running = true

  // ---- Icon rules loading and matching ----
  readonly property string defaultIcon: "󰘔"
  readonly property int maxRulePatternLength: 1024
  readonly property int maxMatchInputLength: 512
  readonly property int maxIconLength: 16
  readonly property int maxCompiledRules: 1000

  readonly property string baseRulesPath: {
    var url = Qt.resolvedUrl("icons.json").toString()
    if (url.indexOf("file://") !== 0) return url
    var p = url.substring(7)
    try { p = decodeURIComponent(p) } catch (e) {}
    return p
  }
  readonly property string overrideRulesPath: Quickshell.env("HOME") + "/.config/omarchy/workspaces-icons.json"

  readonly property var fallbackRules: [
    { pattern: "firefox|zen|chrom|brave|chrome", icon: "󰈹" },
    { pattern: "kitty|foot|alacritty|ghostty|konsole|terminal", icon: "󰆍" },
    { pattern: "code|codium|zed", icon: "󰨞" }
  ]

  property var baseRules: []
  property var overrideRules: []
  property var compiledRules: []

  FileView {
    id: baseIconsFile
    path: root.baseRulesPath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.parseRuleText(baseIconsFile.text(), false)
    onLoadFailed: root.parseRuleText("", false)
  }

  FileView {
    id: overrideIconsFile
    path: root.overrideRulesPath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.parseRuleText(overrideIconsFile.text(), true)
    onLoadFailed: root.parseRuleText("", true)
  }

  function parseRuleText(text, isOverride) {
    var arr = []
    try {
      var parsed = JSON.parse(String(text || "[]"))
      if (parsed instanceof Array) {
        arr = parsed.filter(function(r) {
          return r && typeof r.pattern === "string" && r.pattern.length > 0 &&
                 r.pattern.length <= root.maxRulePatternLength &&
                 typeof r.icon === "string" && r.icon.length > 0 &&
                 r.icon.length <= root.maxIconLength
        })
      }
    } catch (e) {}
    if (isOverride) root.overrideRules = arr
    else root.baseRules = arr
    root.compileRules()
  }

  function compileRules() {
    var list = root.overrideRules.concat(root.baseRules)
    if (list.length === 0) list = root.fallbackRules
    list = list.slice(0, root.maxCompiledRules)
    var out = []
    for (var i = 0; i < list.length; i++) {
      try {
        out.push({ re: new RegExp(list[i].pattern, "i"), icon: list[i].icon })
      } catch (e) {}
    }
    root.compiledRules = out
  }

  function resolveIcon(cls, title) {
    var rules = root.compiledRules
    if (title.length > root.maxMatchInputLength) title = title.substring(0, root.maxMatchInputLength)
    if (cls.length > root.maxMatchInputLength) cls = cls.substring(0, root.maxMatchInputLength)
    for (var i = 0; i < rules.length; i++) {
      if (rules[i].re.test(title)) return rules[i].icon
      if (rules[i].re.test(cls)) return rules[i].icon
    }
    return root.defaultIcon
  }

  function workspaceWindowCount(id) {
    var wins = root.wsWindows[id]
    return wins ? wins.length : 0
  }

  function isWorkspaceOccupied(id) {
    var ws = root.workspaceById(id)
    return root.workspaceWindowCount(id) > 0 || (ws !== null && ws.toplevels.values.length > 0)
  }

  function workspaceIconList(id) {
    var wins = root.wsWindows[id]
    if (!wins) return []
    var icons = []
    for (var i = 0; i < wins.length; i++) {
      var cls = String(wins[i].cls || "").toLowerCase()
      var title = String(wins[i].title || "").toLowerCase()
      var ic = (!cls && !title) ? root.defaultIcon : root.resolveIcon(cls, title)
      if (root.deduplicateIcons && icons.indexOf(ic) !== -1) continue
      icons.push(ic)
      if (root.maxIconsPerWorkspace > 0 && icons.length >= root.maxIconsPerWorkspace) break
    }
    return icons
  }

  function workspaceIconsFor(id) {
    return root.workspaceIconList(id).join(" ")
  }

  function focusWorkspace(id) {
    if (!root.bar) return
    id = Math.floor(Number(id))
    if (!isFinite(id) || id < 1) return
    root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ workspace = \"" + id + "\" })"))
  }

  function cycleWorkspace(delta) {
    if (!root.workspaceIds || root.workspaceIds.length === 0) return
    var currentId = -1
    for (var i = 0; i < root.workspaceIds.length; i++) {
      var ws = root.workspaceById(root.workspaceIds[i])
      if (ws && ws.active) {
        currentId = root.workspaceIds[i]
        break
      }
    }
    var idx = root.workspaceIds.indexOf(currentId)
    if (idx === -1) idx = 0
    var nextIdx = delta > 0 ? (idx + 1) : (idx - 1)
    if (nextIdx < 0) nextIdx = root.workspaceIds.length - 1
    if (nextIdx >= root.workspaceIds.length) nextIdx = 0
    root.focusWorkspace(root.workspaceIds[nextIdx])
  }

  // Progressive icon scaling for vertical bars
  function iconScale(count) {
    if (count <= 2) return 1.0
    return Math.max(0.5, 1.0 - 0.15 * (count - 2))
  }

  function spacingFor(px) {
    return Math.round(Style.spaceReal(3) * px / Style.font.icon)
  }

  TextMetrics {
    id: iconMetrics
    font.family: root.bar ? root.bar.fontFamily : Style.font.family
  }

  function fittedIconCount(icons, avail, basePx) {
    if (!root.vertical || avail <= 0) return icons.length
    var px = Math.floor(basePx * root.iconScale(icons.length))
    var gap = root.spacingFor(px)
    iconMetrics.font.pixelSize = px

    var ellReserve = 0
    if (icons.length > 1) {
      iconMetrics.text = "…"
      ellReserve = gap + iconMetrics.advanceWidth
    }

    var acc = 0
    var count = 0
    for (var i = 0; i < icons.length; i++) {
      iconMetrics.text = icons[i]
      var step = iconMetrics.advanceWidth + gap
      var reserve = (i < icons.length - 1) ? ellReserve : 0
      if (acc + step + reserve > avail && i > 0) break
      acc += step
      count++
    }
    return Math.max(count, 1)
  }

  readonly property color fgColor: root.bar ? root.bar.barForeground : Color.foreground
  readonly property color bgColor: root.bar ? root.bar.background : Color.background
  readonly property color activeColor: Color.bar.active || Color.accent
  readonly property color urgentColor: Color.urgent

  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)

  implicitWidth: root.vertical ? root.barSize : (root.workspaceIds.length > 0 ? pill.implicitWidth + trailingGap : 0)
  implicitHeight: root.vertical ? pill.implicitHeight : root.barSize

  Rectangle {
    id: pill
    anchors.fill: parent
    color: "transparent"
    radius: Style.spaceReal(8)
    implicitWidth: grid.implicitWidth
    implicitHeight: grid.implicitHeight

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.NoButton
      onWheel: function(wheel) {
        root.cycleWorkspace(wheel.angleDelta.y > 0 ? 1 : -1)
      }
    }

    GridLayout {
      id: grid
      anchors.fill: parent
      anchors.rightMargin: root.vertical ? 0 : root.trailingGap
      columns: root.vertical ? 1 : Math.max(1, root.workspaceIds.length)
      columnSpacing: root.vertical ? 0 : Style.spaceReal(4)
      rowSpacing: root.vertical ? Style.spaceReal(4) : 0

      Repeater {
        model: root.workspaceIds

        Rectangle {
          id: btn
          required property int modelData

          readonly property var workspace: root.workspaceById(btn.modelData)
          readonly property bool occupied: root.isWorkspaceOccupied(btn.modelData)
          readonly property bool focused: btn.workspace !== null && btn.workspace.active
          readonly property bool urgent: btn.workspace !== null && btn.workspace.urgent === true

          readonly property var iconList: root.workspaceIconList(btn.modelData)
          readonly property int windowCount: root.workspaceWindowCount(btn.modelData)
          readonly property real iconScaleFactor: root.vertical ? root.iconScale(btn.windowCount) : 1.0
          readonly property int iconPx: Math.floor(Style.font.icon * btn.iconScaleFactor)
          readonly property real contentAvail: root.vertical ? btn.width : 0

          property var fittedIcons: []
          readonly property int fittedCount: btn.fittedIcons.length

          function refit() {
            btn.fittedIcons = btn.iconList.slice(
              0, root.fittedIconCount(btn.iconList, btn.contentAvail, Style.font.icon))
          }
          onIconListChanged: btn.refit()
          onContentAvailChanged: btn.refit()
          Component.onCompleted: btn.refit()

          property bool hovered: false

          radius: Style.spaceReal(8)
          color: btn.urgent ? root.urgentColor : (btn.focused ? Util.alpha(root.fgColor, 0.22) :
                 (btn.hovered ? Util.alpha(root.fgColor, 0.12) : "transparent"))

          opacity: (btn.occupied || btn.focused) ? 1.0 : 0.5

          Layout.alignment: Qt.AlignVCenter
          Layout.fillHeight: true
          Layout.fillWidth: root.vertical

          implicitWidth: root.vertical ? root.barSize : Math.max(Style.spaceReal(22), content.implicitWidth + Style.spaceReal(14))
          implicitHeight: root.vertical ? Math.max(Style.spaceReal(24), content.implicitHeight + Style.spaceReal(8)) : root.barSize

          Row {
            id: content
            anchors.centerIn: parent
            clip: true
            spacing: Style.spaceReal(root.iconSpacing)

            // Workspace Number / Indicator
            Text {
              id: label
              text: {
                if (root.showNumberAlways || !btn.focused) {
                  return btn.modelData === 10 ? "0" : String(btn.modelData)
                } else {
                  return "\uDB85\uDCFB"
                }
              }
              color: btn.urgent ? root.bgColor : (btn.focused ? root.activeColor : root.fgColor)
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Math.floor((root.vertical ? Style.font.icon : Style.font.body) * btn.iconScaleFactor)
              renderType: Text.NativeRendering
            }

            // Horizontal icons
            Text {
              id: horizontalIcons
              visible: !root.vertical && text.length > 0
              text: root.workspaceIconsFor(btn.modelData)
              color: btn.urgent ? root.bgColor : root.fgColor
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.body
              renderType: Text.NativeRendering
            }

            // Vertical icons row
            Row {
              id: verticalIcons
              visible: root.vertical && btn.fittedIcons.length > 0
              spacing: root.spacingFor(btn.iconPx)

              Repeater {
                model: btn.fittedIcons
                Text {
                  required property var modelData
                  text: modelData
                  color: btn.urgent ? root.bgColor : root.fgColor
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: btn.iconPx
                  renderType: Text.NativeRendering
                }
              }

              Text {
                visible: btn.windowCount > 1 && btn.fittedCount < btn.windowCount
                text: "…"
                color: btn.urgent ? root.bgColor : root.fgColor
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: btn.iconPx
                renderType: Text.NativeRendering
              }
            }
          }

          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: btn.hovered = true
            onExited: btn.hovered = false
            onClicked: root.focusWorkspace(btn.modelData)
          }
        }
      }
    }
  }
}
