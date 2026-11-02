import QtQuick
import "../glass"

Item {
    id: root

    readonly property bool open: bridge.open
    readonly property int panelH: Math.min(620, bridge.screenHeight - 60)
    readonly property real y0: 44 - (1 - slide) * (panelH + 60)
    property real slide: open ? 1 : 0
    property int tick: 0

    Behavior on slide { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

    onY0Changed: {
        bridge.panelY = y0
        bridge.panelH = panelH
    }

    Component.onCompleted: {
        bridge.panelY = y0
        bridge.panelH = panelH
    }

    function rel(ms) {
        if (!ms) {
            return ""
        }
        var d = Date.now() - ms
        if (d < 60000) {
            return "только что"
        }
        if (d < 3600000) {
            return Math.floor(d / 60000) + " мин"
        }
        return Qt.formatDateTime(new Date(ms), "HH:mm")
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.tick++
    }

    Item {
        id: backdrop
        anchors.fill: parent

        Image {
            anchors.fill: parent
            source: bridge.wallpaper
            fillMode: Image.PreserveAspectCrop
        }

        Repeater {
            model: bridge.windows
            Rectangle {
                required property var modelData
                x: modelData.x
                y: modelData.y
                width: Math.max(2, modelData.w)
                height: Math.max(2, modelData.h)
                radius: 4
                color: modelData.focused ? Qt.rgba(0.72, 0.78, 0.88, 0.30)
                                         : Qt.rgba(0.60, 0.65, 0.75, 0.18)
            }
        }
    }

    DockGlassPanel {
        id: panel
        x: 0
        y: root.y0
        width: parent.width
        height: root.panelH
        cornerRadius: 18

        Item {
            id: head
            x: 14
            y: 10
            width: parent.width - 28
            height: 34

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Уведомления"
                color: "#F2FFFFFF"
                font.family: "SF Pro Display"
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "Очистить"
                color: bridge.count > 0 ? "#8ECBFF" : "#55FFFFFF"
                font.family: "SF Pro Display"
                font.pixelSize: 12

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    enabled: bridge.count > 0
                    onClicked: bridge.clearAll()
                }
            }
        }

        Rectangle {
            x: 14
            y: 48
            width: parent.width - 28
            height: 1
            color: Qt.rgba(1, 1, 1, 0.10)
        }

        ListView {
            id: list
            anchors {
                top: parent.top
                topMargin: 58
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                leftMargin: 12
                rightMargin: 12
                bottomMargin: 12
            }
            model: bridge.notes
            spacing: 8
            clip: true

            delegate: Rectangle {
                id: card

                required property var modelData

                width: list.width
                height: cardText.height + 20
                radius: 12
                color: ca.containsMouse ? Qt.rgba(1, 1, 1, 0.12)
                                        : Qt.rgba(1, 1, 1, 0.06)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.08)

                Rectangle {
                    visible: card.modelData.urgency === "critical"
                    x: 0
                    y: 10
                    width: 3
                    height: parent.height - 20
                    radius: 1.5
                    color: "#FF6B5E"
                }

                Image {
                    id: ico
                    x: 12
                    y: 12
                    width: 28
                    height: 28
                    source: "image://dockicon/" + card.modelData.app
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true
                    asynchronous: true
                }

                Text {
                    anchors.top: parent.top
                    anchors.topMargin: 12
                    anchors.right: parent.right
                    anchors.rightMargin: 30
                    text: {
                        root.tick
                        return root.rel(card.modelData.when)
                    }
                    color: "#66FFFFFF"
                    font.family: "SF Pro Display"
                    font.pixelSize: 10
                }

                Text {
                    anchors.top: parent.top
                    anchors.topMargin: 9
                    anchors.right: parent.right
                    anchors.rightMargin: 9
                    width: 18
                    height: 18
                    text: "×"
                    color: cx.containsMouse ? "#F2FFFFFF" : "#80FFFFFF"
                    font.family: "SF Pro Display"
                    font.pixelSize: 13
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    opacity: ca.containsMouse ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 100 } }

                    MouseArea {
                        id: cx
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: bridge.dismiss(card.modelData.id)
                    }
                }

                Column {
                    id: cardText
                    anchors {
                        left: ico.right
                        leftMargin: 10
                        right: parent.right
                        rightMargin: 12
                        top: parent.top
                        topMargin: 10
                    }
                    spacing: 3

                    Text {
                        width: parent.width
                        text: card.modelData.summary.length > 0
                            ? card.modelData.summary : card.modelData.app
                        color: "#F2FFFFFF"
                        font.family: "SF Pro Display"
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        visible: card.modelData.body.length > 0
                        text: card.modelData.body
                        color: "#99FFFFFF"
                        font.family: "SF Pro Display"
                        font.pixelSize: 11
                        textFormat: Text.PlainText
                        wrapMode: Text.WordWrap
                        elide: Text.ElideRight
                        maximumLineCount: 3
                    }

                    Text {
                        width: parent.width
                        visible: card.modelData.app.length > 0
                            && card.modelData.summary.length > 0
                        text: card.modelData.app
                        color: "#55FFFFFF"
                        font.family: "SF Pro Display"
                        font.pixelSize: 10
                        elide: Text.ElideRight
                    }

                    // Действия уведомления (notify-send -A "ключ=Подпись"):
                    // пилюли под текстом, клик вызывает действие.
                    Row {
                        visible: Object.keys(card.modelData.actions || {}).length > 0
                        spacing: 6

                        Repeater {
                            model: Object.keys(card.modelData.actions || {})

                            Rectangle {
                                id: act

                                required property string modelData

                                width: actLbl.implicitWidth + 18
                                height: 22
                                radius: 11
                                color: actMa.containsMouse
                                    ? Qt.rgba(1, 1, 1, 0.22)
                                    : Qt.rgba(1, 1, 1, 0.10)
                                border.width: 1
                                border.color: Qt.rgba(1, 1, 1, 0.14)
                                Behavior on color { ColorAnimation { duration: 120 } }

                                Text {
                                    id: actLbl
                                    anchors.centerIn: parent
                                    text: card.modelData.actions[act.modelData]
                                        || act.modelData
                                    color: "#F2FFFFFF"
                                    font.family: "SF Pro Display"
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                }

                                MouseArea {
                                    id: actMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: bridge.invokeAction(
                                        card.modelData.id, act.modelData)
                                }
                            }
                        }
                    }
                }

                // Вся карточка кликабельна (фокус приложения), но живёт под
                // кнопками: крестик и действия объявлены позже и принимают
                // клики первыми.
                MouseArea {
                    id: ca
                    z: -1
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: bridge.focusApp(card.modelData.app)
                }
            }
        }

        Column {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 10
            spacing: 6
            visible: bridge.notes.length === 0

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Нет уведомлений"
                color: "#99FFFFFF"
                font.family: "SF Pro Display"
                font.pixelSize: 12
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "notify-send \"Заголовок\" \"Текст\""
                color: "#55FFFFFF"
                font.family: "SF Pro Display"
                font.pixelSize: 10
            }
        }
    }
}
