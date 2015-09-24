/*
 * Copyright 2013-2015 Canonical Ltd.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#include <QtTest>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusInterface>
#include <QDBusReply>
#include <QDBusVariant>
#include <QDebug>
#include <QDBusObjectPath>

#include <unistd.h>
#include <sys/types.h>

#include "dbusunitysessionservice.h"

enum class Action : unsigned
{
  LOGOUT = 0,
  SHUTDOWN,
  REBOOT,
  NONE
};

class SessionBackendTest : public QObject
{
    Q_OBJECT

private Q_SLOTS:

    void initTestCase() {
        dbusUnitySession = new QDBusInterface ("com.canonical.Unity",
                                               "/com/canonical/Unity/Session",
                                               "com.canonical.Unity.Session",
                                               QDBusConnection::sessionBus(), this);

        m_fakeServer = new QProcess;
        m_fakeServer->start("python3 -m dbusmock org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager");
        m_fakeServer->waitForStarted();
        qDebug() << "Logind DBUS mock running with pid:" << m_fakeServer->processId();

        m_logindMockIface = new QDBusInterface("org.freedesktop.login1", "/org/freedesktop/login1", "org.freedesktop.DBus.Mock",
                                               QDBusConnection::sessionBus(), this);
        QTRY_VERIFY(m_logindMockIface->isValid());

        m_logindMockIface->call("AddTemplate", "logind", QVariant::fromValue(QVariantMap())); // load the logind template, no params

        // add a fake session to make DBusUnitySessionService happy
        QDBusReply<QString> fakeSession = m_logindMockIface->call("AddSession", "fakesession", "fakeseat", (quint32) getuid(),
                                                                  "fakeuser", true);

        if (!fakeSession.isValid()) {
            qWarning() << "Fake session error:" << fakeSession.error().name() << ":" << fakeSession.error().message();
            QFAIL("Fake session could not be found");
        }
        m_logindMockIface->call("AddMethod", "org.freedesktop.login1.Manager", "GetSessionByPID", "u", "o",
                                QStringLiteral("ret='%1'").arg(fakeSession)); // let DBUSS find the fake session to operate on
    }

    void cleanupTestCase() {
        m_fakeServer->terminate();
        m_fakeServer->waitForFinished();
        delete m_fakeServer;
    }

    void testUnitySessionService_data() {
        QTest::addColumn<QString>("method");
        QTest::addColumn<QString>("signal");

        QTest::newRow("Logout") << "RequestLogout" << "LogoutRequested(bool)";
        QTest::newRow("Reboot") << "RequestReboot" << "RebootRequested(bool)";
        QTest::newRow("Shutdown") << "RequestShutdown" << "ShutdownRequested(bool)";
        QTest::newRow("PromptLock") << "PromptLock" << "LockRequested()";
    }

    void testUnitySessionService() {
        QFETCH(QString, method);
        QFETCH(QString, signal);

        DBusUnitySessionService dbusUnitySessionService;
        QCoreApplication::processEvents(); // to let the service register on DBus

        // .. because QSignalSpy checks the signal signature like this: "if (((aSignal[0] - '0') & 0x03) != QSIGNAL_CODE)"
        QSignalSpy spy(&dbusUnitySessionService, qPrintable(signal.prepend(QSIGNAL_CODE)));

        QDBusReply<void> reply = dbusUnitySession->call(method);
        QCOMPARE(reply.isValid(), true);

        QCOMPARE(spy.count(), 1);
    }

    void testGnomeSessionWrapper_data() {
        QTest::addColumn<uint>("method");
        QTest::addColumn<QString>("signal");

        QTest::newRow("Logout") << (uint)Action::LOGOUT << "LogoutRequested(bool)";
        QTest::newRow("Shutdown") << (uint)Action::SHUTDOWN << "ShutdownRequested(bool)";
        QTest::newRow("Reboot") << (uint)Action::REBOOT << "RebootRequested(bool)";
    }

    void testGnomeSessionWrapper() {
        QFETCH(uint, method);
        QFETCH(QString, signal);

        DBusUnitySessionService dbusUnitySessionService;
        QCoreApplication::processEvents(); // to let the service register on DBus

        // Spy on the given signal on the /com/canonical/Unity/Session object
        // as proof we are actually calling the actual method.
        // .. because QSignalSpy checks the signal signature like this: "if (((aSignal[0] - '0') & 0x03) != QSIGNAL_CODE)"
        QSignalSpy spy(&dbusUnitySessionService, qPrintable(signal.prepend(QSIGNAL_CODE)));

        DBusGnomeSessionManagerWrapper dbusGnomeSessionManagerWrapper;
        QCoreApplication::processEvents(); // to let the service register on DBus

        QDBusInterface dbusGnomeSessionWrapper("com.canonical.Unity",
                                               "/org/gnome/SessionManager/EndSessionDialog",
                                               "org.gnome.SessionManager.EndSessionDialog",
                                               QDBusConnection::sessionBus());

        QCOMPARE(dbusGnomeSessionWrapper.isValid(), true);

        // Set the QVariant as a QList<QDBusObjectPath> type
        QDbusList var;
        QVariant inhibitors;
        inhibitors.setValue(var);

        QDBusReply<void> reply = dbusGnomeSessionWrapper.call("Open", method, (unsigned)0, (unsigned)0, inhibitors);
        QCOMPARE(reply.isValid(), true);

        // Make sure we see the signal being emitted.
        QCOMPARE(spy.count(), 1);
    }

    void testUserName() {
        DBusUnitySessionService dbusUnitySessionService;
        QCoreApplication::processEvents(); // to let the service register on DBus

        QProcess * proc = new QProcess(this);
        proc->start("id -un", QProcess::ReadOnly);
        proc->waitForFinished();
        const QByteArray out = proc->readAll().trimmed();

        QCOMPARE(dbusUnitySessionService.UserName(), QString::fromUtf8(out));
    }

    void testRealName() {
        DBusUnitySessionService dbusUnitySessionService;
        QCoreApplication::processEvents(); // to let the service register on DBus

        QDBusInterface accIface("org.freedesktop.Accounts", "/org/freedesktop/Accounts", "org.freedesktop.Accounts", QDBusConnection::systemBus());
        if (accIface.isValid()) {
            QDBusReply<QDBusObjectPath> userPath = accIface.asyncCall("FindUserById", static_cast<qint64>(geteuid()));
            if (userPath.isValid()) {
                QDBusInterface userAccIface("org.freedesktop.Accounts", userPath.value().path(), "org.freedesktop.Accounts.User", QDBusConnection::systemBus());
                QCOMPARE(dbusUnitySessionService.RealName(), userAccIface.property("RealName").toString());
            }
        }
    }

    void testLogin1Capabilities_data() {
        QTest::addColumn<QString>("method");

        QTest::newRow("CanHibernate") << "CanHibernate";
        QTest::newRow("CanSuspend") << "CanSuspend";
        QTest::newRow("CanReboot") << "CanReboot";
        QTest::newRow("CanPowerOff") << "CanPowerOff";
        QTest::newRow("CanHybridSleep") << "CanHybridSleep";
    }

    void testLogin1Capabilities() {
        QFETCH(QString, method);

        DBusUnitySessionService dbusUnitySessionService;
        QDBusInterface login1face("org.freedesktop.login1", "/org/freedesktop/login1", "org.freedesktop.login1.Manager", QDBusConnection::SM_BUSNAME());
        QCoreApplication::processEvents(); // to let the services register on DBus

        if (login1face.isValid()) {
            QDBusReply<QString> reply;
            if (method == "CanHibernate") {
                reply = login1face.call(method);
                QCOMPARE(dbusUnitySessionService.CanHibernate(), (reply == "yes" || reply == "challenge"));
            } else if (method == "CanSuspend") {
                reply = login1face.call(method);
                QCOMPARE(dbusUnitySessionService.CanSuspend(), (reply == "yes" || reply == "challenge"));
            } else if (method == "CanReboot") {
                reply = login1face.call(method);
                QCOMPARE(dbusUnitySessionService.CanReboot(), (reply == "yes" || reply == "challenge"));
            } else if (method == "CanPowerOff") {
                reply = login1face.call(method);
                QCOMPARE(dbusUnitySessionService.CanShutdown(), (reply == "yes" || reply == "challenge"));
            } else if (method == "CanHybridSleep") {
                reply = login1face.call(method);
                QCOMPARE(dbusUnitySessionService.CanHybridSleep(), (reply == "yes" || reply == "challenge"));
            }
        }
    }

private:
    QDBusInterface *dbusUnitySession;
    QProcess * m_fakeServer = nullptr;
    QDBusInterface *m_logindMockIface = nullptr;
};

QTEST_GUILESS_MAIN(SessionBackendTest)
#include "sessionbackendtest.moc"
