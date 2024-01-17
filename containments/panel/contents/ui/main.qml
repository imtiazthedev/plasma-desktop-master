/*
    SPDX-FileCopyrightText: 2013 Marco Martin <mart@kde.org>
    SPDX-FileCopyrightText: 2022 Niccolò Venerandi <niccolo@venerandi.com>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick 2.1
import QtQuick.Layouts 1.1
import org.kde.plasma.plasmoid 2.0

import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.ksvg 1.0 as KSvg
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.kquickcontrolsaddons 2.0
import org.kde.draganddrop 2.0 as DragDrop
import org.kde.kirigami 2.20 as Kirigami

import "LayoutManager.js" as LayoutManager

ContainmentItem {
    id: root
    width: 640
    height: 48

//BEGIN properties
    Layout.preferredWidth: fixedWidth || currentLayout.implicitWidth
    Layout.preferredHeight: fixedHeight || currentLayout.implicitHeight

    property Item toolBox
    property var layoutManager: LayoutManager

    property Item configOverlay

    property bool isHorizontal: Plasmoid.formFactor !== PlasmaCore.Types.Vertical
    property int fixedWidth: 0
    property int fixedHeight: 0
    property bool hasSpacer
    // True when a widget is being drag and dropped within the panel.
    property bool dragAndDropping: false

//END properties

//BEGIN functions
    function checkLastSpacer() {
        for (var i = 0; i < appletsModel.count; ++i) {
            const applet = appletsModel.get(i).applet;
            if (!applet || !applet.visible || !applet.Layout) {
                continue;
            }
            if ((isHorizontal && applet.Layout.fillWidth) ||
                (!isHorizontal && applet.Layout.fillHeight)) {
                    hasSpacer = true;
                return;
            }
        }
        hasSpacer = false;
    }

    function plasmoidLocationString(): string {
        switch (Plasmoid.location) {
        case PlasmaCore.Types.LeftEdge:
            return "west";
        case PlasmaCore.Types.TopEdge:
            return "north";
        case PlasmaCore.Types.RightEdge:
            return "east";
        case PlasmaCore.Types.BottomEdge:
            return "south";
        }
        return "";
    }
//END functions

//BEGIN connections
    Containment.onAppletAdded: (applet) => {
        let plasmoidItem = root.itemFor(applet);
        LayoutManager.addApplet(applet, plasmoidItem.x, plasmoidItem.y);
        root.checkLastSpacer();
        // When a new preset panel is added, avoid calling save() multiple times
        Qt.callLater(LayoutManager.save);
    }

    Containment.onAppletRemoved: (applet) => {
        let plasmoidItem = root.itemFor(applet);
        if (plasmoidItem) {
            appletsModel.remove(plasmoidItem.parent.index);
        }
        checkLastSpacer();
        LayoutManager.save();
    }

    Plasmoid.onUserConfiguringChanged: {
        if (!Plasmoid.userConfiguring) {
            if (root.configOverlay) {
                root.configOverlay.destroy();
                root.configOverlay = null;
            }
            return;
        }

        if (Plasmoid.immutable) {
            return;
        }

        Plasmoid.applets.forEach(applet => applet.expanded = false);
        const component = Qt.createComponent("ConfigOverlay.qml");
        root.configOverlay = component.createObject(root, {
            "anchors.fill": root,
        });
        component.destroy();
    }
//END connections

    DragDrop.DropArea {
        id: dropArea
        anchors.fill: parent

        // These are invisible and only used to read panel margins
        // Both will fallback to "standard" panel margins if the theme does not
        // define a normal or a thick margin.
        KSvg.FrameSvgItem {
            id: panelSvg
            visible: false
            imagePath: "widgets/panel-background"
            prefix: [root.plasmoidLocationString(), ""]
        }
        KSvg.FrameSvgItem {
            id: thickPanelSvg
            visible: false
            prefix: ['thick'].concat(panelSvg.prefix)
            imagePath: "widgets/panel-background"
        }
        property bool marginAreasEnabled: panelSvg.margins != thickPanelSvg.margins
        property var marginHighlightSvg: KSvg.Svg{imagePath: "widgets/margins-highlight"}
        //Margins are either the size of the margins in the SVG, unless that prevents the panel from being at least half a smallMedium icon) tall at which point we set the margin to whatever allows it to be that...or if it still won't fit, 1.
        //the size a margin should be to force a panel to be the required size above
        readonly property real spacingAtMinSize: Math.floor(Math.max(1, (isHorizontal ? root.height : root.width) - Kirigami.Units.iconSizes.smallMedium)/2)

        Component.onCompleted: {
            LayoutManager.plasmoid = root.Plasmoid;
            LayoutManager.root = root;
            LayoutManager.layout = currentLayout;
            LayoutManager.marginHighlights = [];
            LayoutManager.appletsModel = appletsModel;
            LayoutManager.restore();

            root.Plasmoid.internalAction("configure").visible = Qt.binding(function() {
                return !root.Plasmoid.immutable;
            });
            root.Plasmoid.internalAction("configure").enabled = Qt.binding(function() {
                return !root.Plasmoid.immutable;
            });
        }

        onDragEnter: event => {
            if (Plasmoid.immutable) {
                event.ignore();
                return;
            }
            //during drag operations we disable panel auto resize
            root.fixedWidth = root.Layout.preferredWidth
            root.fixedHeight = root.Layout.preferredHeight
            appletsModel.insert(LayoutManager.indexAtCoordinates(event.x, event.y), {applet: dndSpacer})
        }

        onDragMove: event => {
            LayoutManager.move(dndSpacer.parent, LayoutManager.indexAtCoordinates(event.x, event.y));
        }

        onDragLeave: event => {
            /*
            * When reordering task items, dragLeave signal will be emitted directly
            * without dragEnter, and in this case parent.index is undefined, so also
            * check if dndSpacer is in appletsModel.
            */
            if (typeof(dndSpacer.parent.index) === "number") {
                appletsModel.remove(dndSpacer.parent.index);
                root.fixedWidth = root.fixedHeight = 0;
            }
        }

        onDrop: event => {
            appletsModel.remove(dndSpacer.parent.index);
            root.processMimeData(event.mimeData, event.x, event.y);
            event.accept(event.proposedAction);
            root.fixedWidth = root.fixedHeight = 0;
        }

//BEGIN components
        Component {
            id: appletContainerComponent
            // This loader conditionally manages the BusyIndicator, it's not
            // loading the applet. The applet becomes a regular child item.
            Loader {
                id: container
                required property Item applet
                required property int index
                property Item dragging
                property bool isAppletContainer: true
                property bool isMarginSeparator: ((applet.plasmoid.constraintHints & PlasmaCore.Types.MarginAreasSeparator) == PlasmaCore.Types.MarginAreasSeparator)
                property int appletIndex: index // To make sure it's always readable even inside other models
                property bool inThickArea: false
                visible: applet.plasmoid.status !== PlasmaCore.Types.HiddenStatus || (!Plasmoid.immutable && Plasmoid.userConfiguring);

                //when the applet moves caused by its resize, don't animate.
                //this is completely heuristic, but looks way less "jumpy"
                property bool movingForResize: false

                Layout.fillWidth: applet && applet.Layout.fillWidth
                Layout.onFillWidthChanged: {
                    if (Plasmoid.formFactor !== PlasmaCore.Types.Vertical) {
                        checkLastSpacer();
                    }
                }
                Layout.fillHeight: applet && applet.Layout.fillHeight
                Layout.onFillHeightChanged: {
                    if (Plasmoid.formFactor === PlasmaCore.Types.Vertical) {
                        checkLastSpacer();
                    }
                }

                function getMargins(side, returnAllMargins = false, overrideFillArea = null, overrideThickArea = null): real {
                    if (!applet || !applet.plasmoid) {
                        return 0;
                    }
                    //Margins are either the size of the margins in the SVG, unless that prevents the panel from being at least half a smallMedium icon + smallSpace) tall at which point we set the margin to whatever allows it to be that...or if it still won't fit, 1.
                    let fillArea = overrideFillArea === null ? applet && (applet.plasmoid.constraintHints & PlasmaCore.Types.CanFillArea) : overrideFillArea
                    let inThickArea = overrideThickArea === null ? container.inThickArea : overrideThickArea
                    var layout = {
                        top: isHorizontal, bottom: isHorizontal,
                        right: !isHorizontal, left: !isHorizontal
                    };
                    return ((layout[side] || returnAllMargins) && !fillArea) ? Math.round(Math.min(dropArea.spacingAtMinSize, (inThickArea ? thickPanelSvg.fixedMargins[side] : panelSvg.fixedMargins[side]))) : 0;
                }

                Layout.topMargin: getMargins('top')
                Layout.bottomMargin: getMargins('bottom')
                Layout.leftMargin: getMargins('left')
                Layout.rightMargin: getMargins('right')

    // BEGIN BUG 454095: do not combine these expressions to a function or the bindings won't work
                Layout.minimumWidth: (root.isHorizontal ? (applet && applet.Layout.minimumWidth > 0 ? applet.Layout.minimumWidth : root.height) : root.width) - Layout.leftMargin - Layout.rightMargin
                Layout.minimumHeight: (!root.isHorizontal ? (applet && applet.Layout.minimumHeight > 0 ? applet.Layout.minimumHeight : root.width) : root.height) - Layout.bottomMargin - Layout.topMargin

                Layout.preferredWidth: (root.isHorizontal ? (applet && applet.Layout.preferredWidth > 0 ? applet.Layout.preferredWidth : root.height) : root.width) - Layout.leftMargin - Layout.rightMargin
                Layout.preferredHeight: (!root.isHorizontal ? (applet && applet.Layout.preferredHeight > 0 ? applet.Layout.preferredHeight : root.width) : root.height) - Layout.bottomMargin - Layout.topMargin

                Layout.maximumWidth: (root.isHorizontal ? (applet && applet.Layout.maximumWidth > 0 ? applet.Layout.maximumWidth : (Layout.fillWidth ? root.width : root.height)) : root.height) - Layout.leftMargin - Layout.rightMargin
                Layout.maximumHeight: (!root.isHorizontal ? (applet && applet.Layout.maximumHeight > 0 ? applet.Layout.maximumHeight : (Layout.fillHeight ? root.height : root.width)) : root.width) - Layout.bottomMargin - Layout.topMargin
    // END BUG 454095

                Item {
                    id: marginHighlightElements
                    anchors.fill: parent
                    // index -1 is for floating applets, which do not need a margin highlight
                    opacity: Plasmoid.containment.corona.editMode && dropArea.marginAreasEnabled && !root.dragAndDropping && index != -1 ? 1 : 0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: Kirigami.Units.longDuration
                            easing.type: Easing.InOutQuad
                        }
                    }

                    component SideMargin: KSvg.SvgItem {
                        property string side; property bool fill: true
                        property int inset; property int padding
                        property var west: ({'left': 'top', 'top': 'left', 'right': 'top', 'bottom': 'left'})
                        property var mirror: ({'left': 'right', 'top': 'bottom', 'right': 'left', 'bottom': 'top'})
                        property var onComponentCompleted: {
                            let left = west[side]
                            let right = mirror[left]
                            let up = mirror[side]
                            anchors[up] = undefined
                            if (root.isHorizontal) {
                                height = padding;
                            } else {
                                width = padding;
                            }
                            anchors[left+'Margin'] = - currentLayout.rowSpacing/2 - (appletIndex == 0 ? panelSvg.margins[left] + currentLayout.x : 0)
                            anchors[right+'Margin'] = - currentLayout.rowSpacing/2 - (appletIndex == appletsModel.count-1 ? panelSvg.margins[right] + currentLayout.toolBoxSize : 0)
                            anchors[side+'Margin'] = - inset
                        }
                        elementId: fill ? 'fill' : (root.isHorizontal ? side + (inThickArea ? 'left' : 'right') : (inThickArea ? 'top' : 'bottom') + side)
                        svg: dropArea.marginHighlightSvg
                        anchors {top: parent.top; left: parent.left; right: parent.right; bottom: parent.bottom}
                    }
                    Repeater {
                        model: ['top', 'bottom', 'right', 'left']
                        SideMargin {
                            side: modelData
                            inset: container.getMargins(side)
                            visible: (modelData === 'top' || modelData === 'bottom') === root.isHorizontal
                            padding: container.getMargins(side, false, false, isMarginSeparator ? false : inThickArea)
                        }
                    }
                    Repeater {
                        model: ['top', 'bottom', 'right', 'left']
                        SideMargin {
                            side: modelData
                            inset: -container.getMargins(side, false, false, false)
                            padding: container.getMargins(side, false, false, true) + inset
                            visible: isMarginSeparator && (modelData === 'top' || modelData === 'bottom') === root.isHorizontal
                            fill: false
                        }
                    }
                }

                onAppletChanged: {
                    if (applet) {
                        applet.parent = container
                        applet.anchors.fill = container
                    } else {
                        appletsModel.remove(index)
                    }
                }

                active: applet && applet.Plasmoid.busy
                sourceComponent: PlasmaComponents.BusyIndicator {
                    z: 999
                }

                property int oldX: 0
                property int oldY: 0
                onXChanged: if (oldX) animateFrom(oldX, y)
                onYChanged: if (oldY) animateFrom(x, oldY)
                transform: Translate{id: translation}
                function animateFrom(xa, ya) {
                    if (isHorizontal) translation.x = xa - x
                    else translation.y = ya - y
                    oldX = oldY = 0
                    translAnim.running = true
                }
                NumberAnimation {
                    id: translAnim
                    duration: Kirigami.Units.shortDuration
                    easing.type: Easing.OutCubic
                    target: translation
                    properties: "x,y"
                    to: 0
                }
            }
        }
//END components

//BEGIN UI elements

        anchors {
            leftMargin: isHorizontal ? Math.min(dropArea.spacingAtMinSize, panelSvg.fixedMargins.left) : 0
            rightMargin: isHorizontal ? Math.min(dropArea.spacingAtMinSize, panelSvg.fixedMargins.right) : 0
            topMargin: isHorizontal ? 0 : Math.min(dropArea.spacingAtMinSize, panelSvg.fixedMargins.top)
            bottomMargin: isHorizontal ? 0 : Math.min(dropArea.spacingAtMinSize, panelSvg.fixedMargins.bottom)
        }

        Item {
            id: dndSpacer
            property bool busy: false
            Layout.preferredWidth: width
            Layout.preferredHeight: height
            width: isHorizontal ? Kirigami.Units.iconSizes.sizeForLabels * 5 : currentLayout.width
            height: isHorizontal ? currentLayout.height : Kirigami.Units.iconSizes.sizeForLabels * 5
        }

        ListModel {
            id: appletsModel
        }

        GridLayout {
            id: currentLayout

            Repeater {
                model: appletsModel
                delegate: appletContainerComponent
            }

            rowSpacing: Kirigami.Units.smallSpacing
            columnSpacing: Kirigami.Units.smallSpacing

            x: Qt.application.layoutDirection === Qt.RightToLeft && isHorizontal ? toolBoxSize : 0;
            readonly property int toolBoxSize: !toolBox || !Plasmoid.containment.corona.editMode || Qt.application.layoutDirection === Qt.RightToLeft ? 0 : (isHorizontal ? toolBox.width : toolBox.height)

    // BEGIN BUG 454095: use lastSpacer to left align applets, as implicitWidth is updated too late
            width: root.width - (isHorizontal ? toolBoxSize : 0)
            height: root.height - (!isHorizontal ? toolBoxSize : 0)

            Item {
                id: lastSpacer
                visible: !root.hasSpacer
                    || lastSpacer.width === currentLayout.width /* When all widgets are still being loaded in a new panel */
                Layout.fillWidth: true
                Layout.fillHeight: true

                /**
                * This index will be used when adding a new panel.
                *
                * @see LayoutManager.indexAtCoordinates
                */
                readonly property alias index: appletsModel.count
            }
    // END BUG 454095

            rows: isHorizontal ? 1 : currentLayout.children.length
            columns: isHorizontal ? currentLayout.children.length : 1
            flow: isHorizontal ? GridLayout.LeftToRight : GridLayout.TopToBottom
            layoutDirection: Qt.application.layoutDirection
        }
    }
//END UI elements
}
