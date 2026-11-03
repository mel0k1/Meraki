import QtQuick
import QtQuick.Effects

Item {
    id: cell

    required property var modelData
    required property int index

    // Сдвиг при drag-реордере пинов (задаёт Dock.qml); у тянущейся иконки
    // сдвиг следует за курсором без анимации, у остальных — с пружиной.
    property real shiftX: 0
    readonly property bool isDragging: !isService && modelData.pinned
        && root.dragKey === modelData.key

    transform: Translate {
        x: cell.shiftX

        Behavior on x {
            enabled: !cell.isDragging
            NumberAnimation { duration: 130; easing.type: Easing.OutCubic }
        }
    }

    readonly property bool isSep: modelData.kind === "sep"
    readonly property bool isApps: modelData.kind === "apps"
    readonly property bool isTrash: modelData.kind === "trash"
    readonly property bool isService: isSep || isApps || isTrash
    readonly property bool isRunning: modelData.wins.length > 0
    readonly property bool isFocused: isRunning && modelData.wins[0].focused
    readonly property bool isLaunching: !isService
        && bridge.launching[modelData.key] > 0
    readonly property real s: root.scaleAt(index)

    width: root.iconSize * s
    height: root.iconSize

    transformOrigin: Item.Bottom

    // Разделитель групп: тонкая линия по центру слота (MacDock).
    Rectangle {
        visible: cell.isSep
        anchors.centerIn: parent
        width: 1
        height: root.iconSize * 0.55
        color: Qt.rgba(1, 1, 1, 0.20)
    }

    Image {
        id: img

        visible: !cell.isSep
        anchors.bottom: parent.bottom
        x: Math.round((parent.width - width) / 2)
        width: Math.max(1, Math.round(root.iconSize * 0.99 * cell.s))
        height: width
        source: {
            if (cell.isTrash) {
                return "image://dockicon/"
                    + (bridge.trashFull ? "trash-full" : "trash")
            }
            return "image://dockicon/" + cell.modelData.key
        }
        sourceSize: Qt.size(Math.ceil(root.iconSize * root.effMag * 1.25),
                            Math.ceil(root.iconSize * root.effMag * 1.25))
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        asynchronous: true
    }

    // Ячейка «Программы»: глиф Launchpad — 2x2 скруглённые квадрата.
    Canvas {
        id: appsGlyph

        visible: cell.isApps
        anchors.bottom: parent.bottom
        x: Math.round((parent.width - width) / 2)
        width: Math.max(1, Math.round(root.iconSize * 0.72 * cell.s))
        height: width
        antialiasing: true

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.clearRect(0, 0, width, height)
            ctx.fillStyle = "rgba(255,255,255,0.92)"
            var r = width * 0.14
            var a = width * 0.38
            ctx.beginPath()
            ctx.roundedRect(0, 0, a, a, r, r)
            ctx.fill()
            ctx.beginPath()
            ctx.roundedRect(width - a, 0, a, a, r, r)
            ctx.fill()
            ctx.beginPath()
            ctx.roundedRect(0, height - a, a, a, r, r)
            ctx.fill()
            ctx.beginPath()
            ctx.roundedRect(width - a, height - a, a, a, r, r)
            ctx.fill()
        }
    }

    MultiEffect {
        visible: !cell.isSep
        source: cell.isApps ? appsGlyph : img
        anchors.fill: cell.isApps ? appsGlyph : img
        shadowEnabled: true
        shadowColor: "black"
        shadowOpacity: 0.32
        shadowBlur: 0.55
        shadowVerticalOffset: 3
        brightness: ma.containsPress ? -0.25 : 0
    }

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: -(root.bottomPad - 3)
        width: 4
        height: 4
        radius: 2
        visible: cell.isRunning
        color: cell.isFocused ? "#F2FFFFFF" : "#80FFFFFF"
    }

    // Bounce при запуске (MacDock): подъём на 42% иконки с двойным
    // доводом, как в macOS.
    SequentialAnimation on y {
        running: cell.isLaunching
        loops: Animation.Infinite
        alwaysRunToEnd: true
        NumberAnimation { to: -root.iconSize * 0.42; duration: 140;
            easing.type: Easing.OutCubic }
        NumberAnimation { to: 0; duration: 140;
            easing.type: Easing.InCubic }
        NumberAnimation { to: -root.iconSize * 0.07; duration: 60;
            easing.type: Easing.OutCubic }
        NumberAnimation { to: 0; duration: 60;
            easing.type: Easing.InCubic }
    }

    MouseArea {
        id: ma

        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        // Drag-реордер: только закреплённые приложения, порог 6px.
        property bool armed: false
        property bool moved: false
        property real pressX: 0

        onPressed: function(mouse) {
            armed = mouse.button === Qt.LeftButton && !cell.isService
                && cell.modelData.pinned
            moved = false
            pressX = mouse.x
        }
        onPositionChanged: function(mouse) {
            if (!armed || !pressed) {
                return
            }
            if (!moved && Math.abs(mouse.x - pressX) < 6) {
                return
            }
            moved = true
            root.dragActive = true
            root.dragKey = cell.modelData.key
            root.dragMx = cell.mapToItem(root, mouse.x, 0).x
        }
        onReleased: {
            if (moved) {
                root.finishDrag()
            }
        }
        onClicked: function(mouse) {
            if (moved) {
                moved = false
                armed = false
                return
            }
            armed = false
            if (cell.isApps) {
                bridge.openApps()
                return
            }
            if (cell.isTrash) {
                if (mouse.button === Qt.RightButton) {
                    var t = root.slotRect(cell.index)
                    bridge.showMenu(cell.modelData.key,
                        cell.modelData.name, false, true,
                        t.x + t.width / 2, t.y)
                } else {
                    bridge.openTrash()
                }
                return
            }
            if (mouse.button === Qt.RightButton) {
                var r = root.slotRect(cell.index)
                bridge.showMenu(cell.modelData.key, cell.modelData.name,
                    cell.modelData.pinned, cell.isRunning,
                    r.x + r.width / 2, r.y)
                return
            }
            if (cell.isRunning) {
                var w = cell.modelData.wins[0]
                if (w.id < 0) {
                    // Свёрнутое окно из EnumWindows: движок им больше не
                    // управляет, восстанавливаем напрямую.
                    bridge.restoreWindow(w.window)
                } else if (typeof fx !== "undefined" && fx && w.window > 0) {
                    var tr = root.slotRect(cell.index)
                    if (w.iconic) {
                        fx.beginRestore(w.window, w.id, tr.x, tr.y, tr.width, tr.height)
                    } else if (w.focused) {
                        fx.beginMinimize(w.window, w.id, w.x, w.y, w.w, w.h,
                            tr.x, tr.y, tr.width, tr.height)
                    } else {
                        bridge.focusWindow(w.id)
                    }
                } else {
                    bridge.focusWindow(w.id)
                }
            } else if (cell.modelData.cmd !== "") {
                bridge.launch(cell.modelData.cmd)
                bridge.noteLaunch(cell.modelData.key)
            }
        }
        onEntered: root.hoverKey = cell.modelData.key
        onExited: if (root.hoverKey === cell.modelData.key) root.hoverKey = ""
    }
}
