import QtQuick

Rectangle {
    id: bar
    height: 36
    gradient: Gradient {
        orientation: Gradient.Vertical
        GradientStop {
            position: 0.0
            color: "#E6202022"
        }
        GradientStop {
            position: 1.0
            color: "#D218181A"
        }
    }
    border.color: "#26FFFFFF"
    border.width: 1

    Item {
        id: appsBtn

        width: 24
        height: 24
        anchors {
            left: parent.left
            leftMargin: 12
            verticalCenter: parent.verticalCenter
        }

        Repeater {
            model: 9
            Rectangle {
                width: 4
                height: 4
                radius: 2
                color: btnMa.containsMouse ? "#FFFFFF" : "#C8FFFFFF"
                x: 3 + (index % 3) * 7
                y: 3 + Math.floor(index / 3) * 7
            }
        }

        MouseArea {
            id: btnMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: bridge.toggleApps()
        }
    }

    Workspaces {
        anchors {
            left: parent.left
            leftMargin: 46
            verticalCenter: parent.verticalCenter
        }
    }

    Text {
        anchors.centerIn: parent
        text: bridge.activeName
        color: "#E8FFFFFF"
        font.family: "SF Pro Display"
        font.pixelSize: 13
        font.weight: Font.DemiBold
        elide: Text.ElideRight
        width: Math.min(implicitWidth, parent.width - 260)
    }

    Clock {
        id: clock
        anchors {
            right: parent.right
            rightMargin: 14
            verticalCenter: parent.verticalCenter
        }
    }

    Loader {
        anchors {
            right: clock.left
            rightMargin: 16
            verticalCenter: parent.verticalCenter
        }
        active: bridge.viewPrimary === true
        sourceComponent: Tray {}
    }
}
