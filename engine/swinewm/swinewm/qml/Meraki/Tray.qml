import QtQuick
import QtQuick.Window

// Трей в стиле MacBar: иконки 16px по центру ячеек 26×28, при наведении
// пилюля, как у остальных элементов ленты.
Row {
    id: row

    readonly property int iconPx: 16

    spacing: 0

    function screenPt(item, mx, my) {
        var p = item.mapToItem(null, mx, my)
        var w = Window.window
        return Qt.point(p.x + (w ? w.x : 0), p.y + (w ? w.y : 0))
    }

    function report() {
        var w = Window.window
        if (!w) {
            return
        }
        var p = row.mapToItem(null, 0, 0)
        bridge.trayRect(p.x + w.x, p.y + w.y, row.width, row.height)
    }

    Component.onCompleted: report()
    onWidthChanged: report()
    onXChanged: report()

    Repeater {
        model: bridge.trayItems

        Item {
            id: cell

            required property var modelData

            width: 26
            height: 28

            Rectangle {
                anchors.centerIn: parent
                width: parent.width - 2
                height: parent.height - 6
                radius: 6
                color: ma.containsMouse
                    ? Qt.rgba(1, 1, 1, 0.14) : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }
            }

            Image {
                anchors.centerIn: parent
                width: row.iconPx
                height: row.iconPx
                source: "image://trayicon/" + cell.modelData.id + "?v=" + bridge.trayGen
                sourceSize: Qt.size(32, 32)
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
                asynchronous: true
            }

            Timer {
                id: hoverTimer
                interval: 640
                onTriggered: {
                    if (ma.containsMouse) {
                        var p = row.screenPt(ma, ma.mouseX, ma.mouseY)
                        bridge.trayHover(cell.modelData.id, 1, p.x, p.y)
                    }
                }
            }

            MouseArea {
                id: ma

                function btn(b) {
                    return b === Qt.RightButton ? 2 : (b === Qt.MiddleButton ? 1 : 0)
                }

                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onEntered: {
                    bridge.trayHover(cell.modelData.id, 0, 0, 0)
                    hoverTimer.restart()
                }
                onPositionChanged: {
                    bridge.trayHover(cell.modelData.id, 0, 0, 0)
                }
                onExited: {
                    hoverTimer.stop()
                    bridge.trayHover(cell.modelData.id, 2, 0, 0)
                }
                onPressed: function(mouse) {
                    var p = row.screenPt(ma, mouse.x, mouse.y)
                    bridge.trayMouse(cell.modelData.id, btn(mouse.button), true, p.x, p.y)
                }
                onReleased: function(mouse) {
                    var p = row.screenPt(ma, mouse.x, mouse.y)
                    bridge.trayMouse(cell.modelData.id, btn(mouse.button), false, p.x, p.y)
                }
            }
        }
    }
}
