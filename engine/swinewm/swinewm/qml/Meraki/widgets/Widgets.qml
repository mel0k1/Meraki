import QtQuick

Item {
    id: root

    readonly property var cfg: bridge.config
    readonly property bool leftSide: cfg.side === "left"
    readonly property int contentW: Math.max(
        cfg.clockEnabled ? cfg.clockSize : 0,
        cfg.calendarEnabled ? cfg.calendarSize : 0,
        cfg.weatherEnabled ? cfg.weatherWidth : 0,
        cfg.mediaEnabled ? cfg.mediaWidth : 0)

    width: viewW
    height: viewH

    Item {
        id: backdrop
        width: viewW
        height: viewH

        Image {
            anchors.fill: parent
            source: bridge.wallpaper
            fillMode: Image.PreserveAspectCrop
        }

        Repeater {
            model: bridge.windows
            Rectangle {
                required property var modelData
                x: modelData.x - viewX
                y: modelData.y - viewY
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
        bridge.setCards(viewIndex, list)
    }

    Component.onCompleted: reportCards()

    Connections {
        target: media
        function onMediaChanged() { root.reportCards() }
    }

    Column {
        id: col

        x: root.leftSide ? root.cfg.margin
                         : viewW - root.contentW - root.cfg.margin
        y: root.cfg.top
        spacing: root.cfg.spacing

        ClockCard {
            visible: root.cfg.clockEnabled
            x: root.contentW - root.cfg.clockSize
            width: root.cfg.clockSize
            height: root.cfg.clockSize
            showSeconds: root.cfg.clockSeconds
            backdrop: backdrop
        }

        CalendarCard {
            visible: root.cfg.calendarEnabled
            x: root.contentW - root.cfg.calendarSize
            width: root.cfg.calendarSize
            height: root.cfg.calendarSize
            backdrop: backdrop
        }

        WeatherCard {
            visible: root.cfg.weatherEnabled
            fahrenheit: root.cfg.weatherUnits === "fahrenheit"
            x: root.contentW - root.cfg.weatherWidth
            width: root.cfg.weatherWidth
            height: root.cfg.weatherHeight
            backdrop: backdrop
        }

        MediaCard {
            visible: root.cfg.mediaEnabled && media.hasSession
            x: root.contentW - root.cfg.mediaWidth
            width: root.cfg.mediaWidth
            height: root.cfg.mediaHeight
            backdrop: backdrop
        }
    }
}
