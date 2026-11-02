import QtQuick
import "../glass"

Item {
    id: w

    property Item backdrop
    property var now: new Date()

    Timer {
        interval: 33
        repeat: true
        running: w.visible
        onTriggered: w.now = new Date()
    }

    onNowChanged: dial.requestPaint()

    DockGlassPanel {
        anchors.fill: parent
        cornerRadius: 28
        backdrop: w.backdrop
        dispersion: 0.06
        glassBlur: 13
    }

    Canvas {
        id: dial
        anchors.fill: parent
        antialiasing: true

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.clearRect(0, 0, width, height)
            var cx = width / 2, cy = height / 2
            var r = Math.min(width, height) / 2 - 10
            ctx.strokeStyle = "rgba(255,255,255,0.55)"
            ctx.lineCap = "round"
            for (var i = 0; i < 12; i++) {
                var a = i * Math.PI / 6
                var long = i % 3 === 0
                var len = long ? 9 : 5
                ctx.lineWidth = long ? 2.4 : 1.4
                ctx.beginPath()
                ctx.moveTo(cx + Math.sin(a) * (r - len), cy - Math.cos(a) * (r - len))
                ctx.lineTo(cx + Math.sin(a) * r, cy - Math.cos(a) * r)
                ctx.stroke()
            }
            var ms = w.now.getMilliseconds() / 1000
            var s = w.now.getSeconds() + ms
            var m = w.now.getMinutes() + s / 60
            var h = w.now.getHours() % 12 + m / 60

            ctx.strokeStyle = "rgba(255,255,255,0.95)"
            ctx.lineWidth = 4.5
            ctx.beginPath()
            ctx.moveTo(cx - Math.sin(h / 12 * 2 * Math.PI) * r * 0.12,
                       cy + Math.cos(h / 12 * 2 * Math.PI) * r * 0.12)
            ctx.lineTo(cx + Math.sin(h / 12 * 2 * Math.PI) * r * 0.52,
                       cy - Math.cos(h / 12 * 2 * Math.PI) * r * 0.52)
            ctx.stroke()

            ctx.lineWidth = 3.2
            ctx.beginPath()
            ctx.moveTo(cx - Math.sin(m / 60 * 2 * Math.PI) * r * 0.16,
                       cy + Math.cos(m / 60 * 2 * Math.PI) * r * 0.16)
            ctx.lineTo(cx + Math.sin(m / 60 * 2 * Math.PI) * r * 0.76,
                       cy - Math.cos(m / 60 * 2 * Math.PI) * r * 0.76)
            ctx.stroke()

            ctx.strokeStyle = "#FF9F0A"
            ctx.lineWidth = 1.6
            ctx.beginPath()
            ctx.moveTo(cx - Math.sin(s / 60 * 2 * Math.PI) * r * 0.22,
                       cy + Math.cos(s / 60 * 2 * Math.PI) * r * 0.22)
            ctx.lineTo(cx + Math.sin(s / 60 * 2 * Math.PI) * r * 0.80,
                       cy - Math.cos(s / 60 * 2 * Math.PI) * r * 0.80)
            ctx.stroke()

            ctx.fillStyle = "#FF9F0A"
            ctx.beginPath()
            ctx.arc(cx, cy, 2.6, 0, 2 * Math.PI)
            ctx.fill()
        }
    }
}
