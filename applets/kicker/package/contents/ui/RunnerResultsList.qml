/*
    SPDX-FileCopyrightText: 2013-2014 Eike Hein <hein@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15

import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.kirigami 2.20 as Kirigami
import org.kde.ksvg 1.0 as KSvg
import org.kde.plasma.plasmoid 2.0

FocusScope {
    width: runnerMatches.width + vertLine.width + vertLine.anchors.leftMargin + runnerMatches.anchors.leftMargin
    height: parent.height

    signal keyNavigationAtListEnd

    property alias currentIndex: runnerMatches.currentIndex
    property alias count: runnerMatches.count
    property alias containsMouse: runnerMatches.containsMouse

    Accessible.name: header.text
    Accessible.role: Accessible.MenuItem

    KSvg.SvgItem {
        id: vertLine

        anchors.left: parent.left
        anchors.leftMargin: (index > 0 ) ? Kirigami.Units.smallSpacing : 0

        width: (index > 0 ) ? lineSvg.vertLineWidth : 0
        height: parent.height

        visible: (index > 0)

        svg: lineSvg
        elementId: "vertical-line"
    }

    PlasmaComponents3.Label {
        id: header

        anchors.left: vertLine.right

        width: runnerMatches.width
        height: runnerMatches.itemHeight + Kirigami.Units.smallSpacing

        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVTop

        textFormat: Text.PlainText
        wrapMode: Text.NoWrap
        elide: Text.ElideRight
        font.weight: Font.Bold

        text: (runnerMatches.model !== null) ? runnerMatches.model.name : ""
    }

    ItemListView {
        id: runnerMatches

        anchors.top: Plasmoid.configuration.alignResultsToBottom ? undefined : header.bottom
        anchors.bottom: Plasmoid.configuration.alignResultsToBottom ? parent.bottom : undefined
        anchors.bottomMargin: (index == 0 && anchors.bottom !== undefined) ? searchField.height + (2 * Kirigami.Units.smallSpacing) : undefined
        anchors.left: vertLine.right
        anchors.leftMargin: (index > 0) ? Kirigami.Units.smallSpacing : 0

        height: {
            var listHeight = (((index == 0)
                ? rootList.height : runnerColumns.height) - header.height);

            if (model && model.count) {
                return Math.min(favoriteSystemActions.height + favoriteApps.height - header.height, model.count * itemHeight);
            }

            return listHeight;
        }

        focus: true

        iconsEnabled: true
        keyNavigationWraps: (index != 0)

        resetOnExitDelay: 0

        model: runnerModel.modelForRow(index)

        onModelChanged: {
            if (model === undefined || model === null) {
                enabled: false;
                visible: false;
            }
        }

        onCountChanged: {
            if (index == 0 && searchField.focus) {
                currentIndex = 0;
            }
        }
    }

    Component.onCompleted: {
        runnerMatches.keyNavigationAtListEnd.connect(keyNavigationAtListEnd);
    }
}
