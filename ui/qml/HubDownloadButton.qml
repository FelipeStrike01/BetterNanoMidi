import QtQuick

ActionButton {
    id: root

    required property var controller
    property string downloadState: "idle"
    property bool hasUrl: true
    readonly property bool busy: downloadState === "downloading"
    readonly property color stateColor: downloadState === "error" ? "#e88778" : accentColor

    viewMode: "icon"
    iconName: ""
    label: {
        const currentLanguage = controller.language
        const phrase = busy ? "Downloading MIDI" : downloadState === "complete" ? "MIDI downloaded" : downloadState === "error" ? "Download failed" : "Open MIDI"
        return controller.translateText(phrase)
    }
    variant: "ghost"
    implicitWidth: 46
    implicitHeight: 46
    width: 46
    height: 46
    enabled: hasUrl && !busy && downloadState !== "complete"
    Accessible.name: label

    onDownloadStateChanged: {
        if (busy) {
            actionPulse.restart()
        } else if (downloadState === "complete" || downloadState === "error") {
            resultPulse.restart()
        }
    }

    background: Rectangle {
        id: buttonSurface
        radius: 13
        color: root.busy ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.12)
            : root.downloadState === "complete" ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.18)
            : root.downloadState === "error" ? Qt.rgba(root.stateColor.r, root.stateColor.g, root.stateColor.b, 0.12)
            : root.down || root.hovered ? root.raisedColor : "transparent"
        border.color: root.activeFocus ? root.accentHoverColor
            : root.busy || root.downloadState === "complete" ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.58)
            : root.downloadState === "error" ? Qt.rgba(root.stateColor.r, root.stateColor.g, root.stateColor.b, 0.58)
            : root.hovered ? root.lineColor : "transparent"
        border.width: root.activeFocus ? 2 : root.busy || root.downloadState === "complete" || root.downloadState === "error" || root.hovered ? 1 : 0
        scale: root.down ? 0.94 : root.hovered ? 1.035 : 1
        Behavior on color { ColorAnimation { duration: 170; easing.type: Easing.OutCubic } }
        Behavior on border.color { ColorAnimation { duration: 170; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    }

    contentItem: Item {
        Item {
            id: orbit
            anchors.centerIn: parent
            width: 30
            height: 30
            visible: root.busy
            opacity: root.busy ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.24)
            }
            Item {
                anchors.fill: parent
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    width: 4
                    height: 7
                    radius: 3
                    color: root.accentColor
                }
                RotationAnimation on rotation {
                    running: root.busy
                    from: 0
                    to: 360
                    duration: 760
                    loops: Animation.Infinite
                    easing.type: Easing.Linear
                }
            }
        }

        Rectangle {
            id: feedbackRing
            anchors.centerIn: parent
            width: 18
            height: 18
            radius: width / 2
            color: "transparent"
            border.width: 1.4
            border.color: root.stateColor
            opacity: 0
            visible: opacity > 0.01
        }

        Icon {
            id: statusIcon
            anchors.centerIn: parent
            name: root.busy ? "download" : root.downloadState === "complete" ? "check" : root.downloadState === "error" ? "alert" : "download"
            color: root.downloadState === "error" ? root.stateColor : root.busy || root.downloadState === "complete" ? root.accentColor : root.foregroundColor
            iconSize: 17
            scale: root.busy ? 0.86 : 1
            Behavior on scale { NumberAnimation { duration: 190; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 160; easing.type: Easing.OutCubic } }
        }

        ParallelAnimation {
            id: actionPulse
            NumberAnimation { target: feedbackRing; property: "scale"; from: 0.42; to: 1.85; duration: 310; easing.type: Easing.OutCubic }
            NumberAnimation { target: feedbackRing; property: "opacity"; from: 0.72; to: 0; duration: 310; easing.type: Easing.OutCubic }
        }
        ParallelAnimation {
            id: resultPulse
            NumberAnimation { target: feedbackRing; property: "scale"; from: 0.48; to: 1.95; duration: 390; easing.type: Easing.OutCubic }
            NumberAnimation { target: feedbackRing; property: "opacity"; from: 0.76; to: 0; duration: 390; easing.type: Easing.OutCubic }
        }
    }
}
