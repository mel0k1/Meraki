import QtQuick

Item {
    id: clock
    width: row.width + 20
    height: 24

    property string timeText: Qt.formatDateTime(new Date(), "HH:mm")
    property string dateText: Qt.formatDateTime(new Date(), "d MMM")
    property bool open: bridge.centerOpen
    property int unread: bridge.centerCount

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            clock.timeText = Qt.formatDateTime(new Date(), "HH:mm")
            clock.dateText = Qt.formatDateTime(new Date(), "d MMM")
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: ma.containsMouse || clock.open
            ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 8

        Text {
            text: clock.dateText
            color: "#99FFFFFF"
            font.family: "SF Pro Display"
            font.pixelSize: 13
        }

        Text {
            text: clock.timeText
            color: "#F2FFFFFF"
            font.family: "SF Pro Display"
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }
    }

    Rectangle {
        anchors.right: row.right
        anchors.rightMargin: -4
        anchors.top: row.top
        anchors.topMargin: -2
        width: 5
        height: 5
        radius: 2.5
        color: "#FF6B5E"
        visible: clock.unread > 0 && !clock.open
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: bridge.toggleCenter()
    }
}
