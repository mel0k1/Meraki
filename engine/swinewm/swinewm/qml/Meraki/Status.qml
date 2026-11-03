import QtQuick

// Правый блок статуса ленты (порт MacBar): сеть, громкость, батарея,
// поиск и колокольчик. Пилюли при наведении — как у остальных элементов;
// громкость меняется колесом, клик — mute; поиск открывает Spotlight
// (пилюля поиска, тот же хоткей Super+Space).
Row {
    id: status

    spacing: 2
    height: 22

    readonly property var st: bridge.status
    readonly property bool netUp: st.net !== undefined && st.net.up
    readonly property bool wireless: netUp && st.net.wireless
    readonly property bool hasVol: st.volume !== undefined
    readonly property int vol: hasVol ? st.volume : 0
    readonly property bool muted: hasVol && st.muted
    readonly property bool hasBat: st.battery !== undefined
    readonly property int batCap: hasBat ? st.battery.capacity : 0
    readonly property bool charging: hasBat && st.battery.charging

    Connections {
        target: bridge
        function onStatusChanged() {
            netCv.requestPaint()
            volCv.requestPaint()
            batCv.requestPaint()
        }
    }

    // --- сеть ---
    Item {
        width: 26
        height: 22

        Rectangle {
            anchors.centerIn: parent
            width: parent.width - 2
            height: parent.height - 4
            radius: 6
            color: netMa.containsMouse ? Qt.rgba(1, 1, 1, 0.14)
                                       : "transparent"
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        Canvas {
            id: netCv

            anchors.centerIn: parent
            width: 16
            height: 14
            antialiasing: true
            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                ctx.clearRect(0, 0, width, height)
                ctx.strokeStyle = status.netUp
                    ? "rgba(255,255,255,0.92)" : "rgba(255,255,255,0.34)"
                ctx.lineWidth = 1.6
                ctx.lineCap = "round"
                if (status.netUp && !status.wireless) {
                    // Ethernet: прямоугольник с «штекером».
                    ctx.strokeRect(2.2, 6.4, 11.6, 6)
                    ctx.beginPath()
                    ctx.moveTo(4.6, 12.4)
                    ctx.lineTo(4.6, 13.4)
                    ctx.moveTo(8, 12.4)
                    ctx.lineTo(8, 13.4)
                    ctx.moveTo(11.4, 12.4)
                    ctx.lineTo(11.4, 13.4)
                    ctx.stroke()
                    return
                }
                // Wi-Fi: три дуги + точка.
                for (var i = 0; i < 3; i++) {
                    var r = 2.6 + i * 3.2
                    ctx.beginPath()
                    ctx.arc(8, 12.4, r, Math.PI * 1.22, Math.PI * 1.78)
                    ctx.stroke()
                }
                ctx.fillStyle = ctx.strokeStyle
                ctx.beginPath()
                ctx.arc(8, 11.6, 1.5, 0, 2 * Math.PI)
                ctx.fill()
                if (!status.netUp) {
                    ctx.strokeStyle = "rgba(255,255,255,0.55)"
                    ctx.beginPath()
                    ctx.moveTo(1.5, 1.5)
                    ctx.lineTo(14.5, 12.5)
                    ctx.stroke()
                }
            }
        }

        MouseArea {
            id: netMa

            anchors.fill: parent
            hoverEnabled: true
        }
    }

    // --- громкость ---
    Item {
        width: 26
        height: 22

        Rectangle {
            anchors.centerIn: parent
            width: parent.width - 2
            height: parent.height - 4
            radius: 6
            color: volMa.containsMouse ? Qt.rgba(1, 1, 1, 0.14)
                                       : "transparent"
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        Canvas {
            id: volCv

            anchors.centerIn: parent
            width: 16
            height: 14
            antialiasing: true
            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                ctx.clearRect(0, 0, width, height)
                ctx.fillStyle = status.hasVol
                    ? "rgba(255,255,255,0.92)" : "rgba(255,255,255,0.34)"
                // Динамик: корпус + раструб.
                ctx.beginPath()
                ctx.moveTo(2, 5)
                ctx.lineTo(5.4, 5)
                ctx.lineTo(8.6, 2)
                ctx.lineTo(8.6, 12)
                ctx.lineTo(5.4, 9)
                ctx.lineTo(2, 9)
                ctx.closePath()
                ctx.fill()
                if (status.muted) {
                    ctx.strokeStyle = "rgba(255,255,255,0.85)"
                    ctx.lineWidth = 1.6
                    ctx.lineCap = "round"
                    ctx.beginPath()
                    ctx.moveTo(10.6, 4.4)
                    ctx.lineTo(14.4, 9.6)
                    ctx.moveTo(14.4, 4.4)
                    ctx.lineTo(10.6, 9.6)
                    ctx.stroke()
                    return
                }
                ctx.strokeStyle = ctx.fillStyle
                ctx.lineWidth = 1.5
                ctx.lineCap = "round"
                if (status.vol > 8) {
                    ctx.beginPath()
                    ctx.arc(8.6, 7, 3.4, -Math.PI * 0.42, Math.PI * 0.42)
                    ctx.stroke()
                }
                if (status.vol > 55) {
                    ctx.beginPath()
                    ctx.arc(8.6, 7, 5.6, -Math.PI * 0.4, Math.PI * 0.4)
                    ctx.stroke()
                }
            }
        }

        MouseArea {
            id: volMa

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: bridge.volumeMute()
            onWheel: function(w) {
                bridge.volumeNudge(w.angleDelta.y > 0 ? 3 : -3)
            }
        }
    }

    // --- батарея ---
    Item {
        visible: status.hasBat
        width: 52
        height: 22

        Rectangle {
            anchors.centerIn: parent
            width: parent.width - 2
            height: parent.height - 4
            radius: 6
            color: batMa.containsMouse ? Qt.rgba(1, 1, 1, 0.14)
                                       : "transparent"
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        Canvas {
            id: batCv

            anchors.verticalCenter: parent.verticalCenter
            x: 6
            width: 24
            height: 14
            antialiasing: true
            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                ctx.clearRect(0, 0, width, height)
                // Контур 21x11 с выводом-контактом.
                ctx.strokeStyle = "rgba(255,255,255,0.75)"
                ctx.lineWidth = 1.4
                ctx.beginPath()
                ctx.roundedRect(0.7, 1.4, 19.6, 10.2, 2.6, 2.6)
                ctx.stroke()
                ctx.fillStyle = "rgba(255,255,255,0.75)"
                ctx.fillRect(21.2, 4.4, 1.8, 4.2)
                var cap = Math.max(0, Math.min(100, status.batCap))
                ctx.fillStyle = cap <= 15
                    ? "#FF453A" : "#30D158"
                ctx.fillRect(2.7, 3.4, (cap / 100.0) * 15.6, 6.2)
                if (status.charging) {
                    // Болт.
                    ctx.fillStyle = "rgba(255,255,255,0.95)"
                    ctx.beginPath()
                    ctx.moveTo(10.4, 1.2)
                    ctx.lineTo(6.6, 7.4)
                    ctx.lineTo(9.4, 7.4)
                    ctx.lineTo(8.2, 11.8)
                    ctx.lineTo(12.6, 5.6)
                    ctx.lineTo(9.7, 5.6)
                    ctx.closePath()
                    ctx.fill()
                }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            x: 33
            text: status.batCap + "%"
            color: "#F2FFFFFF"
            font.family: "SF Pro Display"
            font.pixelSize: 12
        }

        MouseArea {
            id: batMa

            anchors.fill: parent
            hoverEnabled: true
        }
    }

    // --- поиск (Spotlight) ---
    Item {
        width: 26
        height: 22

        Rectangle {
            anchors.centerIn: parent
            width: parent.width - 2
            height: parent.height - 4
            radius: 6
            color: searchMa.containsMouse ? Qt.rgba(1, 1, 1, 0.14)
                                          : "transparent"
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        Canvas {
            anchors.centerIn: parent
            width: 16
            height: 16
            antialiasing: true
            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                ctx.clearRect(0, 0, width, height)
                ctx.strokeStyle = "rgba(255,255,255,0.88)"
                ctx.lineWidth = 1.7
                ctx.beginPath()
                ctx.arc(6.6, 6.6, 4.9, 0, 2 * Math.PI)
                ctx.stroke()
                ctx.beginPath()
                ctx.moveTo(10.6, 10.6)
                ctx.lineTo(14.4, 14.4)
                ctx.stroke()
            }
        }

        MouseArea {
            id: searchMa

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: bridge.toggleSpotlight()
        }
    }

    // --- колокольчик (центр уведомлений) ---
    Item {
        width: 26
        height: 22

        Rectangle {
            anchors.centerIn: parent
            width: parent.width - 2
            height: parent.height - 4
            radius: 6
            color: bellMa.containsMouse || bridge.centerOpen
                ? Qt.rgba(1, 1, 1, 0.14) : "transparent"
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        Canvas {
            anchors.centerIn: parent
            width: 16
            height: 16
            antialiasing: true
            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                ctx.clearRect(0, 0, width, height)
                ctx.fillStyle = "rgba(255,255,255,0.88)"
                ctx.beginPath()
                ctx.moveTo(8, 1.4)
                ctx.bezierCurveTo(5.2, 1.4, 3.6, 3.6, 3.6, 6.4)
                ctx.lineTo(3.6, 9.6)
                ctx.lineTo(2.4, 12)
                ctx.lineTo(13.6, 12)
                ctx.lineTo(12.4, 9.6)
                ctx.lineTo(12.4, 6.4)
                ctx.bezierCurveTo(12.4, 3.6, 10.8, 1.4, 8, 1.4)
                ctx.closePath()
                ctx.fill()
                ctx.beginPath()
                ctx.arc(8, 13.4, 1.5, 0, Math.PI)
                ctx.fill()
            }
        }

        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 2
            anchors.top: parent.top
            anchors.topMargin: 1
            width: 7
            height: 7
            radius: 3.5
            color: "#FF453A"
            visible: bridge.centerCount > 0 && !bridge.centerOpen
        }

        MouseArea {
            id: bellMa

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: bridge.toggleCenter()
        }
    }
}
