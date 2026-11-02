import QtQuick
import "../glass"

Item {
    id: w

    property Item backdrop

    DockGlassPanel {
        anchors.fill: parent
        cornerRadius: 24
        backdrop: w.backdrop
        dispersion: 0.06
        glassBlur: 13
    }

    Row {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 14

        Rectangle {
            width: 72
            height: 72
            radius: 12
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#3A3A46" }
                GradientStop { position: 1.0; color: "#22222B" }
            }

            Canvas {
                anchors.centerIn: parent
                width: 34
                height: 34
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()
                    ctx.clearRect(0, 0, width, height)
                    ctx.fillStyle = "rgba(255,255,255,0.85)"
                    ctx.beginPath()
                    ctx.ellipse(11, 25, 6, 4.6, -0.3, 0, 2 * Math.PI)
                    ctx.fill()
                    ctx.fillRect(15.4, 4, 2.2, 21)
                    ctx.beginPath()
                    ctx.moveTo(17.6, 4)
                    ctx.quadraticCurveTo(26, 6.5, 27, 14)
                    ctx.quadraticCurveTo(23, 10.5, 17.6, 11.5)
                    ctx.closePath()
                    ctx.fill()
                }
            }
        }

        Column {
            width: parent.width - 72 - 120 - 44
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Text {
                width: parent.width
                text: media.title
                elide: Text.ElideRight
                color: Qt.rgba(1, 1, 1, 0.95)
                font.family: "SF Pro Display"
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }

            Text {
                width: parent.width
                text: media.artist
                elide: Text.ElideRight
                color: Qt.rgba(1, 1, 1, 0.62)
                font.family: "SF Pro Display"
                font.pixelSize: 12
            }
        }

        Row {
            spacing: 10
            anchors.verticalCenter: parent.verticalCenter

            Canvas {
                width: 26
                height: 26
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()
                    ctx.clearRect(0, 0, width, height)
                    ctx.fillStyle = "rgba(255,255,255,0.92)"
                    ctx.beginPath()
                    ctx.moveTo(20, 5)
                    ctx.lineTo(9, 13)
                    ctx.lineTo(20, 21)
                    ctx.closePath()
                    ctx.fill()
                    ctx.fillRect(5, 5, 2.5, 16)
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: media.previous()
                }
            }

            Canvas {
                id: pp

                width: 30
                height: 30
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()
                    ctx.clearRect(0, 0, width, height)
                    ctx.fillStyle = "#FFFFFF"
                    if (media.playing) {
                        ctx.fillRect(9, 6, 4, 18)
                        ctx.fillRect(17, 6, 4, 18)
                    } else {
                        ctx.beginPath()
                        ctx.moveTo(11, 6)
                        ctx.lineTo(23, 15)
                        ctx.lineTo(11, 24)
                        ctx.closePath()
                        ctx.fill()
                    }
                }
                Connections {
                    target: media
                    function onMediaChanged() { pp.requestPaint() }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: media.togglePlay()
                }
            }

            Canvas {
                width: 26
                height: 26
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()
                    ctx.clearRect(0, 0, width, height)
                    ctx.fillStyle = "rgba(255,255,255,0.92)"
                    ctx.beginPath()
                    ctx.moveTo(6, 5)
                    ctx.lineTo(17, 13)
                    ctx.lineTo(6, 21)
                    ctx.closePath()
                    ctx.fill()
                    ctx.fillRect(18.5, 5, 2.5, 16)
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: media.next()
                }
            }
        }
    }
}
