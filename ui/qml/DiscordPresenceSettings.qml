import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    required property var controller
    required property var themePalette
    function t(source) {
        const currentLanguage = root.controller.language
        return root.controller.translateText(source)
    }
    implicitWidth: 360
    implicitHeight: panel.implicitHeight
    Layout.fillWidth: true
    Layout.minimumWidth: 0

    Rectangle {
        id: panel
        width: parent.width
        implicitHeight: content.implicitHeight + 30
        radius: 10
        color: root.themePalette.surface
        border.color: root.themePalette.line

        ColumnLayout {
            id: content
            anchors.fill: parent
            anchors.margins: 15
            spacing: 9

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Icon { name: "piano"; color: root.themePalette.accent; iconSize: 23 }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text { text: root.t("Discord Rich Presence"); color: root.themePalette.text; font.pixelSize: 14; font.weight: Font.DemiBold }
                    Text { text: root.t("Show your current activity on your Better NanoMidi profile."); color: root.themePalette.muted; font.pixelSize: 10; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                }
            }

            ToggleRow {
                Layout.fillWidth: true
                controller: root.controller
                section: "discordPresence"
                setting: "enabled"
                label: root.t("Share activity on Discord")
                detail: root.t("Activity and MIDI filename may be visible on your profile.")
                accentColor: root.themePalette.accent
                textColor: root.themePalette.text
                mutedColor: root.themePalette.muted
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Icon { name: "info"; color: root.themePalette.muted; iconSize: 15 }
                Text {
                    Layout.fillWidth: true
                    text: root.controller.discordPresenceStatus
                    color: root.themePalette.muted
                    font.pixelSize: 10
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
