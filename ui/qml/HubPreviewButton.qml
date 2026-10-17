import QtQuick
import QtQuick.Controls
import QtQuick.Window

Button {
    id: root

    required property var controller
    property string previewState: "idle"
    property bool hasUrl: true
    property color accentColor: "#b76b4d"
    readonly property var theme: Window.window ? Window.window.themePalette : null
    readonly property color accentHoverColor: theme && theme.accentHover ? theme.accentHover : "#cc825f"
    readonly property color foregroundColor: enabled && previewState !== "error"
                                             ? (theme && theme.text ? theme.text : "#e9e1d8")
                                             : (theme && theme.muted ? theme.muted : "#a89d91")
    readonly property color raisedColor: theme && theme.raised ? theme.raised : "#25211d"
    readonly property color lineColor: theme && theme.line ? theme.line : "#382f29"

    readonly property string label: {
        if (previewState === "loading") return controller.translateText("Cancel preview")
        if (previewState === "playing") return controller.translateText("Stop preview")
        if (previewState === "error") return controller.translateText("Preview failed")
        return controller.translateText("Preview MIDI")
    }

    width: 38
    height: 38
    implicitWidth: width
    implicitHeight: height
    padding: 0
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    enabled: hasUrl && (controller.hubPreviewActive || !controller.isRunning)
    Accessible.name: label

    background: Rectangle {
        radius: 11
        color: root.previewState === "playing"
               ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.2)
               : root.down || root.hovered ? root.raisedColor : "transparent"
        border.width: root.activeFocus ? 2 : root.previewState === "playing" || root.hovered ? 1 : 0
        border.color: root.activeFocus ? root.accentHoverColor
                      : root.previewState === "playing" ? root.accentColor
                      : root.hovered ? root.lineColor : "transparent"
        scale: root.down ? 0.94 : root.hovered ? 1.04 : 1
        Behavior on color { ColorAnimation { duration: 160; easing.type: Easing.OutCubic } }
        Behavior on border.color { ColorAnimation { duration: 160; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    }

    contentItem: Item {
        Icon {
            id: previewIcon
            anchors.centerIn: parent
            name: root.previewState === "loading" ? "refresh"
                  : root.previewState === "playing" ? "stop" : "play"
            color: root.previewState === "playing" ? root.accentColor : root.foregroundColor
            iconSize: 16

            RotationAnimation on rotation {
                running: root.previewState === "loading"
                from: 0
                to: 360
                duration: 760
                loops: Animation.Infinite
                easing.type: Easing.Linear
            }
        }
    }

    ToolTip.visible: root.hovered && root.label.length > 0
    ToolTip.delay: 450
    ToolTip.text: root.label
}
