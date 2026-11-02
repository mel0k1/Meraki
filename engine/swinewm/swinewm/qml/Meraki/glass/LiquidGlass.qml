import QtQuick
import QtQuick.Effects

Item {
    id: glass

    property Item backdrop
    property string shader: "qrc:/shaders/dockglass.frag.qsb"
    property bool shaderOk: true

    property real glassBlur: 13
    property real cornerRadius: 18
    property real bezel: 18
    property real thickness: 30
    property real dispersion: 0.06
    property real lensMagnify: 0.08
    property real rim: 0.09
    property real grain: 0.009
    property real tintMix: 0.23
    property real saturation: 1.25
    property bool dark: true
    property color edgeCol: "#8A9AB5"
    property real shadowAmt: 0
    property real rimTint: 0
    property real ringW: 0

    property real captureWidth: 0

    default property alias content: slab.data

    readonly property real padPx: 30
    readonly property real capMargin: 72

    width: 100
    height: 100

    Item { id: slab; anchors.fill: parent }

    readonly property real _gx: glass.backdrop ? glass.mapToItem(glass.backdrop, 0, 0).x : 0
    readonly property real _gy: glass.backdrop ? glass.mapToItem(glass.backdrop, 0, 0).y : 0

    readonly property real capW: {
        var want = Math.max(glass.width, glass.captureWidth) + 2 * (glass.padPx + glass.capMargin)
        return Math.max(1, Math.min(want, glass.backdrop ? glass.backdrop.width : want))
    }
    readonly property real capH: {
        var want = glass.height + 2 * (glass.padPx + glass.capMargin)
        return Math.max(1, Math.min(want, glass.backdrop ? glass.backdrop.height : want))
    }
    readonly property real capX: Math.max(0, Math.min(glass._gx - glass.padPx - glass.capMargin, (glass.backdrop ? glass.backdrop.width : 0) - glass.capW))
    readonly property real capY: Math.max(0, Math.min(glass._gy - glass.padPx - glass.capMargin, (glass.backdrop ? glass.backdrop.height : 0) - glass.capH))

    readonly property real ds: glass.glassBlur >= 8 ? 0.5 : 1.0
    readonly property real bn: glass.glassBlur * 1.5 * glass.ds / 64.0

    ShaderEffectSource {
        id: bsrc
        sourceItem: glass.backdrop
        hideSource: true
        live: glass.visible
        visible: false
        sourceRect: Qt.rect(glass.capX, glass.capY, glass.capW, glass.capH)
        textureSize: Qt.size(Math.max(1, Math.round(glass.capW * glass.ds)), Math.max(1, Math.round(glass.capH * glass.ds)))
    }

    MultiEffect {
        id: bblurFx
        source: bsrc
        width: bsrc.sourceRect.width * glass.ds
        height: bsrc.sourceRect.height * glass.ds
        blurEnabled: true
        blurMax: 64
        blur: Math.min(1.0, glass.bn)
        autoPaddingEnabled: false
        visible: false
    }

    ShaderEffectSource {
        id: bblur
        sourceItem: bblurFx
        live: glass.visible
        mipmap: true
        visible: false
    }

    MultiEffect {
        id: bblur2Fx
        source: bblur
        width: bsrc.sourceRect.width * glass.ds
        height: bsrc.sourceRect.height * glass.ds
        blurEnabled: glass.bn > 1.0
        blurMax: 64
        blur: Math.max(0.0, Math.min(1.0, glass.bn - 1.0))
        autoPaddingEnabled: false
        visible: false
    }

    ShaderEffectSource {
        id: bblur2
        sourceItem: glass.bn > 1.0 ? bblur2Fx : null
        live: glass.visible
        mipmap: true
        visible: false
    }

    ShaderEffect {
        id: fx
        x: -glass.padPx
        y: -glass.padPx
        width: glass.width + 2 * glass.padPx
        height: glass.height + 2 * glass.padPx
        fragmentShader: glass.shader

        onStatusChanged: {
            if (status === ShaderEffect.Error) {
                glass.shaderOk = false
            }
        }

        property variant src: glass.bn > 1.0 ? bblur2 : bblur
        property vector4d edgeTint: Qt.vector4d(glass.edgeCol.r, glass.edgeCol.g, glass.edgeCol.b, 0.5)

        property real padPx: glass.padPx
        property vector2d itemSize: Qt.vector2d(width, height)
        property vector2d glassSize: Qt.vector2d(glass.width, glass.height)
        property vector2d srcSize: Qt.vector2d(glass.capW, glass.capH)
        property vector2d srcOffset: {
            var p = glass.mapToItem(glass.backdrop, -glass.padPx, -glass.padPx)
            return Qt.vector2d(p.x - glass.capX, p.y - glass.capY)
        }
        property real pad: glass.padPx
        property real radius: glass.cornerRadius
        property real bezel: glass.bezel
        property real thickness: glass.thickness
        property real dispersion: glass.dispersion
        property real magnify: glass.lensMagnify
        property real rim: glass.rim
        property real grain: glass.grain
        property real blurPx: 1.5
        property real tintMix: glass.tintMix
        property real saturation: glass.saturation
        property real dark: glass.dark ? 1 : 0
        property real debug: 0
        property real shadowAmt: glass.shadowAmt
        property real rimTint: glass.rimTint
        property real ringW: glass.ringW
        property real flatInner: 0
    }

    Rectangle {
        visible: !glass.shaderOk
        anchors.fill: parent
        radius: glass.cornerRadius
        color: glass.dark ? Qt.rgba(0.10, 0.10, 0.11, 0.42)
                          : Qt.rgba(1, 1, 1, 0.42 * 0.55)
        border.width: 0

        Rectangle {
            anchors.fill: parent
            radius: parent.radius - 0.35
            color: "transparent"
            border.width: 0.25
            border.color: glass.dark ? Qt.rgba(1, 1, 1, 0.06)
                                     : Qt.rgba(1, 1, 1, 0.12)
        }
    }
}
