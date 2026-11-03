import QtQuick
import "../glass"

// Spotlight: пилюля поиска по центру экрана (порт Spotlight из MacBar).
// Приложения — общий скан «Пуска»; числовое выражение считается
// калькулятором, Enter копирует ответ в буфер.
Rectangle {
    id: root

    readonly property bool shown: bridge.open
    readonly property var rows: {
        var out = []
        if (bridge.answer.length > 0) {
            out.push({ kind: "calc", title: bridge.answer,
                sub: "Нажмите Enter, чтобы скопировать" })
        }
        var apps = bridge.filtered
        for (var i = 0; i < apps.length && out.length < 9; i++) {
            out.push({ kind: "app", title: apps[i].name,
                sub: apps[i].path, icon: apps[i].icon, path: apps[i].path })
        }
        return out
    }

    color: shown ? Qt.rgba(0, 0, 0, 0.20) : "transparent"

    MouseArea {
        anchors.fill: parent
        enabled: root.shown
        onClicked: bridge.close()
    }

    Item {
        id: backdrop
        width: bridge.screenWidth
        height: bridge.screenHeight
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2

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
        width: 680
        height: 460
        cornerRadius: 22
        backdrop: backdrop
        opacity: appear
        scale: 0.94 + 0.06 * appear

        Behavior on appear {
            NumberAnimation { duration: 170 }
        }

        Column {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 12

            Rectangle {
                id: searchBox

                width: parent.width
                height: 46
                radius: 14
                color: Qt.rgba(1, 1, 1, 0.09)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.14)

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 10

                    Canvas {
                        width: 17
                        height: 17
                        anchors.verticalCenter: parent.verticalCenter
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.reset()
                            ctx.clearRect(0, 0, width, height)
                            ctx.strokeStyle = "rgba(255,255,255,0.65)"
                            ctx.lineWidth = 1.8
                            ctx.beginPath()
                            ctx.arc(7, 7, 5.2, 0, 2 * Math.PI)
                            ctx.stroke()
                            ctx.beginPath()
                            ctx.moveTo(11.2, 11.2)
                            ctx.lineTo(16, 16)
                            ctx.stroke()
                        }
                    }

                    TextInput {
                        id: input

                        width: parent.width - 30
                        anchors.verticalCenter: parent.verticalCenter
                        color: "#F2FFFFFF"
                        font.family: "SF Pro Display"
                        font.pixelSize: 16
                        clip: true
                        focus: root.shown
                        onTextChanged: bridge.query = text
                        Keys.onEscapePressed: bridge.close()
                        Keys.onReturnPressed: bridge.runResult()
                        Keys.onEnterPressed: bridge.runResult()
                        Keys.onDownPressed: list.incrementCurrentIndex()
                        Keys.onUpPressed: list.decrementCurrentIndex()
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 44
                    visible: input.text === ""
                    text: "Поиск Spotlight"
                    color: Qt.rgba(1, 1, 1, 0.38)
                    font.family: "SF Pro Display"
                    font.pixelSize: 16
                }
            }

            ListView {
                id: list

                width: parent.width
                height: parent.height - 58
                model: root.shown ? root.rows : []
                spacing: 4
                clip: true
                currentIndex: 0

                delegate: Item {
                    id: row

                    required property var modelData
                    required property int index

                    width: list.width
                    height: 52

                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        color: list.currentIndex === row.index
                            || ma.containsMouse
                            ? Qt.rgba(1, 1, 1, 0.10) : "transparent"
                        border.width: list.currentIndex === row.index ? 1 : 0
                        border.color: Qt.rgba(1, 1, 1, 0.12)
                    }

                    Item {
                        id: icoWrap

                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 34
                        height: 34

                        Rectangle {
                            anchors.fill: parent
                            radius: 9
                            visible: row.modelData.kind === "calc"
                            color: Qt.rgba(1, 1, 1, 0.12)

                            Text {
                                anchors.centerIn: parent
                                text: "="
                                color: "#F2FFFFFF"
                                font.family: "SF Pro Display"
                                font.pixelSize: 18
                                font.weight: Font.DemiBold
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: 9
                            visible: row.modelData.kind === "app"
                                && img.status !== Image.Ready
                            color: Qt.rgba(1, 1, 1, 0.10)

                            Text {
                                anchors.centerIn: parent
                                text: row.modelData.title.length > 0
                                    ? row.modelData.title.charAt(0)
                                        .toUpperCase() : "?"
                                color: Qt.rgba(1, 1, 1, 0.75)
                                font.family: "SF Pro Display"
                                font.pixelSize: 15
                                font.weight: Font.DemiBold
                            }
                        }

                        Image {
                            id: img

                            visible: row.modelData.kind === "app"
                            anchors.fill: parent
                            source: row.modelData.kind === "app"
                                ? "image://appicon/" + row.modelData.icon : ""
                            sourceSize: Qt.size(64, 64)
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            mipmap: true
                            asynchronous: true
                        }
                    }

                    Column {
                        anchors.left: icoWrap.right
                        anchors.leftMargin: 10
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            width: parent.width
                            text: row.modelData.title
                            color: "#F2FFFFFF"
                            font.family: "SF Pro Display"
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            elide: Text.ElideMiddle
                        }

                        Text {
                            width: parent.width
                            visible: row.modelData.sub.length > 0
                            text: row.modelData.sub
                            color: "#77FFFFFF"
                            font.family: "SF Pro Display"
                            font.pixelSize: 10
                            elide: Text.ElideMiddle
                        }
                    }

                    MouseArea {
                        id: ma

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: list.currentIndex = row.index
                        onClicked: {
                            if (row.modelData.kind === "calc") {
                                bridge.runResult()
                            } else {
                                bridge.openApp(row.modelData.path)
                            }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: root.rows.length === 0
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
            list.currentIndex = 0
            input.forceActiveFocus()
        }
    }
}
