import QtQuick
import "glass"

// Календарь по клику на часы (порт MacBar): стеклянная панель 320px,
// сетка 7x6, недели с понедельника, сегодня — акцентный круг.
Rectangle {
    id: root

    signal done()

    readonly property var today: new Date()
    property var shown: new Date(today.getFullYear(), today.getMonth(), 1)
    readonly property int wd0: (new Date(shown.getFullYear(),
        shown.getMonth(), 1).getDay() + 6) % 7

    width: 320
    height: 340
    radius: 24
    color: Qt.rgba(0.10, 0.10, 0.12, 0.86)
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.14)

    readonly property var monthNames: [
        "январь", "февраль", "март", "апрель", "май", "июнь", "июль",
        "август", "сентябрь", "октябрь", "ноябрь", "декабрь"
    ]

    function sameDay(a, d) {
        return a.getFullYear() === d.getFullYear()
            && a.getMonth() === d.getMonth()
            && a.getDate() === d.getDate()
    }

    Item {
        id: backdrop

        anchors.fill: parent

        Image {
            anchors.fill: parent
            source: bridge.wallpaper
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
    }

    LiquidGlass {
        anchors.fill: parent
        backdrop: backdrop
        cornerRadius: 24
        bezel: 14
        thickness: 22
        dispersion: 0.05
        lensMagnify: 0.0
        rim: 0.45 * 0.2
        tintMix: 0.42 * 0.55
        saturation: 1.22
        dark: true
        glassBlur: 13
        captureWidth: 0
    }

    MenuBorder {
        anchors.fill: parent
        cornerR: 24
        dark: true
        outline: false
    }

    // --- заголовок: месяц/год и стрелки ---
    Item {
        id: head

        x: 18
        y: 14
        width: parent.width - 36
        height: 30

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: {
                var m = root.monthNames[root.shown.getMonth()]
                return m.charAt(0).toUpperCase() + m.slice(1) + " "
                    + root.shown.getFullYear()
            }
            color: "#F2FFFFFF"
            font.family: "SF Pro Display"
            font.pixelSize: 15
            font.weight: Font.DemiBold
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Repeater {
                model: [
                    { d: -1, g: "‹" },
                    { d: 1, g: "›" }
                ]

                delegate: Rectangle {
                    id: nav

                    required property var modelData

                    width: 26
                    height: 26
                    radius: 13
                    color: navMa.containsMouse
                        ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.06)
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        text: nav.modelData.g
                        color: "#EAFFFFFF"
                        font.pixelSize: 15
                    }

                    MouseArea {
                        id: navMa

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.shown = new Date(
                            root.shown.getFullYear(),
                            root.shown.getMonth() + nav.modelData.d, 1)
                    }
                }
            }
        }
    }

    // --- дни недели ---
    Row {
        id: weekdays

        x: 12
        y: 52
        width: parent.width - 24
        spacing: 0

        Repeater {
            model: ["пн", "вт", "ср", "чт", "пт", "сб", "вс"]

            Text {
                required property var modelData

                width: weekdays.width / 7
                horizontalAlignment: Text.AlignHCenter
                text: modelData
                color: Qt.rgba(1, 1, 1, 0.42)
                font.family: "SF Pro Display"
                font.pixelSize: 11
            }
        }
    }

    // --- сетка дней ---
    Item {
        x: 12
        y: 72
        width: parent.width - 24
        height: 6 * 42

        Repeater {
            model: 42

            Item {
                id: day

                required property int index

                readonly property var date: new Date(root.shown.getFullYear(),
                    root.shown.getMonth(), 1 - root.wd0 + index)
                readonly property bool dim: date.getMonth()
                    !== root.shown.getMonth()
                readonly property bool isToday: root.sameDay(date, root.today)

                x: (index % 7) * (parent.width / 7)
                y: Math.floor(index / 7) * 42
                width: parent.width / 7
                height: 42

                Rectangle {
                    anchors.centerIn: parent
                    width: 30
                    height: 30
                    radius: 15
                    color: day.isToday ? "#0A84FF" : "transparent"
                }

                Text {
                    anchors.centerIn: parent
                    text: day.date.getDate()
                    color: day.isToday ? "#FFFFFFFF"
                        : (day.dim ? Qt.rgba(1, 1, 1, 0.26)
                                   : Qt.rgba(1, 1, 1, 0.88))
                    font.family: "SF Pro Display"
                    font.pixelSize: 13
                    font.weight: day.isToday ? Font.DemiBold : Font.Normal
                }
            }
        }
    }
}
