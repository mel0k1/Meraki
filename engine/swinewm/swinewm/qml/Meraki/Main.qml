import QtQuick

Rectangle {
    id: root
    color: "transparent"

    Bar {
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
    }
}
