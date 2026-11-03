import QtQuick
import "../glass"

// Виджет «Заметка»: липкий стикер на рабочем столе, текст сохраняется
// в ~/.swinewm/notes.txt при окончании редактирования.
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

    Text {
        x: 16
        y: 12
        text: "Заметка"
        color: "#99FFFFFF"
        font.family: "SF Pro Display"
        font.pixelSize: 11
        font.weight: Font.Medium
    }

    Text {
        x: 16
        y: 34
        width: parent.width - 32
        visible: ed.text === "" && !ed.activeFocus
        text: "Записать что-нибудь…"
        color: Qt.rgba(1, 1, 1, 0.30)
        font.family: "SF Pro Display"
        font.pixelSize: 13
        wrapMode: Text.WordWrap
    }

    TextEdit {
        id: ed

        x: 16
        y: 34
        width: parent.width - 32
        height: parent.height - 48
        text: (bridge.config.notesText || "")
        color: "#F2FFFFFF"
        font.family: "SF Pro Display"
        font.pixelSize: 13
        wrapMode: TextEdit.WordWrap
        clip: true
        selectionColor: "#5E5CE6"
        onEditingFinished: bridge.saveNote(text)
    }
}
