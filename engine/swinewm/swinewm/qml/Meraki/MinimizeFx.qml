import QtQuick

Rectangle {
    id: fxroot
    color: "transparent"

    property var job: null
    property real progress: 0
    property bool busy: job !== null
    property bool captured: false
    property real handover: 1

    opacity: handover

    function play(j) {
        job = j
        progress = j.reverse ? 1 : 0
        captured = false
        handover = 1
        captureWait.restart()
    }

    function giveUp() {
        captureWait.stop()
        var j = job
        job = null
        if (j) fx.cancelJob(j.hwnd)
    }

    function start() {
        if (!job) return
        if (job.reverse) {
            fx.commitRestore(job.hwnd, job.id)
        } else {
            fx.commitMinimize(job.hwnd)
        }
        anim.from = job.reverse ? 1 : 0
        anim.to = job.reverse ? 0 : 1
        anim.duration = 420
        anim.restart()
    }

    function finish() {
        anim.stop()
        captureWait.stop()
        var j = job
        if (j && j.reverse) {
            handoverAnim.restart()
            return
        }
        job = null
        if (j) fx.finishJob(j.hwnd)
    }

    Timer {
        id: captureWait
        interval: 900
        onTriggered: if (!fxroot.captured) fxroot.giveUp()
    }

    NumberAnimation {
        id: anim
        target: fxroot
        property: "progress"
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.22, 0.8, 0.28, 1.0, 1.0, 1.0]
        onFinished: fxroot.finish()
    }

    NumberAnimation {
        id: handoverAnim
        target: fxroot
        property: "handover"
        from: 1
        to: 0
        duration: 180
        easing.type: Easing.OutCubic
        onFinished: {
            var j = fxroot.job
            fxroot.job = null
            fxroot.handover = 1
            if (j) fx.finishJob(j.hwnd)
        }
    }

    Connections {
        target: fx
        function onJobStarted(job) { fxroot.play(job) }
    }

    Image {
        id: cap
        visible: false
        cache: false
        asynchronous: false
        source: fxroot.busy ? fx.snapshotUrl : ""
        onStatusChanged: {
            if (status === Image.Ready && fxroot.busy && !fxroot.captured) {
                fxroot.captured = true
                captureWait.stop()
                fxroot.start()
            }
        }
    }

    ShaderEffectSource {
        id: capTex
        sourceItem: cap
        hideSource: true
        visible: false
        live: true
        smooth: true
    }

    ShaderEffect {
        anchors.fill: parent
        visible: fxroot.busy && fxroot.captured
        mesh: GridMesh { resolution: Qt.size(6, 64) }
        vertexShader: "qrc:/shaders/genie.vert.qsb"
        fragmentShader: "qrc:/shaders/genie.frag.qsb"
        property variant source: capTex
        property real progress: fxroot.progress
        property vector4d win: fxroot.job
            ? Qt.vector4d(fxroot.job.win.x, fxroot.job.win.y,
                fxroot.job.win.width, fxroot.job.win.height)
            : Qt.vector4d(0, 0, 1, 1)
        property vector4d target: fxroot.job
            ? Qt.vector4d(fxroot.job.target.x, fxroot.job.target.y,
                fxroot.job.target.width, fxroot.job.target.height)
            : Qt.vector4d(0, 0, 1, 1)
    }
}
