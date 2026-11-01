import QtQuick

Item {
    id: clock
    width: row.width
    height: 22

    property string timeText: Qt.formatDateTime(new Date(), "HH:mm")
    property string dateText: Qt.formatDateTime(new Date(), "d MMM")

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

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
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
}
