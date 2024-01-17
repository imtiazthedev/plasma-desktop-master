/*
    SPDX-FileCopyrightText: 2022 Alexander Lohnau <alexander.lohnau@gmx.de>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.1

import org.kde.config
import org.kde.kirigami 2.19 as Kirigami
import org.kde.kcmutils as KCMUtils
import org.kde.newstuff 1.91 as NewStuff

KCMUtils.ScrollViewKCM {
    id: root

    implicitWidth: Kirigami.Units.gridUnit * 32
    implicitHeight: Kirigami.Units.gridUnit * 18

    actions: [
        Kirigami.Action {
            icon.name: "configure"
            text: i18n("Configure KRunner…")
            onTriggered: kcm.showKRunnerKCM()
        },
        NewStuff.Action {
            text: i18n("Get New Plugins…")
            visible: KAuthorized.authorize(KAuthorized.GHNS)
            configFile: "krunner.knsrc"
            onEntryEvent: (entry, event) => {
                if (event === NewStuff.Engine.StatusChangedEvent) {
                    kcm.reloadPlugin()
                }
            }
        }
    ]

    header: ColumnLayout {
        spacing: Kirigami.Units.smallSpacing

        QQC2.Label {
            text: i18n("Enable or disable plugins (used in KRunner, Application Launcher, and the Overview effect)")
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        Kirigami.SearchField {
            id: searchField
            Layout.fillWidth: true
        }
    }

    view: KCMUtils.PluginSelector {
        sourceModel: kcm.model
        query: searchField.text
        delegate: KCMUtils.PluginDelegate {
            onConfigTriggered: kcm.showKCM(model.config, [], model.metaData)
            highlighted: false
            hoverEnabled: false
        }
    }
}
