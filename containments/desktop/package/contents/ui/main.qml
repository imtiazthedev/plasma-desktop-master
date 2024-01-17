/*
    SPDX-FileCopyrightText: 2011-2013 Sebastian Kügler <sebas@kde.org>
    SPDX-FileCopyrightText: 2011-2019 Marco Martin <mart@kde.org>
    SPDX-FileCopyrightText: 2014-2015 Eike Hein <hein@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15

import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.ksvg 1.0 as KSvg
import org.kde.kquickcontrolsaddons 2.0 as KQuickControlsAddons
import org.kde.kirigami 2.20 as Kirigami

import org.kde.private.desktopcontainment.desktop 0.1 as Desktop
import org.kde.private.desktopcontainment.folder 0.1 as Folder

import org.kde.plasma.private.containmentlayoutmanager 1.0 as ContainmentLayoutManager

import "code/FolderTools.js" as FolderTools

ContainmentItem {
    id: root

    switchWidth: { switchSize(); }
    switchHeight: { switchSize(); }

    // Only exists because the default CompactRepresentation doesn't:
    // - open on drag
    // - allow defining a custom drop handler
    // TODO remove once it gains that feature (perhaps optionally?)
    compactRepresentation: (isFolder && !isContainment) ? compactRepresentation : null

    objectName: isFolder ? "folder" : "desktop"

    width: isPopup ? undefined : preferredWidth(false) // Initial size when adding to e.g. desktop.
    height: isPopup ? undefined : preferredHeight(false) // Initial size when adding to e.g. desktop.

    function switchSize() {
        // Support expanding into the full representation on very thick vertical panels.
        if (isPopup && Plasmoid.formFactor === PlasmaCore.Types.Vertical) {
            return Kirigami.Units.gridUnit * 8;
        }

        return 0;
    }

    LayoutMirroring.enabled: Qt.application.layoutDirection === Qt.RightToLeft
    LayoutMirroring.childrenInherit: true

    property bool isFolder: (Plasmoid.pluginName === "org.kde.plasma.folder")
    property bool isContainment: Plasmoid.isContainment
    property bool isPopup: (Plasmoid.location !== PlasmaCore.Types.Floating)
    property bool useListViewMode: isPopup && Plasmoid.configuration.viewMode === 0

    property Component appletAppearanceComponent
    property Item toolBox

    property int handleDelay: 800
    property real haloOpacity: 0.5

    property int iconSize: Kirigami.Units.iconSizes.small
    property int iconWidth: iconSize
    property int iconHeight: iconWidth

    readonly property int hoverActivateDelay: 750 // Magic number that matches Dolphin's auto-expand folders delay.

    readonly property Loader folderViewLayer: fullRepresentationItem.folderViewLayer
    readonly property ContainmentLayoutManager.AppletsLayout appletsLayout: fullRepresentationItem.appletsLayout

    // Plasmoid.title is set by a Binding {} in FolderViewLayer
    toolTipSubText: ""
    Plasmoid.icon: (!Plasmoid.configuration.useCustomIcon && folderViewLayer.ready) ? symbolicizeIconName(folderViewLayer.view.model.iconName) : Plasmoid.configuration.icon

    onIconHeightChanged: updateGridSize()

    // We want to do this here rather than in the model because we don't always want
    // symbolic icons everywhere, but we do know that we always want them in this
    // specific representation right here
    function symbolicizeIconName(iconName) {
        const symbolicSuffix = "-symbolic";
        if (iconName.endsWith(symbolicSuffix)) {
            return iconName;
        }

        return iconName + symbolicSuffix;
    }

    function updateGridSize() {
        appletsLayout.cellWidth = root.iconWidth + toolBoxSvg.elementSize("left").width + toolBoxSvg.elementSize("right").width;
        appletsLayout.cellHeight = root.iconHeight + toolBoxSvg.elementSize("top").height + toolBoxSvg.elementSize("bottom").height;
        appletsLayout.defaultItemWidth = appletsLayout.cellWidth * 6;
        appletsLayout.defaultItemHeight = appletsLayout.cellHeight * 6;
    }

    function addLauncher(desktopUrl) {
        if (!isFolder) {
            return;
        }

        folderViewLayer.view.linkHere(desktopUrl);
    }

    function preferredWidth(minimum) {
        if (isContainment || !folderViewLayer.ready) {
            return -1;
        } else if (useListViewMode) {
            return (minimum ? folderViewLayer.view.cellHeight * 4 : Kirigami.Units.gridUnit * 16);
        }

        return (folderViewLayer.view.cellWidth * (minimum ? 1 : 3)) + (Kirigami.Units.gridUnit * 2);
    }

    function preferredHeight(minimum) {
        let height;
        if (isContainment || !folderViewLayer.ready) {
            return -1;
        } else if (useListViewMode) {
            height = (folderViewLayer.view.cellHeight * (minimum ? 1 : 15)) + Kirigami.Units.smallSpacing;
        } else {
            height = (folderViewLayer.view.cellHeight * (minimum ? 1 : 2)) + Kirigami.Units.gridUnit;
        }

        if (Plasmoid.configuration.labelMode !== 0) {
            height += folderViewLayer.item.labelHeight;
        }

        return height;
    }

    function isDrag(fromX, fromY, toX, toY) {
        const length = Math.abs(fromX - toX) + Math.abs(fromY - toY);
        return length >= Qt.styleHints.startDragDistance;
    }

    onFocusChanged: {
        if (focus && isFolder) {
            folderViewLayer.item.forceActiveFocus();
        }
    }

    onExternalData: (mimetype, data) => {
        Plasmoid.configuration.url = data
    }

    KSvg.FrameSvgItem {
        id : highlightItemSvg

        visible: false

        imagePath: isPopup ? "widgets/viewitem" : ""
        prefix: "hover"
    }

    KSvg.FrameSvgItem {
        id : listItemSvg

        visible: false

        imagePath: isPopup ? "widgets/viewitem" : ""
        prefix: "normal"
    }

    KSvg.Svg {
        id: toolBoxSvg
        imagePath: "widgets/toolbox"
        property int rightBorder: elementSize("right").width
        property int topBorder: elementSize("top").height
        property int bottomBorder: elementSize("bottom").height
        property int leftBorder: elementSize("left").width
    }

    // FIXME: the use and existence of this property is a workaround
    preloadFullRepresentation: true
    fullRepresentation: FolderViewDropArea {
        id: dropArea

        anchors {
            fill: parent
            leftMargin: (isContainment && Plasmoid.availableScreenRect) ? Plasmoid.availableScreenRect.x : 0
            topMargin: (isContainment && Plasmoid.availableScreenRect) ? Plasmoid.availableScreenRect.y : 0

            rightMargin: (isContainment && Plasmoid.availableScreenRect && parent)
                ? (parent.width - Plasmoid.availableScreenRect.x - Plasmoid.availableScreenRect.width) : 0

            bottomMargin: (isContainment && Plasmoid.availableScreenRect && parent)
                ? (parent.height - Plasmoid.availableScreenRect.y - Plasmoid.availableScreenRect.height) : 0
        }

        Behavior on anchors.topMargin {
            NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.InOutQuad }
        }
        Behavior on anchors.leftMargin {
            NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.InOutQuad }
        }
        Behavior on anchors.rightMargin {
            NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.InOutQuad }
        }
        Behavior on anchors.bottomMargin {
            NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.InOutQuad }
        }

        property alias folderViewLayer: folderViewLayer
        property alias appletsLayout: appletsLayout

        Layout.minimumWidth: preferredWidth(!isPopup)
        Layout.minimumHeight: preferredHeight(!isPopup)

        Layout.preferredWidth: preferredWidth(false)
        Layout.preferredHeight: preferredHeight(false)

        Layout.maximumWidth: isPopup ? preferredWidth(false) : -1
        Layout.maximumHeight: isPopup ? preferredHeight(false) : -1

        preventStealing: true

        onDragEnter: event => {
            if (isContainment && Plasmoid.immutable && !(isFolder && FolderTools.isFileDrag(event))) {
                event.ignore();
            }

            // Don't allow any drops while listing.
            if (isFolder && folderViewLayer.view.status === Folder.FolderModel.Listing) {
                event.ignore();
            }

            // Firefox tabs are regular drags. Since all of our drop handling is asynchronous
            // we would accept this drop and have Firefox not spawn a new window. (Bug 337711)
            if (event.mimeData.formats.indexOf("application/x-moz-tabbrowser-tab") !== -1) {
                event.ignore();
            }
        }

        onDragMove: event => {
            // TODO: We should reject drag moves onto file items that don't accept drops
            // (cf. QAbstractItemModel::flags() here, but DeclarativeDropArea currently
            // is currently incapable of rejecting drag events.

            // Trigger autoscroll.
            if (isFolder && FolderTools.isFileDrag(event)) {
                handleDragMove(folderViewLayer.view, mapToItem(folderViewLayer.view, event.x, event.y));
            } else if (isContainment) {
                appletsLayout.showPlaceHolderAt(
                    Qt.rect(event.x - appletsLayout.minimumItemWidth / 2,
                    event.y - appletsLayout.minimumItemHeight / 2,
                    appletsLayout.minimumItemWidth,
                    appletsLayout.minimumItemHeight)
                );
            }
        }

        onDragLeave: event => {
            // Cancel autoscroll.
            if (isFolder) {
                handleDragEnd(folderViewLayer.view);
            }

            if (isContainment) {
                appletsLayout.hidePlaceHolder();
            }
        }

        onDrop: event => {
            if (isFolder && FolderTools.isFileDrag(event)) {
                handleDragEnd(folderViewLayer.view);
                folderViewLayer.view.drop(root, event, mapToItem(folderViewLayer.view, event.x, event.y));
            } else if (isContainment) {
                root.processMimeData(event.mimeData,
                            event.x - appletsLayout.placeHolder.width / 2, event.y - appletsLayout.placeHolder.height / 2);
                event.accept(event.proposedAction);
                appletsLayout.hidePlaceHolder();
            }
        }

        Component {
            id: compactRepresentation
            CompactRepresentation { folderView: folderViewLayer.view }
        }

        // Can be removed?
        KQuickControlsAddons.EventGenerator {
            id: eventGenerator
        }

        Connections {
            target: Plasmoid.containment.corona
            ignoreUnknownSignals: true
            function onEditModeChanged() {
                appletsLayout.editMode = Plasmoid.containment.corona.editMode;
            }
        }

        ContainmentLayoutManager.AppletsLayout {
            id: appletsLayout
            anchors.fill: parent
            relayoutLock: width != Plasmoid.availableScreenRect.width || height != Plasmoid.availableScreenRect.height
            // NOTE: use Plasmoid.availableScreenRect and not own width and height as they are updated not atomically
            configKey: "ItemGeometries-" + Math.round(Plasmoid.screenGeometry.width) + "x" + Math.round(Plasmoid.screenGeometry.height)
            fallbackConfigKey: Plasmoid.availableScreenRect.width > Plasmoid.availableScreenRect.height ? "ItemGeometriesHorizontal" : "ItemGeometriesVertical"

            containment: Plasmoid
            containmentItem: root
            editModeCondition: Plasmoid.immutable
                    ? ContainmentLayoutManager.AppletsLayout.Locked
                    : ContainmentLayoutManager.AppletsLayout.AfterPressAndHold

            // Sets the containment in edit mode when we go in edit mode as well
            onEditModeChanged: Plasmoid.containment.corona.editMode = editMode;

            minimumItemWidth: Kirigami.Units.gridUnit * 3
            minimumItemHeight: minimumItemWidth

            cellWidth: Kirigami.Units.iconSizes.small
            cellHeight: cellWidth

            eventManagerToFilter: folderViewLayer.item ? folderViewLayer.item.view.view : null

            appletContainerComponent: ContainmentLayoutManager.BasicAppletContainer {
                id: appletContainer
                editModeCondition: Plasmoid.immutable
                    ? ContainmentLayoutManager.ItemContainer.Locked
                    : ContainmentLayoutManager.ItemContainer.AfterPressAndHold
                configOverlayComponent: ConfigOverlay {}
                onUserDrag: {
                    var pos = mapToItem(root.parent, dragCenter.x, dragCenter.y);
                    var newCont = root.containmentItemAt(pos.x, pos.y);

                    if (newCont && newCont.plasmoid !== Plasmoid) {
                        var newPos = newCont.mapFromApplet(Plasmoid, pos.x, pos.y);

                        newCont.Plasmoid.addApplet(appletContainer.applet.plasmoid, Qt.rect(newPos.x, newPos.y, appletContainer.applet.width, appletContainer.applet.height));
                        appletsLayout.hidePlaceHolder();
                    }
                }

                component DropBehavior : Behavior {
                    NumberAnimation {
                        duration: Kirigami.Units.shortDuration
                        easing.type: Easing.InOutQuad
                    }
                }

                DropBehavior on x { }
                DropBehavior on y { }
            }

            placeHolder: ContainmentLayoutManager.PlaceHolder {}

            Loader {
                id: folderViewLayer

                anchors.fill: parent

                property bool ready: status === Loader.Ready
                property Item view: item ? item.view : null
                property QtObject model: item ? item.model : null

                focus: true

                active: isFolder
                asynchronous: false

                source: "FolderViewLayer.qml"

                onFocusChanged: {
                    if (!focus && model) {
                        model.clearSelection();
                    }
                }

                Connections {
                    target: folderViewLayer.view

                    // `FolderViewDropArea` is not a FocusScope. We need to forward manually.
                    function onPressed() {
                        folderViewLayer.forceActiveFocus();
                    }
                }
            }
        }

        PlasmaCore.Action {
            id: configAction
            text: i18n("Configure Desktop and Wallpaper…")
            icon.name: "preferences-desktop-wallpaper"
            shortcut: "alt+d,s"
            onTriggered: Plasmoid.containment.configureRequested(Plasmoid)
        }

        Component.onCompleted: {
            if (!Plasmoid.isContainment) {
                return;
            }

            Plasmoid.setInternalAction("configure", configAction)
            updateGridSize();
        }
    }
}
