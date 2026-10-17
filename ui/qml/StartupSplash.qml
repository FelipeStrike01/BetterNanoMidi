import QtQuick
import QtQuick.Window

Window {
    id: root

    width: 380
    height: 380
    visible: false
    opacity: 0
    color: "transparent"
    flags: Qt.SplashScreen | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    transientParent: null

    required property var themePalette
    required property bool lightTheme
    required property int startupProgress
    required property string startupStatus
    required property bool startupReady
    property bool minimumElapsed: false
    property bool timedOut: false
    signal finished()

    function alpha(color, amount) {
        const resolved = Qt.darker(color, 1.0)
        return Qt.rgba(resolved.r, resolved.g, resolved.b, amount)
    }

    function start() {
        x = Math.round((Screen.desktopAvailableWidth - width) / 2)
        y = Math.round((Screen.desktopAvailableHeight - height) / 2)
        opacity = 0
        splashSurface.scale = 0.955
        flags = Qt.SplashScreen | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
        visible = true
        bringToFront()
        Qt.callLater(function() { root.bringToFront() })
        topmostTimer.start()
        entrance.start()
        minimumElapsed = false
        timedOut = false
        minimumTimer.start()
        fallbackTimer.start()
    }

    function bringToFront() {
        if (!visible)
            return
        raise()
        requestActivate()
    }

    function maybeFinish() {
        if (!visible || !minimumElapsed || (!startupReady && !timedOut) || exitAnimation.running)
            return
        minimumTimer.stop()
        fallbackTimer.stop()
        exitAnimation.start()
    }

    Timer {
        id: minimumTimer
        interval: 3200
        repeat: false
        onTriggered: {
            root.minimumElapsed = true
            root.maybeFinish()
        }
    }

    Timer {
        id: fallbackTimer
        interval: 18000
        repeat: false
        onTriggered: {
            root.timedOut = true
            root.maybeFinish()
        }
    }

    // Windows can finish creating/activating the native splash surface after
    // visible becomes true. Reassert its topmost z-order once that settles.
    Timer {
        id: topmostTimer
        interval: 120
        repeat: false
        onTriggered: root.bringToFront()
    }

    onStartupReadyChanged: maybeFinish()
    onVisibleChanged: {
        if (visible)
            Qt.callLater(function() { root.bringToFront() })
        else
            topmostTimer.stop()
    }

    ParallelAnimation {
        id: entrance
        NumberAnimation {
            target: root
            property: "opacity"
            from: 0
            to: 1
            duration: 240
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: splashSurface
            property: "scale"
            from: 0.955
            to: 1
            duration: 380
            easing.type: Easing.OutCubic
        }
    }

    ParallelAnimation {
        id: exitAnimation
        NumberAnimation {
            target: root
            property: "opacity"
            from: 1
            to: 0
            duration: 180
            easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: splashSurface
            property: "scale"
            from: 1
            to: 0.99
            duration: 180
            easing.type: Easing.InCubic
        }
        onFinished: {
            root.finished()
            root.visible = false
        }
    }

    Rectangle {
        id: splashSurface
        anchors.fill: parent
        radius: 18
        color: root.alpha(root.themePalette.surface, 0.97)
        border.width: 1
        border.color: root.themePalette.line
        clip: true
        transformOrigin: Item.Center

        PlasmaBackground {
            anchors.fill: parent
            baseColor: root.themePalette.background
            windowActive: root.visible
            opacity: 0.32
        }

        Column {
            anchors.centerIn: parent
            spacing: 11

            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                source: Qt.resolvedUrl("../../assets/branding/better-nanomidi/" +
                                       (root.lightTheme ? "symbol-on-light.png" : "symbol-on-dark.png"))
                sourceSize.width: 144
                sourceSize.height: 144
                width: 72
                height: 72
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
                Accessible.name: "Better NanoMidi"
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Better NanoMidi"
                color: root.themePalette.text
                font.family: "Inter"
                font.pixelSize: 22
                font.weight: Font.DemiBold
                font.letterSpacing: -0.25
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.startupStatus
                color: root.themePalette.muted
                font.family: "Inter"
                font.pixelSize: 11
                elide: Text.ElideMiddle
                width: 250
                horizontalAlignment: Text.AlignHCenter
            }

            Row {
                id: activityBars
                anchors.horizontalCenter: parent.horizontalCenter
                height: 28
                spacing: 5

                Repeater {
                    model: [10, 15, 24, 17, 11]

                    delegate: Rectangle {
                        required property int index
                        required property int modelData
                        width: 4
                        height: modelData
                        anchors.verticalCenter: parent.verticalCenter
                        radius: 2
                        color: index === 2 ? root.themePalette.accent : root.alpha(root.themePalette.text, 0.56)
                        transformOrigin: Item.Center

                        SequentialAnimation on scale {
                            running: root.visible
                            loops: Animation.Infinite
                            PauseAnimation { duration: index * 65 }
                            NumberAnimation {
                                from: 0.48
                                to: 1
                                duration: 220
                                easing.type: Easing.OutCubic
                            }
                            NumberAnimation {
                                from: 1
                                to: 0.48
                                duration: 260
                                easing.type: Easing.InOutSine
                            }
                            PauseAnimation { duration: (4 - index) * 45 }
                        }
                    }
                }
            }

            Rectangle {
                id: progressTrack
                width: 176
                height: 3
                radius: 2
                color: root.alpha(root.themePalette.text, 0.12)
                anchors.horizontalCenter: parent.horizontalCenter

                Rectangle {
                    width: progressTrack.width * Math.max(0, Math.min(100, root.startupProgress)) / 100
                    height: parent.height
                    radius: parent.radius
                    color: root.themePalette.accent
                    Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                }
            }
        }
    }
}
