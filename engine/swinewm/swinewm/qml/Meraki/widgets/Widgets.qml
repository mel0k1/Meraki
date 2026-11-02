import QtQuick

Item {
    id: root

    readonly property var cfg: bridge.config
    readonly property bool leftSide: cfg.side === "left"
    readonly property var positions: cfg.positions || {}
    readonly property int contentW: Math.max(
        cfg.clockEnabled ? cfg.clockSize : 0,
        cfg.calendarEnabled ? cfg.calendarSize : 0,
        cfg.weatherEnabled ? cfg.weatherWidth : 0,
        cfg.mediaEnabled ? cfg.mediaWidth : 0)

    // Тянут ли карточку сейчас (для расширенной зоны ввода под курсором)
    property bool clockDrag: false
    property bool calendarDrag: false
    property bool weatherDrag: false
    property bool mediaDrag: false

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
        var cards = [clockC, calendarC, weatherC, mediaC]
        for (var i = 0; i < cards.length; i++) {
            var c = cards[i]
            if (!c.visible || c.width <= 0 || c.height <= 0) {
                continue
            }
            // Пока карточку тянут, зона ввода расширяется: она следует за
            // курсором с задержкой региона, и перетаскивание не срывается.
            var pad = (c === clockC && root.clockDrag)
                || (c === calendarC && root.calendarDrag)
                || (c === weatherC && root.weatherDrag)
                || (c === mediaC && root.mediaDrag) ? 90 : 0
            list.push({
                x: Math.floor(c.x - pad),
                y: Math.floor(c.y - pad),
                w: Math.ceil(c.width + 2 * pad),
                h: Math.ceil(c.height + 2 * pad)
            })
        }
        bridge.setCards(viewIndex, list)
    }

    function defX(w) {
        return root.leftSide
            ? root.cfg.margin + root.contentW - w
            : viewW - root.cfg.margin - w
    }

    function px(key, fallback) {
        var p = root.positions[key]
        return p && p.x !== undefined ? p.x : fallback
    }

    function py(key, fallback) {
        var p = root.positions[key]
        return p && p.y !== undefined ? p.y : fallback
    }

    // Раскладка по умолчанию — прежний стек сверху вниз; карточки, чья
    // позиция задана в widgets.json ("positions"), стоят где сказал пользователь.
    function layout() {
        var y = root.cfg.top
        if (root.cfg.clockEnabled) {
            clockC.x = root.px("clock", root.defX(root.cfg.clockSize))
            clockC.y = root.py("clock", y)
            y += root.cfg.clockSize + root.cfg.spacing
        }
        if (root.cfg.calendarEnabled) {
            calendarC.x = root.px("calendar", root.defX(root.cfg.calendarSize))
            calendarC.y = root.py("calendar", y)
            y += root.cfg.calendarSize + root.cfg.spacing
        }
        if (root.cfg.weatherEnabled) {
            weatherC.x = root.px("weather", root.defX(root.cfg.weatherWidth))
            weatherC.y = root.py("weather", y)
            y += root.cfg.weatherHeight + root.cfg.spacing
        }
        if (root.cfg.mediaEnabled && media.hasSession) {
            mediaC.x = root.px("media", root.defX(root.cfg.mediaWidth))
            mediaC.y = root.py("media", y)
        }
    }

    function clampDrop(key, card) {
        var x = Math.max(0, Math.min(viewW - card.width, card.x))
        var y = Math.max(0, Math.min(viewH - card.height, card.y))
        card.x = x
        card.y = y
        bridge.setWidgetPos(key, Math.round(x), Math.round(y))
    }

    onCfgChanged: {
        layout()
        reportCards()
    }

    Component.onCompleted: {
        layout()
        reportCards()
    }

    Connections {
        target: media
        function onMediaChanged() {
            root.layout()
            root.reportCards()
        }
    }

    ClockCard {
        id: clockC
        visible: root.cfg.clockEnabled
        width: root.cfg.clockSize
        height: root.cfg.clockSize
        showSeconds: root.cfg.clockSeconds
        backdrop: backdrop

        onXChanged: root.reportCards()
        onYChanged: root.reportCards()

        MouseArea {
            z: -1
            anchors.fill: parent
            cursorShape: Qt.SizeAllCursor
            drag.target: clockC
            drag.axis: Drag.XAndYAxis
            onPressed: root.clockDrag = true
            onCanceled: root.clockDrag = false
            onReleased: {
                root.clockDrag = false
                root.clampDrop("clock", clockC)
            }
        }
    }

    CalendarCard {
        id: calendarC
        visible: root.cfg.calendarEnabled
        width: root.cfg.calendarSize
        height: root.cfg.calendarSize
        backdrop: backdrop

        onXChanged: root.reportCards()
        onYChanged: root.reportCards()

        MouseArea {
            z: -1
            anchors.fill: parent
            cursorShape: Qt.SizeAllCursor
            drag.target: calendarC
            drag.axis: Drag.XAndYAxis
            onPressed: root.calendarDrag = true
            onCanceled: root.calendarDrag = false
            onReleased: {
                root.calendarDrag = false
                root.clampDrop("calendar", calendarC)
            }
        }
    }

    WeatherCard {
        id: weatherC
        visible: root.cfg.weatherEnabled
        fahrenheit: root.cfg.weatherUnits === "fahrenheit"
        width: root.cfg.weatherWidth
        height: root.cfg.weatherHeight
        backdrop: backdrop

        onXChanged: root.reportCards()
        onYChanged: root.reportCards()

        MouseArea {
            z: -1
            anchors.fill: parent
            cursorShape: Qt.SizeAllCursor
            drag.target: weatherC
            drag.axis: Drag.XAndYAxis
            onPressed: root.weatherDrag = true
            onCanceled: root.weatherDrag = false
            onReleased: {
                root.weatherDrag = false
                root.clampDrop("weather", weatherC)
            }
        }
    }

    MediaCard {
        id: mediaC
        visible: root.cfg.mediaEnabled && media.hasSession
        width: root.cfg.mediaWidth
        height: root.cfg.mediaHeight
        backdrop: backdrop

        onXChanged: root.reportCards()
        onYChanged: root.reportCards()

        MouseArea {
            z: -1
            anchors.fill: parent
            cursorShape: Qt.SizeAllCursor
            drag.target: mediaC
            drag.axis: Drag.XAndYAxis
            onPressed: root.mediaDrag = true
            onCanceled: root.mediaDrag = false
            onReleased: {
                root.mediaDrag = false
                root.clampDrop("media", mediaC)
            }
        }
    }
}
