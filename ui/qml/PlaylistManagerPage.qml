import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property var controller
    property var themePalette
    property bool compactLayout: false
    property bool editingPlaylist: false

    Component.onCompleted: root.controller.setPlaylistEditing(root.editingPlaylist)
    onEditingPlaylistChanged: root.controller.setPlaylistEditing(root.editingPlaylist)

    ScrollView {
        id: pageScroll
        anchors.fill: parent
        clip: true
        contentWidth: availableWidth
        contentHeight: pageContent.implicitHeight + 44
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        ColumnLayout {
            id: pageContent
            x: 22
            y: 22
            width: pageScroll.availableWidth - 44
            spacing: 14

            RowLayout {
                Layout.fillWidth: true
                spacing: 11

                ActionButton {
                    visible: root.editingPlaylist
                    viewMode: "icon"
                    label: root.controller.translateText("Playlists")
                    iconName: "previous"
                    variant: "ghost"
                    onClicked: root.editingPlaylist = false
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text: root.editingPlaylist
                            ? root.controller.activePlaylistName
                            : root.controller.translateText("Playlists")
                        color: root.themePalette.text
                        font.pixelSize: 26
                        font.weight: Font.DemiBold
                        font.letterSpacing: -0.5
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Text {
                        visible: !root.editingPlaylist
                        text: root.controller.translateText("Create playlists and arrange MIDI tracks for uninterrupted playback.")
                        color: root.themePalette.muted
                        font.pixelSize: 11
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }

                Rectangle {
                    radius: 10
                    color: root.themePalette.surface
                    border.color: root.themePalette.line
                    implicitWidth: playlistCount.implicitWidth + 24
                    implicitHeight: 34

                    Text {
                        id: playlistCount
                        anchors.centerIn: parent
                        text: String(root.controller.midiPlaylists.length) + " " + root.controller.translateText("playlists")
                        color: root.themePalette.muted
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                    }
                }

                ActionButton {
                    visible: !root.editingPlaylist
                    label: root.controller.translateText("Create playlist")
                    iconName: "plus"
                    variant: "primary"
                    onClicked: {
                        root.controller.createPlaylist()
                        root.editingPlaylist = true
                    }
                }
            }

            StackLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: root.editingPlaylist ? 500 : galleryPage.implicitHeight
                Layout.minimumHeight: root.editingPlaylist ? 400 : galleryPage.implicitHeight
                currentIndex: root.editingPlaylist ? 1 : 0

                ColumnLayout {
                    id: galleryPage
                    spacing: 10

                    GridLayout {
                        id: playlistGrid
                        Layout.fillWidth: true
                        columns: Math.max(1, Math.floor((width + columnSpacing) / ((root.compactLayout ? 168 : 190) + columnSpacing)))
                        columnSpacing: root.compactLayout ? 9 : 12
                        rowSpacing: root.compactLayout ? 9 : 12
                        property real cardSize: Math.min(root.compactLayout ? 184 : 208,
                            Math.max(root.compactLayout ? 144 : 156, (width - (columns - 1) * columnSpacing) / columns))
                        Layout.preferredHeight: Math.ceil((root.controller.midiPlaylists.length + 1) / Math.max(1, columns)) * cardSize
                            + Math.max(0, Math.ceil((root.controller.midiPlaylists.length + 1) / Math.max(1, columns)) - 1) * rowSpacing

                        Repeater {
                            model: root.controller.midiPlaylists.length + 1

                            delegate: Item {
                                id: cardTile
                                required property int index
                                Layout.fillWidth: true
                                Layout.preferredHeight: playlistGrid.cardSize

                                readonly property bool createCard: index === root.controller.midiPlaylists.length
                                readonly property var playlistData: createCard ? ({}) : root.controller.midiPlaylists[index]
                                readonly property var coverUrls: createCard ? [] : (playlistData.coverUrls || [])
                                readonly property string fallbackCover: Qt.resolvedUrl("icons/playlist-cover-fallback.svg")

                                Rectangle {
                                    id: cardSurface
                                    width: playlistGrid.cardSize
                                    height: playlistGrid.cardSize
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    radius: 13
                                    color: root.themePalette.raised
                                    border.width: 1
                                    border.color: cardButton.hovered
                                        ? Qt.rgba(root.themePalette.accent.r, root.themePalette.accent.g, root.themePalette.accent.b, 0.78)
                                        : root.themePalette.line
                                    clip: true

                                    Behavior on border.color { ColorAnimation { duration: 160 } }

                                    Image {
                                        anchors.fill: parent
                                        visible: !cardTile.createCard && cardTile.coverUrls.length <= 1
                                        property string requestedCover: cardTile.coverUrls.length ? String(cardTile.coverUrls[0]) : ""
                                        property bool failed: false
                                        source: !failed && requestedCover.length ? requestedCover : cardTile.fallbackCover
                                        fillMode: requestedCover.length && !failed ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                                        asynchronous: true
                                        cache: true
                                        onStatusChanged: if (status === Image.Error && requestedCover.length) failed = true
                                        onRequestedCoverChanged: failed = false
                                    }

                                    Repeater {
                                        model: 4
                                        delegate: Item {
                                            required property int index
                                            property string requestedCover: cardTile.coverUrls.length
                                                ? String(cardTile.coverUrls[index % cardTile.coverUrls.length]) : ""
                                            property bool failed: false
                                            onRequestedCoverChanged: failed = false
                                            x: (index % 2) * (cardSurface.width / 2)
                                            y: Math.floor(index / 2) * (cardSurface.height / 2)
                                            width: cardSurface.width / 2
                                            height: cardSurface.height / 2
                                            visible: !cardTile.createCard && cardTile.coverUrls.length > 1

                                            Image {
                                                anchors.fill: parent
                                                source: parent.failed || !parent.requestedCover.length ? cardTile.fallbackCover : parent.requestedCover
                                                fillMode: Image.PreserveAspectCrop
                                                asynchronous: true
                                                cache: true
                                                onStatusChanged: if (status === Image.Error && parent.requestedCover.length) parent.failed = true
                                            }
                                        }
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        visible: cardTile.createCard
                                        color: Qt.rgba(root.themePalette.accent.r, root.themePalette.accent.g, root.themePalette.accent.b, 0.055)
                                        border.color: "transparent"
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        gradient: Gradient {
                                            GradientStop { position: 0.0; color: "#00100d0a" }
                                            GradientStop { position: 0.48; color: "#30100d0a" }
                                            GradientStop { position: 1.0; color: "#e8100d0a" }
                                        }
                                    }

                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        visible: cardTile.createCard
                                        spacing: 10

                                        Icon {
                                            name: "plus"
                                            color: root.themePalette.accent
                                            iconSize: 25
                                            Layout.alignment: Qt.AlignHCenter
                                        }
                                        Text {
                                            text: root.controller.translateText("Create playlist")
                                            color: root.themePalette.text
                                            font.pixelSize: 12
                                            font.weight: Font.DemiBold
                                            horizontalAlignment: Text.AlignHCenter
                                            Layout.alignment: Qt.AlignHCenter
                                        }
                                    }

                                    ColumnLayout {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        anchors.margins: 14
                                        visible: !cardTile.createCard
                                        spacing: 5

                                        Text {
                                            text: cardTile.playlistData.name || ""
                                            color: root.themePalette.text
                                            font.pixelSize: 14
                                            font.weight: Font.DemiBold
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                        Text {
                                            text: String(cardTile.playlistData.trackCount || 0) + " " + root.controller.translateText("tracks")
                                            color: "#e1d8cf"
                                            font.pixelSize: 10
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                    }

                                    Button {
                                        id: cardButton
                                        anchors.fill: parent
                                        padding: 0
                                        flat: true
                                        hoverEnabled: true
                                        focusPolicy: Qt.StrongFocus
                                        Accessible.name: cardTile.createCard
                                            ? root.controller.translateText("Create playlist")
                                            : cardTile.playlistData.name + ", " + cardTile.playlistData.trackCount + " " + root.controller.translateText("tracks")
                                        background: Item { }
                                        contentItem: Item { }
                                        onClicked: {
                                            if (cardTile.createCard) {
                                                root.controller.createPlaylist()
                                            } else {
                                                root.controller.selectPlaylist(cardTile.index)
                                            }
                                            root.editingPlaylist = true
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                PlaylistPanel {
                    controller: root.controller
                    themePalette: root.themePalette
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredHeight: 500
                    Layout.minimumHeight: 400
                }
            }
        }
    }

    Connections {
        target: root.controller
        function onPlaylistChanged() {
            if (root.editingPlaylist && root.controller.midiPlaylists.length === 0)
                root.editingPlaylist = false
        }
    }
}
