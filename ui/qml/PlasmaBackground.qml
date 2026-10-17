import QtQuick
import QtQuick.Window

Item {
    id: root
    property color baseColor: "#141210"
    property bool windowActive: true
    property real elapsed: 0
    property real pixelRatio: Math.min(1.2, Screen.devicePixelRatio)
    clip: true

    Rectangle {
        anchors.fill: parent
        color: root.baseColor
    }

    ShaderEffect {
        anchors.fill: parent
        opacity: 0.15
        fragmentShader: Qt.resolvedUrl("shaders/plasma.frag.qsb")

        property vector4d u_scene: Qt.vector4d(Math.max(1, root.width * root.pixelRatio),
                                               Math.max(1, root.height * root.pixelRatio),
                                               root.elapsed * 0.86, 4.0)
        property vector4d u_shape: Qt.vector4d(1.5, 0.48, 0.5, 0.0)
        property vector4d u_surface: Qt.vector4d(2.4, 0.92, -0.5, 1.0)
        property vector4d u_finish: Qt.vector4d(3.04, 0.61, 0.016, 0.35)
        property vector4d u_transform: Qt.vector4d(7.0, 0.0, 0.16, 0.0)
        property vector4d u_space: Qt.vector4d(0.0, 0.0, 0.0, 0.0)
        property vector4d u_cursor: Qt.vector4d(0.0, 4.0, 0.65, 0.30)
        property var u_colors: [
            Qt.vector3d(0.577, 0.593, 0.604), Qt.vector3d(0.599, 0.689, 0.732),
            Qt.vector3d(0.667, 0.794, 0.896), Qt.vector3d(0.750, 0.883, 1.000),
            Qt.vector3d(0.750, 0.883, 1.000), Qt.vector3d(0.667, 0.794, 0.896),
            Qt.vector3d(0.599, 0.689, 0.732), Qt.vector3d(0.577, 0.593, 0.604)
        ]
    }

    Timer {
        interval: 50
        repeat: true
        running: root.visible && root.windowActive
        onTriggered: root.elapsed += interval / 1000
    }
}
