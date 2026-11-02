import QtQuick
import "../glass"

Item {
    id: w

    property Item backdrop
    property bool ready: false
    property int temp: 0
    property int hi: 0
    property int lo: 0
    property string cond: "Загрузка…"
    property string kind: "cloud"
    property bool isDay: true
    property var hourly: []
    property bool fahrenheit: false

    function disp(c) {
        return w.fahrenheit ? Math.round(c * 9 / 5 + 32) : c
    }

    function codeInfo(c) {
        if (c === 0) return { k: "sun", t: "Ясно" }
        if (c === 1) return { k: "partly", t: "Преимущественно ясно" }
        if (c === 2) return { k: "partly", t: "Переменная облачность" }
        if (c === 3) return { k: "cloud", t: "Облачно" }
        if (c === 45 || c === 48) return { k: "fog", t: "Туман" }
        if ((c >= 51 && c <= 67) || (c >= 80 && c <= 82))
            return { k: "rain", t: "Дождь" }
        if ((c >= 71 && c <= 77) || c === 85 || c === 86)
            return { k: "snow", t: "Снег" }
        if (c >= 95) return { k: "storm", t: "Гроза" }
        return { k: "cloud", t: "Облачно" }
    }

    function fetch() {
        var cfg = bridge.config
        var url = "https://api.open-meteo.com/v1/forecast?latitude="
            + cfg.latitude + "&longitude=" + cfg.longitude
            + "&current=temperature_2m,weather_code,is_day"
            + "&hourly=temperature_2m,weather_code&forecast_days=2&timezone=auto"
        var xhr = new XMLHttpRequest()
        xhr.open("GET", url)
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) {
                return
            }
            if (xhr.status !== 200) {
                retry.restart()
                return
            }
            try {
                var d = JSON.parse(xhr.responseText)
                var cur = d.current
                var info = codeInfo(cur.weather_code)
                w.kind = cur.is_day ? info.k
                    : (info.k === "sun" ? "moon" : info.k)
                w.temp = Math.round(cur.temperature_2m)
                w.cond = info.t
                w.isDay = cur.is_day
                var times = d.hourly.time
                var today = cur.time.slice(0, 10)
                var hiT = -999, loT = 999
                for (var i = 0; i < times.length; i++) {
                    if (times[i].slice(0, 10) !== today) {
                        continue
                    }
                    var tv = d.hourly.temperature_2m[i]
                    hiT = Math.max(hiT, Math.round(tv))
                    loT = Math.min(loT, Math.round(tv))
                }
                if (hiT > -999) {
                    w.hi = hiT
                    w.lo = loT
                }
                var start = 0
                for (var j = 0; j < times.length; j++) {
                    if (times[j] >= cur.time) {
                        start = j
                        break
                    }
                }
                var out = []
                for (var q = start; q < Math.min(start + 4, times.length); q++) {
                    var inf = codeInfo(d.hourly.weather_code[q])
                    var kk = inf.k
                    if (kk === "sun") {
                        var hh = parseInt(times[q].slice(11, 13))
                        kk = (hh >= 6 && hh < 21) ? "sun" : "moon"
                    }
                    out.push({
                        h: times[q].slice(11, 16),
                        t: Math.round(d.hourly.temperature_2m[q]),
                        k: kk
                    })
                }
                w.hourly = out
                w.ready = true
            } catch (e) {
                retry.restart()
            }
        }
        xhr.send()
    }

    Component.onCompleted: fetch()

    Timer {
        id: retry
        interval: 5 * 60 * 1000
        onTriggered: w.fetch()
    }

    Timer {
        interval: 30 * 60 * 1000
        repeat: true
        running: w.visible
        onTriggered: w.fetch()
    }

    DockGlassPanel {
        anchors.fill: parent
        cornerRadius: 28
        backdrop: w.backdrop
        dispersion: 0.06
        glassBlur: 13
    }

    Text {
        x: 16
        y: 12
        width: 150
        text: bridge.config.city
        elide: Text.ElideRight
        color: Qt.rgba(1, 1, 1, 0.96)
        font.family: "SF Pro Display"
        font.pixelSize: 15
        font.weight: Font.DemiBold
    }

    Text {
        x: 15
        y: 30
        text: w.ready ? (w.disp(w.temp) + "°") : "–°"
        color: Qt.rgba(1, 1, 1, 0.96)
        font.family: "SF Pro Display"
        font.pixelSize: 46
        font.weight: Font.Light
    }

    Column {
        x: 16
        y: w.height - 16 - height
        width: 150
        spacing: 1

        WeatherGlyph {
            visible: w.kind === "sun" || w.kind === "moon"
            kind: w.kind
            size: 20
        }

        Text {
            text: w.cond
            elide: Text.ElideRight
            width: parent.width
            color: Qt.rgba(1, 1, 1, 0.96)
            font.family: "SF Pro Display"
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }

        Text {
            visible: w.ready
            text: "В:" + w.disp(w.hi) + "°  Н:" + w.disp(w.lo) + "°"
            color: Qt.rgba(1, 1, 1, 0.72)
            font.family: "SF Pro Display"
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }
    }

    Rectangle {
        x: 178
        y: 16
        width: 1
        height: w.height - 32
        color: Qt.rgba(1, 1, 1, 0.16)
    }

    Row {
        x: 188
        anchors.verticalCenter: parent.verticalCenter
        Repeater {
            model: w.hourly
            Column {
                id: hourCol

                required property var modelData

                width: (w.width - 196) / 4
                spacing: 5

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: hourCol.modelData.h
                    color: Qt.rgba(1, 1, 1, 0.68)
                    font.family: "SF Pro Display"
                    font.pixelSize: 10
                }

                WeatherGlyph {
                    anchors.horizontalCenter: parent.horizontalCenter
                    kind: hourCol.modelData.k
                    size: 18
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: w.disp(hourCol.modelData.t) + "°"
                    color: Qt.rgba(1, 1, 1, 0.9)
                    font.family: "SF Pro Display"
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }
            }
        }
    }
}
