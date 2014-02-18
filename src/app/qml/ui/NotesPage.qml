/*
 * Copyright: 2013 - 2014 Canonical, Ltd
 *
 * This file is part of reminders
 *
 * reminders is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * reminders is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick 2.0
import Ubuntu.Components 0.1
import Ubuntu.Components.ListItems 0.1
import Evernote 0.1
import "../components"

Page {
    id: root

    property alias filter: notes.filterNotebookGuid

    signal noteSelected(var note)
    signal openSearch()

    onActiveChanged: {
        if (active) {
            NotesStore.refreshNotes();
        }
    }

    // Just for testing
    tools: ToolbarItems {
        ToolbarButton {
            text: i18n.tr("Search")
            iconName: "search"
            onTriggered: {
                root.openSearch();
            }
        }

        ToolbarSpacer { }

        ToolbarButton {
            text: i18n.tr("Accounts")
            iconName: "contacts-app-symbolic"
            visible: accounts.count > 1
            onTriggered: {
                openAccountPage(true);
            }
        }

        ToolbarButton {
            text: i18n.tr("Add note")
            iconName: "add"
            onTriggered: {
                NotesStore.createNote("Untitled");
            }
        }
    }

    Notes {
        id: notes
    }

    ListView {
        anchors { left: parent.left; right: parent.right }
        height: parent.height - y
        model: notes
        clip: true

        delegate: NotesDelegate {
            title: model.title
            creationDate: model.created
            content: model.plaintextContent
            resource: model.resourceUrls.length > 0 ? model.resourceUrls[0] : ""

            Component.onCompleted: NotesStore.refreshNoteContent(model.guid)

            onClicked: {
                root.noteSelected(NotesStore.note(guid));
            }
        }
    }
}
