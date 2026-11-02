import QtQuick

// Верхняя лента в духе macOS Tahoe (порт MacBar): почти прозрачная,
// без рамки; слева логотип-арка и имя активного приложения, по центру
// номера воркспейсов, справа трей и часы.
Rectangle {
    id: bar

    height: 28
    color: Qt.rgba(0.09, 0.09, 0.10, 0.38)

    Row {
        id: leftRow

        x: 6
        height: 28
        spacing: 2

        Item {
            id: logo

            width: 30
            height: 22
            anchors.verticalCenter: parent.verticalCenter

            property bool hot: logoMa.containsMouse

            Rectangle {
                anchors.centerIn: parent
                width: parent.width - 2
                height: parent.height - 6
                radius: 6
                color: logo.hot ? Qt.rgba(1, 1, 1, 0.14) : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }
            }

            Canvas {
                anchors.centerIn: parent
                width: 15
                height: 15
                antialiasing: true

                onLogoHotChanged: requestPaint()
                property bool logoHot: logo.hot

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

            MouseArea {
                id: logoMa

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: bridge.toggleApps()
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, 240)
            text: bridge.activeName.length > 0 ? bridge.activeName : "Meraki"
            color: "#F2FFFFFF"
            font.pixelSize: 13
            font.weight: Font.DemiBold
            elide: Text.ElideRight
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
            sourceComponent: Tray {}
        }

        Clock {
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
