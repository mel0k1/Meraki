import QtQuick

Row {
    id: row
    spacing: 6

    Repeater {
        model: bridge.workspaces

        Rectangle {
            id: pill
            required property var modelData
            radius: 9
            height: 22
            width: label.implicitWidth + 18
            color: modelData.focused ? "#66FFFFFF" : (modelData.urgent ? "#66FF5A52" : "#22FFFFFF")
            border.color: modelData.focused ? "#66FFFFFF" : "#1FFFFFFF"
            border.width: 1

            Text {
                id: label
                anchors.centerIn: parent
                text: pill.modelData.name
                color: pill.modelData.focused ? "#FF101014" : "#D8FFFFFF"
                font.family: "SF Pro Display"
                font.pixelSize: 12
                font.weight: pill.modelData.focused ? Font.Bold : Font.Medium
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: bridge.switchTo(pill.modelData.num)
            }
        }
    }
}
