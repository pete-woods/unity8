/*
 * Copyright (C) 2014 Canonical, Ltd.
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
 *
 * Authors: Michael Zanetti <michael.zanetti@canonical.com>
 */

#include "plugin.h"
#include "dashcommunicator.h"
#include "dashcommunicatorservice.h"

#include <QDBusConnection>
#include <QtQml/qqml.h>

void DashCommunicatorPlugin::registerTypes(const char *uri)
{
    // @uri Unity.DashCommunicator
    Q_ASSERT(uri == QStringLiteral("Unity.DashCommunicator"));
    qmlRegisterType<DashCommunicatorService>(uri, 0, 1, "DashCommunicatorService");
    qmlRegisterType<DashCommunicator>(uri, 0, 1, "DashCommunicator");
}