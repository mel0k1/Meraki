import QtQuick
import "../glass"

// Тосты уведомлений (порт MacShell): карточки справа под лентой,
// выезжают вправо-влево на 46px (770ms OutQuint), живут 6 с, при
// наведении замирают; клик — действие по умолчанию, крестик — закрыть.
Item {
    id: root

    x: 0
    y: 0
    width: 384
    height: windowH
    readonly property real windowH: 12 + toastsCol.height + 12

    Column {
        id: toastsCol

        x: 12
        y: 12
        width: 360
        spacing: 10

        Repeater {
            model: bridge.toasts

            delegate: Item {
                id: slot

                required property var modelData

                width: root.width - 24
                height: 96

                Item {
                    id: card

                    x: (1 - appear) * 46
                    width: parent.width
                    height: 96

                    property real appear: 0
                    Behavior on appear {
                        NumberAnimation {
                            duration: 770
                            easing.type: Easing.OutQuint
                        }
                    }
                    opacity: appear
                    Component.onCompleted: card.appear = 1

                    Item {
                        id: backdrop

                        anchors.fill: parent

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
                        cornerRadius: 22
                        bezel: 12
                        thickness: 24
                        dispersion: 0.06
                        lensMagnify: 0.0
                        rim: 0.45 * 0.22
                        tintMix: 0.42 * 0.55
                        saturation: 1.2
                        dark: true
                        glassBlur: 12
                        captureWidth: 0
                    }

                    MenuBorder {
                        anchors.fill: parent
                        cornerR: 22
                        dark: true
                        outline: false
                    }

                    // Иконка приложения: плитка с первой буквой, поверх —
                    // системная иконка, когда догрузится.
                    Item {
                        x: 14
                        anchors.verticalCenter: parent.verticalCenter
                        width: 42
                        height: 42

                        Rectangle {
                            anchors.fill: parent
                            radius: 10
                            color: Qt.rgba(1, 1, 1, 0.12)

                            Text {
                                anchors.centerIn: parent
                                text: {
                                    var a = slot.modelData.app
                                    return a && a.length > 0
                                        ? a.charAt(0).toUpperCase() : "·"
                                }
                                color: Qt.rgba(1, 1, 1, 0.8)
                                font.family: "SF Pro Display"
                                font.pixelSize: 19
                                font.weight: Font.DemiBold
                            }
                        }

                        Image {
                            id: appIcon

                            anchors.fill: parent
                            source: "image://dockicon/"
                                + slot.modelData.app.toLowerCase()
                            sourceSize: Qt.size(64, 64)
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            asynchronous: true
                        }
                    }

                    Column {
                        x: 68
                        y: 14
                        width: parent.width - 68 - (closeMa.containsMouse
                            ? 44 : 24)
                        spacing: 3

                        Text {
                            width: parent.width
                            text: slot.modelData.summary.length > 0
                                ? slot.modelData.summary
                                : slot.modelData.app
                            color: "#F2FFFFFF"
                            font.family: "SF Pro Display"
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: slot.modelData.body
                            color: Qt.rgba(1, 1, 1, 0.82)
                            font.family: "SF Pro Display"
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                            elide: Text.ElideRight
                            maximumLineCount: 2
                        }

                        Text {
                            text: Qt.formatTime(
                                new Date(slot.modelData.when), "HH:mm")
                            color: Qt.rgba(1, 1, 1, 0.45)
                            font.family: "SF Pro Display"
                            font.pixelSize: 10
                        }
                    }

                    // Крестик по ховеру (MacShell NotifBody).
                    Item {
                        visible: closeMa.containsMouse
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.top: parent.top
                        anchors.topMargin: 12
                        width: 20
                        height: 20

                        Canvas {
                            anchors.centerIn: parent
                            width: 10
                            height: 10
                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.reset()
                                ctx.clearRect(0, 0, width, height)
                                ctx.strokeStyle = "rgba(255,255,255,0.85)"
                                ctx.lineWidth = 1.6
                                ctx.lineCap = "round"
                                ctx.beginPath()
                                ctx.moveTo(0.8, 0.8)
                                ctx.lineTo(9.2, 9.2)
                                ctx.moveTo(9.2, 0.8)
                                ctx.lineTo(0.8, 9.2)
                                ctx.stroke()
                            }
                        }

                        MouseArea {
                            id: closeMa

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: bridge.dismiss(slot.modelData.id)
                        }
                    }

                    MouseArea {
                        id: cardMa

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: bridge.clickToast(slot.modelData.id)
                        onEntered: life.stop()
                        onExited: life.restart()
                    }

                    // 6 секунд жизни, пауза при наведении.
                    Timer {
                        id: life

                        interval: 6000
                        onTriggered: bridge.expireToast(slot.modelData.id)
                    }

                    Component.onCompleted: life.start()
                }
            }
        }
    }
}
