import QtQuick
import QtQuick.Effects

Item {
    id: root
    required property string name
    property color color: "#bcb0a4"
    property real iconSize: 18
    width: iconSize
    height: iconSize

    readonly property var iconFiles: ({
        piano: "brand-piano",
        drums: "brand-drums",
        library: "brand-library",
        playlist: "playlist",
        keyboard: "keyboard",
        sliders: "brand-sliders",
        info: "brand-info",
        refresh: "refresh",
        play: "brand-play",
        pause: "brand-pause",
        stop: "brand-stop",
        emptyMidi: "empty-midi",
        emptyCatalog: "empty-catalog",
        drumsReady: "empty-drums",
        preferences: "empty-settings",
        minimize: "minimize",
        maximize: "maximize",
        restore: "restore",
        close: "close",
        trash: "trash",
        download: "download",
        check: "check",
        alert: "alert",
        previous: "previous",
        next: "next",
        folder: "folder",
        search: "search",
        reset: "reset",
        power: "power",
        accessibility: "accessibility",
        activity: "activity",
        plus: "plus",
        star: "star",
        starFilled: "star-filled",
        moveUp: "move-up",
        moveDown: "move-down"
    })

    readonly property var originalIconNames: ({
        piano: true, drums: true, library: true, sliders: true, info: true,
        play: true, pause: true, stop: true,
        emptyMidi: true, emptyCatalog: true, drumsReady: true, preferences: true
    })

    Image {
        id: sourceImage
        anchors.fill: parent
        source: Qt.resolvedUrl("icons/" + (root.iconFiles[root.name] || "info") + ".svg")
        sourceSize.width: Math.max(24, root.iconSize * 2)
        sourceSize.height: Math.max(24, root.iconSize * 2)
        fillMode: Image.PreserveAspectFit
        cache: true
        visible: !root.originalIconNames[root.name]
    }

    MultiEffect {
        anchors.fill: parent
        source: sourceImage
        brightness: 1.0
        colorization: 1.0
        colorizationColor: root.color
        visible: sourceImage.visible
    }

    Image {
        anchors.fill: parent
        source: Qt.resolvedUrl("icons/" + (root.iconFiles[root.name] || "info") + ".svg")
        sourceSize.width: Math.max(24, root.iconSize * 2)
        sourceSize.height: Math.max(24, root.iconSize * 2)
        fillMode: Image.PreserveAspectFit
        cache: true
        visible: Boolean(root.originalIconNames[root.name])
    }
}
