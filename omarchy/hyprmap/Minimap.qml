import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "Model.js" as Model

// HyprMap: a floating minimap in the bottom-right corner. One rectangle per
// workspace that currently has windows; each rectangle is subdivided by the
// real geometry of every open window and shows its app icon. The active
// workspace is highlighted. The surface is purely visual (empty input region,
// click-through), so it never blocks the desktop below it.
//
// Requires the Omarchy shell. Invoke with:
//   omarchy-shell shell toggle hyprmap
Item {
  id: root

  property var shell: null
  property var manifest: null

  property bool opened: false
  property var rows: []

  readonly property int boxW: 132
  readonly property int boxH: 82
  readonly property int boxSpacing: 8
  readonly property int cardPad: Style.space(12)
  readonly property int cardRadius: 18

  readonly property int wsCount: root.rows.length
  readonly property int cardContentWidth: root.wsCount > 0
    ? root.wsCount * root.boxW + (root.wsCount - 1) * root.boxSpacing
    : 0

  function activeWorkspaceId() {
    return Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1
  }

  function open(payloadJson) {
    root.rows = []
    if (!clientsProc.running) clientsProc.running = true
    root.opened = true
  }

  function close() {
    root.opened = false
  }

  function iconSource(name) {
    var icon = String(name || "application-x-executable")
    var generic = icon.indexOf("application-x-executable") !== -1
    if (!generic && root.shell && root.shell.appLibrary) {
      var via = root.shell.appLibrary.iconSource(icon)
      if (via && via.length > 0 && via.indexOf("application-x-executable") === -1) return via
    }
    if (generic) return Quickshell.iconPath("application-x-executable", true)
    var themed = Quickshell.iconPath(icon, true)
    if (themed && themed.length > 0 && themed.indexOf("application-x-executable") === -1) return themed
    return Quickshell.iconPath("application-x-executable", true)
  }

  Timer {
    id: refreshTimer
    interval: 700
    repeat: true
    running: root.opened
    onTriggered: if (!clientsProc.running) clientsProc.running = true
  }

  IpcHandler {
    target: "hyprmap"

    function ping(): string { return "ok" }
    function state(): string { return root.opened ? "open" : "closed" }
  }

  Process {
    id: clientsProc
    command: ["hyprctl", "-j", "clients"]
    stdout: StdioCollector {
      id: clientsCollected
      waitForEnd: true
    }
    onExited: function(exitCode) {
      root.rows = Model.computeRows(clientsCollected.text, root.activeWorkspaceId())
    }
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "hyprmap"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    // Purely visual surface: empty input region so clicks pass through.
    mask: Region {}

    Rectangle {
      id: card
      x: parent.width - card.width - Style.space(26)
      y: parent.height - card.height - Style.space(26)
      width: root.cardContentWidth + root.cardPad * 2
      height: root.boxH + root.cardPad * 2
      radius: root.cardRadius
      color: Util.alpha(Color.background, 0.42)
      border.color: Util.alpha(Color.popups.border, 0.6)
      border.width: 1
      visible: root.opened && root.wsCount > 0
      opacity: root.opened ? 1 : 0
      Behavior on opacity {
        enabled: root.opened
        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
      }

      Row {
        id: wsRow
        anchors.topMargin: root.cardPad
        anchors.rightMargin: root.cardPad
        anchors.bottomMargin: root.cardPad
        anchors.leftMargin: root.cardPad
        anchors.fill: parent
        spacing: root.boxSpacing

        Repeater {
          model: root.rows

          delegate: Rectangle {
            id: wsBox
            required property var modelData
            readonly property bool active: modelData.active

            width: root.boxW
            height: root.boxH
            radius: 9
            color: active ? Util.alpha(Color.accent, 0.16) : Util.alpha(Color.popups.border, 0.10)
            border.color: active ? Color.accent : Util.alpha(Color.popups.border, 0.45)
            border.width: active ? 2 : 1

            Text {
              anchors.top: parent.top
              anchors.left: parent.left
              anchors.margins: 6
              text: modelData.id
              color: Util.alpha(Color.popups.text, active ? 1 : 0.55)
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: active
            }

            Repeater {
              model: modelData.windows

              delegate: Rectangle {
                id: winRect
                required property var modelData

                x: modelData.cx * wsBox.width
                y: modelData.cy * wsBox.height
                width: modelData.cw * wsBox.width
                height: modelData.ch * wsBox.height
                radius: 4
                color: Util.alpha(Color.accent, 0.12)
                border.color: Util.alpha(Color.popups.border, 0.35)
                border.width: 1
                clip: true

                Image {
                  width: Math.max(6, Math.min(parent.width, parent.height) * 0.5)
                  height: width
                  anchors.centerIn: parent
                  sourceSize.width: width * 2
                  sourceSize.height: width * 2
                  source: root.iconSource(modelData.icon)
                  fillMode: Image.PreserveAspectFit
                  mipmap: true
                  smooth: true
                }
              }
            }
          }
        }
      }
    }
  }
}