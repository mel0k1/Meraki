import QtQuick

// Часы в стиле MacBar: дата приглушённым цветом, время полужирное,
// пилюля при наведении, красная точка — счётчик уведомлений.
Item {
    id: clock

    width: row.width + 18
    height: 22

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
        anchors.centerIn: parent
        width: parent.width - 2
        height: parent.height - 4
        radius: 6
        color: ma.containsMouse || clock.open
            ? Qt.rgba(1, 1, 1, 0.14) : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: clock.dateText
            color: "#B3FFFFFF"
            font.pixelSize: 12
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: clock.timeText
            color: "#F2FFFFFF"
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
