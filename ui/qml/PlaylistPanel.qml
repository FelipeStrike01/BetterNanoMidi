import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root

    property var controller
    property var themePalette
    readonly property int trackCount: controller ? controller.midiPlaylist.length : 0

    Layout.fillWidth: true
    Layout.preferredHeight: 480
    Layout.minimumHeight: 360
    implicitHeight: 480
    radius: 12
    color: themePalette.surface
    border.color: themePalette.line

    Dialog {
        id: deleteConfirmation
        modal: true
        title: root.controller.translateText("Delete playlist")
        standardButtons: Dialog.Yes | Dialog.No
        anchors.centerIn: Overlay.overlay
        onAccepted: root.controller.deletePlaylist(root.controller.activePlaylistIndex)

        contentItem: Text {
            text: root.controller.translateText("Delete this playlist?")
            color: root.themePalette.text
            font.pixelSize: 12
            wrapMode: Text.WordWrap
            width: 280
        }

        background: Rectangle {
            radius: 12
            color: root.themePalette.surface
            border.color: root.themePalette.line
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 11

        RowLayout {
            Layout.fillWidth: true
            spacing: 9

            TextField {
                id: playlistName
                Layout.fillWidth: true
                enabled: root.controller.activePlaylistIndex >= 0
                text: root.controller.activePlaylistName
                placeholderText: root.controller.translateText("Playlist name")
                color: root.themePalette.text
                placeholderTextColor: root.themePalette.muted
                font.pixelSize: 16
                font.weight: Font.DemiBold
                selectByMouse: true
                Accessible.name: root.controller.translateText("Playlist name")
                onEditingFinished: root.controller.renamePlaylist(root.controller.activePlaylistIndex, text)

                background: Rectangle {
                    radius: 7
                    color: playlistName.activeFocus ? root.themePalette.raised : "transparent"
                    border.color: playlistName.activeFocus ? root.themePalette.accent : "transparent"
                }
            }

            Rectangle {
                radius: 10
                color: Qt.rgba(root.themePalette.accent.r, root.themePalette.accent.g, root.themePalette.accent.b, 0.13)
                border.color: Qt.rgba(root.themePalette.accent.r, root.themePalette.accent.g, root.themePalette.accent.b, 0.24)
                implicitWidth: trackCountLabel.implicitWidth + 18
                implicitHeight: 28

                Text {
                    id: trackCountLabel
                    anchors.centerIn: parent
                    text: String(root.trackCount) + " " + root.controller.translateText("tracks")
                    color: root.themePalette.accent
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                }
            }

            ActionButton {
                viewMode: "icon"
                label: root.controller.translateText("Play playlist")
                iconName: "play"
                variant: "primary"
                enabled: root.trackCount > 0
                onClicked: root.controller.playPlaylist()
            }
            ActionButton {
                viewMode: "icon"
                label: root.controller.translateText("Delete playlist")
                iconName: "trash"
                variant: "danger"
                enabled: root.controller.activePlaylistIndex >= 0
                onClicked: deleteConfirmation.open()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 7

            Text {
                text: root.controller.translateText("EDITING PLAYLIST")
                color: root.themePalette.muted
                font.pixelSize: 9
                font.weight: Font.Bold
                font.letterSpacing: 1.2
            }

            Item { Layout.fillWidth: true }

            ActionButton {
                label: root.controller.translateText("Add files")
                iconName: "folder"
                variant: "secondary"
                enabled: root.controller.activePlaylistIndex >= 0
                onClicked: root.controller.addMidiFilesToPlaylist()
            }
            ActionButton {
                viewMode: "icon"
                label: root.controller.translateText("Add current MIDI")
                iconName: "plus"
                variant: "ghost"
                enabled: root.controller.activePlaylistIndex >= 0
                onClicked: root.controller.addCurrentMidiToPlaylist()
            }
            ActionButton {
                viewMode: "icon"
                label: root.controller.translateText("Clear playlist")
                iconName: "trash"
                variant: "ghost"
                enabled: root.trackCount > 0
                onClicked: root.controller.clearMidiPlaylist()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: root.themePalette.line
        }

        Item {
            id: listHost
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 96

            ListView {
                id: playlistList
                anchors.fill: parent
                clip: true
                spacing: 3
                model: root.controller.midiPlaylist
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                delegate: ItemDelegate {
                    id: trackDelegate
                    required property int index
                    required property var modelData
                    width: playlistList.width - 4
                    height: 50
                    highlighted: Boolean(modelData.selected)
                    hoverEnabled: true
                    Accessible.name: String(index + 1) + ". " + modelData.name
                    onClicked: root.controller.selectPlaylistTrack(index)

                    background: Rectangle {
                        radius: 7
                        color: trackDelegate.highlighted
                            ? Qt.rgba(root.themePalette.accent.r, root.themePalette.accent.g, root.themePalette.accent.b, 0.16)
                            : trackDelegate.hovered ? root.themePalette.raised : "transparent"
                        border.color: trackDelegate.highlighted ? Qt.rgba(root.themePalette.accent.r, root.themePalette.accent.g, root.themePalette.accent.b, 0.55) : "transparent"
                        border.width: trackDelegate.highlighted ? 1 : 0
                    }

                    contentItem: RowLayout {
                        spacing: 7

                        Text {
                            text: String(index + 1).padStart(2, "0")
                            color: root.themePalette.muted
                            font.pixelSize: 10
                            font.family: "Consolas"
                        }

                        Rectangle {
                            Layout.preferredWidth: 34
                            Layout.preferredHeight: 34
                            radius: 7
                            color: root.themePalette.raised
                            clip: true

                            Image {
                                id: trackCover
                                anchors.fill: parent
                                property string requestedCover: String(modelData.coverUrl || "")
                                property bool failed: false
                                source: !failed && requestedCover.length
                                    ? requestedCover
                                    : Qt.resolvedUrl("icons/playlist-cover-fallback.svg")
                                fillMode: requestedCover.length && !failed ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                                asynchronous: true
                                cache: true
                                onStatusChanged: if (status === Image.Error && requestedCover.length) failed = true
                                onRequestedCoverChanged: failed = false
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                text: modelData.name
                                color: root.themePalette.text
                                font.pixelSize: 11
                                font.weight: modelData.selected ? Font.DemiBold : Font.Normal
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: modelData.path
                                color: root.themePalette.muted
                                font.pixelSize: 9
                                elide: Text.ElideMiddle
                                Layout.fillWidth: true
                            }
                        }

                        Text {
                            visible: Boolean(modelData.playing) || !Boolean(modelData.available)
                            text: modelData.playing
                                ? root.controller.translateText("Now playing")
                                : root.controller.translateText("Missing file")
                            color: modelData.available ? root.themePalette.accent : "#c67d72"
                            font.pixelSize: 9
                            font.weight: Font.DemiBold
                        }

                        ActionButton {
                            viewMode: "icon"
                            label: root.controller.translateText("Play track")
                            iconName: "play"
                            variant: "ghost"
                            enabled: Boolean(modelData.available)
                            onClicked: root.controller.playPlaylistTrack(index)
                        }
                        ActionButton {
                            viewMode: "icon"
                            label: root.controller.translateText("Move up")
                            iconName: "moveUp"
                            variant: "ghost"
                            enabled: index > 0
                            onClicked: root.controller.movePlaylistTrack(index, -1)
                        }
                        ActionButton {
                            viewMode: "icon"
                            label: root.controller.translateText("Move down")
                            iconName: "moveDown"
                            variant: "ghost"
                            enabled: index < root.trackCount - 1
                            onClicked: root.controller.movePlaylistTrack(index, 1)
                        }
                        ActionButton {
                            viewMode: "icon"
                            label: root.controller.translateText("Remove from playlist")
                            iconName: "trash"
                            variant: "ghost"
                            onClicked: root.controller.removePlaylistTrack(index)
                        }
                    }
                }
            }

            ColumnLayout {
                anchors.centerIn: parent
                visible: playlistList.count === 0
                spacing: 6

                Icon {
                    name: root.controller.midiPlaylists.length ? "emptyMidi" : "playlist"
                    color: root.themePalette.muted
                    iconSize: 24
                    Layout.alignment: Qt.AlignHCenter
                }
                Text {
                    text: root.controller.midiPlaylists.length
                        ? root.controller.translateText("No tracks in playlist")
                        : root.controller.translateText("No playlists yet")
                    color: root.themePalette.text
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    Layout.alignment: Qt.AlignHCenter
                }
                Text {
                    text: root.controller.midiPlaylists.length
                        ? root.controller.translateText("Add MIDI files to create your play order.")
                        : root.controller.translateText("Create a playlist to start building your MIDI rotation.")
                    color: root.themePalette.muted
                    font.pixelSize: 10
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }

        Text {
            text: root.controller.playlistActive
                ? root.controller.translateText("Playlist is playing in order.")
                : root.controller.translateText("Choose a track and start the playlist.")
            color: root.themePalette.muted
            font.pixelSize: 9
            Layout.fillWidth: true
            elide: Text.ElideRight
        }
    }
}
