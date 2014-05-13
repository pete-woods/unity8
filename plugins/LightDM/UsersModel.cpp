/*
 * Copyright (C) 2013 Canonical, Ltd.
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
 * Author: Michael Terry <michael.terry@canonical.com>
 */

#include "UsersModel.h"
#include <QLightDM/UsersModel>
#include <QtCore/QSortFilterProxyModel>
#include <QDebug>

// First, we define an internal class that wraps LightDM's UsersModel.  This
// class will modify some of the data coming from LightDM.  For example, we
// modify any empty Real Names into just normal Names.
// (We can't modify the data directly in UsersModel below because it won't sort
// using the modified data.)
class MangleModel : public QSortFilterProxyModel
{
    Q_OBJECT

public:
    explicit MangleModel(QObject* parent=0);

    virtual QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const;
};

MangleModel::MangleModel(QObject* parent)
  : QSortFilterProxyModel(parent)
{
    setSourceModel(new QLightDM::UsersModel(this));
}

QVariant MangleModel::data(const QModelIndex &index, int role) const
{
    QVariant data = QSortFilterProxyModel::data(index, role);
    QVariant data2 = QSortFilterProxyModel::data(index, QLightDM::UsersModel::UidRole);
    qDebug() << "role" << role << data.toString() << QLightDM::UsersModel::UidRole << data2.toString();

    // If user's real name is empty, switch to unix name
    if (role == QLightDM::UsersModel::RealNameRole && data.toString().isEmpty()) {
        data = QSortFilterProxyModel::data(index, QLightDM::UsersModel::NameRole);
    } else if (role == QLightDM::UsersModel::BackgroundPathRole && data.toString().startsWith('#')) {
        data = "data:image/svg+xml,<svg><rect width='100%' height='100%' fill='" + data.toString() + "'/></svg>";
    }

    return data;
}

// **** Now we continue with actual UsersModel class ****

UsersModel::UsersModel(QObject* parent)
  : QSortFilterProxyModelQML(parent)
{
    setModel(new MangleModel(this));
    setSortCaseSensitivity(Qt::CaseInsensitive);
    setSortLocaleAware(true);
    setSortRole(QLightDM::UsersModel::RealNameRole);
    sort(0);
}

#include "UsersModel.moc"
