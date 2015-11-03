/*
 * Copyright (C) 2015 Canonical, Ltd.
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
 */

#ifndef UNITY_INPUTWATCHER_H
#define UNITY_INPUTWATCHER_H

#include <QObject>
#include <QPointer>
#include <QQmlListProperty>
class QTouchEvent;

/*
  Monitors the target object for input events to figure out whether it's pressed
  or not.
 */
class InputWatcher : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QObject* target READ target WRITE setTarget NOTIFY targetChanged)

    // Whether the target object is pressed (by either touch or mouse)
    Q_PROPERTY(bool targetPressed READ targetPressed NOTIFY targetPressedChanged)

    Q_PROPERTY(int touchCount READ touchCount NOTIFY touchCountChanged DESIGNABLE false)
public:
    InputWatcher(QObject *parent = nullptr);

    QObject *target() const;
    void setTarget(QObject *value);

    bool targetPressed() const;

    int touchCount() const;

    bool eventFilter(QObject *watched, QEvent *event) override;

Q_SIGNALS:
    void targetChanged(QObject *value);
    void targetPressedChanged(bool value);
    void touchCountChanged(int touchCount);

private:
    void processTouchEvent(QTouchEvent *event);
    void setMousePressed(bool value);
    void setTouchCount(int value);

    static int touchPoint_count(QQmlListProperty<QPointF> *prop);
    static QPointF* touchPoint_at(QQmlListProperty<QPointF> *prop, int index);

    bool m_mousePressed;
    int m_touchCount;
    QPointer<QObject> m_target;
};

#endif // UNITY_INPUTWATCHER_H
