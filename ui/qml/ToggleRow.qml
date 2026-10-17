import QtQuick
import QtQuick.Controls

Item {
    id: root
    required property var controller
    required property string section
    required property string setting
    required property string label
    property string detail: ""
    property color accentColor: "#b76b4d"
    property color textColor: "#e9e1d8"
    property color mutedColor: "#a89d91"
    property int rowHeight: detail ? 62 : 44
    implicitHeight: rowHeight
    implicitWidth: 250

    Switch {
        id: toggle
        anchors.fill: parent
        padding: 0
        spacing: 0
        hoverEnabled: true
        checked: {
            const sectionValue = root.controller.settings[root.section]
            if (!sectionValue) return false
            const settingValue = sectionValue[root.setting]
            return settingValue && typeof settingValue === "object" ? Boolean(settingValue.enabled) : Boolean(settingValue)
        }
        onToggled: root.controller.toggleFeature(root.section, root.setting, checked)
        background: Rectangle {
            radius: 5
            color: toggle.hovered ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.055) : "transparent"
            Behavior on color { ColorAnimation { duration: 120 } }
        }
        indicator: Rectangle {
            implicitWidth: 38; implicitHeight: 22
            x: toggle.width - width - 3
            y: toggle.height / 2 - height / 2
            radius: 11
            color: toggle.checked ? Qt.darker(root.accentColor, 1.35) : "#302923"
            border.color: toggle.checked ? root.accentColor : "#3a4650"
            Rectangle {
                x: toggle.checked ? parent.width - width - 3 : 3
                y: 3; width: 14; height: 14; radius: 7
                color: toggle.checked ? Qt.lighter(root.accentColor, 1.65) : "#a6b2ba"
                Behavior on x { NumberAnimation { duration: 165; easing.type: Easing.InOutCubic } }
                Behavior on color { ColorAnimation { duration: 155; easing.type: Easing.OutCubic } }
            }
            Behavior on color { ColorAnimation { duration: 155; easing.type: Easing.OutCubic } }
            Behavior on border.color { ColorAnimation { duration: 155; easing.type: Easing.OutCubic } }
        }
        contentItem: Item {
            Column {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.rightMargin: 54
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Text { text: root.label; color: root.textColor; font.pixelSize: 13; font.weight: Font.Medium; elide: Text.ElideRight; width: parent.width }
                Text {
                    visible: root.detail.length > 0
                    text: root.detail
                    color: root.mutedColor
                    font.pixelSize: 11
                    wrapMode: Text.WordWrap
                    width: parent.width
                }
            }
        }
    }
}
