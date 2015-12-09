#include "TouchGestureArea.h"

// local
#include "TouchOwnershipEvent.h"
#include "TouchRegistry.h"
#include "UnownedTouchEvent.h"

#include <QGuiApplication>
#include <QStyleHints>
#include <private/qquickwindow_p.h>

#define TOUCHGESTUREAREA_DEBUG 1


#if TOUCHGESTUREAREA_DEBUG
#define tgaDebug(params) qDebug().nospace() << "[TGA(" << qPrintable(objectName()) << ")] " << params
#include "DebugHelpers.h"

namespace {

struct InternalStatus {
    enum Status {
        WaitingForTouch,
        Undecided, //Recognizing,
        Recognized,
        WaitingForRejection,
        Rejected
    };
};

TouchGestureArea::Status intenralStatusToGestureStatus(int internalStatus) {
    switch (internalStatus) {
        case InternalStatus::WaitingForTouch: return TouchGestureArea::WaitingForTouch;
        case InternalStatus::Undecided: return TouchGestureArea::Undecided;
        case InternalStatus::Recognized: return TouchGestureArea::Recognized;
        case InternalStatus::WaitingForRejection: return TouchGestureArea::Recognized;
        case InternalStatus::Rejected: return TouchGestureArea::Rejected;
    }
    return TouchGestureArea::WaitingForTouch;
}

const char *statusToString(int status)
{
    if (status == TouchGestureArea::WaitingForTouch) {
        return "WaitingForTouch";
    } else if (status == TouchGestureArea::Undecided) {
        return "Undecided";
    } else if (status == TouchGestureArea::Rejected) {
        return "Rejected";
    } else if (status == TouchGestureArea::WaitingForRejection) {
        return "WaitingForRejection";
    } else {
        return "Recognized";
    }
}

} // namespace {
#else // TOUCHGESTUREAREA_DEBUG
#define tgaDebug(params) ((void)0)
#endif // TOUCHGESTUREAREA_DEBUG


TouchGestureArea::TouchGestureArea(QQuickItem* parent)
    : QQuickItem(parent)
    , m_status(WaitingForTouch)
    , m_recognitionTimer(nullptr)
    , m_dragging(false)
    , m_minimumTouchPoints(1)
    , m_maximumTouchPoints(INT_MAX)
{
    setRecognitionTimer(new UbuntuGestures::Timer(this));
    m_recognitionTimer->setInterval(5000);
    m_recognitionTimer->setSingleShot(true);
}

TouchGestureArea::~TouchGestureArea()
{
    clearTouchLists();
    qDeleteAll(m_touchPoints);
    m_touchPoints.clear();
}

void TouchGestureArea::touchEvent(QTouchEvent *event)
{
    if (!isEnabled() || !isVisible()) {
        QQuickItem::touchEvent(event);
        return;
    }

    switch (m_status) {
        case InternalStatus::WaitingForTouch:
            touchEvent_absent(event);
            break;
        case InternalStatus::Undecided:
            touchEvent_undecided(event);
            break;
        case InternalStatus::Rejected:
            touchEvent_rejected(event);
            break;
        default: // Recognized:
            touchEvent_recognized(event);
            break;
    }

    processTouchEvents(event);
}

void TouchGestureArea::touchEvent_absent(QTouchEvent *event)
{
    tgaDebug("touchEvent_absent" << event << m_touchCandidates.count());

    Q_FOREACH(const QTouchEvent::TouchPoint& touchPoint, event->touchPoints()) {
        Qt::TouchPointState touchPointState = touchPoint.state();
        int touchId = touchPoint.id();

        if (touchPointState & Qt::TouchPointPressed && !m_touchCandidates.contains(touchId)) {
            TouchRegistry::instance()->addCandidateOwnerForTouch(touchId, this);
            m_touchCandidates.append(touchId);
        }
    }

    if (m_touchCandidates.count() > m_maximumTouchPoints) {
        rejectGesture();
        event->ignore();
    } else if (m_touchCandidates.count() >= m_minimumTouchPoints) {
        Q_FOREACH(int candidateTouchId, m_touchCandidates) {
            TouchRegistry::instance()->requestTouchOwnership(candidateTouchId, this);
        }
        setInternalStatus(InternalStatus::Recognized);
        event->accept();
    } else if (m_touchCandidates.count() > 0 ) {
        setInternalStatus(InternalStatus::Undecided);
        event->ignore();
    } else {
        event->ignore();
    }
}

void TouchGestureArea::touchEvent_undecided(QTouchEvent *event)
{
    tgaDebug("touchEvent_undecided" << event << m_touchCandidates.count());

    Q_FOREACH(const QTouchEvent::TouchPoint& touchPoint, event->touchPoints()) {
        Qt::TouchPointState touchPointState = touchPoint.state();
        int touchId = touchPoint.id();

        if (touchPointState & Qt::TouchPointPressed && !m_touchCandidates.contains(touchId)) {
            TouchRegistry::instance()->addCandidateOwnerForTouch(touchId, this);
            m_touchCandidates.append(touchId);
        }
    }

    if (m_touchCandidates.count() > m_maximumTouchPoints) {
        rejectGesture();
        event->ignore();
    } else if (m_touchCandidates.count() >= m_minimumTouchPoints) {
        Q_FOREACH(int candidateTouchId, m_touchCandidates) {
            TouchRegistry::instance()->requestTouchOwnership(candidateTouchId, this);
        }
        setInternalStatus(InternalStatus::Recognized);
        event->accept();
    } else {
        event->ignore();
    }
}

void TouchGestureArea::touchEvent_recognized(QTouchEvent *event)
{
    tgaDebug("touchEvent_recognized" << event << m_touchCandidates.count());

    Q_FOREACH(const QTouchEvent::TouchPoint& touchPoint, event->touchPoints()) {
        int touchId = touchPoint.id();

        if (touchPoint.state() & Qt::TouchPointPressed) {
            m_touchCandidates.append(touchId);
        } else if (touchPoint.state() & Qt::TouchPointReleased) {
            m_touchCandidates.removeAll(touchId);
        }
    }

    if (m_touchCandidates.count() == 0) {
        setInternalStatus(InternalStatus::WaitingForTouch);
    } else if (m_touchCandidates.count() > m_maximumTouchPoints) {
        rejectGesture();
        event->ignore();
    } else if (m_touchCandidates.count() < m_minimumTouchPoints) {
        setInternalStatus(InternalStatus::WaitingForRejection);
    } else if (m_status==InternalStatus::WaitingForRejection) {
        setInternalStatus(InternalStatus::Recognized);
    }
    event->accept();
}

void TouchGestureArea::touchEvent_rejected(QTouchEvent *event)
{
    tgaDebug("touchEvent_rejected" << event << m_touchCandidates.count());

    Q_FOREACH(const QTouchEvent::TouchPoint& touchPoint, event->touchPoints()) {
        Qt::TouchPointState touchPointState = touchPoint.state();
        int touchId = touchPoint.id();

        if (touchPointState & Qt::TouchPointReleased) {
            m_touchCandidates.removeAll(touchId);
        }
    }

    if (m_touchCandidates.count() == 0) {
        setInternalStatus(InternalStatus::WaitingForTouch);
    }
    event->accept();
}

bool TouchGestureArea::event(QEvent *event)
{
    // Process unowned touch events (handles update/release for incomplete gestures)
    if (event->type() == TouchOwnershipEvent::touchOwnershipEventType()) {
        touchOwnershipEvent(static_cast<TouchOwnershipEvent *>(event));
        return true;
    } else if (event->type() == UnownedTouchEvent::unownedTouchEventType()) {
        unownedTouchEvent(static_cast<UnownedTouchEvent *>(event));
        return true;
    }

    return QQuickItem::event(event);
}

void TouchGestureArea::touchOwnershipEvent(TouchOwnershipEvent *event)
{
    tgaDebug("touchOwnershipEvent" << event->gained());

    if (event->gained()) {
        grabTouchPoints(m_touchCandidates);
    } else {
        rejectGesture();
    }
}

void TouchGestureArea::unownedTouchEvent(UnownedTouchEvent *unownedTouchEvent)
{
    switch (m_status) {
        case InternalStatus::WaitingForTouch:
            // do nothing
            break;
        case InternalStatus::Undecided:
            Q_ASSERT(isEnabled() && isVisible());
            unownedTouchEvent_undecided(unownedTouchEvent);
            break;
        case InternalStatus::Rejected:
            unownedTouchEvent_rejected(unownedTouchEvent);
            break;
        default: // Recognized:
            tgaDebug("unownedTouchEvent_recognized");
            // do nothing
            break;
    }

    QTouchEvent* event = unownedTouchEvent->touchEvent();
    processTouchEvents(event);
}

void TouchGestureArea::unownedTouchEvent_undecided(UnownedTouchEvent *unownedTouchEvent)
{
    QTouchEvent* event = unownedTouchEvent->touchEvent();
    tgaDebug("unownedTouchEvent_undecided" << event << m_touchCandidates.count());

    Q_FOREACH(const QTouchEvent::TouchPoint& touchPoint, event->touchPoints()) {
        int touchId = touchPoint.id();

        if (touchPoint.state() & Qt::TouchPointReleased) {
            // touch has ended before recognition concluded
            TouchRegistry::instance()->removeCandidateOwnerForTouch(touchId, this);
            m_touchCandidates.removeAll(touchId);
        }
    }

    if (m_touchCandidates.count() == 0) {
        setInternalStatus(InternalStatus::WaitingForTouch);
    }
}

void TouchGestureArea::unownedTouchEvent_rejected(UnownedTouchEvent *unownedTouchEvent)
{
    QTouchEvent* event = unownedTouchEvent->touchEvent();
    tgaDebug("unownedTouchEvent_rejected" << event << m_touchCandidates.count());

    Q_FOREACH(const QTouchEvent::TouchPoint& touchPoint, event->touchPoints()) {
        if (touchPoint.state() & Qt::TouchPointReleased) {
            m_touchCandidates.removeAll(touchPoint.id());
        }
    }

    if (m_touchCandidates.count() == 0) {
        setInternalStatus(InternalStatus::WaitingForTouch);
    }
}

void TouchGestureArea::processTouchEvents(QTouchEvent *touchEvent)
{
    bool added = false;
    bool ended = false;
    bool moved = false;
    bool wantsDrag = false;

    const int dragThreshold = qApp->styleHints()->startDragDistance();
    const int dragVelocity = qApp->styleHints()->startDragVelocity();

    clearTouchLists();

    Q_FOREACH(const QTouchEvent::TouchPoint& touchPoint, touchEvent->touchPoints()) {
        Qt::TouchPointState touchPointState = touchPoint.state();
        int touchId = touchPoint.id();

        if (touchPointState & Qt::TouchPointReleased) {
            GestureTouchPoint* gtp = static_cast<GestureTouchPoint*>(m_touchPoints.value(touchId));
            if (!gtp) continue;

            updateTouchPoint(gtp, &touchPoint);
            gtp->setPressed(false);
            m_releasedTouchPoints.append(gtp);
            m_touchPoints.remove(touchId);
            ended = true;
        } else {
            GestureTouchPoint* gtp = m_touchPoints.value(touchPoint.id(), nullptr);
            if (!gtp) {
                gtp = addTouchPoint(&touchPoint);
                m_pressedTouchPoints.append(gtp);
                added = true;
            } else if (touchPointState & Qt::TouchPointMoved) {
                updateTouchPoint(gtp, &touchPoint);
                m_movedTouchPoints.append(gtp);
                moved = true;

                const QPointF &currentPos = touchPoint.scenePos();
                const QPointF &startPos = touchPoint.startScenePos();

                bool overDragThreshold = false;
                bool supportsVelocity = (touchEvent->device()->capabilities() & QTouchDevice::Velocity) && dragVelocity;
                overDragThreshold |= qAbs(currentPos.x() - startPos.x()) > dragThreshold ||
                                     qAbs(currentPos.y() - startPos.y()) > dragThreshold;
                if (supportsVelocity) {
                    QVector2D velocityVec = touchPoint.velocity();
                    overDragThreshold |= qAbs(velocityVec.x()) > dragVelocity;
                    overDragThreshold |= qAbs(velocityVec.y()) > dragVelocity;
                }

                if (overDragThreshold) {
                    gtp->setDragging(true);
                    wantsDrag = true;
                }
            } else {
                updateTouchPoint(gtp, &touchPoint);
            }
        }
    }

    if (wantsDrag && !dragging()) {
        setDragging(true);
    }

    if (ended) {
        if (m_touchPoints.isEmpty()) {
            if (!dragging()) Q_EMIT clicked();
            setDragging(false);
        }
        tgaDebug("Released" << m_releasedTouchPoints);
        Q_EMIT released(m_releasedTouchPoints);
    }
    if (added) {
        tgaDebug("Pressed" << m_pressedTouchPoints);
        Q_EMIT pressed(m_pressedTouchPoints);
    }
    if (moved) {
        tgaDebug("Updated" << m_movedTouchPoints);
        Q_EMIT updated(m_movedTouchPoints);
    }
    if (added || ended || moved) Q_EMIT touchPointsUpdated();
}

void TouchGestureArea::clearTouchLists()
{
    Q_FOREACH (QObject *gtp, m_releasedTouchPoints) {
        delete gtp;
    }
    m_releasedTouchPoints.clear();
    m_pressedTouchPoints.clear();
    m_movedTouchPoints.clear();
}

void TouchGestureArea::setInternalStatus(uint newStatus)
{
    if (newStatus == m_status)
        return;

    uint oldStatus = m_status;

    if (oldStatus == InternalStatus::Undecided || oldStatus == InternalStatus::WaitingForRejection) {
        m_recognitionTimer->stop();
    }

    m_status = newStatus;
    Q_EMIT statusChanged(status());

    switch (newStatus) {
        case InternalStatus::WaitingForTouch:
            tgaDebug("setInternalStatus(WaitingForTouch)");
            clearTouchLists();
            break;
        case InternalStatus::Undecided:
            tgaDebug("setInternalStatus(Undecided)");
            m_recognitionTimer->start();
            break;
        case InternalStatus::Recognized:
            tgaDebug("setInternalStatus(Recognised)");
            break;
        case InternalStatus::WaitingForRejection:
            tgaDebug("setInternalStatus(WaitingForRejection)");
            m_recognitionTimer->start();
        case InternalStatus::Rejected:
            tgaDebug("setInternalStatus(Rejected)");
            break;
        default:
            // no-op
            break;
    }
}

void TouchGestureArea::setRecognitionTimer(UbuntuGestures::AbstractTimer *timer)
{
    int interval = 0;
    bool timerWasRunning = false;
    bool wasSingleShot = false;

    // can be null when called from the constructor
    if (m_recognitionTimer) {
        interval = m_recognitionTimer->interval();
        timerWasRunning = m_recognitionTimer->isRunning();
        if (m_recognitionTimer->parent() == this) {
            delete m_recognitionTimer;
        }
    }

    m_recognitionTimer = timer;
    timer->setInterval(interval);
    timer->setSingleShot(wasSingleShot);
    connect(timer, &UbuntuGestures::AbstractTimer::timeout,
            this, &TouchGestureArea::rejectGesture);
    if (timerWasRunning) {
        m_recognitionTimer->start();
    }
}

int TouchGestureArea::status() const
{
    return intenralStatusToGestureStatus(m_status);
}

bool TouchGestureArea::dragging() const
{
    return m_dragging;
}

QQmlListProperty<GestureTouchPoint> TouchGestureArea::touchPoints()
{
    return QQmlListProperty<GestureTouchPoint>(this,
                                                    0,
                                                    nullptr,
                                                    TouchGestureArea::touchPoint_count,
                                                    TouchGestureArea::touchPoint_at,
                                               0);
}

int TouchGestureArea::minimumTouchPoints() const
{
    return m_minimumTouchPoints;
}

void TouchGestureArea::setMinimumTouchPoints(int value)
{
    if (m_minimumTouchPoints != value) {
        m_minimumTouchPoints = value;
        Q_EMIT minimumTouchPointsChanged(value);
    }
}

int TouchGestureArea::maximumTouchPoints() const
{
    return m_maximumTouchPoints;
}

void TouchGestureArea::setMaximumTouchPoints(int value)
{
    if (m_maximumTouchPoints != value) {
        m_maximumTouchPoints = value;
        Q_EMIT maximumTouchPointsChanged(value);
    }
}

void TouchGestureArea::rejectGesture()
{
    if (m_status == InternalStatus::Undecided || m_status == InternalStatus::WaitingForTouch) {
        tgaDebug("rejectGesture()");

        Q_FOREACH(int touchId, m_touchCandidates) {
            TouchRegistry::instance()->removeCandidateOwnerForTouch(touchId, this);
            TouchRegistry::instance()->addTouchWatcher(touchId, this);
        }
    } else if (m_status == InternalStatus::Recognized || m_status == InternalStatus::WaitingForRejection) {
        Q_FOREACH(int touchId, m_touchCandidates) {
            TouchRegistry::instance()->addTouchWatcher(touchId, this);
        }
    }
    setInternalStatus(InternalStatus::Rejected);
}

int TouchGestureArea::touchPoint_count(QQmlListProperty<GestureTouchPoint> *list)
{
    TouchGestureArea *q = static_cast<TouchGestureArea*>(list->object);
    return q->m_touchPoints.count();
}

GestureTouchPoint *TouchGestureArea::touchPoint_at(QQmlListProperty<GestureTouchPoint> *list, int index)
{
    TouchGestureArea *q = static_cast<TouchGestureArea*>(list->object);
    return static_cast<GestureTouchPoint*>((q->m_touchPoints.begin()+index).value());
}

GestureTouchPoint* TouchGestureArea::addTouchPoint(QTouchEvent::TouchPoint const* tp)
{
    GestureTouchPoint* gtp = new GestureTouchPoint();
    gtp->setPointId(tp->id());
    gtp->setPressed(true);
    updateTouchPoint(gtp, tp);
    m_touchPoints.insert(tp->id(), gtp);
    return gtp;
}

void TouchGestureArea::updateTouchPoint(GestureTouchPoint* gtp, QTouchEvent::TouchPoint const* tp)
{
    gtp->setX(tp->pos().x());
    gtp->setY(tp->pos().y());
}

void TouchGestureArea::setDragging(bool dragging)
{
    if (m_dragging == dragging)
        return;
    m_dragging = dragging;
    Q_EMIT draggingChanged(m_dragging);
}

void GestureTouchPoint::setPointId(int id)
{
    if (m_id == id)
        return;
    m_id = id;
    Q_EMIT pointIdChanged();
}

void GestureTouchPoint::setPressed(bool pressed)
{
    if (m_pressed == pressed)
        return;
    m_pressed = pressed;
    Q_EMIT pressedChanged();
}

void GestureTouchPoint::setX(qreal x)
{
    if (m_x == x)
        return;
    m_x = x;
    Q_EMIT xChanged();
}

void GestureTouchPoint::setY(qreal y)
{
    if (m_y == y)
        return;
    m_y = y;
    Q_EMIT yChanged();
}

void GestureTouchPoint::setDragging(bool dragging)
{
    if (m_dragging == dragging)
        return;

    m_dragging = dragging;
    Q_EMIT draggingChanged();
}
