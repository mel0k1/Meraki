import QtQuick

Item {
    id: root

    readonly property bool showCalendar: bridge.screenHeight >= 940
    readonly property bool showWeather: bridge.screenHeight >= 780
    readonly property bool showMedia: bridge.screenHeight >= 620

    width: bridge.screenWidth
    height: bridge.screenHeight

    Item {
        id: backdrop
        width: bridge.screenWidth
        height: bridge.screenHeight

        Image {
            anchors.fill: parent
            source: bridge.wallpaper
            fillMode: Image.PreserveAspectCrop
        }

        Repeater {
            model: bridge.windows
            Rectangle {
                required property var modelData
                x: modelData.x
                y: modelData.y
                width: Math.max(2, modelData.w)
                height: Math.max(2, modelData.h)
                radius: 4
                color: modelData.focused ? Qt.rgba(0.72, 0.78, 0.88, 0.30)
                                         : Qt.rgba(0.60, 0.65, 0.75, 0.18)
            }
        }
    }

    function reportCards() {
        var list = []
        for (var i = 0; i < col.children.length; i++) {
            var c = col.children[i]
            if (c.visible && c.width > 0 && c.height > 0) {
                list.push({
                    x: Math.floor(col.x + c.x),
                    y: Math.floor(col.y + c.y),
                    w: Math.ceil(c.width),
                    h: Math.ceil(c.height)
                })
            }
        }
        bridge.setCards(list)
    }

    Component.onCompleted: reportCards()
    onShowCalendarChanged: reportCards()
    onShowWeatherChanged: reportCards()
    onShowMediaChanged: reportCards()

    Connections {
        target: media
        function onMediaChanged() { root.reportCards() }
    }

    Column {
        id: col

        x: bridge.screenWidth - 342
        y: 76
        spacing: 16

        ClockCard {
            x: 152
            width: 168
            height: 168
            backdrop: backdrop
        }

        CalendarCard {
            visible: root.showCalendar
            x: 96
            width: 224
            height: 224
            backdrop: backdrop
        }

        WeatherCard {
            visible: root.showWeather
            width: 320
            height: 158
            backdrop: backdrop
        }

        MediaCard {
            visible: root.showMedia && media.hasSession
            width: 320
            height: 104
            backdrop: backdrop
        }
    }
}
