/*
    SPDX-FileCopyrightText: 2013 Alexander Mezin <mezin.alexander@gmail.com>

    SPDX-License-Identifier: GPL-2.0-or-later
*/
#include "touchpadservice.h"

#include <Plasma5Support/ServiceJob>

#include "touchpadinterface.h"

TouchpadService::TouchpadService(OrgKdeTouchpadInterface *daemon, const QString &destination, QObject *parent)
    : Plasma5Support::Service(parent)
    , m_daemon(daemon)
    , m_destination(destination)
{
    setName("touchpad");
}

TouchpadService::~TouchpadService()
{
}

class TouchpadJob : public Plasma5Support::ServiceJob
{
public:
    TouchpadJob(OrgKdeTouchpadInterface *daemon,
                const QString &destination,
                const QString &operation,
                const QMap<QString, QVariant> &parameters,
                QObject *parent = nullptr)
        : Plasma5Support::ServiceJob(destination, operation, parameters, parent)
        , m_daemon(daemon)
    {
    }

    void start() override
    {
        if (m_daemon) {
            QMetaObject::invokeMethod(m_daemon, operationName().toLatin1());
        }
        emitResult();
    }

private:
    OrgKdeTouchpadInterface *m_daemon;
};

Plasma5Support::ServiceJob *TouchpadService::createJob(const QString &operation, QMap<QString, QVariant> &params)
{
    return new TouchpadJob(m_daemon, m_destination, operation, params, this);
}
