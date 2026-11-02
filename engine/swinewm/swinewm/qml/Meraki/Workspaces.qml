import QtQuick

// Воркспейсы в стиле MacBar: минимализм, только номера; текущий —
// полупрозрачная пилюля и полужирный текст.
Row {
    id: row

    height: 28

    Repeater {
        model: bridge.workspaces

        Item {
            id: ws

            required property var modelData

            width: 22
            height: 28

            Rectangle {
                anchors.centerIn: parent
                width: parent.width - 2
                height: parent.height - 6
                radius: 6
                color: Qt.rgba(1, 1, 1, 0.16)
                opacity: ws.modelData.focused || wsMa.containsMouse ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 140 } }
            }

            Text {
                anchors.centerIn: parent
                text: ws.modelData.num
                color: ws.modelData.focused ? "#F2FFFFFF"
                    : (ws.modelData.urgent ? "#FFFF8B7E" : "#99FFFFFF")
                font.pixelSize: 13
                font.weight: ws.modelData.focused ? Font.DemiBold : Font.Normal
                Behavior on color { ColorAnimation { duration: 140 } }
            }

            MouseArea {
                id: wsMa

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: bridge.switchTo(ws.modelData.num)
            }
        }
    }
}
