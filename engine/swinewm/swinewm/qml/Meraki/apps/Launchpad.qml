import QtQuick
import "../glass"

Rectangle {
    id: root

    readonly property bool shown: bridge.open

    color: shown ? Qt.rgba(0, 0, 0, 0.42) : "transparent"

    MouseArea {
        anchors.fill: parent
        enabled: root.shown
        onClicked: bridge.close()
    }

    Item {
        id: backdrop
        width: bridge.screenWidth
        height: bridge.screenHeight

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

    DockGlassPanel {
        id: panel

        property real appear: root.shown ? 1 : 0

        x: (parent.width - width) / 2
        y: (parent.height - height) / 2
        width: 760
        height: 540
        cornerRadius: 22
        backdrop: backdrop
        opacity: appear
        scale: 0.94 + 0.06 * appear

        Behavior on appear {
            NumberAnimation { duration: 170 }
        }

        Column {
            anchors.fill: parent
            anchors.margins: 22
            spacing: 14

            Rectangle {
                id: searchBox

                width: parent.width
                height: 42
                radius: 12
                color: Qt.rgba(1, 1, 1, 0.09)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.14)

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 10

                    Canvas {
                        width: 16
                        height: 16
                        anchors.verticalCenter: parent.verticalCenter
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.reset()
                            ctx.clearRect(0, 0, width, height)
                            ctx.strokeStyle = "rgba(255,255,255,0.65)"
                            ctx.lineWidth = 1.8
                            ctx.beginPath()
                            ctx.arc(6.5, 6.5, 5, 0, 2 * Math.PI)
                            ctx.stroke()
                            ctx.beginPath()
                            ctx.moveTo(10.5, 10.5)
                            ctx.lineTo(15, 15)
                            ctx.stroke()
                        }
                    }

                    TextInput {
                        id: input

                        width: parent.width - 30
                        anchors.verticalCenter: parent.verticalCenter
                        color: "#F2FFFFFF"
                        font.family: "SF Pro Display"
                        font.pixelSize: 15
                        clip: true
                        focus: root.shown
                        onTextChanged: bridge.query = text
                        Keys.onEscapePressed: bridge.close()
                        Keys.onReturnPressed: bridge.launchFirst()
                        Keys.onEnterPressed: bridge.launchFirst()
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 42
                    visible: input.text === ""
                    text: "Поиск приложений"
                    color: Qt.rgba(1, 1, 1, 0.38)
                    font.family: "SF Pro Display"
                    font.pixelSize: 15
                }
            }

            Item {
                width: parent.width
                height: parent.height - 56

                GridView {
                    id: grid

                    anchors.fill: parent
                    model: root.shown ? bridge.filtered : []
                    cellWidth: 118
                    cellHeight: 108
                    clip: true

                    ScrollIndicator.vertical: ScrollIndicator {}

                    delegate: Item {
                        width: grid.cellWidth
                        height: grid.cellHeight

                        opacity: ma.containsMouse ? 1 : 0.92

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 5
                            radius: 12
                            color: ma.containsMouse
                                ? Qt.rgba(1, 1, 1, 0.10)
                                : "transparent"
                        }

                        Column {
                            anchors.fill: parent
                            anchors.topMargin: 10
                            spacing: 7

                            Item {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 52
                                height: 52

                                // Пока иконка грузится в фоне — нейтральная
                                // плитка с первой буквой.
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 11
                                    visible: img.status !== Image.Ready
                                    color: Qt.rgba(1, 1, 1, 0.10)

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.name.length > 0
                                            ? modelData.name.charAt(0).toUpperCase() : "?"
                                        color: Qt.rgba(1, 1, 1, 0.75)
                                        font.family: "SF Pro Display"
                                        font.pixelSize: 22
                                        font.weight: Font.DemiBold
                                    }
                                }

                                Image {
                                    id: img

                                    anchors.fill: parent
                                    source: "image://appicon/" + modelData.icon
                                    sourceSize: Qt.size(96, 96)
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    mipmap: true
                                    asynchronous: true
                                }
                            }

                            Text {
                                width: parent.width - 12
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.name
                                color: "#EAFFFFFF"
                                font.family: "SF Pro Display"
                                font.pixelSize: 12
                                elide: Text.ElideMiddle
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }

                        MouseArea {
                            id: ma

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: bridge.openApp(modelData.path)
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: grid.count === 0
                    text: bridge.query.trimmed() === ""
                        ? "Программы не найдены"
                        : "Ничего не найдено"
                    color: Qt.rgba(1, 1, 1, 0.45)
                    font.family: "SF Pro Display"
                    font.pixelSize: 14
                }
            }
        }
    }

    onShownChanged: {
        if (shown) {
            input.text = ""
            input.forceActiveFocus()
        }
    }
}
