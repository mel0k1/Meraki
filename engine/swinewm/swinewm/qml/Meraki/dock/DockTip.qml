import QtQuick

Rectangle {
    id: tip

    readonly property bool shown: root.hovered && root.hoverIndex >= 0
    readonly property string label: shown ? root.items[root.hoverIndex].name : ""

    visible: shown && opacity > 0.01
    opacity: shown ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 120 } }

    width: tipLabel.implicitWidth + 24
    height: 24
    radius: 12
    color: Qt.rgba(0.12, 0.12, 0.14, 0.80)
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.16)

    x: Math.max(6, Math.min(root.width - width - 6, root.mx - width / 2))
    y: root.height - root.margin - root.bottomPad - root.iconSize * root.scaleAt(root.hoverIndex) - height - 10

    Text {
        id: tipLabel
        anchors.centerIn: parent
        text: tip.label
        color: "#F2FFFFFF"
        font.family: "SF Pro Display"
        font.pixelSize: 12
        font.weight: Font.Medium
    }
}
