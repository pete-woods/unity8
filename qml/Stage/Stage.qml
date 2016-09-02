/*
 * Copyright (C) 2014-2016 Canonical, Ltd.
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
import Unity.Application 0.1
import "../Components"
import Utils 0.1
import Ubuntu.Gestures 0.1
import GlobalShortcut 1.0
import "Spread"

AbstractStage {
    id: root
    anchors.fill: parent
    paintBackground: false

    // functions to be called from outside
    function updateFocusedAppOrientation() { /* TODO */ }
    function updateFocusedAppOrientationAnimated() { /* TODO */}
    function pushRightEdge(amount) {
        if (spread.state === "") {
            edgeBarrier.push(amount);
        }
    }
    function closeFocusedDelegate() {
        if (priv.focusedAppDelegate && !priv.focusedAppDelegate.isDash) {
            priv.focusedAppDelegate.close();
        }
    }

    property string mode: "staged"

    // Used by TutorialRight
    property bool spreadShown: state == "altTab"

    mainApp: priv.focusedAppDelegate ? priv.focusedAppDelegate.application : null

    // application windows never rotate independently
    mainAppWindowOrientationAngle: shellOrientationAngle

    orientationChangesEnabled: true

    onAltTabPressedChanged: priv.goneToSpread = altTabPressed

    GlobalShortcut {
        id: showSpreadShortcut
        shortcut: Qt.MetaModifier|Qt.Key_W
        onTriggered: state = "altTab"
    }

    GlobalShortcut {
        id: minimizeAllShortcut
        shortcut: Qt.MetaModifier|Qt.ControlModifier|Qt.Key_D
        onTriggered: priv.minimizeAllWindows()
    }

    GlobalShortcut {
        id: maximizeWindowShortcut
        shortcut: Qt.MetaModifier|Qt.ControlModifier|Qt.Key_Up
        onTriggered: priv.focusedAppDelegate.maximize()
        active: priv.focusedAppDelegate !== null
    }

    GlobalShortcut {
        id: maximizeWindowLeftShortcut
        shortcut: Qt.MetaModifier|Qt.ControlModifier|Qt.Key_Left
        onTriggered: priv.focusedAppDelegate.maximizeLeft()
        active: priv.focusedAppDelegate !== null
    }

    GlobalShortcut {
        id: maximizeWindowRightShortcut
        shortcut: Qt.MetaModifier|Qt.ControlModifier|Qt.Key_Right
        onTriggered: priv.focusedAppDelegate.maximizeRight()
        active: priv.focusedAppDelegate !== null
    }

    GlobalShortcut {
        id: minimizeRestoreShortcut
        shortcut: Qt.MetaModifier|Qt.ControlModifier|Qt.Key_Down
        onTriggered: priv.focusedAppDelegate.maximized || priv.focusedAppDelegate.maximizedLeft || priv.focusedAppDelegate.maximizedRight ||
                     priv.focusedAppDelegate.maximizedHorizontally || priv.focusedAppDelegate.maximizedVertically
                     ? priv.focusedAppDelegate.restoreFromMaximized() : priv.focusedAppDelegate.minimize()
        active: priv.focusedAppDelegate !== null
    }

    GlobalShortcut {
        shortcut: Qt.AltModifier|Qt.Key_Print
        onTriggered: root.itemSnapshotRequested(priv.focusedAppDelegate)
        active: priv.focusedAppDelegate !== null
    }

    QtObject {
        id: priv
        objectName: "DesktopStagePrivate"

        property var focusedAppDelegate: null
        onFocusedAppDelegateChanged: {
            if (focusedAppDelegate && root.state == "spread") {
                goneToSpread = false;
            }
        }

        property var foregroundMaximizedAppDelegate: null // for stuff like drop shadow and focusing maximized app by clicking panel

        property bool goneToSpread: false
        property int closingIndex: -1
//        property int animationDuration: 4000
        property int animationDuration: UbuntuAnimation.FastDuration

        function updateForegroundMaximizedApp() {
            var found = false;
            for (var i = 0; i < appRepeater.count && !found; i++) {
                var item = appRepeater.itemAt(i);
                if (item && item.visuallyMaximized) {
                    foregroundMaximizedAppDelegate = item;
                    found = true;
                }
            }
            if (!found) {
                foregroundMaximizedAppDelegate = null;
            }
        }

        function minimizeAllWindows() {
            for (var i = 0; i < appRepeater.count; i++) {
                var appDelegate = appRepeater.itemAt(i);
                if (appDelegate && !appDelegate.minimized) {
                    appDelegate.minimize();
                }
            }
        }

        function focusNext() {
            for (var i = 0; i < appRepeater.count; i++) {
                var appDelegate = appRepeater.itemAt(i);
                if (appDelegate && !appDelegate.minimized) {
                    print("***** focusing because of focusNext() call", appDelegate.application.appId)
                    appDelegate.focus = true;
                    return;
                }
            }
        }

        property var mainStageDelegate: null
        property var sideStageDelegate: null
        property int mainStageItemId: 0
        property int sideStageItemId: 0
        property string mainStageAppId: ""
        property string sideStageAppId: ""

        onSideStageDelegateChanged: {
            if (!sideStageDelegate) {
                sideStage.hide();
            }
        }

        function updateMainAndSideStageIndexes() {
//            print("updating stage indexes, sideStage shown:", sideStage.shown)
            var choseMainStage = false;
            var choseSideStage = false;

            if (!root.topLevelSurfaceList)
                return;

            for (var i = 0; i < appRepeater.count && (!choseMainStage || !choseSideStage); ++i) {
                var appDelegate = appRepeater.itemAt(i);
                if (/*sideStage.shown && */appDelegate.stage == ApplicationInfoInterface.SideStage
                        && !choseSideStage) {
                    priv.sideStageDelegate = appDelegate
                    priv.sideStageItemId = root.topLevelSurfaceList.idAt(i);
                    priv.sideStageAppId = root.topLevelSurfaceList.applicationAt(i).appId;
                    choseSideStage = true;
                } else if (!choseMainStage && appDelegate.stage == ApplicationInfoInterface.MainStage) {
                    priv.mainStageDelegate = appDelegate;
                    priv.mainStageItemId = root.topLevelSurfaceList.idAt(i);
                    priv.mainStageAppId = root.topLevelSurfaceList.applicationAt(i).appId;
                    choseMainStage = true;
                }
            }
            if (!choseMainStage) {
                priv.mainStageDelegate = null;
                priv.mainStageItemId = 0;
                priv.mainStageAppId = "";
            }
            if (!choseSideStage) {
                priv.sideStageDelegate = null;
                priv.sideStageItemId = 0;
                priv.sideStageAppId = "";
            }

            print("*** updated! MainStage:", priv.mainStageAppId, "SideStage:", priv.sideStageAppId)
        }

        property int nextInStack: 1

        readonly property real virtualKeyboardHeight: SurfaceManager.inputMethodSurface
                                                          ? SurfaceManager.inputMethodSurface.inputBounds.height
                                                          : 0
    }

    Connections {
        target: panelState
        onCloseClicked: { if (priv.focusedAppDelegate) { priv.focusedAppDelegate.close(); } }
        onMinimizeClicked: { if (priv.focusedAppDelegate) { priv.focusedAppDelegate.minimize(); } }
        onRestoreClicked: { if (priv.focusedAppDelegate) { priv.focusedAppDelegate.unmaximize(); } }
        onFocusMaximizedApp: {
            if (priv.foregroundMaximizedAppDelegate) {
                print("***** focusing because of Panel request", model.application.appId)
                priv.foregroundMaximizedAppDelegate.focus = true;
             }
        }
    }

    Binding {
        target: panelState
        property: "buttonsVisible"
        value: priv.focusedAppDelegate !== null && priv.focusedAppDelegate.maximized // FIXME for Locally integrated menus
    }

    Binding {
        target: panelState
        property: "title"
        value: {
            if (priv.focusedAppDelegate !== null) {
                if (priv.focusedAppDelegate.maximized)
                    return priv.focusedAppDelegate.title
                else
                    return priv.focusedAppDelegate.appName
            }
            return ""
        }
        when: priv.focusedAppDelegate
    }

    Binding {
        target: panelState
        property: "dropShadow"
        value: priv.focusedAppDelegate && !priv.focusedAppDelegate.maximized && priv.foregroundMaximizedAppDelegate !== null && mode == "windowed"
    }

    Binding {
        target: panelState
        property: "closeButtonShown"
        value: priv.focusedAppDelegate && priv.focusedAppDelegate.maximized && !priv.focusedAppDelegate.isDash
    }

    Component.onDestruction: {
        panelState.title = "";
        panelState.buttonsVisible = false;
        panelState.dropShadow = false;
    }

    Instantiator {
        model: root.applicationManager
        delegate: Binding {
            target: model.application
            property: "requestedState"

            // TODO: figure out some lifecycle policy, like suspending minimized apps
            //       if running on a tablet or something.
            // TODO: If the device has a dozen suspended apps because it was running
            //       in staged mode, when it switches to Windowed mode it will suddenly
            //       resume all those apps at once. We might want to avoid that.
            value: ApplicationInfoInterface.RequestedRunning // Always running for now
        }
    }

    Binding {
        target: MirFocusController
        property: "focusedSurface"
        value: priv.focusedAppDelegate ? priv.focusedAppDelegate.focusedSurface : null
        when: !appRepeater.startingUp && root.parent
    }

    states: [
        State {
            name: "spread"; when: priv.goneToSpread
            PropertyChanges { target: floatingFlickable; enabled: true }
            PropertyChanges { target: spreadItem; focus: true }
        },
        State {
            name: "stagedrightedge"; when: rightEdgeDragArea.dragging && root.mode == "staged"
        },
        State {
            name: "sidestagedrightedge"; when: rightEdgeDragArea.dragging && root.mode == "stagedWithSideStage"
            PropertyChanges { target: priv; nextInStack: priv.sideStageDelegate && priv.sideStageDelegate.itemIndex < 2 ? 2 : 1 }
        },
        State {
            name: "windowedrightedge"; when: rightEdgeDragArea.dragging && root.mode == "windowed"
        },
        State {
            name: "staged"; when: root.mode === "staged"
        },
        State {
            name: "stagedWithSideStage"; when: root.mode === "stagedWithSideStage"
            PropertyChanges { target: triGestureArea; enabled: true }
            PropertyChanges { target: priv; nextInStack: priv.sideStageDelegate && priv.sideStageDelegate.itemIndex < 2 ? 2 : 1 }
            PropertyChanges { target: sideStage; visible: true }
        },
        State {
            name: "windowed"; when: root.mode === "windowed"
        }
    ]

    transitions: [
        Transition {
            from: "stagedrightedge"; to: "spread"
            PropertyAction { target: spreadItem; property: "highlightedIndex"; value: -1 }
        },
        Transition {
            to: "spread"
            PropertyAction { target: spreadItem; property: "highlightedIndex"; value: 1 }
            PropertyAction { target: floatingFlickable; property: "contentX"; value: 0 }
        },
        Transition {
            from: "spread"
            SequentialAnimation {
                ScriptAction {
                    script: {
                        var item = appRepeater.itemAt(Math.max(0, spreadItem.highlightedIndex));
                        item.claimFocus();
                        item.playFocusAnimation();
                    }
                }
                PropertyAction { target: spreadItem; property: "highlightedIndex"; value: -1 }
            }
        },
        Transition {
            to: "stagedrightedge"
            PropertyAction { target: floatingFlickable; property: "contentX"; value: 0 }
        }

    ]

    FocusScope {
        id: appContainer
        objectName: "appContainer"
        anchors.fill: parent
        focus: root.state !== "altTab"

        CrossFadeImage {
            id: wallpaper
            anchors.fill: parent
            source: root.background
            sourceSize { height: root.height; width: root.width }
            fillMode: Image.PreserveAspectCrop
        }

        Spread {
            id: spreadItem
            anchors.fill: appContainer
            leftMargin: root.leftMargin
            model: root.topLevelSurfaceList
            z: 10

            onLeaveSpread: {
                priv.goneToSpread = false;
            }
        }

        Connections {
            target: root.topLevelSurfaceList
            onListChanged: priv.updateMainAndSideStageIndexes()
        }


        DropArea {
            objectName: "MainStageDropArea"
            anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
            }
            width: appContainer.width - sideStage.width
            enabled: sideStage.enabled

            onDropped: {
                print("dropped on main stage drop area")
                drop.source.appDelegate.saveStage(ApplicationInfoInterface.MainStage);
                drop.source.appDelegate.focus = true;
            }
            keys: "SideStage"
        }

        SideStage {
            id: sideStage
            shown: false
            height: appContainer.height
            x: appContainer.width - width
            visible: false
            z: {
                if (!priv.mainStageItemId) return 0;

                if (priv.sideStageItemId && priv.nextInStack > 0) {
                    var nextDelegateInStack = appRepeater.itemAt(priv.nextInStack);

                    if (nextDelegateInStack.stage ===  ApplicationInfoInterface.MainStage) {
                        // if the next app in stack is a main stage app, put the sidestage on top of it.
                        return 2;
                    }
                    return 1;
                }

                return 2;
            }


            onShownChanged: {
                print("sidestage shown changed:", shown)
                if (!shown && priv.mainStageDelegate) {
                    priv.mainStageDelegate.claimFocus();
                }
            }

//            onShownChanged: {
//                if (!shown && priv.sideStageDelegate && priv.focusedAppDelegate === priv.sideStageDelegate) {
//                    priv.updateMainAndSideStageIndexes();
//                    if (priv.mainStageDelegate) {
//                        priv.mainStageDelegate.focus = true;
//                    }
//                } else if (shown) {
//                    priv.updateMainAndSideStageIndexes();
//                    if (priv.sideStageDelegate) {
//                        priv.sideStageDelegate.focus = true;
//                    }
//                }
//            }

            DropArea {
                id: sideStageDropArea
                objectName: "SideStageDropArea"
                anchors.fill: parent

                property bool dropAllowed: true

                onEntered: {
                    dropAllowed = drag.keys != "Disabled";
                }
                onExited: {
                    dropAllowed = true;
                }
                onDropped: {
                    if (drop.keys == "MainStage") {
                        drop.source.appDelegate.saveStage(ApplicationInfoInterface.SideStage);
                        drop.source.appDelegate.focus = true;
                    }
                }
                drag {
                    onSourceChanged: {
                        if (!sideStageDropArea.drag.source) {
                            dropAllowed = true;
                        }
                    }
                }
            }
        }

        TopLevelSurfaceRepeater {
            id: appRepeater
            model: topLevelSurfaceList
            objectName: "appRepeater"

            delegate: FocusScope {
                id: appDelegate
                objectName: "appDelegate_" + model.id
                property int itemIndex: index // We need this from outside the repeater
                // z might be overriden in some cases by effects, but we need z ordering
                // to calculate occlusion detection
                property int normalZ: topLevelSurfaceList.count - index
                onNormalZChanged: {
                    if (visuallyMaximized) {
                        priv.updateForegroundMaximizedApp();
                    }
                }
                z: normalZ
                x: windowState.relativePosition.mappedX
                y: windowState.relativePosition.mappedY

                width: decoratedWindow.implicitWidth
                height: decoratedWindow.implicitHeight
                opacity: windowState.valid ? windowState.opacity2 : 1
                scale: windowState.valid ? windowState.scale : 1

                visible: {
                    if (visuallyMinimized) return false;
//                    console.log("windowState", windowState.spread)
                    if (state !== "spread" && windowState.spread) return false;
                    return true;
                }

                //                visible: (
                //                          !visuallyMinimized
                //                          && !greeter.fullyShown
                //                          && (priv.foregroundMaximizedAppDelegate === null || priv.foregroundMaximizedAppDelegate.normalZ <= z)
                //                         )
                //                         || decoratedWindow.fullscreen
                //                       //  || (root.state == "altTab" && index === spread.highlightedIndex)

                WindowedState {
                    id: windowState

                    target: appDelegate
                    windowId: model.application.appId

                    defaultX: priv.focusedAppDelegate ? priv.focusedAppDelegate.x + units.gu(3) : (normalZ - 1) * panelState.panelHeight + root.leftMargin;
                    defaultY: priv.focusedAppDelegate ? priv.focusedAppDelegate.y + units.gu(3) : normalZ * panelState.panelHeight;

                    relativePosition {
                        x: windowState.geometry.x
                        y: windowState.geometry.y
                    }
                }

                readonly property rect localWindowedGeometry: {
                    var pt = windowState.relativePosition.map(Qt.point(windowState.windowedGeometry.x,
                                                                       windowState.windowedGeometry.y));
                    return Qt.rect(pt.x,
                                   pt.y,
                                   windowState.windowedGeometry.width,
                                   windowState.windowedGeometry.height);
                }

                function setWindowedX(x) {
                    var point = windowState.absolutePosition.map(Qt.point(x, 0));
                    windowState.windowedGeometry.x = point.x;
                }
                function setWindowedY(y) {
                    var point = windowState.absolutePosition.map(Qt.point(0, y));
                    windowState.windowedGeometry.y = point.y;
                }
                function setWindowedWidth(width) {
                    windowState.windowedGeometry.width = width;
                }
                function setWindowedHeight(height) {
                    windowState.windowedGeometry.height = height;
                }

                function moveWindow(x, y) {
                    windowState.windowedGeometry.x += x;
                    windowState.windowedGeometry.y += y;
                }


//                // requestedX/Y/width/height is what we ask the actual surface to be.
//                // Do not write to those, they will be set by states
//                // Also do not write to the appWindow's actual x,y,width,height as they
//                // will be set by states too.
//                property real requestedX: 0
//                property real requestedY: 0
//                property int requestedWidth: -1
//                property int requestedHeight: -1

//                // In those are for windowed mode. Those values basically store the window's properties
//                // when having a floating window. If you want to move/resize a window in normal mode, this is what you want to write to.
//                property int windowedX: priv.focusedAppDelegate ? priv.focusedAppDelegate.x + units.gu(3) : (normalZ - 1) * units.gu(3)
//                property int windowedY: priv.focusedAppDelegate ? priv.focusedAppDelegate.y + units.gu(3) : normalZ * units.gu(3)
//                property int windowedWidth
//                property int windowedHeight

                Binding {
                    target: appDelegate
                    property: "y"
                    value: windowState.relativePosition.mappedY -
                           Math.min(windowState.relativePosition.mappedY - panelState.panelHeight,
                                    Math.max(0, priv.virtualKeyboardHeight - (appContainer.height - (windowState.relativePosition.mappedY + appDelegate.height))))
                    when: root.oskEnabled && appDelegate.focus && appDelegate.state == "normal"
                          && SurfaceManager.inputMethodSurface
                          && SurfaceManager.inputMethodSurface.state != Mir.HiddenState
                          && SurfaceManager.inputMethodSurface.state != Mir.MinimizedState
                }

                Behavior on x { id: xBehavior; enabled: priv.closingIndex >= 0; UbuntuNumberAnimation { onRunningChanged: if (!running) priv.closingIndex = -1} }

//                Connections {
//                    target: root
//                    onShellOrientationAngleChanged: {
//                        // at this point decoratedWindow.surfaceOrientationAngle is the old shellOrientationAngle
//                        if (application && application.rotatesWindowContents) {
//                            if (appDelegate.state == "normal") {
//                                var angleDiff = decoratedWindow.surfaceOrientationAngle - shellOrientationAngle;
//                                angleDiff = (360 + angleDiff) % 360;
//                                if (angleDiff === 90 || angleDiff === 270) {
//                                    var aux = decoratedWindow.requestedHeight;
//                                    decoratedWindow.requestedHeight = decoratedWindow.requestedWidth + decoratedWindow.visibleDecorationHeight;
//                                    decoratedWindow.requestedWidth = aux - decoratedWindow.visibleDecorationHeight;
//                                }
//                            }
//                            decoratedWindow.surfaceOrientationAngle = shellOrientationAngle;
//                        } else {
//                            decoratedWindow.surfaceOrientationAngle = 0;
//                        }
//                    }
//                }

                readonly property alias application: decoratedWindow.application
                readonly property alias minimumWidth: decoratedWindow.minimumWidth
                readonly property alias minimumHeight: decoratedWindow.minimumHeight
                readonly property alias maximumWidth: decoratedWindow.maximumWidth
                readonly property alias maximumHeight: decoratedWindow.maximumHeight
                readonly property alias widthIncrement: decoratedWindow.widthIncrement
                readonly property alias heightIncrement: decoratedWindow.heightIncrement

                readonly property bool maximized: windowState.state & WindowState.Maximized
                readonly property bool maximizedLeft: windowState.state & WindowState.MaximizedLeft
                readonly property bool maximizedRight: windowState.state & WindowState.MaximizedRight
                readonly property bool maximizedHorizontally: windowState.state & WindowState.MaximizedHorizontally
                readonly property bool maximizedVertically: windowState.state & WindowState.MaximizedVertically
                readonly property bool minimized: windowState.state & WindowState.Minimized
                readonly property bool fullscreen: surface && surface.state === Mir.FullscreenState;

                property bool animationsEnabled: true
                property alias title: decoratedWindow.title
                readonly property string appName: model.application ? model.application.name : ""
                property bool visuallyMaximized: false
                property bool visuallyMinimized: false

                property int stage: ApplicationInfoInterface.MainStage
                function saveStage(newStage) {
                    appDelegate.stage = newStage;
                    WindowStateStorage.saveStage(application.appId, newStage);
                    priv.updateMainAndSideStageIndexes()
                }

                readonly property var surface: model.surface
                readonly property alias resizeArea: resizeArea
                readonly property alias focusedSurface: decoratedWindow.focusedSurface

                readonly property bool isDash: model.application.appId == "unity8-dash"

                function claimFocus() {
                    print("focusing app", priv.sideStageDelegate, appDelegate, sideStage.shown)
                    if (root.mode == "windowed" && minimized) {
                        restore(true)
                    }
                    if (appDelegate.stage == ApplicationInfoInterface.SideStage && !sideStage.shown) {
                        sideStage.show();
                    }
                    appDelegate.focus = true;
                }
                Connections {
                    target: model.surface
                    onFocusRequested: {
                        print("model surface requesting focus", model.application.appId)
                        claimFocus();
                    }
                }
                Connections {
                    target: model.application
                    onFocusRequested: {
                        if (!model.surface) {
                            // when an app has no surfaces, we assume there's only one entry representing it:
                            // this delegate.
                            claimFocus();
                        } else {
                            // if the application has surfaces, focus request should be at surface-level.
                        }
                    }
                }

//                Timer {
//                    interval: 1000
//                    repeat: true
//                    running: index == 0
//                    onTriggered: print("index", index, "focused:", appDelegate.focus, "x", appDelegate.x, "state", appDelegate.state)
//                }

                onFocusChanged: {
                    if (appRepeater.startingUp)
                        return;

                    if (focus) {
                        // break the defaultX/Y binding before we set this app as focused.
                        windowState.defaultX = windowState.defaultX;
                        windowState.defaultY = windowState.defaultY;

                        print("app surface gained focus:", model.application.appId)
                        print("setting focusedAppDelegate to", appDelegate.application.appId)
                        print("raising surface in model", model.id)
                        topLevelSurfaceList.raiseId(model.id);
                        priv.focusedAppDelegate = appDelegate;
                        topLevelSurfaceList.raiseId(model.id);
                    } else if (!focus && priv.focusedAppDelegate === appDelegate) {
                        priv.focusedAppDelegate = null;
                        // FIXME: No idea why the Binding{} doens't update when focusedAppDelegate turns null
                        MirFocusController.focusedSurface = null;
                    }
                }
                Component.onCompleted: {
                    startingUp = false;
                    if (application && application.rotatesWindowContents) {
                        decoratedWindow.surfaceOrientationAngle = shellOrientationAngle;
                    } else {
                        decoratedWindow.surfaceOrientationAngle = 0;
                    }

                    // NB: We're differentiating if this delegate was created in response to a new entry in the model
                    //     or if the Repeater is just populating itself with delegates to match the model it received.
                    if (!appRepeater.startingUp) {
                        // a top level window is always the focused one when it first appears, unfocusing
                        // any preexisting one
                        print("***** focusing after starting up", model.application.appId)
                        focus = true;
                    }
                }
                Component.onDestruction: {
                    if (!root.parent) {
                        // This stage is about to be destroyed. Don't mess up with the model at this point
                        return;
                    }

                    if (visuallyMaximized) {
                        priv.updateForegroundMaximizedApp();
                    }

                    if (focus) {
                        // focus some other window
                        for (var i = 0; i < appRepeater.count; i++) {
                            var appDelegate = appRepeater.itemAt(i);
                            if (appDelegate && !appDelegate.minimized && i != index) {
                                print("***** focusing because of previously focused window disappeared", appDelegate.application.appId)
                                appDelegate.focus = true;
                                return;
                            }
                        }
                    }
                }

                onVisuallyMaximizedChanged: priv.updateForegroundMaximizedApp()

                onStageChanged: {
                    if (!_constructing) {
                        priv.updateMainAndSideStageIndexes();
                    }
                }

                function close() {
                    model.surface.close();
                }

                function maximize(animated) {
                    if (windowState.state == WindowState.Normal) {
                        windowState.saveWindowedState();
                    }
                    windowState.state = WindowState.Maximized;
                }

                function maximizeLeft(animated) {
                    if (windowState.state == WindowState.Normal) {
                        windowState.saveWindowedState();
                    }
                    animationsEnabled = (animated === undefined) || animated;
                    windowState.state = WindowState.MaximizedLeft;
                }

                function maximizeRight(animated) {
                    if (windowState.state == WindowState.Normal) {
                        windowState.saveWindowedState();
                    }
                    animationsEnabled = (animated === undefined) || animated;
                    windowState.state = WindowState.MaximizedRight;
                }

                function maximizeHorizontally(animated) {
                    if (windowState.state == WindowState.Normal) {
                        windowState.saveWindowedState();
                    }
                    animationsEnabled = (animated === undefined) || animated;
                    windowState.state = WindowState.MaximizedHorizontally;
                }

                function maximizeVertically(animated) {
                    if (windowState.state == WindowState.Normal) {
                        windowState.saveWindowedState();
                    }
                    animationsEnabled = (animated === undefined) || animated;
                    windowState.state = WindowState.MaximizedVertically;
                }

                function minimize(animated) {
                    if (windowState.state == WindowState.Normal) {
                        windowState.saveWindowedState();
                    }
                    windowState.state |= WindowState.Minimized;
                }

                function unmaximize(animated) {
                    windowState.state = WindowState.Normal;
                }

                function restore(animated) {
                    windowState.state &= ~WindowState.Minimized;
                    focus = true;
                }

                function playFocusAnimation() {
                    print("playing focus animation", state, root.mode, "app", model.application.appId)
                    if (state == "stagedrightedge") {
                        // TODO: Can we drop this if and find something that always works?
                        if (root.mode == "staged") {
                            rightEdgeFocusAnimation.targetX = 0
                            print("doing it to 0")
                            rightEdgeFocusAnimation.start()
                        } else if (root.mode == "stagedWithSideStage") {
                            rightEdgeFocusAnimation.targetX = appDelegate.stage == ApplicationInfoInterface.SideStage ? sideStage.x : 0
                            rightEdgeFocusAnimation.start()
                        }
                    } else {
                        focusAnimation.start()
                    }
                }
                function playHidingAnimation() {
                    hidingAnimation.start()
                }

                UbuntuNumberAnimation {
                    id: focusAnimation
                    target: appDelegate
                    property: "scale"
                    from: 0.98
                    to: 1
                    duration: UbuntuAnimation.SnapDuration
                }
                ParallelAnimation {
                    id: rightEdgeFocusAnimation
                    property int targetX: 0
                    UbuntuNumberAnimation { target: appDelegate; properties: "x"; to: rightEdgeFocusAnimation.targetX; duration: priv.animationDuration }
                    UbuntuNumberAnimation { target: decoratedWindow; properties: "angle"; to: 0; duration: priv.animationDuration }
                    UbuntuNumberAnimation { target: decoratedWindow; properties: "itemScale"; to: 1; duration: priv.animationDuration }
                    onStopped: appDelegate.focus = true
                }
                ParallelAnimation {
                    id: hidingAnimation
                    UbuntuNumberAnimation { target: windowState; property: "opacity2"; to: 0; duration: priv.animationDuration }
                    onStopped: windowState.opacity2 = 1
                }

                SpreadMaths {
                    id: spreadMaths
                    spread: spreadItem
                    itemIndex: index
                    flickable: floatingFlickable
                }
                StageMaths {
                    id: stageMaths
                    sceneWidth: root.width
                    stage: appDelegate.stage
                    thisDelegate: appDelegate
                    mainStageDelegate: priv.mainStageDelegate
                    sideStageDelegate: priv.sideStageDelegate
                    sideStageWidth: sideStage.panelWidth
                    sideStageX: sideStage.x
                }

                StagedRightEdgeMaths {
                    id: stagedRightEdgeMaths
                    sceneWidth: appContainer.width - root.leftMargin
                    sceneHeight: appContainer.height
                    isMainStageApp: priv.mainStageDelegate == appDelegate
                    isSideStageApp: priv.sideStageDelegate == appDelegate
                    sideStageWidth: sideStage.width
                    itemIndex: index
                    nextInStack: priv.nextInStack
                    progress: 0
                    targetHeight: spreadItem.stackHeight
                    targetX: spreadMaths.targetX
                    startY: appDelegate.fullscreen ? 0 : panelState.panelHeight
                    targetY: spreadMaths.targetY
                    targetAngle: spreadMaths.targetAngle
                    targetScale: spreadMaths.targetScale
                }

                state: {
                    if (!windowState.valid) return "offscreen";

                    if (root.state == "spread") return "spread";
                    if (root.state == "sidestagedrightedge" || root.state == "stagedrightedge" || rightEdgeFocusAnimation.running || hidingAnimation.running) return "stagedrightedge";
                    if (root.state == "staged") return "staged";
                    if (root.state == "stagedWithSideStage") return "stagedWithSideStage";
                    if (windowState.state === WindowState.Normal) return "normal";
                    if (windowState.stateSource) {
                        if (windowState.state === WindowState.Maximized) return "maximized";
                        if (windowState.state & WindowState.Minimized) return "minimized";
                    }
                    return "offscreen";
                }
                states: [
                    State {
                        name: "spread";
                        PropertyChanges {
                            target: decoratedWindow;
                            showDecoration: false;
                            angle: spreadMaths.targetAngle
                            itemScale: spreadMaths.targetScale
                            scaleToPreviewSize: spreadItem.stackHeight
                            scaleToPreviewProgress: 1
                            shadowOpacity: spreadMaths.shadowOpacity
                            showHighlight: spreadItem.highlightedIndex === index
                            anchors.topMargin: dragArea.distance
                        }
                        PropertyChanges {
                            target: appDelegate
                            z: index
                            visible: spreadMaths.itemVisible
                        }
                        PropertyChanges {
                            target: windowState.absolutePosition
                            x: spreadMaths.targetX
                            y: spreadMaths.targetY
                        }
                        PropertyChanges {
                            target: windowState.geometry
                            x: windowState.absolutePosition.mappedX
                            y: windowState.absolutePosition.mappedY
                            height: spreadItem.spreadItemHeight
                        }
                        PropertyChanges { target: windowState; spread: true }
                        PropertyChanges { target: dragArea; enabled: true }
                        PropertyChanges { target: windowInfoItem; opacity: spreadMaths.tileInfoOpacity; visible: spreadMaths.itemVisible }
                    },
                    State {
                        name: "stagedrightedge"
                        PropertyChanges {
                            target: stagedRightEdgeMaths
                            progress: rightEdgeDragArea.progress
                        }
                        PropertyChanges {
                            target: appDelegate
                            z: index +1
                            height: stagedRightEdgeMaths.animatedHeight
                        }
                        PropertyChanges {
                            target: windowState.absolutePosition
                            x: stagedRightEdgeMaths.animatedX
                            y: stagedRightEdgeMaths.animatedY
                        }
                        PropertyChanges {
                            target: decoratedWindow
                            hasDecoration: false
                            angle: stagedRightEdgeMaths.animatedAngle
                            itemScale: stagedRightEdgeMaths.animatedScale
                            scaleToPreviewSize: spreadItem.stackHeight
                            scaleToPreviewProgress: stagedRightEdgeMaths.scaleToPreviewProgress
                            shadowOpacity: .3
                        }
                        PropertyChanges {
                            target: windowState.geometry
                            x: windowState.absolutePosition.mappedX
                            y: windowState.absolutePosition.mappedY
                            width: appDelegate.windowedWidth
                            height: appDelegate.windowedHeight
                            restoreEntryValues: false // leave the geometry alone unless we change it in another state.
                        }
                    },
                    State {
                        name: "staged"
                        PropertyChanges {
                            target: windowState.absolutePosition
                            x: appDelegate.focus ? 0 : root.width
                            y: appDelegate.fullscreen ? 0 : panelState.panelHeight
                            restoreEntryValues: false
                        }
                        PropertyChanges {
                            target: windowState.geometry
                            x: windowState.absolutePosition.mappedX
                            y: windowState.absolutePosition.mappedY
                            width: appContainer.width
                            height: appDelegate.fullscreen ? appContainer.height : appContainer.height - panelState.panelHeight
                            restoreEntryValues: false
                        }
                        PropertyChanges {
                            target: appDelegate
                            visuallyMaximized: true
                        }
                    },
                    State {
                        name: "stagedWithSideStage"
                        PropertyChanges {
                            target: stageMaths
                            itemIndex: index
                        }
                        PropertyChanges {
                            target: windowState.absolutePosition
                            x: stageMaths.itemX
                            y: appDelegate.fullscreen ? 0 : panelState.panelHeight
                            restoreEntryValues: false
                        }
                        PropertyChanges {
                            target: windowState.geometry
                            x: windowState.absolutePosition.mappedX
                            y: windowState.absolutePosition.mappedY
                            width: stageMaths.itemWidth
                            height: appDelegate.fullscreen ? appContainer.height : appContainer.height - panelState.panelHeight
                            restoreEntryValues: false
                        }
                        PropertyChanges {
                            target: appDelegate
                            z: stageMaths.itemZ
                            visuallyMaximized: true
                        }
                    },
                    State {
                        name: "normal"
                        PropertyChanges {
                            target: windowState.geometry
                            x: windowState.windowedGeometry.x
                            y: windowState.windowedGeometry.y
                            width: windowState.windowedGeometry.width
                            height: windowState.windowedGeometry.height
                            restoreEntryValues: false
                        }
                        PropertyChanges {
                            target: resizeArea
                            enabled: true
                        }
                    },
                    State {
                        name: "maximized"
                        PropertyChanges {
                            target: appDelegate
                            visuallyMaximized: true
                        }
                        PropertyChanges {
                            target: windowState.absolutePosition
                            x: root.leftMargin
                            y: 0
                        }
                        PropertyChanges {
                            target: windowState.geometry
                            x: windowState.absolutePosition.mappedX
                            y: windowState.absolutePosition.mappedY
                            width: appContainer.width - root.leftMargin
                            height: appContainer.height
                        }
                    },
                    State {
                        name: "minimized"
                        PropertyChanges {
                            target: appDelegate
                            visuallyMinimized: true
                        }
                        PropertyChanges {
                            target: windowState
                            scale: units.gu(5) / appDelegate.width;
                            opacity2: 0
                        }
                        PropertyChanges {
                            target: windowState.absolutePosition
                            x: -appDelegate.width / 2 + root.leftMargin
                        }
                        PropertyChanges {
                            target: windowState.geometry
                            x: windowState.absolutePosition.mappedX
                            y: windowState.absolutePosition.mappedY
                        }
                    },
                    State {
                        name: "offscreen"
                    }
                ]
                onStateChanged: console.log("APP STATE", model.application.appId, state, "on ", screenWindow.objectName)

                transitions: [
                    Transition {
                        from: ""
                        PropertyAction { target: appDelegate; properties: "visuallyMaximized,visuallyMaximized" }
                        PropertyAction { target: windowState.absolutePosition; properties: "x,y" }
                        PropertyAction { target: windowState.geometry; properties: "x,y,width,height" }
                        PropertyAction { target: windowState; properties: "scale,opacity2" }
                    },
                    Transition {
                        from: "spread"; to: "*"
                        PropertyAction { target: windowState.absolutePosition; properties: "x,y"}
                        PropertyAction { target: windowState.geometry; properties: "height" }
                        PropertyAction { target: windowState; properties: "spread" }
                        ScriptAction { script: if (appDelegate.focus) appDelegate.playFocusAnimation() }
                    },
                    Transition {
                        to: "staged"
                        SequentialAnimation {
                            ParallelAnimation {
                                PropertyAction { target: appDelegate; properties: "visuallyMaximized" }
                                PropertyAction { target: windowState.absolutePosition; properties: "x,y" }
                                UbuntuNumberAnimation { target: windowState.geometry; properties: "x,y,width,height"; duration: priv.animationDuration }
                                UbuntuNumberAnimation { target: windowState; properties: "scale,opacity2"; duration: priv.animationDuration }
                            }
                            PropertyAction { target: appDelegate; property: "visuallyMaximized" }
                        }
                    },
                    Transition {
                        to: "stagedWithSideStage"
                        SequentialAnimation {
                            ParallelAnimation {
                                PropertyAction { target: stageMaths; properties: "itemIndex" }
                                PropertyAction { target: appDelegate; properties: "visuallyMaximized,z" }
                                PropertyAction { target: windowState.absolutePosition; properties: "x,y" }
                                UbuntuNumberAnimation { target: windowState.geometry; properties: "x,y,width,height"; duration: priv.animationDuration }
                                UbuntuNumberAnimation { target: windowState; properties: "scale,opacity2"; duration: priv.animationDuration }
                            }
                            PropertyAction { target: appDelegate; property: "visuallyMaximized" }
                        }
                    },
                    Transition {
                        to: "normal"
                        PropertyAction { target: appDelegate; properties: "visuallyMaximized,visuallyMaximized" }
                        UbuntuNumberAnimation { target: windowState.geometry; properties: "x,y,width,height"; duration: priv.animationDuration }
                        UbuntuNumberAnimation { target: windowState; properties: "scale,opacity2"; duration: priv.animationDuration }
                    },
                    Transition {
                        to: "maximized,fullscreen"
                        SequentialAnimation {
                            ParallelAnimation {
                                PropertyAction { target: appDelegate; properties: "visuallyMinimized" }
                                PropertyAction { target: windowState.absolutePosition; properties: "x,y" }
                                UbuntuNumberAnimation { target: windowState.geometry; properties: "x,y,width,height"; duration: priv.animationDuration }
                                UbuntuNumberAnimation { target: windowState; properties: "scale,opacity2"; duration: priv.animationDuration }
                            }
                            PropertyAction { target: appDelegate; property: "visuallyMaximized" }
                        }
                    },
                    Transition {
                        to: "minimized"
                        SequentialAnimation {
                            ParallelAnimation {
                                PropertyAction { target: appDelegate; properties: "visuallyMaximized" }
                                PropertyAction { target: windowState.absolutePosition; properties: "x,y" }
                                UbuntuNumberAnimation { target: windowState.geometry; properties: "x,y,width,height"; duration: priv.animationDuration }
                                UbuntuNumberAnimation { target: windowState; properties: "scale,opacity2"; duration: priv.animationDuration }
                            }
                            PropertyAction { target: appDelegate; property: "visuallyMinimized" }
                            ScriptAction {
                                script: {
                                    if (appDelegate.minimized) {
                                        appDelegate.focus = false;
                                        priv.focusNext();
                                    }
                                }
                            }
                        }
                    },
                    Transition {
                        to: "spread"
                        PropertyAction { target: windowState; property: "spread" }
                        PropertyAction { target: appDelegate; properties: "z,visuallyMaximized,visuallyMaximized" }
                        PropertyAction { target: decoratedWindow; property: "scaleToPreviewSize" }
                        PropertyAction { target: windowState.absolutePosition; properties: "x,y" }
                        UbuntuNumberAnimation { target: windowState.geometry; properties: "x,y,width,height"; duration: priv.animationDuration }
                        UbuntuNumberAnimation { target: windowState; properties: "scale,opacity2"; duration: priv.animationDuration }
                        UbuntuNumberAnimation { target: decoratedWindow; properties: "itemScale,angle,scaleToPreviewProgress"; duration: priv.animationDuration }
                    }
                ]

//                onXChanged: if (model.application.appId == "unity8-dash") print("dash moved to", x)
//                onRequestedWidthChanged: if (index == 0) print("requestedWidth", requestedWidth)
//                onStateChanged: if (model.application.appId == "unity8-dash") print("state changed", state)
//                states: [
//                    State {
//                        name: "spread"; when: root.state == "spread"
//                        PropertyChanges {
//                            target: decoratedWindow;
//                            showDecoration: false;
//                            angle: spreadMaths.targetAngle
//                            itemScale: spreadMaths.targetScale
//                            scaleToPreviewSize: spreadItem.stackHeight
//                            scaleToPreviewProgress: 1
//                            hasDecoration: root.mode === "windowed"
//                            shadowOpacity: spreadMaths.shadowOpacity
//                            showHighlight: spreadItem.highlightedIndex === index
//                            anchors.topMargin: dragArea.distance
//                        }
//                        PropertyChanges {
//                            target: appDelegate
//                            z: index
//                            height: spreadItem.spreadItemHeight
//                            requestedWidth: decoratedWindow.oldRequestedWidth
//                            requestedHeight: decoratedWindow.oldRequestedHeight
//                            visible: spreadMaths.itemVisible
//                        }
//                        PropertyChanges {
//                            target: spreadPositioner
//                            x: spreadMaths.targetX
//                            y: spreadMaths.targetY
//                        }
//                        PropertyChanges {
//                            target: windowState.relativePosition
//                            x: spreadPositioner.mappedX
//                            y: spreadPositioner.mappedY
//                        }
//                        PropertyChanges { target: dragArea; enabled: true }
//                        PropertyChanges { target: windowInfoItem; opacity: spreadMaths.tileInfoOpacity; visible: spreadMaths.itemVisible }
//                    },
//                    State {
//                        name: "stagedrightedge"
//                        when: root.state == "sidestagedrightedge" || root.state == "stagedrightedge" || rightEdgeFocusAnimation.running || hidingAnimation.running
//                        PropertyChanges {
//                            target: stagedRightEdgeMaths
//                            progress: rightEdgeDragArea.progress
//                        }
//                        PropertyChanges {
//                            target: appDelegate
//                            z: index +1
//                            height: stagedRightEdgeMaths.animatedHeight
//                            requestedWidth: decoratedWindow.oldRequestedWidth
//                            requestedHeight: decoratedWindow.oldRequestedHeight
//                        }
//                        PropertyChanges {
//                            target: spreadPositioner
//                            x: stagedRightEdgeMaths.animatedX
//                            y: stagedRightEdgeMaths.animatedY
//                        }
//                        PropertyChanges {
//                            target: windowState.relativePosition
//                            x: spreadPositioner.mappedX
//                            y: spreadPositioner.mappedY
//                        }
//                        PropertyChanges {
//                            target: decoratedWindow
//                            hasDecoration: false
//                            angle: stagedRightEdgeMaths.animatedAngle
//                            itemScale: stagedRightEdgeMaths.animatedScale
//                            scaleToPreviewSize: spreadItem.stackHeight
//                            scaleToPreviewProgress: stagedRightEdgeMaths.scaleToPreviewProgress
//                            shadowOpacity: .3
//                        }
//                    },
//                    State {
//                        name: "staged"; when: root.state == "staged"
//                        PropertyChanges {
//                            target: appDelegate
//                            requestedX: appDelegate.focus ? 0 : root.width
//                            requestedY: appDelegate.fullscreen ? 0 : panelState.panelHeight
//                            requestedWidth: appContainer.width
//                            requestedHeight: appDelegate.fullscreen ? appContainer.height : appContainer.height - panelState.panelHeight
//                            visuallyMaximized: true
//                        }
//                        PropertyChanges {
//                            target: decoratedWindow
//                            hasDecoration: false
//                        }
//                        PropertyChanges {
//                            target: resizeArea
//                            enabled: false
//                        }
//                    },
//                    State {
//                        name: "stagedWithSideStage"; when: root.state == "stagedWithSideStage"
//                        PropertyChanges {
//                            target: stageMaths
//                            itemIndex: index
//                        }
//                        PropertyChanges {
//                            target: appDelegate
//                            requestedX: stageMaths.itemX
//                            requestedY: appDelegate.fullscreen ? 0 : panelState.panelHeight
//                            z: stageMaths.itemZ
//                            requestedWidth: stageMaths.itemWidth
//                            requestedHeight: appDelegate.fullscreen ? appContainer.height : appContainer.height - panelState.panelHeight
//                            visuallyMaximized: true
//                        }
//                        PropertyChanges {
//                            target: decoratedWindow
//                            hasDecoration: false
//                        }
//                        PropertyChanges {
//                            target: resizeArea
//                            enabled: false
//                        }
//                    },
//                    State {
//                        name: "maximized"; when: root.state === "windowed" && appDelegate.maximized && !appDelegate.minimized
//                        PropertyChanges {
//                            target: appDelegate;
//                            requestedX: root.leftMargin;
//                            requestedY: 0;
//                            visuallyMinimized: false;
//                            visuallyMaximized: true
//                            requestedWidth: appContainer.width - root.leftMargin;
//                            requestedHeight: appContainer.height;
//                        }
//                    },
//                    State {
//                        name: "fullscreen"; when: surface ? surface.state === Mir.FullscreenState : application.fullscreen && !appDelegate.minimized
//                        PropertyChanges {
//                            target: appDelegate;
//                            requestedX: rotation == 0 ? 0 : (parent.width - width) / 2 + (shellOrientationAngle == 90 ? 0 : panelState.panelHeight)
//                            requestedY: rotation == 0 ? 0 : (parent.height - height) / 2
//                            requestedWidth: appContainer.width;
//                            requestedHeight: appContainer.height;
//                        }
//                        PropertyChanges { target: decoratedWindow; hasDecoration: false }
//                    },
//                    State {
//                        name: "normal";
//                        when: appDelegate.windowState == WindowStateStorage.WindowStateNormal
//                        PropertyChanges {
//                            target: appDelegate
//                            visuallyMinimized: false
//                            visuallyMaximized: false
//                            requestedX: appDelegate.windowedX
//                            requestedY: appDelegate.windowedY
//                            requestedWidth: appDelegate.windowedWidth
//                            requestedHeight: appDelegate.windowedHeight
//                        }
//                        PropertyChanges { target: touchControls; enabled: true }
//                        PropertyChanges { target: resizeArea; enabled: true }
//                        PropertyChanges { target: decoratedWindow; shadowOpacity: .3}
//                    },
//                    State {
//                        name: "maximizedLeft"; when: appDelegate.maximizedLeft && !appDelegate.minimized
//                        PropertyChanges {
//                            target: appDelegate
//                            requestedX: root.leftMargin
//                            requestedY: panelState.panelHeight
//                        }
//                        PropertyChanges {
//                            target: decoratedWindow
//                            requestedWidth: (appContainer.width - root.leftMargin)/2
//                            requestedHeight: appContainer.height - panelState.panelHeight
//                            shadowOpacity: .3
//                        }
//                    },
//                    State {
//                        name: "maximizedRight"; when: appDelegate.maximizedRight && !appDelegate.minimized
//                        PropertyChanges {
//                            target: appDelegate;
//                            requestedX: (appContainer.width + root.leftMargin)/2
//                            requestedY: panelState.panelHeight
//                        }
//                        PropertyChanges {
//                            target: decoratedWindow
//                            requestedWidth: (appContainer.width - root.leftMargin)/2
//                            requestedHeight: appContainer.height - panelState.panelHeight
//                            shadowOpacity: .3
//                        }
//                    },
//                    State {
//                        name: "maximizedHorizontally"; when: appDelegate.maximizedHorizontally && !appDelegate.minimized
//                        PropertyChanges {
//                            target: appDelegate;
//                            requestedX: root.leftMargin
//                        }
//                        PropertyChanges {
//                            target: decoratedWindow;
//                            requestedWidth: appContainer.width - root.leftMargin
//                            shadowOpacity: .3
//                        }
//                    },
//                    State {
//                        name: "maximizedVertically"; when: appDelegate.maximizedVertically && !appDelegate.minimized
//                        PropertyChanges {
//                            target: appDelegate;
//                            requestedY: panelState.panelHeight
//                        }
//                        PropertyChanges {
//                            target: decoratedWindow;
//                            requestedHeight: appContainer.height - panelState.panelHeight
//                            shadowOpacity: .3
//                        }
//                    },
//                    State {
//                        name: "minimized"; when: appDelegate.minimized
//                        PropertyChanges {
//                            target: appDelegate;
//                            requestedX: -appDelegate.width / 2;
//                            scale: units.gu(5) / appDelegate.width;
//                            opacity: 0;
//                            visuallyMinimized: true;
//                            visuallyMaximized: false
//                        }
//                    }

//                ]
//                transitions: [
//                    Transition {
//                        from: "staged,stagedWithSideStage,minimized"; to: "normal"
//                        enabled: appDelegate.animationsEnabled
//                        PropertyAction { target: appDelegate; properties: "visuallyMinimized,visuallyMaximized" }
//                        UbuntuNumberAnimation { target: appDelegate; properties: "requestedX,requestedY,opacity,requestedWidth,requestedHeight,scale"; duration: priv.animationDuration }
//                    },
//                    Transition {
//                        from: "spread"; to: "*"
////                        UbuntuNumberAnimation { target: appDelegate; properties: "requestedX,requestedY,height"; duration: priv.animationDuration }
////                        UbuntuNumberAnimation { target: decoratedWindow; properties: "width,height,itemScale,angle"; duration: priv.animationDuration }
//                        ScriptAction { script: if (appDelegate.focus) appDelegate.playFocusAnimation() }
//                    },
//                    Transition {
//                        to: "minimized"
//                        enabled: appDelegate.animationsEnabled
//                        PropertyAction { target: appDelegate; property: "visuallyMaximized" }
//                        SequentialAnimation {
//                            ParallelAnimation {
//                                UbuntuNumberAnimation { target: appDelegate; properties: "requestedX,requestedY,opacity,scale"; duration: priv.animationDuration }
//                                UbuntuNumberAnimation { target: decoratedWindow; properties: "requestedWidth,requestedHeight"; duration: priv.animationDuration }
//                            }
//                            PropertyAction { target: appDelegate; property: "visuallyMinimized" }
//                            ScriptAction {
//                                script: {
//                                    if (appDelegate.minimized) {
//                                        appDelegate.focus = false;
//                                        priv.focusNext();
//                                    }
//                                }
//                            }
//                        }
//                    },
//                    Transition {
//                        to: "maximized,fullscreen"
//                        enabled: appDelegate.animationsEnabled
//                        SequentialAnimation {
//                            PropertyAction { target: appDelegate; property: "visuallyMinimized" }
//                            ParallelAnimation {
//                                UbuntuNumberAnimation { target: appDelegate; properties: "requestedX,requestedY,opacity,scale,requestedWidth,requestedHeight"; duration: UbuntuAnimation.FastDuration }
//                            }
//                            PropertyAction { target: appDelegate; property: "visuallyMaximized" }
//                        }
//                    },
//                    Transition {
//                        to: "spread"
//                        // DecoratedWindow wants the sceleToPreviewSize set before enabling scaleToPreview
//                        PropertyAction { target: appDelegate; property: "z" }
//                        PropertyAction { target: decoratedWindow; property: "scaleToPreviewSize" }
//                        UbuntuNumberAnimation { target: appDelegate; properties: "requestedX,requestedY,height"; duration: priv.animationDuration }
//                        UbuntuNumberAnimation { target: decoratedWindow; properties: "width,height,itemScale,angle,scaleToPreviewProgress"; duration: priv.animationDuration }
//                    },
//                    Transition {
//                        from: "normal,staged"; to: "stagedWithSideStage"
//                        UbuntuNumberAnimation { target: appDelegate; properties: "requestedX,requestedY"; duration: priv.animationDuration }
//                        UbuntuNumberAnimation { target: appDelegate; properties: "requestedWidth,requestedHeight"; duration: priv.animationDuration }
//                    }
//                ]

//                Binding {
//                    id: previewBinding
//                    target: appDelegate
//                    property: "z"
//                    value: topLevelSurfaceList.count + 1
//                    when: index == spread.highlightedIndex
//                }

                Binding {
                    target: panelState
                    property: "buttonsAlwaysVisible"
                    value: appDelegate && appDelegate.maximized && touchControls.overlayShown
                }

                WindowResizeArea {
                    id: resizeArea
                    objectName: "windowResizeArea"

                    // workaround so that it chooses the correct resize borders when you drag from a corner ResizeGrip
                    anchors.margins: touchControls.overlayShown ? borderThickness/2 : -borderThickness

                    target: appDelegate
                    panelState: root.panelState
                    minWidth: units.gu(10)
                    minHeight: units.gu(10)
                    borderThickness: units.gu(2)
                    windowId: model.application.appId // FIXME: Change this to point to windowId once we have such a thing
                    screenWidth: appContainer.width
                    screenHeight: appContainer.height
                    leftMargin: root.leftMargin
                    enabled: false

                    onPressed: {
                        print("***** focusing because of resize area press", model.application.appId)
                        appDelegate.focus = true;
                    }

                    property bool saveStateOnDestruction: true
                    Component.onDestruction: {
                        if (saveStateOnDestruction) {
                            windowState.saveWindowedState();
                        }
                    }
                }

                DecoratedWindow {
                    id: decoratedWindow
                    objectName: "decoratedWindow"
                    anchors.left: appDelegate.left
                    anchors.top: appDelegate.top
                    application: model.application
                    surface: model.surface
                    active: appDelegate.focus
                    focus: true
                    hasDecoration: root.mode === "windowed"
                    showDecoration: true
                    maximizeButtonShown: (maximumWidth == 0 || maximumWidth >= appContainer.width) &&
                                         (maximumHeight == 0 || maximumHeight >= appContainer.height)
                    overlayShown: touchControls.overlayShown
                    width: implicitWidth
                    height: implicitHeight
                    panelState: root.panelState

                    requestedWidth: windowState.valid ? windowState.geometry.width : -1
                    requestedHeight: windowState.valid ? windowState.geometry.height : -1

                    property int oldRequestedWidth: -1
                    property int oldRequestedHeight: -1

                    onRequestedWidthChanged: oldRequestedWidth = requestedWidth
                    onRequestedHeightChanged: oldRequestedHeight = requestedHeight

                    onCloseClicked: { appDelegate.close(); }
                    onMaximizeClicked: {
                        if (appDelegate.maximized || appDelegate.maximizedLeft || appDelegate.maximizedRight
                                || appDelegate.maximizedHorizontally || appDelegate.maximizedVertically) {
                            appDelegate.restore();
                        } else {
                            appDelegate.maximize();
                        }
                    }
                    onMaximizeHorizontallyClicked: {
                        if (appDelegate.maximizedHorizontally) {
                            appDelegate.restore();
                        } else {
                            appDelegate.maximizeHorizontally();
                        }
                    }
                    onMaximizeVerticallyClicked: {
                        if (appDelegate.maximizedVertically) {
                            appDelegate.restore();
                        } else {
                            appDelegate.maximizeVertically();
                        }
                    }
                    onMinimizeClicked: {
                        appDelegate.minimize();
                    }
                    onDecorationPressed: { appDelegate.focus = true; }

                    property real angle: 0
                    property real itemScale: 1
                    transform: [
                        Scale {
                            origin.x: 0
                            origin.y: decoratedWindow.implicitHeight / 2
                            xScale: decoratedWindow.itemScale
                            yScale: decoratedWindow.itemScale
                        },
                        Rotation {
                            origin { x: 0; y: (decoratedWindow.height / 2) }
                            axis { x: 0; y: 1; z: 0 }
                            angle: decoratedWindow.angle
                        }
                    ]
                }

                WindowControlsOverlay {
                    id: touchControls
                    anchors.fill: appDelegate
                    target: appDelegate
                    enabled: false
                    panelState: root.panelState
                }

                WindowedFullscreenPolicy {
                    id: windowedFullscreenPolicy
                    active: root.mode == "windowed"
                    surface: model.surface
                }
                StagedFullscreenPolicy {
                    id: stagedFullscreenPolicy
                    active: root.mode == "staged" || root.mode == "stagedWithSideStage"
                    surface: model.surface
                }

                SpreadDelegateInputArea {
                    id: dragArea
                    anchors.fill: parent
                    enabled: false
                    closeable: model.application.appId !== "unity8-dash"

                    onClicked: {
                        spreadItem.highlightedIndex = index;
                        if (distance == 0) {
                            print("focusing because of inputBlocker click")
                            priv.goneToSpread = false;
                        }
                    }
                    onContainsMouseChanged: {
                        if (containsMouse) spreadItem.highlightedIndex = index
                    }
                    onClose: {
                        priv.closingIndex = index
                        model.surface.close()
                    }
                }

//                Rectangle { anchors.fill: parent; color: "blue"; opacity: .4 }

                WindowInfoItem {
                    id: windowInfoItem
                    anchors { left: parent.left; top: decoratedWindow.bottom; topMargin: units.gu(1) }
                    title: decoratedWindow.title
                    iconSource: model.application.icon
                    height: spreadItem.appInfoHeight
                    opacity: 0
                    visible: opacity > 0
                }
            }
        }
    }

    EdgeBarrier {
        id: edgeBarrier

        // NB: it does its own positioning according to the specified edge
        edge: Qt.RightEdge

        onPassed: { spread.show(); }
        material: Component {
            Item {
                Rectangle {
                    width: parent.height
                    height: parent.width
                    rotation: 90
                    anchors.centerIn: parent
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(0.16,0.16,0.16,0.5)}
                        GradientStop { position: 1.0; color: Qt.rgba(0.16,0.16,0.16,0)}
                    }
                }
            }
        }
    }

    FloatingFlickable {
        id: floatingFlickable
        anchors.fill: appContainer
        enabled: false
        contentWidth: spreadItem.spreadTotalWidth
        rightMargin: leftMargin
        leftMargin: {
            var stepOnXAxis = 1 / spreadItem.visibleItemCount
            var distanceToIndex1 = spreadItem.curve.getYFromX(stepOnXAxis)
            var middlePartDistance = spreadItem.curve.getYFromX(0.5 + stepOnXAxis/2) - spreadItem.curve.getYFromX(0.5 - stepOnXAxis/2)
            return 1.2 * (middlePartDistance - distanceToIndex1) * spreadItem.spreadWidth
        }

    }

    PropertyAnimation {
        id: shortRightEdgeSwipeAnimation
        property: "x"
        to: 0
        duration: priv.animationDuration
    }

    SwipeArea {
        id: rightEdgeDragArea
        direction: Direction.Leftwards
        anchors { top: parent.top; right: parent.right; bottom: parent.bottom }
        width: root.dragAreaWidth

        property var gesturePoints: new Array()

        property real progress: -touchPosition.x / root.width
//        onProgressChanged: print("dda progress", progress, root.width, touchPosition.x, root.width + touchPosition.x)

        Rectangle { color: "blue"; anchors.fill: parent }
        onTouchPositionChanged: {
            if (dragging) {
                // Gesture recognized. Let's move the spreadView with the finger
//                var dragX = Math.min(touchX + width, width); // Prevent dragging rightwards
//                dragX = -dragX + spreadDragArea.width - spreadView.shift;
//                // Don't allow dragging further than the animation crossing with phase2's animation
//                var maxMovement =  spreadView.width * spreadView.positionMarker4 - spreadView.shift;

//                spreadView.contentX = Math.min(dragX, maxMovement);
            } else {
//                // Initial touch. Let's reset the spreadView to the starting position.
//                spreadView.phase = 0;
//                spreadView.contentX = -spreadView.shift;
            }

            gesturePoints.push(touchPosition.x);
        }

        onDraggingChanged: {
            print("dda dragging changed", dragging)
            if (dragging) {
                // A potential edge-drag gesture has started. Start recording it
                gesturePoints = [];
            } else {
                if (gesturePoints[gesturePoints.length - 1] < -root.width * 0.4 ) {
                    print("gone to spread true")
                    priv.goneToSpread = true;
                } else {
                    if (appRepeater.count > 1) {
                        print("playing focus animation for", priv.nextInStack)
                        appRepeater.itemAt(0).playHidingAnimation()
                        appRepeater.itemAt(priv.nextInStack).playFocusAnimation()
                    } else {
                        appRepeater.itemAt(0).playFocusAnimation();
                    }
                }

//                // Ok. The user released. Find out if it was a one-way movement.
//                var oneWayFlick = true;
//                var smallestX = spreadDragArea.width;
//                for (var i = 0; i < gesturePoints.length; i++) {
//                    if (gesturePoints[i] >= smallestX) {
//                        oneWayFlick = false;
//                        break;
//                    }
//                    smallestX = gesturePoints[i];
//                }
//                gesturePoints = [];

//                if (oneWayFlick && spreadView.shiftedContentX > units.gu(2) &&
//                        spreadView.shiftedContentX < spreadView.positionMarker1 * spreadView.width) {
//                    // If it was a short one-way movement, do the Alt+Tab switch
//                    // no matter if we didn't cross positionMarker1 yet.
//                    spreadView.snapTo(1);
//                } else if (!dragging) {
//                    // otherwise snap to the closest snap position we can find
//                    // (might be back to start, to app 1 or to spread)
//                    spreadView.snap();
//                }
            }
        }
    }

    TabletSideStageTouchGesture {
        id: triGestureArea
        anchors.fill: parent
        enabled: false
        property Item appDelegate

        dragComponent: dragComponent
        dragComponentProperties: { "appDelegate": appDelegate }

        onPressed: {
            print("********* triGestureArea pressed!")
            function matchDelegate(obj) { return String(obj.objectName).indexOf("appDelegate") >= 0; }

            var delegateAtCenter = Functions.itemAt(appContainer, x, y, matchDelegate);
            print("dragging delegate", delegateAtCenter)
            if (!delegateAtCenter) return;

            appDelegate = delegateAtCenter;
        }

        onClicked: {
            if (sideStage.shown) {
               sideStage.hide();
            } else  {
               sideStage.show();
            }
        }

        onDragStarted: {
            // If we're dragging to the sidestage.
            if (!sideStage.shown) {
                sideStage.show();
            }
        }

        Component {
            id: dragComponent
            SurfaceContainer {
                property Item appDelegate

                surface: appDelegate ? appDelegate.surface : null

                consumesInput: false
                interactive: false
//                resizeSurface: false
                focus: false
                requestedWidth: appDelegate.requestedWidth
                requestedHeight: appDelegate.requestedHeight

                width: units.gu(40)
                height: units.gu(40)

                Drag.hotSpot.x: width/2
                Drag.hotSpot.y: height/2
                // only accept opposite stage.
                Drag.keys: {
                    if (!surface) return "Disabled";
                    if (appDelegate.isDash) return "Disabled";

                    if (appDelegate.stage === ApplicationInfo.MainStage) {
                        if (appDelegate.application.supportedOrientations
                                & (Qt.PortraitOrientation|Qt.InvertedPortraitOrientation)) {
                            return "MainStage";
                        }
                        return "Disabled";
                    }
                    return "SideStage";
                }
            }
        }
    }
}
