import QtQuick
import "../glass"

Item {
    id: root

    readonly property int iconSize: 52
    readonly property real effMag: 1.7
    readonly property int spacing: 6
    readonly property int hPad: 10
    readonly property int topPad: 8
    readonly property int bottomPad: 9
    readonly property int margin: 6
    readonly property int bgHeight: iconSize + topPad + bottomPad
    readonly property real headroom: iconSize * (effMag - 1) + 10
    readonly property real magRadius: (iconSize + spacing) * 2.6
    readonly property real totalW0: items.length * (iconSize + spacing) - spacing
    readonly property real refLeft: (width - totalW0) / 2

    property var items: []
    property real mx: -10000
    property bool hovered: false
    property string hoverKey: ""

    // Drag-реордер пинов: тянем закреплённую иконку, остальные сдвигаются,
    // отпускание — bridge.reorderPin(key, слот среди пинов).
    property bool dragActive: false
    property string dragKey: ""
    property real dragMx: -10000

    // Smart-hide (macOS): док уезжает за кромку, когда окно налегает на
    // его полосу; выезд — по ховеру/кромке (см. MerakiDock::updateSmartHide).
    readonly property bool hidden: bridge.dockHidden === true
    readonly property real hideShift: hidden ? bgHeight + margin + 4 : 0

    readonly property int hoverIndex: {
        for (var i = 0; i < items.length; i++)
            if (items[i].key === hoverKey) return i
        return -1
    }

    // Слот dragged-иконки и целевой слот броска — в нумерации пинов.
    readonly property int dragSlot: {
        var n = 0
        for (var i = 0; i < items.length; i++) {
            var it = items[i]
            if (it.kind === "app" && it.pinned) {
                if (it.key === dragKey) return n
                n++
            }
        }
        return -1
    }
    readonly property int dropSlot: {
        if (!dragActive || dragSlot < 0) return -1
        var pins = 0
        for (var i = 0; i < items.length; i++)
            if (items[i].kind === "app" && items[i].pinned) pins++
        var raw = Math.floor((dragMx - refLeft
            + (iconSize + spacing) / 2) / (iconSize + spacing))
        return Math.max(0, Math.min(pins - 1, raw))
    }

    function shiftFor(index, item) {
        if (!dragActive || item.kind !== "app" || !item.pinned) return 0
        var s = 0
        for (var i = 0; i < index; i++) {
            var it2 = items[i]
            if (it2.kind === "app" && it2.pinned) s++
        }
        var step = iconSize + spacing
        if (item.key === dragKey) {
            return dragMx - (refLeft + index * step + iconSize / 2)
        }
        if (dragSlot < 0 || dropSlot < 0) return 0
        if (dragSlot < dropSlot && s > dragSlot && s <= dropSlot) return -step
        if (dragSlot > dropSlot && s < dragSlot && s >= dropSlot) return step
        return 0
    }

    function finishDrag() {
        if (!dragActive) return
        var k = dragKey
        var slot = dropSlot
        dragActive = false
        dragKey = ""
        dragMx = -10000
        if (slot >= 0) bridge.reorderPin(k, slot)
    }

    height: Math.ceil(margin + bgHeight + headroom)

    // Корень масштабирует сам QQuickView (SizeRootObjectToView), так что
    // ширину не задаём: она всегда равна ширине окна.
    Component.onCompleted: {
        bridge.dockRestHeight = margin + bgHeight
        rebuild()
        Qt.callLater(syncWidth)
    }

    // Без этих связок док один раз строится на старте и навсегда
    // застывает пустым: окна движка приходят позже.
    Connections {
        target: bridge
        function onWindowsChanged() { root.rebuild() }
        function onPinsChanged() { root.rebuild() }
    }

    function syncWidth() {
        bridge.dockWidth = slab.width + 16
    }

    onItemsChanged: Qt.callLater(syncWidth)
    onHoveredChanged: {
        bridge.dockHovered = hovered
        Qt.callLater(syncWidth)
    }

    function slotRect(index) {
        return Qt.rect(refLeft + index * (iconSize + spacing) + viewX,
                       height - margin - bottomPad - iconSize + viewY,
                       iconSize, iconSize)
    }

    function windowsFor(key) {
        var out = []
        var ws = bridge.windows
        var k = key.toLowerCase()
        for (var i = 0; i < ws.length; i++)
            if (ws[i].appId.toLowerCase() === k) out.push(ws[i])
        return out
    }

    function rebuild() {
        var list = []
        var seen = {}
        var pins = bridge.pins
        for (var i = 0; i < pins.length; i++) {
            var p = pins[i]
            var wins = windowsFor(p.key)
            seen[p.key.toLowerCase()] = true
            list.push({ kind: "app", key: p.key, name: p.name,
                cmd: p.cmd, wins: wins, pinned: true })
        }
        // Запущенные непины — отдельной группой с разделителем (MacDock).
        var running = []
        var ws2 = bridge.windows
        for (var j = 0; j < ws2.length; j++) {
            var k = ws2[j].appId
            if (seen[k.toLowerCase()]) continue
            var wl = windowsFor(k)
            if (wl.length === 0) continue
            seen[k.toLowerCase()] = true
            running.push({ kind: "app", key: k, name: bridge.appName(k),
                cmd: "", wins: wl, pinned: false })
        }
        if (running.length > 0) {
            if (list.length > 0) list.push({ kind: "sep" })
            list = list.concat(running)
        }
        list.push({ kind: "sep" })
        list.push({ kind: "apps", key: "__apps__", name: "Программы",
            wins: [], pinned: false })
        list.push({ kind: "trash", key: "__trash__", name: "Корзина",
            wins: [], pinned: false })
        items = list
    }

    function scaleAt(index) {
        if (index < 0 || !hovered) return 1
        var c0 = refLeft + index * (iconSize + spacing) + iconSize / 2
        var dist = Math.abs(mx - c0)
        var f = dist < magRadius ? 0.5 * (1 + Math.cos(Math.PI * dist / magRadius)) : 0
        return 1 + (effMag - 1) * f
    }

    MouseArea {
        id: hh
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        property real rawMx: -10000
        onPositionChanged: function(mouse) {
            rawMx = mouse.x
            root.hovered = true
        }
        onExited: {
            root.hovered = false
            root.hoverKey = ""
            root.mx = -10000
        }
    }

    FrameAnimation {
        running: root.hovered
        onTriggered: root.mx = hh.rawMx
    }

    Item {
        id: backdrop
        anchors.fill: parent

        Image {
            anchors.fill: parent
            source: bridge.wallpaper
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
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

    LiquidGlass {
        id: slab
        backdrop: backdrop
        x: (parent.width - width) / 2
        y: parent.height - root.margin - height + root.hideShift
        width: row.width + 2 * root.hPad
        onWidthChanged: root.syncWidth()
        height: root.bgHeight
        cornerRadius: 18
        bezel: Math.min(height * 0.36, 26)
        thickness: 30
        dispersion: 0.06
        lensMagnify: 0.08
        rim: 0.45 * 0.20
        grain: 0.009
        tintMix: 0.42 * 0.55
        saturation: 1.25
        dark: true
        glassBlur: 13
        captureWidth: root.totalW0 + 2 * root.hPad + root.iconSize * (root.effMag - 1) * 3.6

        Behavior on y {
            NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
        }
    }

    // Кромка дока: тёмный контур снаружи + линия в цвете обоев (MacShell).
    MenuBorder {
        x: slab.x
        y: slab.y
        width: slab.width
        height: slab.height
        cornerR: 18
        dark: true
        outline: false
    }

    Row {
        id: row
        spacing: root.spacing
        x: (parent.width - width) / 2
        y: parent.height - root.margin - root.bottomPad - root.iconSize
           + root.hideShift

        Behavior on y {
            NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
        }

        Repeater {
            model: root.items

            DockIcon {
                shiftX: root.shiftFor(index, modelData)
            }
        }
    }

    DockTip {}

    Preview {}
}
