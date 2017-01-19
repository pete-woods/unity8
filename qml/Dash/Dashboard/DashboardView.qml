/*
 * Copyright (C) 2017 Canonical, Ltd.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick 2.4
import QtQuick.Layouts 1.2
import Ubuntu.Components 1.3
import Ubuntu.Components.ListItems 1.3
import "../../Components"
import ".."

StyledItem {
    id: root
    objectName: "dashboard"

    property bool editMode: false
    property int columnCount: 3

    readonly property int leftMargin: units.gu(3)
    readonly property int topMargin: units.gu(3)
    readonly property int contentSpacing: units.gu(1)

    theme: ThemeSettings {
        name: "Ubuntu.Components.Themes.Ambiance"
    }

    ListModel {
        id: fakeModel
        ListElement { name: "Weather"; headerColor: "yellow" }
        ListElement { name: "BBC News"; headerColor: "red"  }
        ListElement { name: "Fitbit"; headerColor: "teal"  }
        ListElement { name: "The Guardian"; headerColor: "blue"  }
        ListElement { name: "Telegram"; headerColor: "navy"  }
        ListElement { name: "Clock"; content: "Qt.formatTime(new Date())"; ttl: 1000 }
        ListElement { name: "G" }
        ListElement { name: "H" }
        ListElement { name: "I" }
        ListElement { name: "J" }
        ListElement { name: "K" }
        ListElement { name: "L" }
        ListElement { name: "M" }
        ListElement { name: "N" }
        ListElement { name: "O" }
        ListElement { name: "P" }
        ListElement { name: "Q" }
        ListElement { name: "R" }
        ListElement { name: "S" }
        ListElement { name: "T" }
        ListElement { name: "U" }
    }

    Component {
        id: dashboardViewContentsComponent
        DashboardViewContents {
            model: fakeModel
            editMode: root.editMode
            columnCount: root.columnCount
            contentSpacing: root.contentSpacing
        }
    }

    Loader {
        active: true
        asynchronous: true
        visible: active && status === Loader.Ready
        anchors {
            left: parent.left
            top: parent.top
            bottom: buttonBar.top
            right: parent.right
            topMargin: root.topMargin
            bottomMargin: root.contentSpacing
        }

        sourceComponent: {
            if (root.state == "dashboard") {
                return dashboardViewContentsComponent;
            }
        }
    }

    RowLayout {
        id: buttonBar
        spacing: root.contentSpacing
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            leftMargin: root.leftMargin
            rightMargin: root.leftMargin
            topMargin: root.contentSpacing
            bottomMargin: root.contentSpacing
        }

        Button {
            text: root.columnCount == 1 ? i18n.tr("Location...") : i18n.tr("Edit location")
            visible: root.editMode && root.state == "dashboard"
            onClicked: root.state = "location"
        }

        Button {
            text: root.columnCount == 1 ? i18n.tr("Add...") : i18n.tr("Add more sources")
            //iconName: "add" // FIXME screws the button width and the whole layout
            iconPosition: "right"
            visible: root.editMode && root.state == "dashboard"
            onClicked: root.state = "sources"
        }

        Item { // horizontal spacer
            Layout.fillWidth: true
        }

        Button {
            text: root.editMode ? i18n.tr("Done") : i18n.tr("Edit")
            onClicked: {
                root.editMode = !root.editMode;
                root.state = "dashboard";
            }
        }
    }

    state: "dashboard"
    states: [
        State {
            name: "dashboard"
        },
        State {
            name: "sources"
        },
        State {
            name: "location"
        }
    ]
}