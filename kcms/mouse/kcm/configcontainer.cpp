/*
    SPDX-FileCopyrightText: 2018 Roman Gilg <subdiff@gmail.com>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include "configcontainer.h"

#include "configplugin.h"
#include "inputbackend.h"

#include <KWindowSystem>

#include <memory> // std::unique_ptr

extern "C" {
Q_DECL_EXPORT void kcminit()
{
    std::unique_ptr<InputBackend> backend(InputBackend::implementation());
    backend->kcmInit();
}
}

ConfigContainer::ConfigContainer(QObject *parent, const KPluginMetaData &data)
    : KCModule(parent, data)
{
    m_plugin = ConfigPlugin::implementation(this);
}

/*QSize ConfigContainer::minimumSizeHint() const
{
    return m_plugin->minimumSizeHint();
}
QSize ConfigContainer::sizeHint() const
{
    return m_plugin->sizeHint();
}
void ConfigContainer::resizeEvent(QResizeEvent *event)
{
    Q_UNUSED(event);
    m_plugin->resize(this->size());
}
*/

void ConfigContainer::load()
{
    m_plugin->load();
}

void ConfigContainer::save()
{
    m_plugin->save();
}

void ConfigContainer::defaults()
{
    m_plugin->defaults();
}

/*void ConfigContainer::hideEvent(QHideEvent *e)
{
    m_plugin->hideEvent(e);
    KCModule::hideEvent(e);
}

*/
