import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    required property var controller
    required property var themePalette
    property bool compactLayout: false
    property string searchText: ""
    property bool favoritesOnly: false

    readonly property var visibleMidis: {
        const query = searchText.trim().toLowerCase()
        return controller.midiLibrary.filter(entry => {
            if (favoritesOnly && !entry.favorite) return false
            if (!query) return true
            return String(entry.name || "").toLowerCase().includes(query)
                || String(entry.folder || "").toLowerCase().includes(query)
        })
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.compactLayout ? 18 : 26
        spacing: 13

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: root.controller.translateText("My MIDI Library")
                    color: root.themePalette.text
                    font.pixelSize: 25
                    font.weight: Font.DemiBold
                    font.letterSpacing: -0.4
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
                Text {
                    text: root.controller.translateText("Browse local MIDI files and keep your favorites close.")
                    color: root.themePalette.muted
                    font.pixelSize: 11
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }
            }

            ActionButton {
                viewMode: "icon"
                label: root.controller.translateText("Refresh library")
                iconName: "refresh"
                variant: "ghost"
                onClicked: root.controller.refreshMidiLibrary()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 9

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                radius: 9
                color: root.themePalette.surface
                border.color: searchField.activeFocus ? root.themePalette.accent : root.themePalette.line
                border.width: searchField.activeFocus ? 1.5 : 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 11
                    anchors.rightMargin: 10
                    spacing: 8

                    Icon {
                        name: "search"
                        color: root.themePalette.muted
                        iconSize: 16
                    }
                    TextField {
                        id: searchField
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        text: root.searchText
                        placeholderText: root.controller.translateText("Search your MIDI library")
                        color: root.themePalette.text
                        placeholderTextColor: root.themePalette.muted
                        font.pixelSize: 12
                        selectByMouse: true
                        background: Item { }
                        onTextChanged: root.searchText = text
                        Accessible.name: placeholderText
                    }
                }
            }

            ButtonGroup { id: libraryFilterGroup }

            Button {
                id: allFilter
                ButtonGroup.group: libraryFilterGroup
                checkable: true
                checked: !root.favoritesOnly
                implicitHeight: 38
                implicitWidth: allLabel.implicitWidth + 25
                hoverEnabled: true
                Accessible.name: allLabel.text
                onClicked: root.favoritesOnly = false
                contentItem: Text {
                    id: allLabel
                    text: root.controller.translateText("All MIDI") + "  " + root.controller.midiLibrary.length
                    color: allFilter.checked ? root.themePalette.text : root.themePalette.muted
                    font.pixelSize: 11
                    font.weight: allFilter.checked ? Font.DemiBold : Font.Medium
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: 11
                    rightPadding: 11
                }
                background: Rectangle {
                    radius: 8
                    color: allFilter.checked ? root.themePalette.raised : (allFilter.hovered ? root.themePalette.surface : "transparent")
                    border.color: allFilter.checked ? root.themePalette.line : "transparent"
                    border.width: 1
                }
            }

            Button {
                id: favoriteFilter
                ButtonGroup.group: libraryFilterGroup
                checkable: true
                checked: root.favoritesOnly
                implicitHeight: 38
                implicitWidth: favoriteLabel.implicitWidth + 25
                hoverEnabled: true
                Accessible.name: favoriteLabel.text
                onClicked: root.favoritesOnly = true
                contentItem: Text {
                    id: favoriteLabel
                    text: root.controller.translateText("Favorites") + "  " + root.controller.midiLibrary.filter(entry => entry.favorite).length
                    color: favoriteFilter.checked ? root.themePalette.accent : root.themePalette.muted
                    font.pixelSize: 11
                    font.weight: favoriteFilter.checked ? Font.DemiBold : Font.Medium
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: 11
                    rightPadding: 11
                }
                background: Rectangle {
                    radius: 8
                    color: favoriteFilter.checked
                        ? Qt.rgba(root.themePalette.accent.r, root.themePalette.accent.g, root.themePalette.accent.b, 0.1)
                        : (favoriteFilter.hovered ? root.themePalette.surface : "transparent")
                    border.color: favoriteFilter.checked ? Qt.rgba(root.themePalette.accent.r, root.themePalette.accent.g, root.themePalette.accent.b, 0.32) : "transparent"
                    border.width: 1
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 280

            ListView {
                id: midiList
                anchors.fill: parent
                clip: true
                spacing: 7
                model: root.visibleMidis
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                delegate: Rectangle {
                    id: midiRow
                    required property var modelData
                    required property int index
                    width: midiList.width
                    height: 68
                    radius: 10
                    color: rowHover.containsMouse ? root.themePalette.raised : root.themePalette.surface
                    border.color: rowHover.containsMouse ? Qt.rgba(root.themePalette.accent.r, root.themePalette.accent.g, root.themePalette.accent.b, 0.42) : root.themePalette.line
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: 130 } }
                    Behavior on border.color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }

                    MouseArea {
                        id: rowHover
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                        hoverEnabled: true
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 9
                        spacing: 11

                        Rectangle {
                            id: coverFrame
                            Layout.preferredWidth: 46
                            Layout.preferredHeight: 46
                            radius: 7
                            color: root.themePalette.raised
                            clip: true
                            property string requestedCover: root.controller.midiCoverForPath(midiRow.modelData.path)
                            property bool failed: false
                            onRequestedCoverChanged: failed = false

                            Image {
                                anchors.fill: parent
                                source: !coverFrame.failed && coverFrame.requestedCover.length
                                    ? coverFrame.requestedCover
                                    : Qt.resolvedUrl("icons/playlist-cover-fallback.svg")
                                fillMode: coverFrame.requestedCover.length && !coverFrame.failed
                                    ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                                asynchronous: true
                                cache: true
                                onStatusChanged: if (status === Image.Error && coverFrame.requestedCover.length) coverFrame.failed = true
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3

                            Text {
                                text: midiRow.modelData.name
                                color: root.themePalette.text
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Text {
                                text: midiRow.modelData.folder
                                color: root.themePalette.muted
                                font.pixelSize: 9
                                elide: Text.ElideMiddle
                                Layout.fillWidth: true
                            }
                        }

                        ActionButton {
                            viewMode: "icon"
                            label: root.controller.translateText("Add to playlist")
                            iconName: "playlist"
                            variant: "ghost"
                            onClicked: root.controller.addMidiToPlaylist(midiRow.modelData.path)
                        }
                        ActionButton {
                            viewMode: "icon"
                            label: root.controller.translateText("Play now")
                            iconName: "play"
                            variant: "ghost"
                            onClicked: root.controller.playMidiFromLibrary(midiRow.modelData.path)
                        }
                        ActionButton {
                            viewMode: "icon"
                            label: root.controller.translateText(midiRow.modelData.favorite ? "Remove from favorites" : "Add to favorites")
                            iconName: midiRow.modelData.favorite ? "starFilled" : "star"
                            textColor: midiRow.modelData.favorite ? root.themePalette.accent : root.themePalette.text
                            accentColor: root.themePalette.accent
                            variant: "ghost"
                            onClicked: root.controller.toggleMidiFavorite(midiRow.modelData.path)
                        }
                    }
                }
            }

            ColumnLayout {
                anchors.centerIn: parent
                visible: midiList.count === 0
                spacing: 7

                Icon {
                    name: root.favoritesOnly ? "star" : "emptyMidi"
                    color: root.themePalette.muted
                    iconSize: 30
                    Layout.alignment: Qt.AlignHCenter
                }
                Text {
                    text: {
                        if (root.controller.midiLibrary.length === 0)
                            return root.controller.translateText("No MIDI files found")
                        if (root.favoritesOnly)
                            return root.controller.translateText("No favorites yet")
                        return root.controller.translateText("No matching MIDIs")
                    }
                    color: root.themePalette.text
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    Layout.alignment: Qt.AlignHCenter
                }
                Text {
                    text: {
                        if (root.controller.midiLibrary.length === 0)
                            return root.controller.translateText("Open a MIDI or download a score from MIDI Hub to see it here.")
                        if (root.favoritesOnly)
                            return root.controller.translateText("Mark a MIDI with the star to add it to Favorites.")
                        return root.controller.translateText("Try another title or folder name.")
                    }
                    color: root.themePalette.muted
                    font.pixelSize: 10
                    Layout.alignment: Qt.AlignHCenter
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }
}
