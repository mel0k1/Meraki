import QtQuick
import "glass"

// Верхняя лента в стиле MacShell (порт MacBar): Liquid Glass полоса
// во всю ширину, слева логотип-арка, имя активного приложения и меню,
// по центру воркспейсы, справа трей и часы.
Item {
    id: bar

    height: 28

    // Тот же расчёт, что у LGlass ленты в MacShell: tint glassOpacity*0.6,
    // thickness 16, strength 0.9, rim 0.45, grain 0.03, blur 5.
    readonly property real k: 0.9

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
                color: modelData.focused ? Qt.rgba(0.72, 0.78, 0.88, 0.30)
                                         : Qt.rgba(0.60, 0.65, 0.75, 0.18)
            }
        }
    }

    LiquidGlass {
        id: glassStrip

        anchors.fill: parent
        backdrop: backdrop
        cornerRadius: 0
        bezel: Math.min(bar.height * 0.36, 26)
        thickness: 16 * bar.k * 1.6
        dispersion: 0.06 * bar.k * 1.3
        lensMagnify: 0.05 * bar.k * 1.6
        rim: 0.45
        grain: 0.03 * 0.2
        tintMix: 0.42 * 0.6 * 0.55
        saturation: 1.25
        dark: true
        glassBlur: 5
        captureWidth: 0
    }

    // Фолбэк на случай ошибки шейдера: тихая тёмная полоса, чтобы текст
    // оставался читаемым.
    Rectangle {
        anchors.fill: parent
        visible: !glassStrip.shaderOk
        color: Qt.rgba(0.09, 0.09, 0.10, 0.55)
    }

    Row {
        id: leftRow

        x: 6
        height: 28
        spacing: 0

        Repeater {
            model: [
                { id: "logo", label: "" },
                { id: "app", label: bridge.activeName, bold: true },
                { id: "file", label: "Файл" },
                { id: "view", label: "Вид" },
                { id: "window", label: "Окно" },
                { id: "help", label: "Справка" }
            ]

            delegate: Item {
                id: mt

                required property var modelData

                width: mt.modelData.id === "logo" ? 30
                       : tl.implicitWidth + 20
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

                Canvas {
                    visible: mt.modelData.id === "logo"
                    anchors.centerIn: parent
                    width: 15
                    height: 15
                    antialiasing: true

                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.reset()
                        ctx.scale(width / 18, height / 18)
                        ctx.fillStyle = "#F2FFFFFF"
                        ctx.beginPath()
                        ctx.moveTo(8.54, 0.45)
                        ctx.bezierCurveTo(7.78, 2.32, 7.32, 3.54, 6.48, 5.35)
                        ctx.bezierCurveTo(7, 5.9, 7.63, 6.54, 8.67, 7.26)
                        ctx.bezierCurveTo(7.56, 6.81, 6.8, 6.35, 6.23, 5.87)
                        ctx.bezierCurveTo(5.15, 8.13, 3.45, 11.35, 0, 17.55)
                        ctx.bezierCurveTo(2.71, 15.98, 4.81, 15.02, 6.77, 14.65)
                        ctx.lineTo(6.64, 13.49)
                        ctx.lineTo(6.64, 13.4)
                        ctx.bezierCurveTo(6.68, 11.67, 7.59, 10.33, 8.66, 10.42)
                        ctx.bezierCurveTo(9.72, 10.51, 10.56, 12, 10.51, 13.73)
                        ctx.lineTo(10.4, 14.66)
                        ctx.bezierCurveTo(12.34, 15.04, 14.44, 16, 17.13, 17.55)
                        ctx.bezierCurveTo(16.6, 16.58, 16.12, 15.71, 15.67, 14.88)
                        ctx.bezierCurveTo(14.96, 14.33, 14.22, 13.61, 12.75, 12.86)
                        ctx.bezierCurveTo(13.77, 13.13, 14.51, 13.44, 15.08, 13.78)
                        ctx.bezierCurveTo(10.24, 6.35, 9.4, 3.82, 8.54, 0.45)
                        ctx.closePath()
                        ctx.fill()
                    }
                }

                Text {
                    id: tl

                    visible: mt.modelData.id !== "logo"
                    anchors.centerIn: parent
                    text: mt.modelData.label
                    color: "#F2FFFFFF"
                    font.family: "SF Pro Display"
                    font.pixelSize: 13
                    font.weight: mt.modelData.bold ? Font.DemiBold : Font.Normal
                    elide: Text.ElideRight
                }

                MouseArea {
                    id: ma

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    // hoverPop из MacBar: открытое меню переключается
                    // наведением на соседние названия без клика.
                    onEntered: {
                        if (mt.modelData.id !== "logo"
                                && bridge.barMenuOpen()) {
                            var e = mt.mapToItem(null, 0, 0)
                            bridge.showBarMenu(mt.modelData.id,
                                e.x + viewX, e.y + viewY + mt.height)
                        }
                    }
                    onClicked: {
                        var p = mt.mapToItem(null, 0, 0)
                        bridge.showBarMenu(mt.modelData.id,
                            p.x + viewX, p.y + viewY + mt.height)
                    }
                }
            }
        }
    }

    Workspaces {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
    }

    Row {
        id: rightRow

        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        height: 28
        spacing: 2

        Loader {
            anchors.verticalCenter: parent.verticalCenter
            active: viewPrimary === true
            sourceComponent: Status {}
        }

        Loader {
            anchors.verticalCenter: parent.verticalCenter
            active: viewPrimary === true
            sourceComponent: Tray {}
        }

        Clock {
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
