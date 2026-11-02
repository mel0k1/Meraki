import QtQuick
import QtQuick.Effects

Item {
    id: cell

    required property var modelData
    required property int index

    readonly property bool isRunning: modelData.wins.length > 0
    readonly property bool isFocused: isRunning && modelData.wins[0].focused
    readonly property bool isLaunching: bridge.launching[modelData.key] > 0
    readonly property real s: root.scaleAt(index)

    width: root.iconSize * s
    height: root.iconSize

    transformOrigin: Item.Bottom

    Image {
        id: img
        anchors.bottom: parent.bottom
        x: Math.round((parent.width - width) / 2)
        width: Math.max(1, Math.round(root.iconSize * 0.99 * cell.s))
        height: width
        source: "image://dockicon/" + cell.modelData.key
        sourceSize: Qt.size(Math.ceil(root.iconSize * root.effMag * 1.25),
                            Math.ceil(root.iconSize * root.effMag * 1.25))
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        asynchronous: true
    }

    MultiEffect {
        source: img
        anchors.fill: img
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

    SequentialAnimation on scale {
        running: cell.isLaunching
        loops: Animation.Infinite
        NumberAnimation { to: 1.25; duration: 240; easing.type: Easing.InOutQuad }
        NumberAnimation { to: 0.9; duration: 240; easing.type: Easing.InOutQuad }
        NumberAnimation { to: 1.0; duration: 160; easing.type: Easing.InOutQuad }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton) {
                var t = root.slotRect(cell.index)
                bridge.showMenu(cell.modelData.key, cell.modelData.name,
                    cell.modelData.pinned, cell.isRunning,
                    t.x + t.width / 2, t.y)
                return
            }
            if (cell.isRunning) {
                var w = cell.modelData.wins[0]
                if (typeof fx !== "undefined" && fx && w.window > 0) {
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
