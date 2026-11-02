import QtQuick

// Часы в стиле MacBar: дата приглушённым цветом, время полужирное,
// пилюля при наведении; клик — календарь-поповер, уведомления переехали
// на колокольчик в Status.
Item {
    id: clock

    width: row.width + 18
    height: 22

    property string timeText: Qt.formatDateTime(new Date(), "HH:mm")
    property string dateText: Qt.formatDateTime(new Date(), "ddd d MMM")

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            clock.timeText = Qt.formatDateTime(new Date(), "HH:mm")
            clock.dateText = Qt.formatDateTime(new Date(), "ddd d MMM")
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: parent.width - 2
        height: parent.height - 4
        radius: 6
        color: ma.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : "transparent"
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

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            var p = clock.mapToItem(null, 0, 0)
            bridge.showCalendar(p.x + viewX, p.y + viewY + clock.height)
        }
    }
}
