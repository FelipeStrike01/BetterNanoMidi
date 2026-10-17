import QtQuick

Column {
    id: root
    required property var controller
    required property var themePalette
    function t(source) {
        const currentLanguage = root.controller.language
        return root.controller.translateText(source)
    }
    spacing: 8
    Row {
        spacing: 10
        Text { text: root.t("Activity"); color: root.themePalette.text; font.pixelSize: 12; font.weight: Font.DemiBold }
        Rectangle { width: 6; height: 6; radius: 3; color: root.themePalette.success; anchors.verticalCenter: parent.verticalCenter }
        Text { text: root.t("LIVE"); color: root.themePalette.success; font.pixelSize: 9; font.weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter }
        Item { width: 1; height: 1 }
        ActionButton {
            label: root.t("Clear")
            variant: "danger"
            onClicked: root.controller.clearActivity()
        }
    }
    Rectangle {
        width: parent.width; height: 104; radius: 8
        color: "#171411"; border.color: root.themePalette.line
        Flickable {
            anchors.fill: parent; anchors.margins: 11; clip: true
            contentHeight: logText.implicitHeight
            Text {
                id: logText
                objectName: "activityLogText"
                width: parent.width
                text: root.controller && root.controller.consoleText
                      ? String(root.controller.consoleText)
                      : root.t("No activity yet. Playback and device events will appear here.")
                color: "#c8bcb0"; font.pixelSize: 10; font.family: "Consolas"
                wrapMode: Text.WrapAnywhere
            }
            onContentHeightChanged: contentY = Math.max(0, contentHeight - height)
        }
    }
}
