import QtQuick
import "../glass"

// Виджет «Система»: ЦП и ОЗУ кольцами, данные из sysinfo (обновление 2 с).
Item {
    id: w

    property Item backdrop
    readonly property var s: bridge.sys || {}

    DockGlassPanel {
        anchors.fill: parent
        cornerRadius: 28
        backdrop: w.backdrop
        dispersion: 0.06
        glassBlur: 13
    }

    Connections {
        target: bridge
        function onSysChanged() {
            cpuCv.requestPaint()
            memCv.requestPaint()
        }
    }

    function ring(ctx, cx, cy, r, frac, color) {
        ctx.strokeStyle = "rgba(255,255,255,0.16)"
        ctx.lineWidth = 6
        ctx.lineCap = "round"
        ctx.beginPath()
        ctx.arc(cx, cy, r, 0, 2 * Math.PI)
        ctx.stroke()
        if (frac > 0.005) {
            ctx.strokeStyle = color
            ctx.beginPath()
            ctx.arc(cx, cy, r, -Math.PI / 2,
                -Math.PI / 2 + Math.min(1, frac) * 2 * Math.PI)
            ctx.stroke()
        }
    }

    Canvas {
        id: cpuCv

        x: (parent.width - width) / 2 - 32
        y: (parent.height - height) / 2 - 16
        width: 64
        height: 64
        antialiasing: true

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.clearRect(0, 0, width, height)
            w.ring(ctx, 32, 32, 24, (w.s.cpu || 0) / 100.0, "#8ECBFF")
        }
    }

    Text {
        anchors.centerIn: cpuCv
        text: (w.s.cpu !== undefined ? w.s.cpu : "—") + "%"
        color: "#F2FFFFFF"
        font.family: "SF Pro Display"
        font.pixelSize: 13
        font.weight: Font.DemiBold
    }

    Text {
        anchors.horizontalCenter: cpuCv.horizontalCenter
        anchors.top: cpuCv.bottom
        anchors.topMargin: 4
        text: "ЦП"
        color: "#99FFFFFF"
        font.family: "SF Pro Display"
        font.pixelSize: 10
    }

    Canvas {
        id: memCv

        x: (parent.width - width) / 2 + 32
        y: (parent.height - height) / 2 - 16
        width: 64
        height: 64
        antialiasing: true

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.clearRect(0, 0, width, height)
            w.ring(ctx, 32, 32, 24, (w.s.mem || 0) / 100.0, "#FF9F0A")
        }
    }

    Text {
        anchors.centerIn: memCv
        text: (w.s.mem !== undefined ? w.s.mem : "—") + "%"
        color: "#F2FFFFFF"
        font.family: "SF Pro Display"
        font.pixelSize: 13
        font.weight: Font.DemiBold
    }

    Text {
        anchors.horizontalCenter: memCv.horizontalCenter
        anchors.top: memCv.bottom
        anchors.topMargin: 4
        text: "ОЗУ"
        color: "#99FFFFFF"
        font.family: "SF Pro Display"
        font.pixelSize: 10
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 12
        visible: w.s.memUsed !== undefined
        text: w.s.memUsed + " / " + w.s.memTotal + " ГБ"
        color: "#77FFFFFF"
        font.family: "SF Pro Display"
        font.pixelSize: 10
    }
}
