import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

Window {
    id: window
    visible: false
    width: Math.min(1260, Math.max(640, Screen.desktopAvailableWidth - 48))
    height: Math.min(820, Math.max(480, Screen.desktopAvailableHeight - 64))
    minimumWidth: Math.min(760, Math.max(640, Screen.desktopAvailableWidth - 48))
    minimumHeight: Math.min(500, Math.max(460, Screen.desktopAvailableHeight - 64))
    color: "transparent"
    opacity: 0
    flags: Qt.Window | Qt.FramelessWindowHint
    title: window.t("Better NanoMidi")
    property bool isMaximized: visibility === Window.Maximized
    property bool isMinimized: visibility === Window.Minimized
    property bool restoringFromMinimized: false
    property bool closeReady: false
    property bool compactNavigation: width < 1080
    property bool compactLayout: pages.width < 940
    property var appController: controller
    property var themePalette: controller.themePalette
    readonly property bool lightTheme: {
        const color = Qt.darker(window.themePalette.background, 1.0)
        return color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722 > 0.52
    }

    function t(source) {
        const currentLanguage = controller.language
        return controller.translateText(source)
    }

    function withAlpha(sourceColor, alpha) {
        const parsedColor = Qt.darker(sourceColor, 1.0)
        return Qt.rgba(parsedColor.r, parsedColor.g, parsedColor.b, alpha)
    }

    function midiFileName(path) {
        return String(path || "").split(/[\\/]/).pop()
    }

    function minimizeAnimated() {
        if (minimizeAnimation.running || isMinimized) return
        minimizeAnimation.start()
    }

    function toggleMaximized() {
        if (window.isMaximized) {
            window.showNormal()
        } else {
            // Let Windows manage the full work-area geometry and restore bounds.
            // The shell's scale/fade animation keeps the transition polished.
            window.showMaximized()
        }
    }

    function closeAnimated() {
        if (closeAnimation.running || closeReady) return
        closeAnimation.start()
    }

    function activateAfterSplash() {
        window.visible = true
        window.raise()
        window.requestActivate()
        openAnimation.start()
        controller.activateMainWindow()
    }

    onClosing: function(closeEvent) {
        if (!window.closeReady) {
            closeEvent.accepted = false
            window.closeAnimated()
        }
    }

    onVisibilityChanged: {
        if (visibility === Window.Minimized) {
            restoringFromMinimized = true
        } else if (restoringFromMinimized) {
            restoringFromMinimized = false
            opacity = 0
            shell.opacity = 0.78
            shell.scale = 0.99
            restoreAnimation.restart()
        }
    }
    onIsMaximizedChanged: {
        if (isMinimized || restoringFromMinimized) return
        shell.opacity = 0.96
        shell.scale = 0.994
        expandAnimation.restart()
    }
    Component.onCompleted: startupSplash.start()

    StartupSplash {
        id: startupSplash
        themePalette: window.themePalette
        lightTheme: window.lightTheme
        startupProgress: controller.startupProgress
        startupStatus: controller.startupStatus
        startupReady: controller.startupReady
        onFinished: window.activateAfterSplash()
    }

    ParallelAnimation {
        id: openAnimation
        NumberAnimation {
            target: window; property: "opacity"; from: 0; to: 1
            duration: 330; easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: shell; property: "opacity"; from: 0.88; to: 1
            duration: 380; easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: shell; property: "scale"; from: 0.99; to: 1
            duration: 430; easing.type: Easing.OutCubic
        }
    }
    ParallelAnimation {
        id: minimizeAnimation
        NumberAnimation {
            target: window; property: "opacity"; from: 1; to: 0
            duration: 165; easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: shell; property: "opacity"; from: 1; to: 0.78
            duration: 165; easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: shell; property: "scale"; from: 1; to: 0.988
            duration: 195; easing.type: Easing.InCubic
        }
        onFinished: {
            window.showMinimized()
            window.opacity = 0
            shell.opacity = 1
            shell.scale = 1
        }
    }
    ParallelAnimation {
        id: closeAnimation
        NumberAnimation {
            target: window; property: "opacity"; from: 1; to: 0
            duration: 175; easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: shell; property: "opacity"; from: 1; to: 0.72
            duration: 175; easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: shell; property: "scale"; from: 1; to: 0.99
            duration: 195; easing.type: Easing.InCubic
        }
        onFinished: {
            window.closeReady = true
            window.close()
        }
    }
    ParallelAnimation {
        id: restoreAnimation
        NumberAnimation {
            target: window; property: "opacity"; from: 0; to: 1
            duration: 300; easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: shell; property: "opacity"; from: 0.78; to: 1
            duration: 360; easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: shell; property: "scale"; from: 0.99; to: 1
            duration: 390; easing.type: Easing.OutCubic
        }
    }
    ParallelAnimation {
        id: pageTransition
        NumberAnimation {
            id: pageFadeIn
            property: "opacity"; from: 0; to: 1
            duration: 220; easing.type: Easing.OutCubic
        }
        NumberAnimation {
            id: pageScaleIn
            property: "scale"; from: 0.994; to: 1
            duration: 250; easing.type: Easing.OutCubic
        }
    }
    ParallelAnimation {
        id: expandAnimation
        NumberAnimation {
            target: shell; property: "opacity"; from: 0.94; to: 1
            duration: 390; easing.type: Easing.OutQuart
        }
        NumberAnimation {
            target: shell; property: "scale"; from: 0.986; to: 1
            duration: 430; easing.type: Easing.OutQuart
        }
    }
    Rectangle {
        id: shell
        anchors.fill: parent
        radius: window.isMaximized ? 0 : 18
        color: "transparent"
        border.width: 1
        border.color: window.themePalette.line
        clip: true
        transformOrigin: Item.Center
        Behavior on radius { NumberAnimation { duration: 360; easing.type: Easing.OutCubic } }

        PlasmaBackground {
            anchors.fill: parent
            baseColor: window.themePalette.background
            windowActive: window.active && !window.isMinimized
            z: 0
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0
            z: 1

            Rectangle {
                id: titleBar
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                color: window.withAlpha(window.themePalette.surface, 0.93)
                border.color: window.themePalette.line
                border.width: 0

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 18
                    anchors.rightMargin: 10
                    spacing: 14
                    RowLayout {
                        spacing: 12
                        Image {
                            source: Qt.resolvedUrl("../../assets/branding/better-nanomidi/" +
                                                  (window.lightTheme ? "logo-horizontal-on-light.png" : "logo-horizontal-on-dark.png"))
                            sourceSize.width: 512
                            sourceSize.height: 146
                            Layout.preferredWidth: 126
                            Layout.preferredHeight: 36
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            mipmap: true
                            Accessible.name: window.t("Better NanoMidi")
                        }
                        Rectangle { width: 1; height: 18; color: "#382f29" }
                        Text { text: controller.pageTitle; color: window.themePalette.muted; font.pixelSize: 12 }
                    }
                    Item { Layout.fillWidth: true }
                    RowLayout {
                        spacing: 5
                        ActionButton { viewMode: "icon"; iconName: "minimize"; label: window.t("Minimize"); variant: "ghost"; onClicked: window.minimizeAnimated() }
                        ActionButton { viewMode: "icon"; iconName: window.isMaximized ? "restore" : "maximize"; label: window.isMaximized ? window.t("Restore") : window.t("Maximize"); variant: "ghost"; onClicked: window.toggleMaximized() }
                        ActionButton { viewMode: "icon"; iconName: "close"; label: window.t("Close"); variant: "ghost"; onClicked: window.closeAnimated() }
                    }
                }
                MouseArea {
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.bottom: parent.bottom
                    anchors.rightMargin: 165
                    acceptedButtons: Qt.LeftButton
                    onPressed: window.startSystemMove()
                    onDoubleClicked: window.toggleMaximized()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                Rectangle {
                    id: sidebar
                    Layout.preferredWidth: window.compactNavigation ? 64 : 224
                    Layout.fillHeight: true
                    color: window.withAlpha(window.themePalette.background, 0.84)
                    border.color: "#302923"
                    border.width: 0

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: window.compactNavigation ? 5 : 12
                        spacing: 12
                        ColumnLayout {
                            Layout.fillWidth: true
                            visible: !window.compactNavigation
                            Layout.leftMargin: 54
                            Layout.topMargin: 7
                            spacing: 5
                            Text { text: window.t("PLAYBACK"); color: window.themePalette.muted; font.pixelSize: 9; font.weight: Font.Bold; font.letterSpacing: 1.5 }
                        }
                        Rectangle { Layout.fillWidth: true; height: 1; color: "#302923" }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3
                            NavButton { compact: window.compactNavigation; accentColor: window.themePalette.accent; textColor: window.themePalette.text; mutedColor: window.themePalette.muted; label: window.t("MIDI Player"); iconName: "piano"; selected: controller.currentPage === 0; onActivated: controller.navigate("midi") }
                            NavButton { compact: window.compactNavigation; accentColor: window.themePalette.accent; textColor: window.themePalette.text; mutedColor: window.themePalette.muted; label: window.t("Drums Player"); iconName: "drums"; selected: controller.currentPage === 1; onActivated: controller.navigate("drums") }
                            NavButton { compact: window.compactNavigation; accentColor: controller.currentPage === 2 ? "#46d5a0" : window.themePalette.accent; textColor: window.themePalette.text; mutedColor: window.themePalette.muted; label: window.t("MIDI Hub"); iconName: "library"; selected: controller.currentPage === 2; onActivated: controller.navigate("hub") }
                            NavButton { compact: window.compactNavigation; accentColor: window.themePalette.accent; textColor: window.themePalette.text; mutedColor: window.themePalette.muted; label: window.t("MIDI to QWERTY"); iconName: "keyboard"; selected: controller.currentPage === 3; onActivated: controller.navigate("miditoqwerty") }
                            NavButton { compact: window.compactNavigation; accentColor: window.themePalette.accent; textColor: window.themePalette.text; mutedColor: window.themePalette.muted; label: window.t("Playlists"); iconName: "playlist"; selected: controller.currentPage === 7; onActivated: controller.navigate("playlists") }
                        }
                        Item { Layout.fillHeight: true }
                        Text { visible: !window.compactNavigation; text: window.t("PREFERENCES"); color: window.themePalette.muted; font.pixelSize: 9; font.weight: Font.Bold; font.letterSpacing: 1.7; Layout.leftMargin: 54 }
                        NavButton { compact: window.compactNavigation; accentColor: window.themePalette.accent; textColor: window.themePalette.text; mutedColor: window.themePalette.muted; label: window.t("Settings"); iconName: "sliders"; selected: controller.currentPage === 4; onActivated: controller.navigate("settings") }
                        NavButton { compact: window.compactNavigation; accentColor: window.themePalette.accent; textColor: window.themePalette.text; mutedColor: window.themePalette.muted; label: window.t("About"); iconName: "info"; selected: controller.currentPage === 5; onActivated: controller.navigate("info") }
                        NavButton {
                            compact: window.compactNavigation
                            visible: controller.platformName === "Darwin"
                            label: window.t("Permissions"); iconName: "info"; selected: controller.currentPage === 6
                            onActivated: controller.navigate("darwinpermission")
                        }
                        Rectangle { Layout.fillWidth: true; height: 1; color: "#302923"; Layout.topMargin: 4 }
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: 7; Layout.bottomMargin: 2
                            spacing: 9
                            Rectangle { width: 7; height: 7; radius: 4; color: controller.isRunning ? "#8aab86" : "#81766c" }
                            Text { visible: !window.compactNavigation; text: controller.isRunning ? window.t("Engine active") : window.t("Ready for playback"); color: window.themePalette.muted; font.pixelSize: 10 }
                            Item { Layout.fillWidth: true }
                            Text { visible: !window.compactNavigation; text: controller.appVersion; color: "#81766c"; font.pixelSize: 9; font.family: "Consolas" }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "transparent"

                    StackLayout {
                        id: pages
                        anchors.fill: parent
                        currentIndex: controller.currentPage
                        onCurrentIndexChanged: {
                            if (!currentItem) return
                            currentItem.opacity = 0
                            currentItem.scale = 0.994
                            pageFadeIn.target = currentItem
                            pageScaleIn.target = currentItem
                            pageTransition.restart()
                        }

                        // MIDI Player
                        Item {
                            ScrollView {
                                id: midiPageScroll
                                anchors.fill: parent
                                clip: true
                                contentWidth: availableWidth
                                contentHeight: midiPageContent.implicitHeight + 44
                                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                            ColumnLayout {
                                id: midiPageContent
                                x: 22; y: 22; width: midiPageScroll.availableWidth - 44
                                spacing: 14
                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: 5
                                    Text { text: window.t("MIDI Player"); color: window.themePalette.text; font.pixelSize: 25; font.weight: Font.DemiBold; font.letterSpacing: -0.45 }
                                    Text { text: window.t("Route a score through your keyboard or a MIDI output device."); color: window.themePalette.muted; font.pixelSize: 12 }
                                }
                                GridLayout {
                                    id: midiBody
                                    Layout.fillWidth: true
                                    columns: window.compactLayout ? 1 : 3
                                    columnSpacing: 20; rowSpacing: 16
                                    ColumnLayout {
                                        Layout.fillWidth: true; Layout.alignment: Qt.AlignTop
                                        Layout.preferredWidth: 600
                                        spacing: 16
                                        Rectangle {
                                        Layout.fillWidth: true; height: 118; radius: 10
                                            color: window.withAlpha(window.themePalette.surface, 0.93); border.color: window.themePalette.line
                                            ColumnLayout {
                                                anchors.fill: parent; anchors.margins: 17; spacing: 12
                                                RowLayout {
                                                    Layout.fillWidth: true
                                                    Text { text: window.t("OUTPUT ROUTING"); color: window.themePalette.muted; font.pixelSize: 9; font.weight: Font.Bold; font.letterSpacing: 1.3 }
                                                    Item { Layout.fillWidth: true }
                                                    ToggleRow {
                                                        controller: window.appController; section: "midiPlayer"; setting: "useMIDIOutput"
                                                        label: window.t("Use MIDI Output"); rowHeight: 24; implicitWidth: 170
                                                    }
                                                }
                                                RowLayout {
                                                    Layout.fillWidth: true; spacing: 9
                                                    DarkComboBox { themePalette: window.themePalette;
                                                        id: outputDevice
                                                        Layout.fillWidth: true
                                                        model: controller.ui.midiPlayer.outputDeviceDropdown.values.length ? controller.ui.midiPlayer.outputDeviceDropdown.values.map(value => window.t(String(value))) : [window.t("No output devices")]
                                                        currentIndex: Math.max(0, model.indexOf(window.t(String(controller.ui.midiPlayer.outputDeviceDropdown.value))))
                                                        enabled: Boolean(controller.settings.midiPlayer.useMIDIOutput) && controller.ui.midiPlayer.outputDeviceDropdown.enabled
                                                        onActivated: controller.setOutputDevice(currentText)
                                                        contentItem: Text { leftPadding: 11; text: outputDevice.displayText; color: outputDevice.enabled ? "#e2d7cd" : "#81766c"; font.pixelSize: 12; verticalAlignment: Text.AlignVCenter; elide: Text.ElideMiddle }
                                                        background: Rectangle { radius: 6; color: Qt.darker(window.themePalette.background, 1.12); border.color: outputDevice.activeFocus ? window.themePalette.accent : window.themePalette.line }
                                                        delegate: ItemDelegate { required property var modelData; width: outputDevice.width; text: modelData; highlighted: outputDevice.highlightedIndex === index; contentItem: Text { text: parent.text; color: window.themePalette.text; font.pixelSize: 12 } background: Rectangle { color: parent.highlighted ? "#382f29" : "#201c19" } }
                                                    }
                                                    ActionButton { viewMode: "icon"; iconName: "refresh"; label: window.t("Refresh MIDI devices"); variant: "ghost"; onClicked: controller.refreshDevices() }
                                                }
                                            }
                                        }
                                        Rectangle {
                                        Layout.fillWidth: true; height: String(controller.ui.midiPlayer.filePathEntry.value || "").length > 0 ? 136 : 170; radius: 10
                                            color: window.withAlpha(window.themePalette.surface, 0.93); border.color: window.themePalette.line
                                            ColumnLayout {
                                                anchors.fill: parent; anchors.margins: 17; spacing: 11
                                                RowLayout {
                                                    Layout.fillWidth: true
                                                    Text { text: window.t("MIDI SCORE"); color: window.themePalette.muted; font.pixelSize: 9; font.weight: Font.Bold; font.letterSpacing: 1.3 }
                                                    Item { Layout.fillWidth: true }
                                                    Text { text: controller.ui.midiPlayer.timelineIndicator.text === "Loading MIDI…" ? window.t("Loading MIDI…") : controller.ui.midiPlayer.timelineIndicator.text || "0:00:00 / 0:00:00"; color: window.themePalette.muted; font.pixelSize: 10; font.family: "Consolas" }
                                                }
                                                RowLayout {
                                                    Layout.fillWidth: true; spacing: 9
                                                    TextField {
                                                        id: midiPath
                                                        Layout.fillWidth: true
                                                        text: String(controller.ui.midiPlayer.filePathEntry.value || "")
                                                        Component.onCompleted: cursorPosition = 0
                                                        placeholderText: window.t("Choose a .mid or .midi file")
                                                        onEditingFinished: controller.setMidiFileValue(text)
                                                        color: window.themePalette.text; placeholderTextColor: "#887b6f"; font.pixelSize: 11; selectByMouse: true
                                                        background: Rectangle { radius: 6; color: Qt.darker(window.themePalette.background, 1.12); border.color: midiPath.activeFocus ? window.themePalette.accent : window.themePalette.line }
                                                    }
                                                    ActionButton { label: controller.midiLoading ? window.t("Loading…") : window.t("Browse"); iconName: "folder"; variant: "secondary"; enabled: !controller.midiLoading; onClicked: controller.selectMidiFile("") }
                                                }
                                                RowLayout {
                                                    spacing: 8
                                                    visible: controller.midiLibrary.length > 0
                                                    Text {
                                                        text: window.t("LIBRARY") + " · " + controller.midiLibrary.length
                                                        color: window.themePalette.muted
                                                        font.pixelSize: 8
                                                        font.weight: Font.Bold
                                                        font.letterSpacing: 0.7
                                                        Layout.minimumWidth: 66
                                                    }
                                                    DarkComboBox {
                                                        id: midiLibraryPicker
                                                        Layout.fillWidth: true
                                                        Layout.preferredHeight: 36
                                                        themePalette: window.themePalette
                                                        enabled: !controller.midiLoading
                                                        model: controller.midiLibrary.map(entry => String(entry.name || window.midiFileName(entry.path)))
                                                        currentIndex: {
                                                            const selectedPath = String(controller.ui.midiPlayer.filePathEntry.value || "").toLowerCase()
                                                            for (let i = 0; i < controller.midiLibrary.length; i++) {
                                                                if (String(controller.midiLibrary[i].path).toLowerCase() === selectedPath) return i
                                                            }
                                                            return -1
                                                        }
                                                        Accessible.name: window.t("MIDI library")
                                                        contentItem: Text {
                                                            leftPadding: midiLibraryPicker.leftPadding
                                                            rightPadding: midiLibraryPicker.rightPadding
                                                            text: midiLibraryPicker.currentIndex >= 0
                                                                  ? window.midiFileName(controller.midiLibrary[midiLibraryPicker.currentIndex].path)
                                                                  : window.t("Choose a MIDI from your library")
                                                            color: midiLibraryPicker.enabled ? window.themePalette.text : window.themePalette.muted
                                                            font.pixelSize: 11
                                                            verticalAlignment: Text.AlignVCenter
                                                            elide: Text.ElideRight
                                                        }
                                                        delegate: ItemDelegate {
                                                            required property int index
                                                            width: midiLibraryPicker.width - 8
                                                            height: 48
                                                            highlighted: midiLibraryPicker.highlightedIndex === index || hovered
                                                            hoverEnabled: true
                                                            contentItem: Column {
                                                                anchors.left: parent.left
                                                                anchors.right: parent.right
                                                                anchors.verticalCenter: parent.verticalCenter
                                                                spacing: 2
                                                                Text {
                                                                    text: controller.midiLibrary[index].name
                                                                    color: window.themePalette.text
                                                                    font.pixelSize: 11
                                                                    elide: Text.ElideRight
                                                                    width: parent.width
                                                                }
                                                                Text {
                                                                    text: controller.midiLibrary[index].folder
                                                                    color: window.themePalette.muted
                                                                    font.pixelSize: 9
                                                                    elide: Text.ElideMiddle
                                                                    width: parent.width
                                                                }
                                                            }
                                                            background: Rectangle {
                                                                radius: 8
                                                                color: parent.highlighted
                                                                    ? Qt.rgba(window.themePalette.accent.r, window.themePalette.accent.g, window.themePalette.accent.b, 0.24)
                                                                    : "transparent"
                                                                border.width: parent.highlighted ? 1 : 0
                                                                border.color: Qt.rgba(window.themePalette.accent.r, window.themePalette.accent.g, window.themePalette.accent.b, 0.3)
                                                            }
                                                        }
                                                        onActivated: {
                                                            if (currentIndex >= 0 && currentIndex < controller.midiLibrary.length)
                                                                controller.setMidiFileValue(String(controller.midiLibrary[currentIndex].path))
                                                        }
                                                    }
                                                    ActionButton {
                                                        viewMode: "icon"
                                                        iconName: "refresh"
                                                        label: window.t("Refresh MIDI library")
                                                        variant: "ghost"
                                                        enabled: !controller.midiLoading
                                                        onClicked: controller.refreshMidiLibrary()
                                                    }
                                                }
                                                RowLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 9
                                                    visible: String(controller.ui.midiPlayer.filePathEntry.value || "").length === 0
                                                    Icon { name: "emptyMidi"; color: window.themePalette.accent; iconSize: 23 }
                                                    ColumnLayout {
                                                        spacing: 2
                                                        Text { text: window.t("No MIDI loaded"); color: window.themePalette.text; font.pixelSize: 11; font.weight: Font.DemiBold }
                                                        Text { text: window.t("Select a file to get started."); color: window.themePalette.muted; font.pixelSize: 10 }
                                                    }
                                                }
                                            }
                                        }
                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 92
                                            radius: 10
                                            color: window.withAlpha(window.themePalette.surface, 0.93)
                                            border.color: window.themePalette.line

                                            ColumnLayout {
                                                anchors.fill: parent
                                                anchors.margins: 12
                                                spacing: 7

                                                RowLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 7
                                                    Text { text: window.t("PLAYLIST"); color: window.themePalette.muted; font.pixelSize: 9; font.weight: Font.Bold; font.letterSpacing: 1.1 }
                                                    Text { text: controller.activePlaylistName || window.t("No playlist selected"); color: window.themePalette.text; font.pixelSize: 10; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true }
                                                    ActionButton { viewMode: "icon"; iconName: "playlist"; label: window.t("Open Playlists"); variant: "ghost"; onClicked: controller.navigate("playlists") }
                                                }

                                                RowLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 8
                                                    DarkComboBox {
                                                        id: activePlaylistPicker
                                                        themePalette: window.themePalette
                                                        Layout.fillWidth: true
                                                        enabled: controller.midiPlaylists.length > 0
                                                        model: controller.midiPlaylists.map(playlist => String(playlist.name))
                                                        currentIndex: controller.activePlaylistIndex
                                                        Accessible.name: window.t("Choose a playlist")
                                                        contentItem: Text {
                                                            leftPadding: activePlaylistPicker.leftPadding
                                                            rightPadding: activePlaylistPicker.rightPadding
                                                            text: activePlaylistPicker.currentIndex >= 0
                                                                ? activePlaylistPicker.displayText
                                                                : window.t("Choose a playlist")
                                                            color: activePlaylistPicker.enabled ? window.themePalette.text : window.themePalette.muted
                                                            font.pixelSize: 11
                                                            verticalAlignment: Text.AlignVCenter
                                                            elide: Text.ElideRight
                                                        }
                                                        onActivated: controller.selectPlaylist(currentIndex)
                                                    }
                                                    ActionButton {
                                                        label: window.t("Play playlist")
                                                        iconName: "play"
                                                        variant: "primary"
                                                        enabled: controller.midiPlaylist.length > 0
                                                        onClicked: controller.playPlaylist()
                                                    }
                                                }
                                            }
                                        }
                                        Rectangle {
                                            Layout.fillWidth: true; Layout.minimumHeight: 205; Layout.preferredHeight: 205; Layout.maximumHeight: 205; radius: 10
                                            color: window.withAlpha(window.themePalette.surface, 0.93); border.color: window.themePalette.line
                                            ColumnLayout {
                                                anchors.fill: parent; anchors.margins: 18; spacing: 13
                                                RowLayout {
                                                    Layout.fillWidth: true
                                                    Text { text: window.t("TRANSPORT"); color: window.themePalette.muted; font.pixelSize: 9; font.weight: Font.Bold; font.letterSpacing: 1.3 }
                                                    Item { Layout.fillWidth: true }
                                                    Text { text: controller.ui.midiPlayer.playButton.text === "Paused" ? window.t("PAUSED") : controller.isRunning ? window.t("PLAYING") : window.t("STOPPED"); color: controller.isRunning ? "#8aab86" : "#a89d91"; font.pixelSize: 9; font.weight: Font.Bold; font.letterSpacing: 0.8 }
                                                    Rectangle { width: 7; height: 7; radius: 4; color: controller.isRunning ? "#8aab86" : "#81766c" }
                                                }
                                                RowLayout {
                                                    Layout.fillWidth: true; spacing: 10
                                                    ActionButton { label: window.t("Play"); iconName: "play"; variant: "primary"; onClicked: controller.playMidi() }
                                                    ActionButton { label: controller.ui.midiPlayer.playButton.text === "Paused" ? window.t("Resume") : window.t("Pause"); iconName: controller.ui.midiPlayer.playButton.text === "Paused" ? "play" : "pause"; variant: "secondary"; onClicked: controller.pauseMidi() }
                                                    ActionButton { label: window.t("Stop"); iconName: "stop"; variant: "danger"; onClicked: controller.stopMidi() }
                                                    Item { Layout.fillWidth: true }
                                                    Text { text: window.t("Play") + " " + controller.settings.hotkeys.play.toUpperCase() + "    " + window.t("Pause") + " " + controller.settings.hotkeys.pause.toUpperCase() + "    " + window.t("Stop") + " " + controller.settings.hotkeys.stop.toUpperCase(); color: window.themePalette.muted; font.pixelSize: 9; font.family: "Consolas" }
                                                }
                                                RowLayout {
                                                    Layout.fillWidth: true; spacing: 28
                                                    RangeControl {
                                                        accentColor: window.themePalette.accent; textColor: window.themePalette.text; mutedColor: window.themePalette.muted
                                                        controller: window.appController; label: window.t("Playback speed"); controlName: "midiSpeedController"; minimum: 1; maximum: 500; stepSize: 1
                                                        initialValue: Number(controller.playbackSpeed || 100); suffix: "%"; width: 240
                                                    }
                                                    RangeControl {
                                                        accentColor: window.themePalette.accent; textColor: window.themePalette.text; mutedColor: window.themePalette.muted
                                                        controller: window.appController; label: window.t("Finger limit"); controlName: "midiFingerLimit"; minimum: 1; maximum: 11; stepSize: 1
                                                        initialValue: Number(controller.settings.midiPlayer.fingerLimit || 11); suffix: ""; width: 170
                                                    }
                                                }
                                            }
                                        }
                                        ConsolePanel { controller: window.appController; themePalette: window.themePalette; Layout.fillWidth: true; visible: Boolean(controller.settings.appUI.console) }
                                    }
                                    Rectangle { visible: !window.compactLayout; Layout.fillHeight: true; Layout.minimumHeight: 1; width: 1; color: "#302923" }
                                    ColumnLayout {
                                        Layout.fillWidth: true; Layout.alignment: Qt.AlignTop
                                        Layout.preferredWidth: 250
                                        Layout.maximumWidth: window.compactLayout ? 16777215 : 250
                                        spacing: 6
                                        Text { text: window.t("PLAYBACK OPTIONS"); color: window.themePalette.muted; font.pixelSize: 9; font.weight: Font.Bold; font.letterSpacing: 1.3; Layout.bottomMargin: 2 }
                                        ToggleRow { accentColor: window.themePalette.accent; textColor: window.themePalette.text; mutedColor: window.themePalette.muted; controller: window.appController; section: "midiPlayer"; setting: "sustain"; label: window.t("Sustain") }
                                        ToggleRow { accentColor: window.themePalette.accent; textColor: window.themePalette.text; mutedColor: window.themePalette.muted; controller: window.appController; section: "midiPlayer"; setting: "noDoubles"; label: window.t("No duplicate notes") }
                                        ToggleRow { accentColor: window.themePalette.accent; textColor: window.themePalette.text; mutedColor: window.themePalette.muted; controller: window.appController; section: "midiPlayer"; setting: "velocity"; label: window.t("Velocity mapping") }
                                        ToggleRow { accentColor: window.themePalette.accent; textColor: window.themePalette.text; mutedColor: window.themePalette.muted; controller: window.appController; section: "midiPlayer"; setting: "88Keys"; label: window.t("88-key range") }
                                        Rectangle { Layout.fillWidth: true; height: 1; color: window.themePalette.line; Layout.topMargin: 4; Layout.bottomMargin: 4 }
                                        ToggleRow { accentColor: window.themePalette.accent; textColor: window.themePalette.text; mutedColor: window.themePalette.muted; controller: window.appController; section: "midiPlayer"; setting: "customHoldLength"; label: window.t("Custom hold length") }
                                        ToggleRow { accentColor: window.themePalette.accent; textColor: window.themePalette.text; mutedColor: window.themePalette.muted; controller: window.appController; section: "midiPlayer"; setting: "randomFail"; label: window.t("Random timing") }
                                        ToggleRow { accentColor: window.themePalette.accent; textColor: window.themePalette.text; mutedColor: window.themePalette.muted; controller: window.appController; section: "midiPlayer"; setting: "loopSong"; label: window.t("Loop song") }
                                        ToggleRow { accentColor: window.themePalette.accent; textColor: window.themePalette.text; mutedColor: window.themePalette.muted; controller: window.appController; section: "midiPlayer"; setting: "releaseOnPause"; label: window.t("Release keys on pause") }
                                        Rectangle { Layout.fillWidth: true; height: 1; color: window.themePalette.line; Layout.topMargin: 8; Layout.bottomMargin: 5 }
                                        Text { text: window.t("PITCH"); color: window.themePalette.muted; font.pixelSize: 9; font.weight: Font.Bold; font.letterSpacing: 1.3 }
                                        Text { text: window.t("Transpose the score or choose a center note for the keyboard map."); color: window.themePalette.muted; font.pixelSize: 11; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                                        DarkComboBox { themePalette: window.themePalette;
                                            Layout.fillWidth: true; model: ["Middle", "Low", "High"]
                                            currentIndex: Math.max(0, model.indexOf(String(controller.ui.midiPlayer.pitchDropdown.value || "Middle")))
                                            onActivated: controller.setPitch(currentText, "pitch")
                                            contentItem: Text { leftPadding: 10; text: parent.displayText; color: window.themePalette.text; font.pixelSize: 12; verticalAlignment: Text.AlignVCenter }
                                            background: Rectangle { radius: 6; color: "#1d1a17"; border.color: "#382f29" }
                                        }
                                        Text { text: window.t("Key transpose"); color: "#c8bcb0"; font.pixelSize: 11; Layout.topMargin: 7 }
                                        DarkComboBox { themePalette: window.themePalette;
                                            Layout.fillWidth: true; model: ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
                                            currentIndex: Math.max(0, model.indexOf(String(controller.ui.midiPlayer.keyTransposeDropdown.value || "C")))
                                            onActivated: controller.setPitch(currentText, "transpose")
                                            contentItem: Text { leftPadding: 10; text: parent.displayText; color: window.themePalette.text; font.pixelSize: 12; verticalAlignment: Text.AlignVCenter }
                                            background: Rectangle { radius: 6; color: "#1d1a17"; border.color: "#382f29" }
                                        }
                                    }
                                }
                            }
                            }
                        }

                        // Drums Player
                        Item {
                            ScrollView {
                                id: drumsScroll
                                anchors.fill: parent; clip: true
                                contentWidth: availableWidth
                                contentHeight: drumsContent.implicitHeight + 44
                                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                                ColumnLayout {
                                    id: drumsContent
                                    x: 22; y: 22; width: drumsScroll.availableWidth - 44; spacing: 18
                                    ColumnLayout { spacing: 5; Text { text: window.t("Drums Player"); color: window.themePalette.text; font.pixelSize: 25; font.weight: Font.DemiBold } Text { text: window.t("Play a drum MIDI arrangement with mapped keyboard controls."); color: window.themePalette.muted; font.pixelSize: 12 } }
                                    Rectangle {
                                        Layout.fillWidth: true; height: String(controller.ui.drums.midiPathDropdown.value || "").length > 0 && String(controller.ui.drums.midiPathDropdown.value || "") !== "None" ? 142 : 178; radius: 10; color: window.withAlpha(window.themePalette.surface, 0.93); border.color: window.themePalette.line
                                        ColumnLayout {
                                            anchors.fill: parent; anchors.margins: 18; spacing: 12
                                            Text { text: window.t("DRUM SCORE"); color: window.themePalette.muted; font.pixelSize: 9; font.weight: Font.Bold; font.letterSpacing: 1.3 }
                                            RowLayout {
                                                Layout.fillWidth: true; spacing: 9
                                                TextField {
                                                    id: drumsPath; Layout.fillWidth: true
                                                    Layout.minimumWidth: 0
                                                    text: String(controller.ui.drums.midiPathDropdown.value || "")
                                                    placeholderText: window.t("Choose a drum .mid file")
                                                    onEditingFinished: controller.setDrumFileValue(text)
                                                    color: window.themePalette.text; placeholderTextColor: "#887b6f"; font.pixelSize: 11; selectByMouse: true
                                                    background: Rectangle { radius: 6; color: Qt.darker(window.themePalette.background, 1.12); border.color: drumsPath.activeFocus ? window.themePalette.accent : window.themePalette.line }
                                                }
                                                ActionButton { label: window.t("Browse"); iconName: "folder"; variant: "secondary"; onClicked: controller.selectDrumFile("") }
                                                Text { text: controller.ui.drums.timelineIndicator.text || "0:00:00 / 0:00:00"; color: window.themePalette.muted; font.pixelSize: 10; font.family: "Consolas" }
                                            }
                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 9
                                                visible: String(controller.ui.drums.midiPathDropdown.value || "").length === 0 || String(controller.ui.drums.midiPathDropdown.value || "") === "None"
                                                Icon { name: "drumsReady"; color: window.themePalette.accent; iconSize: 24 }
                                                ColumnLayout {
                                                    spacing: 2
                                                    Text { text: window.t("Ready to play"); color: window.themePalette.text; font.pixelSize: 11; font.weight: Font.DemiBold }
                                                    Text { text: window.t("Choose a kit and set up the rhythm."); color: window.themePalette.muted; font.pixelSize: 10 }
                                                }
                                            }
                                        }
                                    }
                                    GridLayout {
                                        id: drumsBody
                                        Layout.fillWidth: true; Layout.minimumWidth: 0
                                        columns: window.compactLayout ? 1 : 2
                                        columnSpacing: 20; rowSpacing: 16
                                        Rectangle {
                                            Layout.fillWidth: true; Layout.preferredWidth: 600; Layout.minimumWidth: 0; Layout.minimumHeight: 210; radius: 10
                                            color: window.withAlpha(window.themePalette.surface, 0.93); border.color: window.themePalette.line
                                            ColumnLayout {
                                                anchors.fill: parent; anchors.margins: 18; spacing: 15
                                                    RowLayout { Text { text: window.t("TRANSPORT"); color: window.themePalette.muted; font.pixelSize: 9; font.weight: Font.Bold; font.letterSpacing: 1.3 } Item { Layout.fillWidth: true } Text { text: controller.ui.drums.playButton.text === "Paused" ? window.t("PAUSED") : controller.isRunning ? window.t("PLAYING") : window.t("STOPPED"); color: controller.isRunning ? "#8aab86" : "#a89d91"; font.pixelSize: 9; font.weight: Font.Bold } }
                                                RowLayout {
                                                    spacing: 10
                                                    ActionButton { viewMode: "icon"; iconName: "play"; label: window.t("Play drums"); variant: "primary"; onClicked: controller.playDrums() }
                                                    ActionButton { viewMode: "icon"; iconName: controller.ui.drums.playButton.text === "Paused" ? "play" : "pause"; label: controller.ui.drums.playButton.text === "Paused" ? window.t("Resume drums") : window.t("Pause drums"); variant: "secondary"; onClicked: controller.pauseDrums() }
                                                    ActionButton { viewMode: "icon"; iconName: "stop"; label: window.t("Stop drums"); variant: "danger"; onClicked: controller.stopDrums() }
                                                }
                                                RowLayout {
                                                    Layout.fillWidth: true; spacing: 18
                                                    RangeControl { Layout.fillWidth: true; accentColor: window.themePalette.accent; textColor: window.themePalette.text; mutedColor: window.themePalette.muted; controller: window.appController; label: window.t("Playback speed"); controlName: "drumsSpeedController"; minimum: 1; maximum: 500; stepSize: 1; initialValue: Number(controller.playbackSpeed || 100); suffix: "%" }
                                                    RangeControl { Layout.fillWidth: true; accentColor: window.themePalette.accent; textColor: window.themePalette.text; mutedColor: window.themePalette.muted; controller: window.appController; label: window.t("Finger limit"); controlName: "drumsFingerLimit"; minimum: 1; maximum: 11; stepSize: 1; initialValue: Number(controller.settings.drumsMacro.fingerLimit || 11) }
                                                }
                                            }
                                        }
                                        Rectangle {
                                            Layout.fillWidth: true; Layout.preferredWidth: 320; Layout.minimumWidth: 0; Layout.minimumHeight: 210; radius: 10
                                            color: window.withAlpha(window.themePalette.surface, 0.93); border.color: window.themePalette.line
                                            ColumnLayout {
                                                anchors.fill: parent; anchors.margins: 18; spacing: 3
                                                Text { text: window.t("DRUM MAP"); color: window.themePalette.muted; font.pixelSize: 9; font.weight: Font.Bold; font.letterSpacing: 1.3; Layout.bottomMargin: 5 }
                                                GridLayout {
                                                    columns: 2; columnSpacing: 12; rowSpacing: 8; Layout.fillWidth: true; Layout.minimumWidth: 0
                                                    Repeater {
                                                        model: ["Kick", "Snare", "Closed hi-hat", "Open hi-hat", "Tom", "Crash", "Ride"]
                                                        delegate: RowLayout {
                                                            required property string modelData
                                                            Layout.fillWidth: true; spacing: 10
                                                            Text { text: window.t(modelData); color: window.themePalette.muted; font.pixelSize: 11; Layout.fillWidth: true }
                                                            Rectangle { width: 27; height: 25; radius: 5; color: "#171411"; border.color: "#382f29"; Text { anchors.centerIn: parent; text: ({"Kick":"b", "Snare":"c", "Closed hi-hat":"x", "Open hi-hat":"z", "Tom":"g", "Crash":"e", "Ride":"u"})[modelData]; color: "#d9cfc4"; font.pixelSize: 11; font.family: "Consolas" } }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    Rectangle { Layout.fillWidth: true; height: 1; color: "#302923" }
                                    GridLayout {
                                        Layout.fillWidth: true; Layout.minimumWidth: 0; columns: window.compactLayout ? 1 : 2; columnSpacing: 20; rowSpacing: 4
                                        ToggleRow { Layout.fillWidth: true; accentColor: window.themePalette.accent; textColor: window.themePalette.text; mutedColor: window.themePalette.muted; controller: window.appController; section: "drumsMacro"; setting: "loopSong"; label: window.t("Loop song") }
                                        ToggleRow { Layout.fillWidth: true; accentColor: window.themePalette.accent; textColor: window.themePalette.text; mutedColor: window.themePalette.muted; controller: window.appController; section: "drumsMacro"; setting: "releaseOnPause"; label: window.t("Release keys on pause") }
                                        ToggleRow { Layout.fillWidth: true; accentColor: window.themePalette.accent; textColor: window.themePalette.text; mutedColor: window.themePalette.muted; controller: window.appController; section: "drumsMacro"; setting: "customHoldLength"; label: window.t("Custom note length") }
                                        ToggleRow { Layout.fillWidth: true; accentColor: window.themePalette.accent; textColor: window.themePalette.text; mutedColor: window.themePalette.muted; controller: window.appController; section: "drumsMacro"; setting: "randomFail"; label: window.t("Random timing") }
                                    }
                                    ConsolePanel { controller: window.appController; themePalette: window.themePalette; Layout.fillWidth: true; visible: Boolean(controller.settings.appUI.console) }
                                }
                            }
                        }

                        // MIDI Hub
                        Item {
                            id: hubPage
                            property color hubAccent: "#46d5a0"
                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: window.compactLayout ? 18 : 26
                                spacing: 15
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 5
                                    Text { text: window.t("MIDI Hub"); color: window.themePalette.text; font.pixelSize: 25; font.weight: Font.DemiBold; font.letterSpacing: -0.3 }
                                    Text { text: window.t("Search the community catalog and open a score in the player."); color: window.themePalette.muted; font.pixelSize: 12 }
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 9
                                    TextField {
                                        id: hubSearch
                                        Layout.fillWidth: true
                                        placeholderText: window.t("Search title, artist, or uploader")
                                        text: String(controller.ui.hub.searchEntry.value || "")
                                        color: window.themePalette.text
                                        placeholderTextColor: window.themePalette.muted
                                        font.pixelSize: 12
                                        selectByMouse: true
                                        onAccepted: if (!controller.hubLoading || controller.hubNotice.length > 0) controller.searchHub(text)
                                        background: Rectangle {
                                            radius: 7
                                            color: window.withAlpha(window.themePalette.background, 0.84)
                                            border.color: hubSearch.activeFocus ? hubPage.hubAccent : window.themePalette.line
                                            Behavior on border.color { ColorAnimation { duration: 120 } }
                                        }
                                    }
                                    DarkComboBox { themePalette: window.themePalette;
                                        id: hubSort
                                        Layout.preferredWidth: 150
                                        model: [window.t("Newest"), window.t("Oldest"), window.t("Downloads"), window.t("Views")]
                                        accentColor: hubPage.hubAccent
                                        textColor: window.themePalette.text
                                        mutedColor: window.themePalette.muted
                                        fieldColor: window.withAlpha(window.themePalette.surface, 0.93)
                                        popupColor: window.themePalette.raised
                                        lineColor: window.themePalette.line
                                        currentIndex: Math.max(0, model.indexOf(window.t(String(controller.ui.hub.sortComboBox.value || "Newest"))))
                                        onActivated: controller.sortHub(["Newest", "Oldest", "Downloads", "Views"][currentIndex])
                                        enabled: !controller.hubLoading
                                    }
                                    ActionButton { label: window.t("Search"); iconName: "search"; variant: "primary"; accentColor: hubPage.hubAccent; enabled: !controller.hubLoading || controller.hubNotice.length > 0; onClicked: controller.searchHub(hubSearch.text) }
                                    ActionButton { viewMode: "icon"; iconName: "refresh"; label: window.t("Reload catalog"); variant: "ghost"; onClicked: controller.reloadHub() }
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { text: controller.hubResultCount + " " + window.t("scores"); color: window.themePalette.muted; font.pixelSize: 10 }
                                    Item { Layout.fillWidth: true }
                                    Text {
                                        visible: controller.hubLoading || controller.hubNotice.length > 0 || controller.hubError.length > 0
                                        text: controller.hubLoading ? (controller.hubNotice || window.t("Loading catalog…")) : (controller.hubNotice || controller.hubError)
                                        color: controller.hubError.length > 0 ? window.themePalette.danger : hubPage.hubAccent
                                        font.pixelSize: 10
                                        elide: Text.ElideRight
                                        Layout.maximumWidth: parent.width * 0.62
                                    }
                                }
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 11
                                    color: window.withAlpha(window.themePalette.surface, 0.93)
                                    border.color: window.themePalette.line
                                    clip: true
                                    Item {
                                        id: hubLoadingRail
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        height: 2
                                        z: 3
                                        clip: true
                                        visible: opacity > 0.01
                                        opacity: controller.hubLoading ? 1 : 0
                                        Behavior on opacity { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }

                                        Rectangle {
                                            id: hubLoadingSegment
                                            width: Math.max(72, hubLoadingRail.width * 0.2)
                                            height: parent.height
                                            radius: 1
                                            color: hubPage.hubAccent
                                            SequentialAnimation on x {
                                                running: controller.hubLoading
                                                loops: Animation.Infinite
                                                NumberAnimation {
                                                    from: -hubLoadingSegment.width
                                                    to: hubLoadingRail.width
                                                    duration: 980
                                                    easing.type: Easing.InOutCubic
                                                }
                                            }
                                        }
                                    }
                                    ColumnLayout {
                                        anchors.fill: parent
                                        spacing: 0
                                        Item {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            ListView {
                                                id: hubList
                                                anchors.fill: parent
                                                anchors.margins: 12
                                                clip: true
                                                model: controller.hubResults
                                                spacing: 10
                                                add: Transition {
                                                    ParallelAnimation {
                                                        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 230; easing.type: Easing.OutCubic }
                                                        NumberAnimation { property: "scale"; from: 0.99; to: 1; duration: 280; easing.type: Easing.OutCubic }
                                                    }
                                                }
                                                delegate: Item {
                                                    id: hubRow
                                                    required property var modelData
                                                    width: ListView.view.width
                                                    height: window.compactLayout ? 126 : 148
                                                    property color rowColor: rowMouse.containsMouse ? window.withAlpha(Qt.lighter(window.themePalette.surface, 1.13), 0.95) : window.withAlpha(window.themePalette.surface, 0.89)
                                                    property real coverWidth: Math.min(width * (window.compactLayout ? 0.38 : 0.44), 520)
                                                    property real uploaderWidth: window.compactLayout ? 92 : 142
                                                    property real activityWidth: window.compactLayout ? 88 : 116

                                                    Rectangle {
                                                        anchors.fill: parent
                                                        radius: 10
                                                        color: hubRow.rowColor
                                                        border.width: 1
                                                        border.color: rowMouse.containsMouse ? hubPage.hubAccent : window.themePalette.line
                                                        Behavior on border.color { ColorAnimation { duration: 130 } }
                                                    }
                                                    Rectangle {
                                                        anchors.left: parent.left
                                                        anchors.top: parent.top
                                                        anchors.bottom: parent.bottom
                                                        width: hubRow.coverWidth
                                                        radius: 10
                                                        color: window.themePalette.raised
                                                        clip: true
                                                        Image {
                                                            id: hubCoverImage
                                                            anchors.fill: parent
                                                            property string remoteSource: String(hubRow.modelData.imageUrl || "")
                                                            property bool coverFailed: false
                                                            source: coverFailed || remoteSource.length === 0
                                                                    ? Qt.resolvedUrl("../../assets/branding/better-nanomidi/" +
                                                                                     (window.lightTheme ? "symbol-on-light.png" : "symbol-on-dark.png"))
                                                                    : remoteSource
                                                            sourceSize.width: 640
                                                            sourceSize.height: 360
                                                            fillMode: remoteSource.length === 0 || coverFailed ? Image.PreserveAspectFit : Image.PreserveAspectCrop
                                                            asynchronous: true
                                                            cache: true
                                                            smooth: true
                                                            scale: rowMouse.containsMouse ? 1.035 : 1
                                                            visible: status === Image.Ready
                                                            opacity: status === Image.Ready
                                                                     ? (remoteSource.length === 0 || coverFailed ? 0.68 : 1)
                                                                     : 0
                                                            onStatusChanged: if (status === Image.Error && remoteSource.length > 0 && !coverFailed) coverFailed = true
                                                            onRemoteSourceChanged: coverFailed = false
                                                            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                                            Behavior on scale { NumberAnimation { duration: 210; easing.type: Easing.OutCubic } }
                                                        }
                                                    }
                                                    Rectangle {
                                                        anchors.left: parent.left
                                                        anchors.top: parent.top
                                                        anchors.bottom: parent.bottom
                                                        width: hubRow.coverWidth
                                                        gradient: Gradient {
                                                            orientation: Gradient.Horizontal
                                                            GradientStop { position: 0.0; color: Qt.rgba(hubRow.rowColor.r, hubRow.rowColor.g, hubRow.rowColor.b, 0.0) }
                                                            GradientStop { position: 0.28; color: Qt.rgba(hubRow.rowColor.r, hubRow.rowColor.g, hubRow.rowColor.b, 0.0) }
                                                            GradientStop { position: 0.38; color: Qt.rgba(hubRow.rowColor.r, hubRow.rowColor.g, hubRow.rowColor.b, 0.008) }
                                                            GradientStop { position: 0.48; color: Qt.rgba(hubRow.rowColor.r, hubRow.rowColor.g, hubRow.rowColor.b, 0.025) }
                                                            GradientStop { position: 0.58; color: Qt.rgba(hubRow.rowColor.r, hubRow.rowColor.g, hubRow.rowColor.b, 0.075) }
                                                            GradientStop { position: 0.67; color: Qt.rgba(hubRow.rowColor.r, hubRow.rowColor.g, hubRow.rowColor.b, 0.17) }
                                                            GradientStop { position: 0.75; color: Qt.rgba(hubRow.rowColor.r, hubRow.rowColor.g, hubRow.rowColor.b, 0.32) }
                                                            GradientStop { position: 0.82; color: Qt.rgba(hubRow.rowColor.r, hubRow.rowColor.g, hubRow.rowColor.b, 0.50) }
                                                            GradientStop { position: 0.88; color: Qt.rgba(hubRow.rowColor.r, hubRow.rowColor.g, hubRow.rowColor.b, 0.67) }
                                                            GradientStop { position: 0.93; color: Qt.rgba(hubRow.rowColor.r, hubRow.rowColor.g, hubRow.rowColor.b, 0.82) }
                                                            GradientStop { position: 0.97; color: Qt.rgba(hubRow.rowColor.r, hubRow.rowColor.g, hubRow.rowColor.b, 0.93) }
                                                            GradientStop { position: 0.99; color: Qt.rgba(hubRow.rowColor.r, hubRow.rowColor.g, hubRow.rowColor.b, 0.985) }
                                                            GradientStop { position: 1.0; color: Qt.rgba(hubRow.rowColor.r, hubRow.rowColor.g, hubRow.rowColor.b, 1.0) }
                                                        }
                                                    }
                                                    Column {
                                                        id: hubTitle
                                                        anchors.left: parent.left
                                                        anchors.leftMargin: Math.min(hubRow.coverWidth * 0.82, hubRow.width * 0.42)
                                                        anchors.right: hubUploader.left
                                                        anchors.rightMargin: 15
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        spacing: 6
                                                        Text {
                                                            text: hubRow.modelData.name
                                                            color: window.themePalette.text
                                                            font.pixelSize: window.compactLayout ? 13 : 16
                                                            font.weight: Font.DemiBold
                                                            elide: Text.ElideRight
                                                            width: parent.width
                                                        }
                                                        Text {
                                                            text: hubRow.modelData.source === "bitmidi"
                                                                  ? "BitMidi community catalog"
                                                                  : hubRow.modelData.artists + (hubRow.modelData.arranger ? " · " + hubRow.modelData.arranger : "")
                                                            color: window.themePalette.muted
                                                            font.pixelSize: 11
                                                            elide: Text.ElideRight
                                                            width: parent.width
                                                        }
                                                    }
                                                    Column {
                                                        id: hubUploader
                                                        anchors.right: hubActivity.left
                                                        anchors.rightMargin: window.compactLayout ? 8 : 14
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        width: hubRow.uploaderWidth
                                                        spacing: 5
                                                        Text { text: hubRow.modelData.source === "bitmidi" ? window.t("Source") : window.t("Uploaded by"); color: window.themePalette.muted; font.pixelSize: 9 }
                                                        Text { text: hubRow.modelData.uploader; color: window.themePalette.text; font.pixelSize: 10; elide: Text.ElideRight; width: parent.width }
                                                    }
                                                    Column {
                                                        id: hubActivity
                                                        anchors.right: hubDownload.left
                                                        anchors.rightMargin: window.compactLayout ? 5 : 12
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        width: hubRow.activityWidth
                                                        spacing: 7
                                                        Text { text: hubRow.modelData.source === "bitmidi" ? hubRow.modelData.plays + " " + window.t("plays") : hubRow.modelData.downloads + " " + window.t("downloads"); color: window.themePalette.muted; font.pixelSize: 9; elide: Text.ElideRight; width: parent.width }
                                                        Text { text: hubRow.modelData.views + " " + window.t("views"); color: window.themePalette.muted; font.pixelSize: 9; elide: Text.ElideRight; width: parent.width }
                                                    }
                                                    HubDownloadButton {
                                                        id: hubDownload
                                                        controller: window.appController
                                                        anchors.right: parent.right
                                                        anchors.rightMargin: 12
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        accentColor: hubPage.hubAccent
                                                        downloadState: String(controller.hubDownloadStates[hubRow.modelData.downloadUrl] || "idle")
                                                        hasUrl: String(hubRow.modelData.downloadUrl || "").length > 0
                                                        onClicked: controller.downloadMidi(hubRow.modelData.downloadUrl)
                                                    }
                                                    MouseArea { id: rowMouse; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton; z: 3 }
                                                }
                                                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                                            }
                                            Column {
                                                anchors.centerIn: parent
                                                visible: !controller.hubLoading && controller.hubResults.length === 0
                                                spacing: 7
                                                Icon { name: "emptyCatalog"; color: window.themePalette.accent; iconSize: 46; anchors.horizontalCenter: parent.horizontalCenter }
                                                Text { text: controller.hubError ? window.t("Catalog unavailable") : window.t("No results found"); color: window.themePalette.text; font.pixelSize: 14; font.weight: Font.DemiBold; anchors.horizontalCenter: parent.horizontalCenter }
                                                Text { text: controller.hubError || controller.hubNotice || window.t("Try another search or reload catalog."); color: window.themePalette.muted; font.pixelSize: 11; anchors.horizontalCenter: parent.horizontalCenter }
                                            }
                                        }
                                        Rectangle { Layout.fillWidth: true; height: 1; color: window.themePalette.line }
                                        RowLayout {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 48
                                            Layout.leftMargin: 18
                                            Layout.rightMargin: 18
                                            Text { text: window.t("Page {page} of {total}").replace("{page}", controller.hubPage).replace("{total}", controller.hubTotalPages); color: window.themePalette.muted; font.pixelSize: 10 }
                                            Item { Layout.fillWidth: true }
                                            ActionButton { viewMode: "icon"; iconName: "previous"; label: window.t("Previous page"); variant: "ghost"; enabled: controller.hubPage > 1 && !controller.hubLoading; onClicked: controller.previousHubPage() }
                                            ActionButton { viewMode: "icon"; iconName: "next"; label: window.t("Next page"); variant: "ghost"; enabled: controller.hubPage < controller.hubTotalPages && !controller.hubLoading; onClicked: controller.nextHubPage() }
                                        }
                                    }
                                }
                            }
                        }

                        // MIDI to QWERTY
                        Item {
                            ScrollView {
                                id: qwertyScroll
                                anchors.fill: parent; clip: true
                                contentWidth: availableWidth
                                contentHeight: qwertyContent.implicitHeight + 44
                                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                                ColumnLayout {
                                    id: qwertyContent
                                    x: 22; y: 22; width: qwertyScroll.availableWidth - 44; spacing: 18
                                    ColumnLayout { spacing: 5; Text { text: window.t("MIDI to QWERTY"); color: window.themePalette.text; font.pixelSize: 25; font.weight: Font.DemiBold } Text { text: window.t("Turn MIDI input into keyboard notes with a configurable key map."); color: window.themePalette.muted; font.pixelSize: 12 } }
                                    Rectangle {
                                        Layout.fillWidth: true; height: 105; radius: 10; color: window.withAlpha(window.themePalette.surface, 0.93); border.color: window.themePalette.line
                                        RowLayout {
                                            anchors.fill: parent; anchors.margins: 18; spacing: 14
                                                ColumnLayout { Layout.fillWidth: true; spacing: 7; Text { text: window.t("MIDI INPUT DEVICE"); color: window.themePalette.muted; font.pixelSize: 9; font.weight: Font.Bold; font.letterSpacing: 1.3 } DarkComboBox { themePalette: window.themePalette; id: inputDevice; Layout.fillWidth: true; model: controller.ui.midiToQwerty.inputDeviceDropdown.values.length ? controller.ui.midiToQwerty.inputDeviceDropdown.values.map(value => window.t(String(value))) : [window.t("No input devices")]; currentIndex: Math.max(0, model.indexOf(window.t(String(controller.ui.midiToQwerty.inputDeviceDropdown.value)))); enabled: controller.ui.midiToQwerty.inputDeviceDropdown.enabled && !controller.isRunning; onActivated: controller.setInputDevice(currentText); contentItem: Text { leftPadding: 10; text: inputDevice.displayText; color: inputDevice.enabled ? "#e2d7cd" : "#81766c"; font.pixelSize: 12; verticalAlignment: Text.AlignVCenter } background: Rectangle { radius: 6; color: Qt.darker(window.themePalette.background, 1.12); border.color: inputDevice.activeFocus ? window.themePalette.accent : window.themePalette.line } } }
                                            ActionButton { label: controller.isRunning ? window.t("Disable input") : window.t("Enable input"); iconName: "power"; variant: controller.isRunning ? "danger" : "primary"; Layout.alignment: Qt.AlignBottom; onClicked: controller.toggleInputListener() }
                                            ActionButton { viewMode: "icon"; iconName: "refresh"; label: window.t("Refresh MIDI devices"); variant: "ghost"; Layout.alignment: Qt.AlignBottom; onClicked: controller.refreshDevices() }
                                        }
                                    }
                                    GridLayout {
                                        id: qwertyBody
                                        Layout.fillWidth: true; Layout.minimumWidth: 0
                                        columns: window.compactLayout ? 1 : 3
                                        columnSpacing: 24; rowSpacing: 18
                                        ColumnLayout {
                                            Layout.fillWidth: true; Layout.minimumWidth: 0; Layout.preferredWidth: 380; Layout.alignment: Qt.AlignTop; spacing: 1
                                            Text { text: window.t("INPUT PROCESSING"); color: window.themePalette.muted; font.pixelSize: 9; font.weight: Font.Bold; font.letterSpacing: 1.3; Layout.bottomMargin: 4 }
                                            ToggleRow { accentColor: window.themePalette.accent; textColor: window.themePalette.text; mutedColor: window.themePalette.muted; controller: window.appController; section: "midiToQwerty"; setting: "sustain"; label: window.t("Sustain"); detail: window.t("Extend note duration using sustain input.") }
                                            ToggleRow { accentColor: window.themePalette.accent; textColor: window.themePalette.text; mutedColor: window.themePalette.muted; controller: window.appController; section: "midiToQwerty"; setting: "noDoubles"; label: window.t("No duplicate notes") }
                                            ToggleRow { accentColor: window.themePalette.accent; textColor: window.themePalette.text; mutedColor: window.themePalette.muted; controller: window.appController; section: "midiToQwerty"; setting: "velocity"; label: window.t("Velocity mapping") }
                                            ToggleRow { accentColor: window.themePalette.accent; textColor: window.themePalette.text; mutedColor: window.themePalette.muted; controller: window.appController; section: "midiToQwerty"; setting: "88Keys"; label: window.t("88-key range") }
                                            ToggleRow { accentColor: window.themePalette.accent; textColor: window.themePalette.text; mutedColor: window.themePalette.muted; controller: window.appController; section: "midiToQwerty"; setting: "customHoldLength"; label: window.t("Custom hold length") }
                                            DarkComboBox { themePalette: window.themePalette;
                                                Layout.fillWidth: true; Layout.topMargin: 10
                                                model: ["pynput", "keyboard"]
                                                currentIndex: Math.max(0, model.indexOf(String(controller.settings.midiToQwerty.inputModule || "pynput")))
                                                onActivated: controller.setConfigValue("midiToQwerty", "inputModule", currentText)
                                                contentItem: Text { leftPadding: 10; text: parent.displayText; color: window.themePalette.text; font.pixelSize: 11; verticalAlignment: Text.AlignVCenter }
                                                background: Rectangle { radius: 6; color: "#1d1a17"; border.color: "#382f29" }
                                            }
                                            Text { text: window.t("Input module"); color: "#a89d91"; font.pixelSize: 10 }
                                        }
                                        Rectangle { visible: !window.compactLayout; width: 1; Layout.preferredWidth: 1; Layout.minimumWidth: 1; Layout.fillHeight: true; Layout.minimumHeight: 1; color: "#302923" }
                                        ColumnLayout {
                                            Layout.fillWidth: true; Layout.minimumWidth: 0; Layout.preferredWidth: 380; Layout.alignment: Qt.AlignTop; spacing: 21
                                            RangeControl { Layout.fillWidth: true; accentColor: window.themePalette.accent; textColor: window.themePalette.text; mutedColor: window.themePalette.muted; controller: window.appController; label: window.t("Sustain cutoff"); controlName: "midiToQWERTYSustainCutoff"; minimum: 0; maximum: 127; stepSize: 1; initialValue: Number(controller.settings.midiToQwerty.sustainCutoff || 63) }
                                            RangeControl { Layout.fillWidth: true; accentColor: window.themePalette.accent; textColor: window.themePalette.text; mutedColor: window.themePalette.muted; controller: window.appController; label: window.t("Note hold length"); controlName: "midiToQWERTYNoteLength"; minimum: 0.1; maximum: 10; stepSize: 0.1; initialValue: Number(controller.settings.midiToQwerty.customHoldLength.noteLength || 0.1); suffix: " s"; active: Boolean(controller.settings.midiToQwerty.customHoldLength.enabled) }
                                        }
                                    }
                                    PianoKeyboard { Layout.fillWidth: true; Layout.preferredHeight: 112 }
                                    Text { text: window.t("Key layout preview. MIDI notes use the configured 61-key or 88-key map from your settings file."); color: window.themePalette.muted; font.pixelSize: 10; Layout.fillWidth: true }
                                    ConsolePanel { controller: window.appController; themePalette: window.themePalette; Layout.fillWidth: true; visible: Boolean(controller.settings.appUI.console) }
                                }
                            }
                        }

                        // Settings
                        Item {
                            ScrollView {
                                id: settingsScroll
                                anchors.fill: parent; clip: true
                                contentWidth: availableWidth
                                contentHeight: settingsContent.implicitHeight + 44
                                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                                ColumnLayout {
                                    id: settingsContent
                                    x: 22; y: 22; width: settingsScroll.availableWidth - 44; spacing: 18
                                    ColumnLayout { spacing: 5; Text { text: window.t("Settings"); color: window.themePalette.text; font.pixelSize: 25; font.weight: Font.DemiBold } Text { text: window.t("Tune playback behavior, app preferences, and keyboard shortcuts."); color: window.themePalette.muted; font.pixelSize: 12 } }
                                    GridLayout {
                                        id: settingsBody
                                        Layout.fillWidth: true; Layout.minimumWidth: 0
                                        columns: window.compactLayout ? 1 : 3
                                        columnSpacing: 22; rowSpacing: 18
                                        ColumnLayout {
                                            Layout.fillWidth: true; Layout.minimumWidth: 0; Layout.preferredWidth: 380; Layout.alignment: Qt.AlignTop; spacing: 1
                                            Text { text: window.t("APP PREFERENCES"); color: window.themePalette.muted; font.pixelSize: 9; font.weight: Font.Bold; font.letterSpacing: 1.3; Layout.bottomMargin: 5 }
                                                RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 12
                                                Text { text: window.t("Language"); color: "#c8bcb0"; font.pixelSize: 11; Layout.fillWidth: true }
                                                DarkComboBox {
                                                    id: languageSelector
                                                    themePalette: window.themePalette
                                                    Layout.preferredWidth: 150
                                                    model: ["English", "Português"]
                                                    currentIndex: controller.language === "pt" ? 1 : 0
                                                    onActivated: controller.setLanguage(currentIndex === 1 ? "pt" : "en")
                                                }
                                            }
                                        ToggleRow { accentColor: window.themePalette.accent; textColor: window.themePalette.text; mutedColor: window.themePalette.muted; controller: window.appController; section: "appUI"; setting: "topmost"; label: window.t("Keep window on top") }
                                            ToggleRow { accentColor: window.themePalette.accent; textColor: window.themePalette.text; mutedColor: window.themePalette.muted; controller: window.appController; section: "appUI"; setting: "console"; label: window.t("Activity logging") }
                                            ToggleRow { accentColor: window.themePalette.accent; textColor: window.themePalette.text; mutedColor: window.themePalette.muted; controller: window.appController; section: "appUI"; setting: "tooltip"; label: window.t("Tooltips") }
                                            ToggleRow { accentColor: window.themePalette.accent; textColor: window.themePalette.text; mutedColor: window.themePalette.muted; controller: window.appController; section: "appUI"; setting: "timestamp"; label: window.t("Show playback timestamps") }
                                            ToggleRow { accentColor: window.themePalette.accent; textColor: window.themePalette.text; mutedColor: window.themePalette.muted; controller: window.appController; section: "appUI"; setting: "checkForUpdates"; label: window.t("Check for updates") }
                                            ToggleRow { accentColor: window.themePalette.accent; textColor: window.themePalette.text; mutedColor: window.themePalette.muted; controller: window.appController; section: "appUI"; setting: "sendTelemetry"; label: window.t("Send anonymous usage data") }
                                            DiscordPresenceSettings { controller: window.appController; themePalette: window.themePalette; Layout.topMargin: 10 }
                                            RowLayout {
                                                Layout.fillWidth: true
                                                Layout.topMargin: 3
                                                spacing: 8
                                                visible: controller.platformName === "Windows"
                                                ActionButton { Layout.fillWidth: true; label: window.t("Open debug console"); iconName: "activity"; variant: "secondary"; onClicked: controller.openConsole() }
                                                ActionButton { Layout.fillWidth: true; label: window.t("Close debug console"); iconName: "close"; variant: "ghost"; onClicked: controller.closeConsole() }
                                            }
                                            Text { text: window.t("Theme"); color: "#c8bcb0"; font.pixelSize: 11; Layout.topMargin: 8 }
                                            DarkComboBox { themePalette: window.themePalette;
                                                Layout.fillWidth: true; model: controller.themeNames.map(name => window.t(name))
                                                currentIndex: Math.max(0, model.indexOf(window.t(controller.currentTheme)))
                                                onActivated: controller.setTheme("Dark")
                                                contentItem: Text { leftPadding: 10; text: parent.displayText; color: window.themePalette.text; font.pixelSize: 11; verticalAlignment: Text.AlignVCenter }
                                                background: Rectangle { radius: 6; color: "#1d1a17"; border.color: "#382f29" }
                                            }
                                            RowLayout {
                                                Layout.topMargin: 8; spacing: 9
                                                ActionButton { label: window.t("Clear MIDI list"); iconName: "trash"; variant: "danger"; onClicked: controller.clearMidiList() }
                                                ActionButton { label: window.t("Clear drums list"); iconName: "trash"; variant: "danger"; onClicked: controller.clearDrumList() }
                                            }
                                        }
                                        Rectangle { visible: !window.compactLayout; width: 1; Layout.preferredWidth: 1; Layout.minimumWidth: 1; Layout.fillHeight: true; Layout.minimumHeight: 560; color: "#302923" }
                                        ColumnLayout {
                                            Layout.fillWidth: true; Layout.minimumWidth: 0; Layout.preferredWidth: 380; Layout.alignment: Qt.AlignTop; spacing: 16
                                            Text { text: window.t("PLAYBACK TUNING"); color: window.themePalette.muted; font.pixelSize: 9; font.weight: Font.Bold; font.letterSpacing: 1.3 }
                                            RangeControl { Layout.fillWidth: true; accentColor: window.themePalette.accent; textColor: window.themePalette.text; mutedColor: window.themePalette.muted; controller: window.appController; label: window.t("MIDI note length"); controlName: "midiNoteLength"; minimum: 0.1; maximum: 10; stepSize: 0.1; initialValue: Number(controller.settings.midiPlayer.customHoldLength.noteLength); suffix: " s"; active: Boolean(controller.settings.midiPlayer.customHoldLength.enabled) }
                                            RangeControl { Layout.fillWidth: true; accentColor: window.themePalette.accent; textColor: window.themePalette.text; mutedColor: window.themePalette.muted; controller: window.appController; label: window.t("MIDI random speed"); controlName: "midiSpeedFail"; minimum: 0; maximum: 100; stepSize: 1; initialValue: Number(controller.settings.midiPlayer.randomFail.speed); suffix: "%"; active: Boolean(controller.settings.midiPlayer.randomFail.enabled) }
                                            RangeControl { Layout.fillWidth: true; accentColor: window.themePalette.accent; textColor: window.themePalette.text; mutedColor: window.themePalette.muted; controller: window.appController; label: window.t("MIDI random transpose"); controlName: "midiTransposeFail"; minimum: 0; maximum: 100; stepSize: 1; initialValue: Number(controller.settings.midiPlayer.randomFail.transpose); suffix: "%"; active: Boolean(controller.settings.midiPlayer.randomFail.enabled) }
                                            RangeControl { Layout.fillWidth: true; accentColor: window.themePalette.accent; textColor: window.themePalette.text; mutedColor: window.themePalette.muted; controller: window.appController; label: window.t("MIDI note reduction"); controlName: "midiDecreaseSize"; minimum: 1; maximum: 100; stepSize: 1; initialValue: Number(controller.settings.midiPlayer.decreaseSize); suffix: "%" }
                                            RangeControl { Layout.fillWidth: true; accentColor: window.themePalette.accent; textColor: window.themePalette.text; mutedColor: window.themePalette.muted; controller: window.appController; label: window.t("Drums note length"); controlName: "drumsNoteLength"; minimum: 0.1; maximum: 10; stepSize: 0.1; initialValue: Number(controller.settings.drumsMacro.customHoldLength.noteLength); suffix: " s"; active: Boolean(controller.settings.drumsMacro.customHoldLength.enabled) }
                                            RangeControl { Layout.fillWidth: true; accentColor: window.themePalette.accent; textColor: window.themePalette.text; mutedColor: window.themePalette.muted; controller: window.appController; label: window.t("Drums random speed"); controlName: "drumsSpeedFail"; minimum: 0; maximum: 100; stepSize: 1; initialValue: Number(controller.settings.drumsMacro.randomFail.speed); suffix: "%"; active: Boolean(controller.settings.drumsMacro.randomFail.enabled) }
                                            RangeControl { Layout.fillWidth: true; accentColor: window.themePalette.accent; textColor: window.themePalette.text; mutedColor: window.themePalette.muted; controller: window.appController; label: window.t("Drums note reduction"); controlName: "drumsDecreaseSize"; minimum: 1; maximum: 100; stepSize: 1; initialValue: Number(controller.settings.drumsMacro.decreaseSize); suffix: "%" }
                                        }
                                    }
                                    Rectangle { Layout.fillWidth: true; height: 1; color: "#302923" }
                                    ColumnLayout {
                                        Layout.fillWidth: true; spacing: 11
                                        Text { text: window.t("GLOBAL HOTKEYS"); color: window.themePalette.muted; font.pixelSize: 9; font.weight: Font.Bold; font.letterSpacing: 1.3 }
                                        Text { text: window.t("Click a shortcut, then press the key you want to use."); color: window.themePalette.muted; font.pixelSize: 10 }
                                        GridLayout {
                                            id: hotkeysGrid
                                            Layout.fillWidth: true; columns: Math.max(1, Math.floor((width + 6) / 148)); columnSpacing: 6; rowSpacing: 10
                                            Repeater {
                                                model: [{key:"play", label:window.t("Play")}, {key:"pause", label:window.t("Pause")}, {key:"stop", label:window.t("Stop")}, {key:"speedup", label:window.t("Speed up")}, {key:"slowdown", label:window.t("Slow down")}]
                                                delegate: ColumnLayout {
                                                    required property var modelData
                                                    Layout.preferredWidth: 142; Layout.minimumWidth: 118; Layout.fillWidth: true; spacing: 6
                                                    Text { text: modelData.label; color: "#b5a99d"; font.pixelSize: 10 }
                                                    ActionButton {
                                                        variant: "secondary"
                                                        Layout.fillWidth: true
                                                        label: {
                                                            const page = controller.ui.settings
                                                            const prop = modelData.key === "play" ? "playHotkeyButton" : modelData.key === "pause" ? "pauseHotkeyButton" : modelData.key === "stop" ? "stopHotkeyButton" : modelData.key === "speedup" ? "speedUpHotkeyButton" : "slowHotkeyButton"
                                                            return page[prop].text || String(controller.settings.hotkeys[modelData.key]).toUpperCase()
                                                        }
                                                        enabled: {
                                                            const prop = modelData.key === "play" ? "playHotkeyButton" : modelData.key === "pause" ? "pauseHotkeyButton" : modelData.key === "stop" ? "stopHotkeyButton" : modelData.key === "speedup" ? "speedUpHotkeyButton" : "slowHotkeyButton"
                                                            return controller.ui.settings[prop].enabled
                                                        }
                                                        onClicked: controller.setHotkey(modelData.key)
                                                    }
                                                }
                                            }
                                        }
                                        RowLayout {
                                            Layout.fillWidth: true; spacing: 20; Layout.topMargin: 7
                                            ColumnLayout { Layout.fillWidth: true; spacing: 6; Text { text: window.t("MIDI input module"); color: "#bcb0a4"; font.pixelSize: 10 } DarkComboBox { themePalette: window.themePalette; Layout.fillWidth: true; model: ["pynput", "keyboard"]; currentIndex: Math.max(0, model.indexOf(String(controller.settings.midiPlayer.inputModule || "pynput"))); onActivated: controller.setConfigValue("midiPlayer", "inputModule", currentText); contentItem: Text { leftPadding: 10; text: parent.displayText; color: window.themePalette.text; font.pixelSize: 11; verticalAlignment: Text.AlignVCenter } background: Rectangle { radius: 6; color: "#1d1a17"; border.color: "#382f29" } } }
                                            ColumnLayout { Layout.fillWidth: true; spacing: 6; Text { text: window.t("Drums input module"); color: "#bcb0a4"; font.pixelSize: 10 } DarkComboBox { themePalette: window.themePalette; Layout.fillWidth: true; model: ["pynput", "keyboard"]; currentIndex: Math.max(0, model.indexOf(String(controller.settings.drumsMacro.inputModule || "pynput"))); onActivated: controller.setConfigValue("drumsMacro", "inputModule", currentText); contentItem: Text { leftPadding: 10; text: parent.displayText; color: window.themePalette.text; font.pixelSize: 11; verticalAlignment: Text.AlignVCenter } background: Rectangle { radius: 6; color: "#1d1a17"; border.color: "#382f29" } } }
                                        }
                                    }
                                }
                            }
                        }

                        // About
                        Item {
                            ColumnLayout {
                                anchors.fill: parent; anchors.margins: 28; spacing: 16
                                RowLayout {
                                    spacing: 14
                                    Image {
                                        source: Qt.resolvedUrl("../../assets/branding/better-nanomidi/" +
                                                              (window.lightTheme ? "symbol-on-light.png" : "symbol-on-dark.png"))
                                        sourceSize.width: 128
                                        sourceSize.height: 128
                                        Layout.preferredWidth: 48
                                        Layout.preferredHeight: 48
                                        fillMode: Image.PreserveAspectFit
                                        smooth: true
                                        mipmap: true
                                        Accessible.name: window.t("Better NanoMidi logo")
                                    }
                                    ColumnLayout {
                                        spacing: 5
                                        Text { text: window.t("About Better NanoMidi"); color: window.themePalette.text; font.pixelSize: 25; font.weight: Font.DemiBold }
                                        Text { text: window.t("Project notes and release information."); color: window.themePalette.muted; font.pixelSize: 12 }
                                    }
                                }
                                Rectangle {
                                    Layout.fillWidth: true; Layout.fillHeight: true; radius: 16; color: window.withAlpha(window.themePalette.surface, 0.88); border.color: window.themePalette.line
                                    ScrollView {
                                        anchors.fill: parent; anchors.margins: 26; clip: true
                                        TextEdit {
                                            text: controller.infoHtml
                                            textFormat: TextEdit.RichText
                                            readOnly: true; selectByMouse: true; wrapMode: TextEdit.Wrap
                                            color: window.themePalette.text; font.pixelSize: 13
                                            onLinkActivated: controller.openExternalLink(link)
                                            width: parent.width
                                        }
                                    }
                                }
                                RowLayout { Text { text: window.t("Better NanoMidi"); color: window.themePalette.text; font.pixelSize: 10; font.weight: Font.DemiBold } Rectangle { width: 1; height: 12; color: window.themePalette.line } Text { text: controller.appVersion; color: window.themePalette.muted; font.pixelSize: 10; font.family: "Consolas" } Item { Layout.fillWidth: true } Text { text: window.t("PySide6 + Qt Quick"); color: window.themePalette.muted; font.pixelSize: 10 } }
                            }
                        }

                        // macOS permissions
                        Item {
                            ColumnLayout {
                                anchors.fill: parent; anchors.margins: 30; spacing: 18
                                Text { text: window.t("macOS permissions"); color: window.themePalette.text; font.pixelSize: 25; font.weight: Font.DemiBold }
                                Text { text: window.t("Keyboard automation needs Accessibility and Input Monitoring access. Open the matching system settings, enable nanoMIDIPlayer, then restart the input listener."); color: "#bcb0a4"; font.pixelSize: 12; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                                RowLayout { spacing: 10; ActionButton { label: window.t("Accessibility"); iconName: "accessibility"; variant: "secondary"; onClicked: controller.openAccessibilitySettings() } ActionButton { label: window.t("Input monitoring"); iconName: "activity"; variant: "secondary"; onClicked: controller.openInputMonitoringSettings() } }
                                Item { Layout.fillHeight: true }
                            }
                        }

                        PlaylistManagerPage {
                            controller: window.appController
                            themePalette: window.themePalette
                            compactLayout: window.compactLayout
                        }
                    }
                }
            }
        }

        // Small resize zones keep the frameless window manageable on Windows.
        MouseArea { anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom; width: 6; cursorShape: Qt.SizeHorCursor; onPressed: window.startSystemResize(Qt.LeftEdge) }
        MouseArea { anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom; width: 6; cursorShape: Qt.SizeHorCursor; onPressed: window.startSystemResize(Qt.RightEdge) }
        MouseArea { anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; height: 6; cursorShape: Qt.SizeVerCursor; onPressed: window.startSystemResize(Qt.TopEdge) }
        MouseArea { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 6; cursorShape: Qt.SizeVerCursor; onPressed: window.startSystemResize(Qt.BottomEdge) }
    }
}
