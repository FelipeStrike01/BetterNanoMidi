import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Button {
    id: root
    required property string label
    required property string iconName
    required property bool selected
    property bool compact: false
    property color accentColor: "#b76b4d"
    property color textColor: "#e9e1d8"
    property color mutedColor: "#bcb0a4"
    property bool tooltipsEnabled: typeof controller === "undefined" || Boolean(controller.settings.appUI.tooltip)
    signal activated()
    implicitWidth: compact ? 52 : 204
    implicitHeight: 46
    Layout.fillWidth: true
    padding: 0
    hoverEnabled: true
    onClicked: activated()
    ToolTip.visible: tooltipsEnabled && compact && hovered
    ToolTip.text: label
    ToolTip.delay: 500
    background: Rectangle {
        radius: 5
            color: root.selected ? Qt.darker(root.accentColor, 3.5) : root.hovered ? "#201c19" : "transparent"
        Rectangle {
            width: 2; height: 19; radius: 2
            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
            color: root.selected ? root.accentColor : "transparent"
            opacity: root.selected ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 160; easing.type: Easing.OutCubic } }
        }
        Behavior on color { ColorAnimation { duration: 130 } }
    }
    contentItem: Item {
        Row {
            anchors.left: root.compact ? undefined : parent.left
            anchors.horizontalCenter: root.compact ? parent.horizontalCenter : undefined
            anchors.leftMargin: root.compact ? 0 : 18
            anchors.verticalCenter: parent.verticalCenter
            width: root.compact ? 24 : parent.width - 36
            spacing: root.compact ? 0 : 12
            Item {
                width: 24; height: 24
                Icon {
                    anchors.centerIn: parent
                    name: root.iconName
                    color: root.selected ? root.accentColor : root.mutedColor
                    iconSize: 18
                    Behavior on color { ColorAnimation { duration: 170; easing.type: Easing.OutCubic } }
                }
            }
            Text {
                visible: !root.compact
                text: root.label
                color: root.selected ? root.textColor : root.mutedColor
                font.pixelSize: 13
                font.weight: root.selected ? Font.DemiBold : Font.Medium
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                width: Math.max(0, parent.width - 36)
            }
        }
    }
}
