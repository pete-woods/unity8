/*
 * Copyright (C) 2015 Canonical, Ltd.
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

import QtQuick 2.0
import QtQuick.Window 2.0
import Unity.Screens 0.1
import Unity.Session 0.1
import GSettings 1.0
import "Components"
import "Components/UnityInputInfo"
import "Rotation"

Rectangle {
    id: root
    color: "black"

    implicitWidth: units.gu(40)
    implicitHeight: units.gu(71)

    // NB: native and primary orientations here don't map exactly to their QScreen counterparts
    readonly property int nativeOrientation: width > height ? Qt.LandscapeOrientation : Qt.PortraitOrientation

    readonly property int primaryOrientation:
            deviceConfiguration.primaryOrientation == deviceConfiguration.useNativeOrientation
                   ? nativeOrientation : deviceConfiguration.primaryOrientation

    Screens { id: screens }
    readonly property bool multiMonitor: screens.count > 1

    DeviceConfiguration {
        id: deviceConfiguration
        name: applicationArguments.deviceName
    }


    // to be overwritten by tests
    property var usageModeSettings: GSettings { schema.id: "com.canonical.Unity8" }
    property var oskSettings: GSettings { schema.id: "com.canonical.keyboard.maliit" }

    property int physicalOrientation: Screen.orientation
    property bool orientationLocked: OrientationLock.enabled
    property var orientationLock: OrientationLock

    property int orientation
    onPhysicalOrientationChanged: {
        if (!orientationLocked) {
            orientation = physicalOrientation;
        }
    }
    onOrientationLockedChanged: {
        if (orientationLocked) {
            orientationLock.savedOrientation = physicalOrientation;
        } else {
            orientation = physicalOrientation;
        }
    }
    Component.onCompleted: {
        if (orientationLocked) {
            orientation = orientationLock.savedOrientation;
        }
        // We need to manually update this on startup as the binding
        // below doesn't seem to have any effect at that stage
        oskSettings.stayHidden = UnityInputInfo.keyboards > 0
        oskSettings.disableHeight = shell.usageScenario == "desktop"
    }

    Binding {
        target: oskSettings
        property: "stayHidden"
        value: UnityInputInfo.keyboards > 0
    }

    Binding {
        target: oskSettings
        property: "disableHeight"
        value: shell.usageScenario == "desktop"
    }

    readonly property int supportedOrientations: shell.supportedOrientations
                                               & deviceConfiguration.supportedOrientations
    property int acceptedOrientationAngle: {
        if (multiMonitor) {
            return Screen.angleBetween(nativeOrientation, deviceConfiguration.multiMonitorOrientation);
        }

        if (orientation & supportedOrientations) {
            return Screen.angleBetween(nativeOrientation, orientation);
        } else if (shell.orientation & supportedOrientations) {
            // stay where we are
            return shell.orientationAngle;
        } else if (angleToOrientation(shell.mainAppWindowOrientationAngle) & supportedOrientations) {
            return shell.mainAppWindowOrientationAngle;
        } else {
            // rotate to some supported orientation as we can't stay where we currently are
            // TODO: Choose the closest to the current one
            if (supportedOrientations & Qt.PortraitOrientation) {
                return Screen.angleBetween(nativeOrientation, Qt.PortraitOrientation);
            } else if (supportedOrientations & Qt.LandcscapeOrientation) {
                return Screen.angleBetween(nativeOrientation, Qt.LandscapeOrientation);
            } else if (supportedOrientations & Qt.InvertedPortraitOrientation) {
                return Screen.angleBetween(nativeOrientation, Qt.InvertedPortraitOrientation);
            } else if (supportedOrientations & Qt.InvertedLandscapeOrientation) {
                return Screen.angleBetween(nativeOrientation, Qt.InvertedLandscapeOrientation);
            } else {
                // if all fails, fallback to primary orientation
                return Screen.angleBetween(nativeOrientation, primaryOrientation);
            }
        }
    }

    function angleToOrientation(angle) {
        switch (angle) {
        case 0:
            return nativeOrientation;
            break;
        case 90:
            return nativeOrientation === Qt.PortraitOrientation ? Qt.InvertedLandscapeOrientation
                                                                : Qt.PortraitOrientation;
            break;
        case 180:
            return nativeOrientation === Qt.PortraitOrientation ? Qt.InvertedPortraitOrientation
                                                                : Qt.InvertedLandscapeOrientation;
            break;
        case 270:
            return nativeOrientation === Qt.PortraitOrientation ? Qt.LandscapeOrientation
                                                                : Qt.InvertedPortraitOrientation;
            break;
        default:
            console.warn("angleToOrientation: Invalid orientation angle: " + angle);
            return primaryOrientation;
        }
    }

    RotationStates {
        id: rotationStates
        objectName: "rotationStates"
        orientedShell: root
        shell: shell
        shellCover: shellCover
        windowScreenshot: windowScreenshot
    }

    Shell {
        id: shell
        objectName: "shell"
        width: root.width
        height: root.height
        orientation: root.angleToOrientation(orientationAngle)
        primaryOrientation: root.primaryOrientation
        nativeOrientation: root.nativeOrientation
        nativeWidth: root.width
        nativeHeight: root.height
        mode: applicationArguments.mode

        // TODO: Factor in the connected input devices (eg: physical keyboard, mouse, touchscreen),
        //       what's the output device (eg: big TV, desktop monitor, phone display), etc.
        usageScenario: {
            if (root.usageModeSettings.usageMode === "Windowed" || multiMonitor) {
                return "desktop";
            } else if (root.usageModeSettings.usageMode === "Staged") {
                if (deviceConfiguration.category === "phone") {
                    return "phone";
                } else {
                    return "tablet";
                }
            } else { // automatic
                if (UnityInputInfo.mice > deviceConfiguration.ignoredMice) {
                    return "desktop";
                } else {
                    return deviceConfiguration.category;
                }
            }
        }

        property real transformRotationAngle
        property real transformOriginX
        property real transformOriginY

        transform: Rotation {
            origin.x: shell.transformOriginX; origin.y: shell.transformOriginY; axis { x: 0; y: 0; z: 1 }
            angle: shell.transformRotationAngle
        }
    }

    Rectangle {
        id: shellCover
        color: "black"
        anchors.fill: parent
        visible: false
    }

    WindowScreenshot {
        id: windowScreenshot
        visible: false
        width: root.width
        height: root.height

        property real transformRotationAngle
        property real transformOriginX
        property real transformOriginY

        transform: Rotation {
            origin.x: windowScreenshot.transformOriginX; origin.y: windowScreenshot.transformOriginY;
            axis { x: 0; y: 0; z: 1 }
            angle: windowScreenshot.transformRotationAngle
        }
    }
}
