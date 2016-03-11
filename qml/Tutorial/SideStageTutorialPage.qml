/*
 * Copyright (C) 2016 Canonical, Ltd.
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
import Ubuntu.Components 1.3
import Ubuntu.Gestures 0.1
import "../Components"
import "../Stages"
import "." as LocalComponents

TutorialPage {
    id: root

    property var panel

    title: i18n.tr("Open/Close side stage")
    text: i18n.tr("3 finger tap the screen.")
    fullTextWidth: true

    SequentialAnimation {
        id: teaseAnimation
        paused: running && root.paused
        running: true
        loops: Animation.Infinite

        property real scale: 1

        UbuntuNumberAnimation {
            target: teaseAnimation
            property: "scale"
            to: 0.95
            duration: UbuntuAnimation.FastDuration
        }
        UbuntuNumberAnimation {
            target: teaseAnimation
            property: "scale"
            to: 1
            duration: UbuntuAnimation.SleepyDuration
        }
    }

    Behavior on textYOffset { UbuntuNumberAnimation {} }

    StateGroup {
        id: internalState
        states: [
            State {
                name: "initial"
                StateChangeScript {
                    script: {
                        root.hideError();
                        overlayGesture.hide();
                        overlayFinish.hide();
                        sideStage.hide();
                    }
                }
            },
            State {
                name: "overlayGesture"
                PropertyChanges {
                    target: root
                    title: i18n.tr("Load the sidestage")
                    text: i18n.tr("3 finger drag from one window to the other")
                }
                PropertyChanges { target: root; textYOffset: -units.gu(15); }
                PropertyChanges { target: tapIcon; visible: false; }
                StateChangeScript {
                    script: {
                        root.hideError();
                        overlayGesture.show();
                        sideStage.show();
                    }
                }
            },
            State {
                name: "overlayFinish"
                PropertyChanges {
                    target: root
                    title: i18n.tr("This is the loaded side stage")
                    text: i18n.tr("Tap here to continue.")
                }
                PropertyChanges { target: tapIcon; visible: false; }
                StateChangeScript {
                    script: {
                        root.hideError();
                        overlayFinish.show();
                    }
                }
                PropertyChanges { target: gestureArea; enabled: false }
            }
        ]
    }

    foreground {
        children: [
            Icon {
                id: tapIcon
                width: units.gu(20)
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.horizontalCenter
                source: "../Stages/graphics/sidestage_open.svg"
                scale: teaseAnimation.scale
            },
            SideStage {
                id: sideStage
                height: parent.height
                x: parent.width - width
                showHint: false
                enableDrag: false

                Icon {
                    name: "tick"
                    anchors.verticalCenter: parent.verticalCenter
                    x: Math.max(parent.width / 2 - width / 2, 0)
                    width: units.gu(8)
                    visible: overlayFinish.shown
                }

                DropArea {
                    anchors.fill: parent
                    onDropped: {
                        root.hideError();
                        internalState.state = "overlayFinish";
                    }
                }
            },
            Showable {
                id: overlayGesture
                objectName: "overlayGesture"
                anchors.fill: parent
                hides: [ overlayFinish ]

                opacity: 0
                shown: false
                showAnimation: SequentialAnimation {
                    PropertyAction { target: overlayGesture; property: "opacity"; value: 0 }
                    ParallelAnimation {
                        PropertyAction { target: overlayGesture; property: "visible"; value: true }
                        UbuntuNumberAnimation { target: overlayGesture; property: "opacity"; to: 1 }
                    }
                }
                Icon {
                    width: units.gu(40)
                    anchors.centerIn: parent
                    source: "../Stages/graphics/sidestage_drag.svg"
                    scale: teaseAnimation.scale
                }
            },
            Showable {
                id: overlayFinish
                objectName: "overlayFinish"
                anchors.fill: parent
                hides: [ overlayGesture ]

                opacity: 0
                shown: false
                showAnimation: SequentialAnimation {
                    PropertyAction { target: overlayFinish; property: "opacity"; value: 0 }
                    ParallelAnimation {
                        PropertyAction { target: overlayFinish; property: "visible"; value: true }
                        UbuntuNumberAnimation { target: overlayFinish; property: "opacity"; to: 1 }
                    }
                }

                LocalComponents.Tick {
                    objectName: "tickTap"
                    anchors {
                        left: parent.left
                        leftMargin: root.textLeft
                        top: parent.top
                        topMargin: root.textBottom + units.gu(3)
                    }
                    onClicked: root.hide()
                }
            },
            Label {
                anchors {
                    left: parent.left
                    leftMargin: root.textLeft
                    bottom: parent.bottom
                    bottomMargin: units.gu(3)
                }

                text: "Dismiss"
                font.underline: true
                fontSize: "medium"

                MouseArea {
                    anchors {
                        fill: parent
                        margins: -units.gu(1)
                    }
                    onClicked: root.finished();
                }
            }

        ]
    }

    TabletSideStageTouchGesture {
        id: gestureArea
        anchors {
            left: parent.left
            top: parent.top
            bottom: parent.bottom
        }
        width: parent.width - sideStage.width

        onClicked: {
            root.hideError();
            if (internalState.state !== "overlayGesture") {
                internalState.state = "overlayGesture";
            } else {
                internalState.state = "initial";
            }
        }

        dragComponent: overlayGesture.shown ? dragComponent : null
        Component {
            id: dragComponent
            Icon {
                width: units.gu(20)
                source: "../Stages/graphics/sidestage_open.svg"
            }
        }

        onDropped: {
            // still in the gesture state after dropping?
            if (!overlayFinish.shown) {
                root.showError();
            }
        }
        onCancelled: {
            root.showError();
        }
    }
}
