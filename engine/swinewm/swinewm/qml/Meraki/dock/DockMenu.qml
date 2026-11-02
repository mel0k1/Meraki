import QtQuick

Rectangle {
    id: root

    signal done()

    readonly property int pad: 10
    readonly property int itemH: 40

    width: 224
    radius: 14
    color: Qt.rgba(0.11, 0.11, 0.13, 0.88)
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.16)

    Text {
        x: root.pad
        y: root.pad - 4
        width: parent.width - 2 * root.pad
        height: 24
        verticalAlignment: Text.AlignVCenter
        text: menu.name
        color: "#80FFFFFF"
        font.family: "SF Pro Display"
        font.pixelSize: 11
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
    }

    Rectangle {
        x: root.pad
        y: root.pad + 24
        width: parent.width - 2 * root.pad
        height: 1
        color: Qt.rgba(1, 1, 1, 0.10)
    }

    Column {
        x: root.pad
        y: root.pad + 24 + 8
        width: parent.width - 2 * root.pad
        spacing: 2

        Repeater {
            model: [
                { label: menu.pinned ? "Открепить из Dock" : "Закрепить в Dock", act: "pin" },
                { label: "Закрыть", act: "close" }
            ].filter(function (it) {
                return it.act !== "close" || menu.running
            })

            delegate: Rectangle {
                id: itm

                required property var modelData

                width: parent.width
                height: root.itemH
                radius: 8
                color: ma.containsMouse ? Qt.rgba(1, 1, 1, 0.14)
                                        : Qt.rgba(1, 1, 1, 0.02)

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    x: 12
                    text: itm.modelData.label
                    color: "#F2FFFFFF"
                    font.family: "SF Pro Display"
                    font.pixelSize: 13
                    elide: Text.ElideRight
                    width: parent.width - 24
                }

                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (itm.modelData.act === "pin") {
                            bridge.togglePin(menu.key)
                        } else {
                            bridge.closeApp(menu.key)
                        }
                        root.done()
                    }
                }
            }
        }
    }
}
