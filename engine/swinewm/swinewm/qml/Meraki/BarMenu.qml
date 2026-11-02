import QtQuick
import "../glass"

// Выпадающее меню верхней ленты: стеклянная панель (Liquid Glass),
// как меню дока; пункты приходят от bridge (barmenu.items), клики
// уходят в bridge.barAction().
Item {
    id: root

    signal done()

    readonly property int itemH: 27
    readonly property int pad: 7

    width: 236
    height: 2 * pad + col.height + 6

    Item {
        id: backdrop

        width: parent.width
        height: parent.height

        Image {
            anchors.fill: parent
            source: bridge.wallpaper
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
    }

    LiquidGlass {
        anchors.fill: parent
        backdrop: backdrop
        cornerRadius: 14
        bezel: 12
        thickness: 20
        dispersion: 0.06
        lensMagnify: 0.0
        rim: 0.45 * 0.20
        grain: 0.009
        tintMix: 0.42 * 0.55
        saturation: 1.25
        dark: true
        glassBlur: 13
        captureWidth: parent.width
    }

    MenuBorder {
        anchors.fill: parent
        cornerR: 14
        dark: true
        outline: false
    }

    Column {
        id: col

        x: root.pad
        y: root.pad
        width: parent.width - 2 * root.pad
        spacing: 1

        Repeater {
            model: barmenu.items

            delegate: Item {
                id: itm

                required property var modelData

                width: col.width
                height: root.itemH

                Rectangle {
                    visible: itm.modelData.sep === true
                    anchors.centerIn: parent
                    width: parent.width
                    height: 1
                    color: Qt.rgba(1, 1, 1, 0.13)
                }

                Rectangle {
                    visible: itm.modelData.sep !== true && ma.containsMouse
                    anchors.fill: parent
                    anchors.margins: 1
                    radius: 7
                    color: "#0A84FF"
                }

                Text {
                    visible: itm.modelData.sep !== true
                    anchors.verticalCenter: parent.verticalCenter
                    x: 10
                    width: parent.width - 20
                    text: itm.modelData.label
                    color: ma.containsMouse ? "#FFFFFF"
                                            : Qt.rgba(1, 1, 1, 0.92)
                    font.family: "SF Pro Display"
                    font.pixelSize: 13
                    elide: Text.ElideRight
                }

                MouseArea {
                    id: ma

                    visible: itm.modelData.sep !== true
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.done()
                        bridge.barAction(itm.modelData.act)
                    }
                }
            }
        }
    }
}
