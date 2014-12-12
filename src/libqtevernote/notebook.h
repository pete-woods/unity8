/*
 * Copyright: 2013 Canonical, Ltd
 *
 * This file is part of reminders
 *
 * reminders is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * reminders is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authors: Michael Zanetti <michael.zanetti@canonical.com>
 */

#ifndef NOTEBOOK_H
#define NOTEBOOK_H

#include <QObject>
#include <QDateTime>
#include <QSettings>

class Notebook : public QObject
{
    Q_OBJECT

    // Don't forget to update clone() if you add new properties
    Q_PROPERTY(QString guid READ guid NOTIFY guidChanged)
    Q_PROPERTY(QString name READ name WRITE setName NOTIFY nameChanged)
    Q_PROPERTY(int noteCount READ noteCount NOTIFY noteCountChanged)
    Q_PROPERTY(bool published READ published NOTIFY publishedChanged)
    Q_PROPERTY(QDateTime lastUpdated READ lastUpdated NOTIFY lastUpdatedChanged)
    Q_PROPERTY(QString lastUpdatedString READ lastUpdatedString NOTIFY lastUpdatedChanged)
    // Don't forget to update clone() if you add new properties

    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
    Q_PROPERTY(bool synced READ synced NOTIFY syncedChanged)

public:
    explicit Notebook(QString guid, quint32 updateSequenceNumber, QObject *parent = 0);

    QString guid() const;

    QString name() const;
    void setName(const QString &name);

    int noteCount() const;

    bool published() const;
    void setPublished(bool published);

    QDateTime lastUpdated() const;
    void setLastUpdated(const QDateTime &lastUpdated);

    QString lastUpdatedString() const;

    quint32 updateSequenceNumber() const;
    quint32 lastSyncedSequenceNumber() const;

    bool loading() const;
    bool synced() const;

    Notebook *clone();

public slots:
    void save();

signals:
    void guidChanged();
    void nameChanged();
    void noteCountChanged();
    void publishedChanged();
    void lastUpdatedChanged();
    void loadingChanged();
    void syncedChanged();

private slots:
    void noteAdded(const QString &noteGuid, const QString &notebookGuid);
    void noteRemoved(const QString &noteGuid, const QString &notebookGuid);
    void noteChanged(const QString &noteGuid, const QString &notebookGuid);
    void noteGuidChanged(const QString &oldGuid, const QString &newGuid);

private:
    void setGuid(const QString &guid);

    void setLoading(bool loading);
    void setUpdateSequenceNumber(quint32 updateSequenceNumber);
    void setLastSyncedSequenceNumber(quint32 lastSyncedSequenceNumber);

    void syncToInfoFile();

private:
    quint32 m_updateSequenceNumber;
    quint32 m_lastSyncedSequenceNumber;
    QString m_guid;
    QString m_name;
    bool m_published;
    QDateTime m_lastUpdated;
    QList<QString> m_notesList;

    QString m_infoFile;

    bool m_loading;
    bool m_synced;

    friend class NotesStore;
};

#endif // NOTEBOOK_H
