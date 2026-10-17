import QtQuick
import QtQuick.Controls

Column {
    id: root
    objectName: controlName
    required property var controller
    required property string label
    required property string controlName
    required property real minimum
    required property real maximum
    required property real initialValue
    property real stepSize: 1
    property string suffix: ""
    property string description: ""
    property bool active: true
    property color accentColor: "#b76b4d"
    property color textColor: "#e9e1d8"
    property color mutedColor: "#a89d91"
    spacing: 8
    width: 360
    enabled: active
    opacity: active ? 1 : 0.48

    function syncInitialValue() {
        slider.value = Math.max(root.minimum, Math.min(root.maximum, Number(root.initialValue)))
    }
    onInitialValueChanged: syncInitialValue()
    Component.onCompleted: {
        syncInitialValue()
        sliderReady = true
    }
    property bool sliderReady: false

    Row {
        width: parent.width
        spacing: 12
        Column {
            width: parent.width - 76
            spacing: 3
            Text { text: root.label; color: root.textColor; font.pixelSize: 13; font.weight: Font.DemiBold }
            Text { visible: root.description.length > 0; text: root.description; color: root.mutedColor; font.pixelSize: 11; wrapMode: Text.WordWrap; width: parent.width }
        }
        Text {
            objectName: root.controlName + "Value"
            width: 64; horizontalAlignment: Text.AlignRight
            text: Number(slider.value).toFixed(root.stepSize < 1 ? 2 : 0) + root.suffix
            color: "#e2d7cd"; font.pixelSize: 12; font.family: "Consolas"
        }
    }
    Row {
        width: parent.width
        spacing: 12
        Slider {
            id: slider
            objectName: root.controlName + "Slider"
            hoverEnabled: true
            width: parent.width - 48
            from: root.minimum; to: root.maximum; stepSize: root.stepSize
            value: root.initialValue
            onMoved: root.controller.previewControl(root.controlName, value)
            onValueChanged: {
                if (!root.sliderReady) return
                if (pressed) {
                    root.controller.previewControl(root.controlName, value)
                } else if (activeFocus) {
                    root.controller.setControl(root.controlName, value)
                }
            }
            onPressedChanged: {
                if (!pressed && root.sliderReady) {
                    root.controller.setControl(root.controlName, value)
                }
            }
            background: Rectangle {
                x: slider.leftPadding; y: slider.topPadding + slider.availableHeight / 2 - height / 2
                width: slider.availableWidth; height: 4; radius: 2; color: "#382f29"
                Rectangle { width: slider.visualPosition * parent.width; height: parent.height; radius: 2; color: root.accentColor }
            }
            handle: Rectangle {
                x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
                y: slider.topPadding + slider.availableHeight / 2 - height / 2
                width: 14; height: 14; radius: 7; color: Qt.lighter(root.accentColor, 1.65); border.color: root.accentColor
                scale: slider.pressed ? 1.16 : slider.hovered ? 1.08 : 1
                Behavior on scale { NumberAnimation { duration: 135; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 140; easing.type: Easing.OutCubic } }
            }
        }
        ActionButton { viewMode: "icon"; iconName: "reset"; label: root.controller.language === "pt" ? "Redefinir " + root.label : "Reset " + root.label; variant: "ghost"; onClicked: root.controller.resetControl(root.controlName) }
    }
}
