import QtQuick

Item {
    id: panel

    property Item backdrop
    property bool dark: true
    property real glassBlur: 13
    property real cornerRadius: 16
    property real dispersion: 0.06
    property real tintMix: 0.42 * 0.55
    property real saturation: 1.25
    property real rim: 0.45 * 0.20

    default property alias content: body.data

    LiquidGlass {
        anchors.fill: parent
        backdrop: panel.backdrop
        cornerRadius: panel.cornerRadius
        bezel: Math.min(panel.height * 0.36, 26)
        thickness: 24
        dispersion: panel.dispersion
        lensMagnify: 0.0
        rim: panel.rim
        grain: 0.009
        tintMix: panel.tintMix
        saturation: panel.saturation
        dark: panel.dark
        glassBlur: panel.glassBlur
        captureWidth: panel.width
    }

    Item { id: body; anchors.fill: parent }
}
