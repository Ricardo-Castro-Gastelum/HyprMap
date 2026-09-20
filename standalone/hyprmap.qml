import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "Model.js" as Model

// HyprMap — standalone build for plain Hyprland + Quickshell (no Omarchy).
//
// A floating minimap in the bottom-right corner. One rectangle per workspace
// that currently has windows; each rectangle is subdivided by the real
// geometry of every open window and shows its app icon. The active workspace
// is highlighted. The surface is purely visual (empty input region,
// click-through), so it never blocks the desktop below it.
//
// Run with:  quickshell -c hyprmap
// Toggle with:  quickshell ipc -i hyprmap call hyprmap toggle
Item {
  id: root

  property bool opened: true
  property var rows: []

  readonly property int boxW: 132
  readonly property int boxH: 82
  readonly property int boxSpacing: 8
  readonly property int cardPad: 12
  readonly property int cardRadius: 18

  readonly property int wsCount: root.rows.length
  readonly property int cardContentWidth: root.wsCount > 0
    ? root.wsCount * root.boxW + (root.wsCount - 1) * root.boxSpacing
    : 0

  readonly property color accent: Qt.rgba(0.36, 0.67, 1.0, 1)
  readonly property color cardBackground: Qt.rgba(0.05, 0.06, 0.07, 0.42)
  readonly property color cardBorder: Qt.rgba(0.85, 0.9, 0.98, 0.25)
  readonly property color boxBorder: Qt.rgba(1, 1, 1, 0.45)
  readonly property color boxFill: Qt.rgba(1, 1, 1, 0.10)
  readonly property color accentFill: Qt.rgba(0.36, 0.67, 1.0, 0.16)
  readonly property color accentTint: Qt.rgba(0.36, 0.67, 1.0, 0.12)
  readonly property color textInk: Qt.rgba(1, 1, 1, 0.9)

  function iconSource(name) {
    var icon = String(name || "application-x-executable")
    var generic = icon.indexOf("application-x-executable") !== -1
    if (generic) return Quickshell.iconPath("application-x-executable", true)
    var themed = Quickshell.iconPath(icon, true)
    if (themed && themed.length > 0 && themed.indexOf("application-x-executable") === -1) return themed
    return Quickshell.iconPath("application-x-executable", true)
  }

  function refresh() {
    if (!clientsProc.running) clientsProc.running = true
  }

  Timer {
    id: refreshTimer
    interval: 700
    repeat: true
    running: true
    onTriggered: root.refresh()
  }

  IpcHandler {
    target: "hyprmap"

    function toggle(): string { root.opened = !root.opened; return "ok" }
    function show(): string { root.opened = true; return "ok" }
    function hide(): string { root.opened = false; return "ok" }
    function ping(): string { return "ok" }
  }

  Process {
    id: clientsProc
    command: ["hyprctl", "-j", "clients"]
    stdout: StdioCollector {
      id: clientsCollected
      waitForEnd: true
    }
    onExited: function(exitCode) {
      root.rows = Model.computeRows(clientsCollected.text, -1)
    }
  }

  Component.onCompleted: root.refresh()

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
      x: parent.width - card.width - 26
      y: parent.height - card.height - 26
      width: root.cardContentWidth + root.cardPad * 2
      height: root.boxH + root.cardPad * 2
      radius: root.cardRadius
      color: root.cardBackground
      border.color: root.cardBorder
      border.width: 1
      visible: root.wsCount > 0
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
            color: active ? root.accentFill : root.boxFill
            border.color: active ? root.accent : root.boxBorder
            border.width: active ? 2 : 1

            Text {
              anchors.top: parent.top
              anchors.left: parent.left
              anchors.margins: 6
              text: modelData.id
              color: root.textInk
              font.pixelSize: Math.max(10, Qt.application.font.pixelSize)
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
                color: root.accentTint
                border.color: Qt.rgba(1, 1, 1, 0.35)
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