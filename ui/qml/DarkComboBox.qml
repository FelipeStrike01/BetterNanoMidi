pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

ComboBox {
    id: control
    property var themePalette: ({
        text: "#e9e1d8", muted: "#a89d91", surface: "#1d1a17",
        raised: "#201c19", line: "#382f29", accent: "#b76b4d"
    })
    property color textColor: themePalette.text
    property color mutedColor: themePalette.muted
    property color fieldColor: themePalette.surface
    property color popupColor: themePalette.raised
    property color lineColor: themePalette.line
    property color accentColor: themePalette.accent

    implicitHeight: 37
    leftPadding: 12
    rightPadding: 36
    hoverEnabled: true

    contentItem: Text {
        leftPadding: control.leftPadding
        rightPadding: control.rightPadding
        text: control.displayText
        color: control.enabled ? control.textColor : control.mutedColor
        font.pixelSize: 12
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    indicator: Item {
        width: 14
        height: 14
        x: control.width - width - 11
        y: control.height / 2 - height / 2
        rotation: control.popup.visible ? 180 : 0
        Rectangle { width: 7; height: 1.5; radius: 1; x: 1; y: 5; rotation: 42; color: control.mutedColor }
        Rectangle { width: 7; height: 1.5; radius: 1; x: 6; y: 5; rotation: -42; color: control.mutedColor }
        Behavior on rotation { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    }

    background: Rectangle {
        radius: 10
        color: control.down ? Qt.darker(control.fieldColor, 1.12)
              : control.hovered ? Qt.lighter(control.fieldColor, 1.05)
              : control.fieldColor
        border.width: control.activeFocus ? 1.5 : 1
        border.color: control.activeFocus ? control.accentColor
                     : control.hovered ? Qt.lighter(control.lineColor, 1.22)
                     : control.lineColor
        Behavior on color { ColorAnimation { duration: 130; easing.type: Easing.OutCubic } }
        Behavior on border.color { ColorAnimation { duration: 110 } }
    }

    delegate: ItemDelegate {
        id: itemDelegate
        required property int index
        width: control.width - 8
        height: 35
        text: control.textAt(index)
        highlighted: control.highlightedIndex === index || hovered
        hoverEnabled: true
        contentItem: Text {
            text: itemDelegate.text
            color: control.textColor
            font.pixelSize: 12
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
        background: Rectangle {
            radius: 7
            color: itemDelegate.highlighted
                ? Qt.rgba(control.accentColor.r, control.accentColor.g, control.accentColor.b, 0.2)
                : itemDelegate.hovered ? Qt.rgba(1, 1, 1, 0.035) : "transparent"
            border.width: itemDelegate.highlighted ? 1 : 0
            border.color: Qt.rgba(control.accentColor.r, control.accentColor.g, control.accentColor.b, 0.24)
            Behavior on color { ColorAnimation { duration: 100 } }
        }
    }

    popup: Popup {
        y: control.height + 6
        width: control.width
        padding: 6
        implicitHeight: Math.min(listView.contentHeight, 320) + padding * 2
        contentItem: ListView {
            id: listView
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            implicitHeight: contentHeight
            model: control.popup.visible ? control.delegateModel : null
            currentIndex: control.highlightedIndex
            ScrollIndicator.vertical: ScrollIndicator { }
        }
        background: Rectangle {
            radius: 12
            color: control.popupColor
            border.color: Qt.lighter(control.lineColor, 1.12)
            border.width: 1
        }
        enter: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 155; easing.type: Easing.OutCubic }
                NumberAnimation { property: "scale"; from: 0.975; to: 1; duration: 190; easing.type: Easing.OutCubic }
            }
        }
        exit: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 105; easing.type: Easing.InCubic }
                NumberAnimation { property: "scale"; from: 1; to: 0.985; duration: 120; easing.type: Easing.InCubic }
            }
        }
    }
}
