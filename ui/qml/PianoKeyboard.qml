import QtQuick

Item {
    id: root
    implicitHeight: 112
    implicitWidth: 520
    property color whiteKeyColor: "#f8f7f3"
    property color blackKeyColor: "#111111"
    readonly property var blackAfterWhite: [true, false, true, true, false, true, true]

    Rectangle {
        anchors.fill: parent
        color: "#171614"
        radius: 8
        border.color: "#302d29"
    }

    Item {
        id: keybed
        anchors.fill: parent
        anchors.margins: 9
        clip: true

        Repeater {
            model: 52

            delegate: Rectangle {
                required property int index
                readonly property real keyWidth: keybed.width / 52
                x: index * keyWidth
                width: keyWidth + 0.35
                height: keybed.height
                color: root.whiteKeyColor
                border.width: 1
                border.color: "#aaa9a3"
            }
        }

        Repeater {
            model: 52

            delegate: Rectangle {
                required property int index
                readonly property real keyWidth: keybed.width / 52
                visible: index < 51 && root.blackAfterWhite[index % 7]
                x: (index + 1) * keyWidth - width / 2
                width: keyWidth * 0.62
                height: keybed.height * 0.66
                color: root.blackKeyColor
                border.width: 1
                border.color: "#030303"
                z: 2
            }
        }
    }
}
