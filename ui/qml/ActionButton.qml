import QtQuick
import QtQuick.Controls
import QtQuick.Window

Button {
    id: root

    property string label: ""
    property string iconName: ""
    property string viewMode: "text"
    property string variant: "secondary"
    readonly property bool iconOnly: viewMode === "icon"
    readonly property var theme: Window.window ? Window.window.themePalette : null
    property color accentColor: theme && theme.accent ? theme.accent : "#b76b4d"
    property color accentHoverColor: theme && theme.accentHover ? theme.accentHover : "#cc825f"
    property color textColor: theme && theme.text ? theme.text : "#e9e1d8"
    property color mutedColor: theme && theme.muted ? theme.muted : "#a89d91"
    property color surfaceColor: theme && theme.surface ? theme.surface : "#1d1a17"
    property color raisedColor: theme && theme.raised ? theme.raised : "#25211d"
    property color lineColor: theme && theme.line ? theme.line : "#382f29"
    property bool tooltipsEnabled: typeof controller === "undefined" || Boolean(controller.settings.appUI.tooltip)
    readonly property color foregroundColor: {
        if (!root.enabled) return root.mutedColor
        if (root.variant === "primary") return "#141210"
        if (root.variant === "danger") return "#e4aaa0"
        return root.textColor
    }
    readonly property color fillColor: {
        if (!root.enabled) return root.surfaceColor
        if (root.variant === "primary")
            return root.down ? Qt.darker(root.accentColor, 1.14) : root.hovered ? root.accentHoverColor : root.accentColor
        if (root.variant === "danger")
            return root.down ? "#37231f" : root.hovered ? "#30211e" : "#261c1a"
        if (root.variant === "ghost")
            return root.down || root.hovered ? root.raisedColor : "transparent"
        return root.down ? "#302a24" : root.hovered ? "#2d2721" : root.raisedColor
    }
    readonly property color outlineColor: {
        if (root.activeFocus) return root.accentHoverColor
        if (root.variant === "primary") return root.accentColor
        if (root.variant === "danger") return "#654039"
        if (root.variant === "ghost") return root.hovered ? root.lineColor : "transparent"
        return root.lineColor
    }

    implicitWidth: root.iconOnly ? 36 : Math.max(72, caption.implicitWidth + (root.iconName.length > 0 ? 54 : 28))
    implicitHeight: 36
    padding: 0
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    Accessible.name: root.label.length > 0 ? root.label : root.iconName

    contentItem: Item {
        scale: root.down ? 0.97 : 1
        Behavior on scale { NumberAnimation { duration: 145; easing.type: Easing.OutCubic } }
        Row {
            anchors.centerIn: parent
            spacing: 8
            Icon {
                id: buttonIcon
                visible: root.iconName.length > 0
                name: root.iconName
                color: root.foregroundColor
                iconSize: 16
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                id: caption
                visible: !root.iconOnly && root.label.length > 0
                text: root.label
                color: root.foregroundColor
                font.pixelSize: 12
                font.weight: Font.DemiBold
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
        }
    }

    Connections {
        target: root
        function onClicked() {
            if (root.iconName === "refresh") refreshSpin.restart()
        }
    }

    NumberAnimation {
        id: refreshSpin
        target: buttonIcon
        property: "rotation"
        from: 0
        to: 360
        duration: 430
        easing.type: Easing.OutCubic
    }

    background: Rectangle {
        radius: 5
        color: root.fillColor
        border.color: root.outlineColor
        border.width: root.activeFocus ? 2 : root.variant === "ghost" && !root.hovered ? 0 : 1
        Behavior on color { ColorAnimation { duration: 100 } }
        Behavior on border.color { ColorAnimation { duration: 135; easing.type: Easing.OutCubic } }
    }

    ToolTip.visible: root.tooltipsEnabled && root.iconOnly && root.hovered && root.label.length > 0
    ToolTip.delay: 450
    ToolTip.text: root.label
}
