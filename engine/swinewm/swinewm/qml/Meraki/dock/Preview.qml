import QtQuick
import Meraki 1.0
import "../glass"

Item {
    id: panel

    readonly property bool shown: root.hovered && root.hoverIndex >= 0 &&
        root.items[root.hoverIndex].wins.length > 0 &&
        root.items[root.hoverIndex].wins[0].window > 0
    readonly property var win: shown ? root.items[root.hoverIndex].wins[0] : null

    width: 232
    height: 168
    visible: shown && opacity > 0.01
    opacity: shown ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 130 } }

    x: Math.max(6, Math.min(root.width - width - 6, root.mx - width / 2))
    y: root.height - root.margin - root.bottomPad - root.iconSize * root.scaleAt(root.hoverIndex) - height - 12

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
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: 8
        }
        height: 116
        hwnd: panel.win ? panel.win.window : 0
        visible: panel.shown
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
            anchors.centerIn: parent
            width: parent.width - 12
            text: panel.win && panel.win.title.length > 42
                ? panel.win.title.slice(0, 42) + "…"
                : (panel.win ? panel.win.title : "")
            color: "#F2FFFFFF"
            font.family: "SF Pro Display"
            font.pixelSize: 11
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
