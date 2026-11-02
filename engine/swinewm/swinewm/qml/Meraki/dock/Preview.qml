import QtQuick
import Meraki 1.0
import "../glass"

Item {
    id: panel

    readonly property var slot: root.hovered && root.hoverIndex >= 0
        ? root.items[root.hoverIndex] : null
    readonly property int clamped: slot && slot.wins.length
        ? Math.min(winIndex, slot.wins.length - 1) : 0
    readonly property bool shown: slot !== null && slot.wins.length > 0 &&
        slot.wins[clamped].window > 0
    readonly property var win: shown ? slot.wins[clamped] : null
    // Свёрнутое окно не захватить живьём: показываем иконку приложения.
    readonly property bool iconic: shown && panel.win.id < 0
    readonly property bool multi: shown && slot.wins.length > 1
    property int winIndex: 0

    width: 232
    height: 168
    visible: shown && opacity > 0.01
    opacity: shown ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 130 } }

    x: Math.max(6, Math.min(root.width - width - 6, root.mx - width / 2))
    y: root.height - root.margin - root.bottomPad - root.iconSize * root.scaleAt(root.hoverIndex) - height - 12

    Connections {
        target: root
        function onHoverKeyChanged() { panel.winIndex = 0 }
    }

    LiquidGlass {
        anchors.fill: parent
        backdrop: backdrop
        cornerRadius: 16
        bezel: Math.min(height * 0.36, 26)
        thickness: 24
        dispersion: 0.06
        lensMagnify: 0.0
        rim: 0.45 * 0.20
        grain: 0.009
        tintMix: 0.42 * 0.55
        saturation: 1.25
        dark: true
        glassBlur: 13
        captureWidth: panel.width
    }

    LiveThumb {
        id: thumb
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: 8
        }
        height: 116
        hwnd: panel.win && !panel.iconic ? panel.win.window : 0
        visible: panel.shown && !panel.iconic

        MouseArea {
            anchors.fill: parent
            enabled: panel.shown
            cursorShape: Qt.PointingHandCursor
            onClicked: bridge.focusWindow(panel.win.id)
        }
    }

    Item {
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: 8
        }
        height: 116
        visible: panel.iconic

        Image {
            anchors.centerIn: parent
            width: 72
            height: 72
            source: panel.slot ? "image://dockicon/" + panel.slot.key : ""
            sourceSize: Qt.size(96, 96)
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: bridge.restoreWindow(panel.win.window)
        }
    }

    Rectangle {
        id: closeBtn
        anchors {
            top: parent.top
            right: parent.right
            margins: 13
        }
        width: 18
        height: 18
        radius: 9
        color: closeMa.containsMouse
            ? "#E8614C" : Qt.rgba(0.10, 0.10, 0.12, 0.62)
        visible: panel.shown

        Text {
            anchors.centerIn: parent
            text: "×"
            color: "#F2FFFFFF"
            font.pixelSize: 12
            font.weight: Font.DemiBold
        }

        MouseArea {
            id: closeMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (panel.win.id < 0) {
                    bridge.closeHwnd(-panel.win.id)
                } else {
                    bridge.closeWindow(panel.win.id)
                }
            }
        }
    }

    Rectangle {
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            margins: 8
        }
        height: 24
        radius: 8
        color: Qt.rgba(0.10, 0.10, 0.12, 0.55)

        Text {
            id: prevBtn
            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            text: "‹"
            color: prevMa.containsMouse ? "#F2FFFFFF" : "#8CFFFFFF"
            visible: panel.multi
            font.pixelSize: 13
            font.weight: Font.DemiBold

            MouseArea {
                id: prevMa
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    var n = panel.slot.wins.length
                    panel.winIndex = (panel.winIndex + n - 1) % n
                }
            }
        }

        Text {
            anchors.centerIn: parent
            width: parent.width - (panel.multi ? 44 : 12)
            text: {
                if (!panel.win) return ""
                var t = panel.win.title
                if (panel.multi) {
                    t += "  ·  " + (panel.clamped + 1) + "/" + panel.slot.wins.length
                }
                return t
            }
            color: "#F2FFFFFF"
            font.family: "SF Pro Display"
            font.pixelSize: 11
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            id: nextBtn
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            text: "›"
            color: nextMa.containsMouse ? "#F2FFFFFF" : "#8CFFFFFF"
            visible: panel.multi
            font.pixelSize: 13
            font.weight: Font.DemiBold

            MouseArea {
                id: nextMa
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    var n = panel.slot.wins.length
                    panel.winIndex = (panel.winIndex + 1) % n
                }
            }
        }
    }
}
