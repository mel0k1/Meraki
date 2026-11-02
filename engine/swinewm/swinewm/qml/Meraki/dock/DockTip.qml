import QtQuick
import "../glass"

Item {
    id: tip

    readonly property var item: root.hovered && root.hoverIndex >= 0
        ? root.items[root.hoverIndex] : null
    readonly property bool canShow: item !== null && item.wins.length === 0
    readonly property bool bubbleVisible: shownKey !== ""
        && root.hoverKey === shownKey && canShow
    property string shownKey: ""

    readonly property string label: item ? item.name : ""
    width: Math.min(lbl.implicitWidth + 30, 240)
    height: 30

    x: Math.max(8, Math.min(root.width - width - 8, root.mx - width / 2))
    y: root.height - root.margin - root.bottomPad
        - root.iconSize * root.scaleAt(root.hoverIndex) - height - 8

    visible: opacity > 0.01
    opacity: bubbleVisible ? 1 : 0
    scale: bubbleVisible ? 1 : 0.92
    transformOrigin: Item.Bottom
    Behavior on opacity { NumberAnimation { duration: 130 } }
    Behavior on scale {
        NumberAnimation { duration: 130; easing.type: Easing.OutCubic }
    }

    Timer {
        id: delay
        interval: 260
        onTriggered: tip.shownKey = root.hoverKey
    }

    Timer {
        id: linger
        interval: 140
        onTriggered: tip.shownKey = ""
    }

    Connections {
        target: root
        function onHoverKeyChanged() {
            linger.stop()
            if (root.hoverKey === "") {
                if (tip.shownKey !== "") {
                    linger.restart()
                }
                delay.stop()
            } else if (tip.shownKey !== "") {
                tip.shownKey = root.hoverKey
            } else {
                delay.restart()
            }
        }
    }

    DockGlassPanel {
        id: bubble
        anchors.fill: parent
        cornerRadius: 14
        backdrop: backdrop

        Text {
            id: lbl
            anchors.centerIn: parent
            width: Math.min(implicitWidth, tip.width - 24)
            text: tip.label
            color: "#F2FFFFFF"
            font.family: "SF Pro Display"
            font.pixelSize: 12
            font.weight: Font.Medium
            elide: Text.ElideRight
        }
    }
}
