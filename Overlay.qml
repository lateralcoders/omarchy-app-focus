import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui

Item {
  id: root

  property var shell: null
  property var manifest: null

  property bool opened: false
  property string mode: "apps"
  property string filterText: ""
  property int selectedIndex: 0
  property int appIndex: 0
  property string status: ""
  property string activeId: ""
  property string activeLabel: ""
  property var apps: []
  property int imageRev: 0

  property string previewQueuedId: ""
  property bool previewStopping: false

  property color background: Commons.Color.menu.background
  property color foreground: Commons.Color.menu.text
  property color border: Commons.Color.menu.border
  property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  property color scrim: Commons.Color.menu.scrim
  property color selectedBackground: Commons.Color.menu.selectedBackground
  property color selectedText: Commons.Color.menu.selectedText
  readonly property int cornerRadius: Style.cornerRadius
  property string fontFamily: Style.font.menuFamily
  property int contentSpacing: Style.spacing.md
  property int headerHeight: Math.max(Style.space(34), Style.font.title + Style.spacing.controlPaddingY * 2)
  property int rowHeight: Math.max(Style.space(46), Style.font.body + Style.font.caption + Style.spacing.sm)
  property int appCardWidth: Math.min(Style.space(480), panel.width - Style.gapsOut * 2)
  property int windowCardWidth: Math.min(Style.space(920), panel.width - Style.gapsOut * 2)
  property int windowCardHeight: Math.min(Style.space(680), panel.height - Style.gapsOut * 2)

  function fittedAppHeight() {
    var rows = Math.max(1, appModel.count)
    var statusExtra = root.status !== "" ? Style.font.body + root.contentSpacing : 0
    var wanted = root.headerHeight + statusExtra + Style.font.caption + root.contentSpacing * 3
    wanted += rows * (root.rowHeight + Style.space(2))
    wanted += Style.spacing.panelPadding * 2 + Style.space(28)
    var maxHeight = Math.min(Style.space(640), Math.max(Style.space(220), panel.height - Style.gapsOut * 2))
    return Math.max(Style.space(200), Math.min(maxHeight, wanted))
  }

  function pluginId() {
    return (root.manifest && root.manifest.id) || "io.github.lateralcoders.app-focus"
  }

  function helperPath() {
    var url = String(Qt.resolvedUrl("app-focus"))
    if (url.indexOf("file://") === 0)
      return decodeURIComponent(url.slice("file://".length))
    return url
  }

  function imageUrl(path) {
    if (!path) return ""
    return "file://" + encodeURI(String(path)) + "#" + root.imageRev
  }

  function open(payload) {
    root.opened = true
    root.mode = "apps"
    root.filterText = ""
    root.selectedIndex = 0
    root.appIndex = 0
    root.activeId = ""
    root.activeLabel = ""
    root.status = "Looking up apps…"
    windowModel.clear()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
    root.refreshApps()
  }

  function close() {
    root.opened = false
    root.mode = "apps"
    root.filterText = ""
  }

  function dismiss() {
    root.close()
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide(root.pluginId())
  }

  function toggle(payload) {
    if (root.opened) root.dismiss()
    else root.open(payload || "")
  }

  function refreshApps() {
    if (listProc.running) {
      root.listStopping = true
      listProc.running = false
      return
    }
    root.launchList()
  }

  property bool listStopping: false

  function launchList() {
    root.listStopping = false
    listProc.command = ["/usr/bin/python3", "-I", root.helperPath(), "--json"]
    listProc.running = true
  }

  function applyApps(raw) {
    var parsed
    try {
      parsed = JSON.parse(raw)
    } catch (e) {
      root.status = "Could not read the window list"
      return
    }
    if (!Array.isArray(parsed)) {
      root.status = "Could not read the window list"
      return
    }
    root.apps = parsed
    root.status = ""
    root.rebuildApps()
  }

  function rebuildApps() {
    appModel.clear()
    var query = root.filterText.toLowerCase().trim()
    for (var i = 0; i < root.apps.length; i++) {
      var app = root.apps[i]
      var hay = ((app.label || "") + " " + (app.detail || "") + " " + (app.search || "")).toLowerCase()
      if (query && hay.indexOf(query) < 0) continue
      appModel.append({
        appId: String(app.id || ""),
        label: String(app.label || ""),
        detail: String(app.detail || ""),
        windowCount: Number(app.count || 0),
        search: String(app.search || "")
      })
    }
    if (appModel.count === 0) root.selectedIndex = 0
    else if (root.selectedIndex >= appModel.count) root.selectedIndex = appModel.count - 1
    else if (root.selectedIndex < 0) root.selectedIndex = 0
    Qt.callLater(function() {
      if (root.mode === "apps" && appModel.count > 0)
        appList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
    })
  }

  function setFilter(next) {
    root.filterText = next
    root.selectedIndex = 0
    root.rebuildApps()
  }

  function moveApp(delta) {
    if (appModel.count === 0) return
    var next = root.selectedIndex + delta
    if (next < 0) next = appModel.count - 1
    if (next >= appModel.count) next = 0
    root.selectedIndex = next
    appList.positionViewAtIndex(next, ListView.Contain)
  }

  function moveWindow(delta) {
    if (windowModel.count === 0) return
    var next = (root.selectedIndex + delta + windowModel.count) % windowModel.count
    root.selectedIndex = next
    windowList.positionViewAtIndex(next, ListView.Contain)
  }

  function confirmApp() {
    if (root.mode !== "apps" || appModel.count === 0) return
    var row = appModel.get(root.selectedIndex)
    if (!row) return
    if (Number(row.windowCount) > 1) {
      root.openWindows(String(row.appId), String(row.label))
      return
    }
    root.runActivate(String(row.appId))
  }

  function openWindows(appId, label) {
    root.appIndex = root.selectedIndex
    root.activeId = appId
    root.activeLabel = label
    root.mode = "windows"
    root.selectedIndex = 0
    root.status = "Capturing previews…"
    windowModel.clear()
    root.startPreviews(appId)
  }

  function backToApps() {
    root.mode = "apps"
    root.selectedIndex = root.appIndex
    root.status = ""
    Qt.callLater(function() {
      if (appModel.count > 0)
        appList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
    })
  }

  function startPreviews(appId) {
    root.previewQueuedId = appId
    if (previewProc.running) {
      root.previewStopping = true
      previewProc.running = false
      return
    }
    root.launchPreviews()
  }

  function launchPreviews() {
    root.previewStopping = false
    previewProc.command = ["/usr/bin/python3", "-I", root.helperPath(), "--previews", root.previewQueuedId]
    previewProc.running = true
  }

  function applyPreviews(raw) {
    var parsed
    try {
      parsed = JSON.parse(raw)
    } catch (e) {
      root.status = "Could not capture previews"
      return
    }
    if (!Array.isArray(parsed) || parsed.length === 0) {
      root.status = "Could not capture previews"
      return
    }
    windowModel.clear()
    for (var i = 0; i < parsed.length; i++) {
      windowModel.append({
        address: String(parsed[i].address || ""),
        label: String(parsed[i].label || "window"),
        image: String(parsed[i].image || "")
      })
    }
    root.imageRev += 1
    root.selectedIndex = 0
    root.status = ""
    Qt.callLater(function() {
      if (windowModel.count > 0)
        windowList.positionViewAtIndex(0, ListView.Contain)
    })
  }

  function confirmWindow() {
    if (root.mode !== "windows" || windowModel.count === 0) return
    var row = windowModel.get(root.selectedIndex)
    if (!row || !row.address) return
    root.runFocus(root.activeId, String(row.address))
  }

  function runActivate(appId) {
    if (actionProc.running) return
    actionProc.command = ["/usr/bin/python3", "-I", root.helperPath(), "--activate", appId]
    actionProc.running = true
  }

  function runFocus(appId, address) {
    if (actionProc.running) return
    actionProc.command = ["/usr/bin/python3", "-I", root.helperPath(), "--focus", appId, address]
    actionProc.running = true
  }

  function currentWindowLabel() {
    if (windowModel.count === 0) return ""
    if (root.selectedIndex < 0 || root.selectedIndex >= windowModel.count) return ""
    var row = windowModel.get(root.selectedIndex)
    return row ? String(row.label || "") : ""
  }

  function currentWindowImage() {
    if (windowModel.count === 0) return ""
    if (root.selectedIndex < 0 || root.selectedIndex >= windowModel.count) return ""
    var row = windowModel.get(root.selectedIndex)
    return row ? root.imageUrl(row.image) : ""
  }

  ListModel { id: appModel }
  ListModel { id: windowModel }

  Process {
    id: listProc
    stdout: StdioCollector {
      id: listOut
      waitForEnd: true
    }
    stderr: StdioCollector {
      id: listErr
      waitForEnd: true
    }
    onExited: function(exitCode) {
      if (root.listStopping) {
        root.listStopping = false
        root.launchList()
        return
      }
      if (!root.opened || root.mode !== "apps") return
      if (exitCode !== 0) {
        console.warn("app-focus list failed", exitCode, listErr.text)
        root.status = "Could not list apps"
        return
      }
      root.applyApps(listOut.text)
    }
  }

  Process {
    id: previewProc
    stdout: StdioCollector {
      id: previewOut
      waitForEnd: true
    }
    stderr: StdioCollector {
      id: previewErr
      waitForEnd: true
    }
    onExited: function(exitCode) {
      if (root.previewStopping) {
        root.previewStopping = false
        root.launchPreviews()
        return
      }
      if (!root.opened || root.mode !== "windows") return
      if (exitCode !== 0) {
        console.warn("app-focus previews failed", exitCode, previewErr.text)
        root.status = "Could not capture previews"
        return
      }
      root.applyPreviews(previewOut.text)
    }
  }

  Process {
    id: actionProc
    stderr: StdioCollector {
      id: actionErr
      waitForEnd: true
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        console.warn("app-focus action failed", exitCode, actionErr.text)
        root.status = "Could not focus that window"
        return
      }
      root.dismiss()
    }
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-app-focus"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      color: root.scrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.dismiss()
    }

    BorderSurface {
      id: card
      width: root.mode === "windows" ? root.windowCardWidth : root.appCardWidth
      height: root.mode === "windows" ? root.windowCardHeight : root.fittedAppHeight()
      radius: root.cornerRadius
      anchors.centerIn: parent
      color: root.background
      borderSpec: root.borderSpec
      padding: Style.spacing.panelPadding

      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true

        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Escape) {
            if (root.mode === "windows") root.backToApps()
            else if (root.filterText) root.setFilter("")
            else root.dismiss()
            event.accepted = true
          } else if (root.mode === "apps" && Util.editsFilter(event, root.filterText)) {
            root.setFilter(Util.editedFilter(event, root.filterText))
            event.accepted = true
          } else if (event.key === Qt.Key_Up) {
            if (root.mode === "windows") root.moveWindow(-1)
            else root.moveApp(-1)
            event.accepted = true
          } else if (event.key === Qt.Key_Down) {
            if (root.mode === "windows") root.moveWindow(1)
            else root.moveApp(1)
            event.accepted = true
          } else if (event.key === Qt.Key_Left) {
            if (root.mode === "windows") root.moveWindow(-1)
            event.accepted = true
          } else if (event.key === Qt.Key_Right) {
            if (root.mode === "windows") root.moveWindow(1)
            event.accepted = true
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (root.mode === "windows") root.confirmWindow()
            else root.confirmApp()
            event.accepted = true
          } else if (root.mode === "apps" && event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 32 && event.text.charCodeAt(0) !== 127) {
            root.setFilter(root.filterText + event.text)
            event.accepted = true
          }
        }
      }

      ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset
        spacing: root.contentSpacing

        Text {
          Layout.fillWidth: true
          Layout.preferredHeight: root.headerHeight
          verticalAlignment: Text.AlignVCenter
          textFormat: Text.PlainText
          text: root.mode === "windows" ? (root.activeLabel || "Windows") : (root.filterText || "Type an app name")
          color: root.foreground
          opacity: root.mode === "apps" && !root.filterText ? 0.58 : 1
          font.family: root.fontFamily
          font.pixelSize: Style.font.heading
          elide: Text.ElideRight
        }

        Text {
          Layout.fillWidth: true
          visible: root.status !== ""
          textFormat: Text.PlainText
          text: root.status
          color: root.foreground
          opacity: 0.72
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
        }

        Item {
          Layout.fillWidth: true
          Layout.fillHeight: true
          visible: root.mode === "apps"

          ListView {
            id: appList
            anchors.fill: parent
            model: appModel
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            spacing: Style.space(2)

            delegate: Rectangle {
              required property int index
              required property string appId
              required property string label
              required property string detail
              required property real windowCount
              required property string search
              width: appList.width
              height: root.rowHeight
              radius: Style.space(6)
              color: index === root.selectedIndex ? root.selectedBackground : "transparent"

              Column {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Style.spacing.sm
                anchors.rightMargin: Style.spacing.sm

                Text {
                  width: parent.width
                  textFormat: Text.PlainText
                  text: label
                  color: index === root.selectedIndex ? root.selectedText : root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  elide: Text.ElideRight
                }
                Text {
                  width: parent.width
                  textFormat: Text.PlainText
                  text: detail
                  color: index === root.selectedIndex ? root.selectedText : root.foreground
                  opacity: index === root.selectedIndex ? 0.8 : 0.62
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                }
              }

              MouseArea {
                anchors.fill: parent
                onClicked: {
                  root.selectedIndex = index
                  root.confirmApp()
                }
              }
            }
          }

          Text {
            anchors.centerIn: parent
            visible: appModel.count === 0 && root.status === ""
            textFormat: Text.PlainText
            text: "Nothing matches"
            color: root.foreground
            opacity: 0.58
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          Layout.fillHeight: true
          visible: root.mode === "windows"
          spacing: root.contentSpacing

          Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Style.space(6)
            color: "transparent"
            border.width: Math.max(1, Style.space(1))
            border.color: root.border

            Image {
              id: stage
              anchors.fill: parent
              anchors.margins: Style.space(8)
              source: root.currentWindowImage()
              fillMode: Image.PreserveAspectFit
              smooth: true
              asynchronous: true
              cache: false
            }

            MouseArea {
              anchors.fill: parent
              enabled: windowModel.count > 0
              onClicked: root.confirmWindow()
            }
          }

          Text {
            Layout.fillWidth: true
            textFormat: Text.PlainText
            text: root.currentWindowLabel()
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            elide: Text.ElideRight
          }

          ListView {
            id: windowList
            Layout.fillWidth: true
            Layout.preferredHeight: Style.space(78)
            orientation: ListView.Horizontal
            model: windowModel
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            spacing: Style.space(8)

            delegate: Rectangle {
              required property int index
              required property string address
              required property string label
              required property string image
              width: Style.space(112)
              height: Style.space(72)
              radius: Style.space(4)
              color: "transparent"
              border.width: index === root.selectedIndex ? Math.max(2, Style.space(2)) : Math.max(1, Style.space(1))
              border.color: index === root.selectedIndex ? root.selectedBackground : root.border

              Image {
                anchors.fill: parent
                anchors.margins: Style.space(3)
                source: root.imageUrl(image)
                fillMode: Image.PreserveAspectFit
                smooth: true
                asynchronous: true
                cache: false
              }

              MouseArea {
                anchors.fill: parent
                onClicked: {
                  if (root.selectedIndex === index) root.confirmWindow()
                  else {
                    root.selectedIndex = index
                    windowList.positionViewAtIndex(index, ListView.Contain)
                  }
                }
              }
            }
          }
        }

        Text {
          Layout.fillWidth: true
          textFormat: Text.PlainText
          text: root.mode === "windows"
                ? "Arrows move  ·  Enter focuses  ·  Esc back"
                : "Enter focuses or launches  ·  Esc closes"
          color: root.foreground
          opacity: 0.5
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }
    }
  }
}
