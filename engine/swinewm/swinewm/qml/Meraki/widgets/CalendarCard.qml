import QtQuick
import "../glass"

Item {
    id: w

    property Item backdrop
    property var now: new Date()
    readonly property var loc: Qt.locale()

    function firstOffset() {
        var d = new Date(w.now.getFullYear(), w.now.getMonth(), 1)
        var dw = d.getDay() === 0 ? 7 : d.getDay()
        return (dw - w.loc.firstDayOfWeek + 7) % 7
    }

    function daysInMonth() {
        return new Date(w.now.getFullYear(), w.now.getMonth() + 1, 0).getDate()
    }

    Timer {
        interval: 30000
        repeat: true
        running: w.visible
        onTriggered: w.now = new Date()
    }

    readonly property var days: {
        var out = []
        var off = w.firstOffset()
        for (var i = 0; i < off; i++) {
            out.push(0)
        }
        var n = w.daysInMonth()
        for (var j = 1; j <= n; j++) {
            out.push(j)
        }
        return out
    }

    DockGlassPanel {
        anchors.fill: parent
        cornerRadius: 28
        backdrop: w.backdrop
        dispersion: 0.06
        glassBlur: 13
    }

    Column {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 6

        Text {
            text: w.loc.standaloneMonthName(w.now.getMonth(), Locale.LongFormat)
                + " " + w.now.getFullYear()
            color: "#F2FFFFFF"
            font.family: "SF Pro Display"
            font.pixelSize: 16
            font.weight: Font.DemiBold
        }

        Row {
            width: parent.width
            Repeater {
                model: 7
                Text {
                    required property int index
                    width: (w.width - 28) / 7
                    horizontalAlignment: Text.AlignHCenter
                    text: w.loc.standaloneDayName(
                        (w.loc.firstDayOfWeek + index - 1) % 7 + 1,
                        Locale.NarrowFormat).toUpperCase()
                    color: Qt.rgba(1, 1, 1, 0.55)
                    font.family: "SF Pro Display"
                    font.pixelSize: 10
                }
            }
        }

        Grid {
            id: grid
            width: parent.width
            columns: 7
            model: w.days
            property int today: w.now.getDate()

            delegate: Item {
                required property var modelData
                required property int index
                width: (w.width - 28) / 7
                height: 24

                Rectangle {
                    anchors.centerIn: parent
                    width: 22
                    height: 22
                    radius: 11
                    visible: modelData === grid.today
                        && w.now.getMonth() === new Date().getMonth()
                        && w.now.getFullYear() === new Date().getFullYear()
                    color: Qt.rgba(1, 1, 1, 0.92)
                }

                Text {
                    anchors.centerIn: parent
                    text: modelData > 0 ? modelData : ""
                    color: modelData === grid.today
                        && w.now.getMonth() === new Date().getMonth()
                        && w.now.getFullYear() === new Date().getFullYear()
                        ? "#FF202124" : Qt.rgba(1, 1, 1, 0.88)
                    font.family: "SF Pro Display"
                    font.pixelSize: 12
                    font.weight: modelData === grid.today
                        && w.now.getMonth() === new Date().getMonth()
                        && w.now.getFullYear() === new Date().getFullYear()
                        ? Font.DemiBold : Font.Normal
                }
            }
        }
    }
}
