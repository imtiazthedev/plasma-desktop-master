/*
    SPDX-FileCopyrightText: 2022 Tanbir Jishan <tantalising007@gmail.com>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick 2.15
import QtQml 2.15
import org.kde.plasma.core 2.0 as PlasmaCore

KickoffListView {
    id: root
    required property var gridModel

    highlight: null // highlight off since it otherwise highlights a whole section
    model: gridModel.sections
    section.property: "section"
    delegate: ListOfGridsViewDelegate {
        width: root.width

        allAppsSection: section
        isCurrentSectionGrid: ListView.isCurrentItem
        isSearchFieldActive: kickoff.contentArea === root && kickoff.searchField.activeFocus
        parentView: ListView.view
        gridIndex: index

        model: PlasmaCore.SortFilterModel {
            id: sectionModel

            sourceModel: root.gridModel
            filterRegExp: allAppsSection
            filterRole: "group"

            function trigger(row, actionId, argument) {
                const filteredIndex = sectionModel.index(row, 0)
                const sourceIndex = sectionModel.mapToSource(filteredIndex)
                sourceModel.trigger(sourceIndex.row, actionId, argument)
            }
        }
        onShowSectionView: root.showSectionViewRequested(sectionName)
    }
}
