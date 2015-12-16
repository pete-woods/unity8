#include "TouchGestureArea.h"

// local
#include "TouchOwnershipEvent.h"
#include "TouchRegistry.h"
#include "UnownedTouchEvent.h"

#include <QGuiApplication>
#include <QStyleHints>
#include <private/qquickwindow_p.h>

#define TOUCHGESTUREAREA_DEBUG 0

namespace {

struct InternalStatus {
    enum Status {
        WaitingForTouch,
        Undecided,
        WaitingForOwnership, //Recognizing,
        Recognized,
        WaitingForRejection,
        Rejected
    };
};

TouchGestureArea::Status intenralStatusToGestureStatus(int internalStatus) {
    switch (internalStatus) {
        case InternalStatus::WaitingForTouch: return TouchGestureArea::WaitingForTouch;
        case InternalStatus::Undecided: return TouchGestureArea::Undecided;
        case InternalStatus::WaitingForOwnership: return TouchGestureArea::Undecided;
        case InternalStatus::Recognized: return TouchGestureArea::Recognized;
        case InternalStatus::WaitingForRejection: return TouchGestureArea::Recognized;
        case InternalStatus::Rejected: return TouchGestureArea::Rejected;
    }
    return TouchGestureArea::WaitingForTouch;
}

}

#if TOUCHGESTUREAREA_DEBUG
#define tgaDebug(params) qDebug().nospace() << "[TGA(" << qPrintable(objectName()) << ")] " << params
#include "DebugHelpers.h"

namespace {

const char *statusToString(int status)
{
    if (status == InternalStatus::WaitingForTouch) {
        return "WaitingForTouch";
    } else if (status == InternalStatus::Undecided) {
        return "Undecided";
    } else if (status == InternalStatus::WaitingForOwnership) {
        return "WaitingForOwnership";
    } else if (status == InternalStatus::Rejected) {
        return "Rejected";
    } else if (status == InternalStatus::WaitingForRejection) {
        return "WaitingForRejection";
    } else {
        return "Recognized";
    }
    return "Unknown";
}

QString touchState(Qt::TouchPointState state) {
    switch (state) {
        case Qt::TouchPointPressed: return "pressed";
        case Qt::TouchPointMoved: return "moved";
        case Qt::TouchPointStationary: return "stationary";
        case Qt::TouchPointReleased: return "released";
        break;
    }
    return "unknown";
}

QString touchesString(QList<QObject*> touches) {
    QString str;
    Q_FOREACH(QObject* object, touches) {
        GestureTouchPoint* touchPoint = qobject_cast<GestureTouchPoint*>(object);
        if (touchPoint) {
            str += QString("[%1 @ (%2, %3)], ").arg(touchPoint->id()).arg(touchPoint->x()).arg(touchPoint->y());
        }
    }
    return str;
}

QString touchesString(QList<GestureTouchPoint*> touches) {
    QString str;
    Q_FOREACH(GestureTouchPoint* touchPoint, touches) {
        str += QString("[%1 @ (%2, %3)], ").arg(touchPoint->id()).arg(touchPoint->x()).arg(touchPoint->y());
    }
    return str;
}

QString touchEventString(QTouchEvent* event) {
    if (!event) return QString();
    QString str;
    Q_FOREACH(const auto& touchPoint, event->touchPoints()) {
        str += QString("[%1:%2 @ (%3, %4)], ").arg(touchPoint.id())
                                              .arg(touchState(touchPoint.state()))
                                              .arg(touchPoint.pos().x())
                                              .arg(touchPoint.pos().y());
    }
    return str;
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
    , m_recognitionPeriod(50)
{
    setRecognitionTimer(new UbuntuGestures::Timer(this));
    m_recognitionTimer->setInterval(m_recognitionPeriod);
    m_recognitionTimer->setSingleShot(true);

    connect(this, &TouchGestureArea::recognitionPeriodChanged, this, [this]() {
        if (m_recognitionTimer) {
            m_recognitionTimer->setInterval(m_recognitionPeriod);
        }
    });
}

TouchGestureArea::~TouchGestureArea()
{
    clearTouchLists();
    qDeleteAll(m_liveTouchPoints);
    m_liveTouchPoints.clear();
    qDeleteAll(m_cachedTouchPoints);
    m_cachedTouchPoints.clear();
}

bool TouchGestureArea::event(QEvent *event)
{
    // Process unowned touch events (handles update/release for incomplete gestures)
    if (event->type() == TouchOwnershipEvent::touchOwnershipEventType()) {
        touchOwnershipEvent(static_cast<TouchOwnershipEvent *>(event));
        return true;
    } else if (event->type() == UnownedTouchEvent::unownedTouchEventType()) {
        unownedTouchEvent(static_cast<UnownedTouchEvent *>(event)->touchEvent());
        return true;
    }

    return QQuickItem::event(event);
}

void TouchGestureArea::touchOwnershipEvent(TouchOwnershipEvent *event)
{
    int touchId = event->touchId();
    tgaDebug("touchOwnershipEvent - id:" << touchId << ", gained:" << event->gained());

    if (event->gained()) {
        grabTouchPoints(QVector<int>() << touchId);
        m_candidateTouches.remove(touchId);
        TouchRegistry::instance()->addTouchWatcher(touchId, this);
        m_watchedTouches.insert(touchId);

        if (m_watchedTouches.count() >= m_minimumTouchPoints) {
            setInternalStatus(InternalStatus::Recognized);
        }
    } else {
        rejectGesture();
    }
}

void TouchGestureArea::touchEvent(QTouchEvent *event)
{
    if (!isEnabled() || !isVisible()) {
        tgaDebug(QString("NOT ENABLED touchEvent(%1) %2").arg(statusToString(m_status)).arg(touchEventString(event)));
        QQuickItem::touchEvent(event);
        return;
    }

    tgaDebug(QString("touchEvent(%1) %2").arg(statusToString(m_status)).arg(touchEventString(event)));

    switch (m_status) {
        case InternalStatus::WaitingForTouch:
            touchEvent_waitingForTouch(event);
            break;
        case InternalStatus::Undecided:
            touchEvent_undecided(event);
            break;
        case InternalStatus::WaitingForOwnership:
            touchEvent_waitingForOwnership(event);
            break;
        case InternalStatus::Recognized:
        case InternalStatus::WaitingForRejection:
            touchEvent_recognized(event);
            break;
        case InternalStatus::Rejected:
            touchEvent_rejected(event);
            break;
        default: // Recognized:
            break;
    }

    updateTouchPoints(event);
}

void TouchGestureArea::touchEvent_waitingForTouch(QTouchEvent *event)
{
    Q_FOREACH(const QTouchEvent::TouchPoint& touchPoint, event->touchPoints()) {
        Qt::TouchPointState touchPointState = touchPoint.state();
        int touchId = touchPoint.id();

        if (touchPointState == Qt::TouchPointPressed) {
            if (!m_candidateTouches.contains(touchId)) {
                TouchRegistry::instance()->addCandidateOwnerForTouch(touchId, this);
                m_candidateTouches.insert(touchId);
            }
        }
    }
    event->ignore();

    if (m_candidateTouches.count() > m_maximumTouchPoints) {
        rejectGesture();
    } else if (m_candidateTouches.count() >= m_minimumTouchPoints) {
        setInternalStatus(InternalStatus::WaitingForOwnership);

        QSet<int> tmpCandidates(m_candidateTouches);
        Q_FOREACH(int candidateTouchId, tmpCandidates) {
            TouchRegistry::instance()->requestTouchOwnership(candidateTouchId, this);
        }
        event->accept();
    } else if (m_candidateTouches.count() > 0) {
        setInternalStatus(InternalStatus::Undecided);
    }
}

void TouchGestureArea::touchEvent_undecided(QTouchEvent *event)
{
    Q_FOREACH(const QTouchEvent::TouchPoint& touchPoint, event->touchPoints()) {
        Qt::TouchPointState touchPointState = touchPoint.state();
        int touchId = touchPoint.id();

        if (touchPointState == Qt::TouchPointPressed) {
            if (!m_candidateTouches.contains(touchId)) {
                TouchRegistry::instance()->addCandidateOwnerForTouch(touchId, this);
                m_candidateTouches.insert(touchId);
            }
        }
    }
    event->ignore();

    if (m_candidateTouches.count() > m_maximumTouchPoints) {
        rejectGesture();
    } else if (m_candidateTouches.count() >= m_minimumTouchPoints) {
        setInternalStatus(InternalStatus::WaitingForOwnership);

        QSet<int> tmpCandidates(m_candidateTouches);
        Q_FOREACH(int candidateTouchId, tmpCandidates) {
            TouchRegistry::instance()->requestTouchOwnership(candidateTouchId, this);
        }
        event->accept();
    }
}

void TouchGestureArea::touchEvent_waitingForOwnership(QTouchEvent *event)
{
    Q_FOREACH(const QTouchEvent::TouchPoint& touchPoint, event->touchPoints()) {
        Qt::TouchPointState touchPointState = touchPoint.state();
        int touchId = touchPoint.id();

        if (touchPointState == Qt::TouchPointPressed) {
            if (!m_watchedTouches.contains(touchId)) {
                TouchRegistry::instance()->addTouchWatcher(touchId, this);
                m_watchedTouches.insert(touchId);
            }
        }
    }
}

void TouchGestureArea::touchEvent_recognized(QTouchEvent *event)
{
    Q_FOREACH(const QTouchEvent::TouchPoint& touchPoint, event->touchPoints()) {
        Qt::TouchPointState touchPointState = touchPoint.state();
        int touchId = touchPoint.id();

        if (touchPointState == Qt::TouchPointPressed) {
            if (!m_watchedTouches.contains(touchId)) {
                TouchRegistry::instance()->addTouchWatcher(touchId, this);
                m_watchedTouches.insert(touchId);
            }
        }
    }

    if (m_watchedTouches.count() > m_maximumTouchPoints) {
        rejectGesture();
    } else if (m_watchedTouches.count() >= m_minimumTouchPoints &&
               m_status==InternalStatus::WaitingForRejection) {
        setInternalStatus(InternalStatus::Recognized);
    }
}

void TouchGestureArea::touchEvent_rejected(QTouchEvent *event)
{
    Q_FOREACH(const QTouchEvent::TouchPoint& touchPoint, event->touchPoints()) {
        Qt::TouchPointState touchPointState = touchPoint.state();
        int touchId = touchPoint.id();

        if (touchPointState == Qt::TouchPointPressed) {
            if (!m_watchedTouches.contains(touchId)) {
                TouchRegistry::instance()->addTouchWatcher(touchId, this);
                m_watchedTouches.insert(touchId);
            }
        }
    }
}

void TouchGestureArea::unownedTouchEvent(QTouchEvent *unownedTouchEvent)
{
    tgaDebug(QString("unownedTouchEvent(%1) %2").arg(statusToString(m_status)).arg(touchEventString(unownedTouchEvent)));

    switch (m_status) {
        case InternalStatus::WaitingForTouch:
            break;
        case InternalStatus::Undecided:
            unownedTouchEvent_undecided(unownedTouchEvent);
            // do nothing
            break;
        case InternalStatus::WaitingForOwnership:
            unownedTouchEvent_waitingForOwnership(unownedTouchEvent);
            break;
        case InternalStatus::Recognized:
        case InternalStatus::WaitingForRejection:
            unownedTouchEvent_recognised(unownedTouchEvent);
            break;
        case InternalStatus::Rejected:
            unownedTouchEvent_rejected(unownedTouchEvent);
            break;
        default:
            break;
    }

    updateTouchPoints(unownedTouchEvent);
}

void TouchGestureArea::unownedTouchEvent_undecided(QTouchEvent *event)
{
    Q_FOREACH(const QTouchEvent::TouchPoint& touchPoint, event->touchPoints()) {
        Qt::TouchPointState touchPointState = touchPoint.state();
        int touchId = touchPoint.id();

        if (touchPointState == Qt::TouchPointReleased) {
            if (m_candidateTouches.contains(touchId)) {
                TouchRegistry::instance()->removeCandidateOwnerForTouch(touchId, this);
                m_candidateTouches.remove(touchId);
            }
        }
    }
    event->ignore();

    if (m_candidateTouches.count() == 0) {
        setInternalStatus(InternalStatus::WaitingForTouch);
    }
}

void TouchGestureArea::unownedTouchEvent_waitingForOwnership(QTouchEvent *event)
{
    Q_FOREACH(const QTouchEvent::TouchPoint& touchPoint, event->touchPoints()) {
        Qt::TouchPointState touchPointState = touchPoint.state();
        int touchId = touchPoint.id();

        if (touchPointState == Qt::TouchPointReleased) {
            if (m_candidateTouches.contains(touchId)) {
                TouchRegistry::instance()->removeCandidateOwnerForTouch(touchId, this);
                m_candidateTouches.remove(touchId);
            }
            if (m_watchedTouches.contains(touchId)) {
                m_watchedTouches.remove(touchId);
            }
        }
    }

    if (m_candidateTouches.count() + m_watchedTouches.count() == 0) {
        setInternalStatus(InternalStatus::WaitingForTouch);
    }
}

void TouchGestureArea::unownedTouchEvent_recognised(QTouchEvent *event)
{
    Q_FOREACH(const QTouchEvent::TouchPoint& touchPoint, event->touchPoints()) {
        Qt::TouchPointState touchPointState = touchPoint.state();
        int touchId = touchPoint.id();

        if (touchPointState == Qt::TouchPointReleased) {
            if (m_watchedTouches.contains(touchId)) {
                m_watchedTouches.remove(touchId);
            }
        }
    }

    if (m_watchedTouches.count() < m_minimumTouchPoints && m_status==InternalStatus::Recognized) {
       setInternalStatus(InternalStatus::WaitingForRejection);
    }
}

void TouchGestureArea::unownedTouchEvent_rejected(QTouchEvent *event)
{
    Q_FOREACH(const QTouchEvent::TouchPoint& touchPoint, event->touchPoints()) {
        Qt::TouchPointState touchPointState = touchPoint.state();
        int touchId = touchPoint.id();

        if (touchPointState == Qt::TouchPointPressed) {
            if (!m_watchedTouches.contains(touchId)) {
                TouchRegistry::instance()->addTouchWatcher(touchId, this);
                m_watchedTouches.insert(touchId);
            }
        }
        if (touchPointState == Qt::TouchPointReleased) {
            if (m_watchedTouches.contains(touchId)) {
                m_watchedTouches.remove(touchId);
            }
        }
    }

    if (m_watchedTouches.count() == 0) {
        setInternalStatus(InternalStatus::WaitingForTouch);
    }
}

void TouchGestureArea::updateTouchPoints(QTouchEvent *touchEvent)
{
    bool added = false;
    bool ended = false;
    bool moved = false;
    bool wantsDrag = false;

    const int dragThreshold = qApp->styleHints()->startDragDistance();
    const int dragVelocity = qApp->styleHints()->startDragVelocity();

    clearTouchLists();
    bool updateable = m_status != InternalStatus::WaitingForRejection;

    Q_FOREACH(const QTouchEvent::TouchPoint& touchPoint, touchEvent->touchPoints()) {
        Qt::TouchPointState touchPointState = touchPoint.state();
        int touchId = touchPoint.id();

        if (touchPointState & Qt::TouchPointReleased) {
            GestureTouchPoint* gtp = static_cast<GestureTouchPoint*>(m_liveTouchPoints.value(touchId));
            if (!gtp) continue;

            updateTouchPoint(gtp, &touchPoint);
            gtp->setPressed(false);
            m_releasedTouchPoints.append(gtp);
            m_liveTouchPoints.remove(touchId);

            if (updateable) {
                if (m_cachedTouchPoints.contains(touchId)) {
                    GestureTouchPoint* cachedPoint = m_cachedTouchPoints.take(touchId);
                    m_cachedTouchPoints.remove(touchId);
                    cachedPoint->deleteLater();
                }
            }
            ended = true;
        } else {
            GestureTouchPoint* gtp = m_liveTouchPoints.value(touchPoint.id(), nullptr);
            if (!gtp) {
                gtp = addTouchPoint(&touchPoint);
                m_pressedTouchPoints.append(gtp);

                if (updateable) {
                    if (m_cachedTouchPoints.contains(touchId)) {
                        updateTouchPoint(m_cachedTouchPoints[touchId], &touchPoint);
                    } else {
                        m_cachedTouchPoints[touchId] = new GestureTouchPoint(*gtp);
                    }
                }
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

                if (updateable) {
                    if (m_cachedTouchPoints.contains(touchId)) {
                        updateTouchPoint(m_cachedTouchPoints[touchId], &touchPoint);
                        if (overDragThreshold) {
                            m_cachedTouchPoints[touchId]->setDragging(true);
                        }
                    }
                }
            }
        }
    }

    if (updateable) {
        if (wantsDrag && !dragging()) {
            setDragging(true);
        }

        if (ended) {
            if (m_liveTouchPoints.isEmpty()) {
                if (!dragging()) Q_EMIT clicked();
                setDragging(false);
            }
            tgaDebug("Released " << touchesString(m_releasedTouchPoints));
            Q_EMIT released(m_releasedTouchPoints);
        }
        if (added) {
            tgaDebug("Pressed " << touchesString(m_pressedTouchPoints));
            Q_EMIT pressed(m_pressedTouchPoints);
        }
        if (moved) {
            tgaDebug("Updated " << touchesString(m_movedTouchPoints));
            Q_EMIT updated(m_movedTouchPoints);
        }
        if (added || ended || moved) {
            Q_EMIT touchPointsUpdated();
        }
    }
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

    m_status = newStatus;
    Q_EMIT statusChanged(status());

    if (oldStatus == InternalStatus::Undecided || oldStatus == InternalStatus::WaitingForRejection) {
        m_recognitionTimer->stop();
    }

    tgaDebug(statusToString(oldStatus) << " -> " << statusToString(newStatus));

    switch (newStatus) {
        case InternalStatus::WaitingForTouch:
            resyncCachedTouchPoints();
            break;
        case InternalStatus::Undecided:
            m_recognitionTimer->start();
            break;
        case InternalStatus::Recognized:
            resyncCachedTouchPoints();
            break;
        case InternalStatus::WaitingForRejection:
            m_recognitionTimer->start();
            break;
        case InternalStatus::Rejected:
            resyncCachedTouchPoints();
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
    connect(timer, SIGNAL(timeout()),
            this, SLOT(rejectGesture()));
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

int TouchGestureArea::recognitionPeriod() const
{
    return m_recognitionPeriod;
}

void TouchGestureArea::setRecognitionPeriod(int value)
{
    if (value != m_recognitionPeriod) {
        m_recognitionPeriod = value;
        Q_EMIT recognitionPeriodChanged(value);
    }
}

void TouchGestureArea::rejectGesture()
{
    tgaDebug("rejectGesture");
    ungrabTouchPoints();

    Q_FOREACH(int touchId, m_candidateTouches) {
        TouchRegistry::instance()->removeCandidateOwnerForTouch(touchId, this);
    }

    // Monitor the candidates
    Q_FOREACH(int touchId, m_candidateTouches) {
        TouchRegistry::instance()->addTouchWatcher(touchId, this);
        m_watchedTouches.insert(touchId);
    }
    m_candidateTouches.clear();

    if (m_watchedTouches.count() == 0) {
        setInternalStatus(InternalStatus::WaitingForTouch);
    } else {
        setInternalStatus(InternalStatus::Rejected);
    }
}

void TouchGestureArea::resyncCachedTouchPoints()
{
    clearTouchLists();

    bool added = false;
    bool ended = false;
    bool moved = false;
    bool wantsDrag = false;

    // list of deletes
    QMutableHashIterator<int, GestureTouchPoint*> removeIter(m_cachedTouchPoints);
    while(removeIter.hasNext()) {
        removeIter.next();
        if (!m_liveTouchPoints.contains(removeIter.key())) {
            m_releasedTouchPoints.append(removeIter.value());
            removeIter.remove();
            ended = true;
        }
    }

    // list of adds/moves
    Q_FOREACH(GestureTouchPoint* touchPoint, m_liveTouchPoints) {
        if (m_cachedTouchPoints.contains(touchPoint->id())) {
            GestureTouchPoint* cachedPoint = m_cachedTouchPoints[touchPoint->id()];

            if (*cachedPoint != *touchPoint) {
                *cachedPoint = *touchPoint;
                m_movedTouchPoints.append(touchPoint);
                moved = true;
            }
        } else {
            m_cachedTouchPoints.insert(touchPoint->id(), new GestureTouchPoint(*touchPoint));
            m_pressedTouchPoints.append(touchPoint);
            added = true;
        }
    }

    if (wantsDrag && !dragging()) {
        setDragging(true);
    }

    if (ended) {
        if (m_cachedTouchPoints.isEmpty()) {
            if (!dragging()) Q_EMIT clicked();
            setDragging(false);
        }
        tgaDebug("Cached Release " << touchesString(m_releasedTouchPoints));
        Q_EMIT released(m_releasedTouchPoints);
    }
    if (added) {
        tgaDebug("Cached Press " << touchesString(m_pressedTouchPoints));
        Q_EMIT pressed(m_pressedTouchPoints);
    }
    if (moved) {
        tgaDebug("Cached Update " << touchesString(m_movedTouchPoints));
        Q_EMIT updated(m_movedTouchPoints);
    }
    if (added || ended || moved) Q_EMIT touchPointsUpdated();

//    tgaDebug("Resync LiveTouches " << touchesString(m_liveTouchPoints.values()));
//    tgaDebug("Resync CachedTouches " << touchesString(m_cachedTouchPoints.values()));
}

int TouchGestureArea::touchPoint_count(QQmlListProperty<GestureTouchPoint> *list)
{
    TouchGestureArea *q = static_cast<TouchGestureArea*>(list->object);
    return q->m_cachedTouchPoints.count();
}

GestureTouchPoint *TouchGestureArea::touchPoint_at(QQmlListProperty<GestureTouchPoint> *list, int index)
{
    TouchGestureArea *q = static_cast<TouchGestureArea*>(list->object);
    return static_cast<GestureTouchPoint*>((q->m_cachedTouchPoints.begin()+index).value());
}

GestureTouchPoint* TouchGestureArea::addTouchPoint(QTouchEvent::TouchPoint const* tp)
{
    GestureTouchPoint* gtp = new GestureTouchPoint();
    gtp->setId(tp->id());
    gtp->setPressed(true);
    updateTouchPoint(gtp, tp);
    m_liveTouchPoints.insert(tp->id(), gtp);
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

    tgaDebug("setDragging " << dragging);

    m_dragging = dragging;
    Q_EMIT draggingChanged(m_dragging);
}

void GestureTouchPoint::setId(int id)
{
    if (m_id == id)
        return;
    m_id = id;
    Q_EMIT idChanged();
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
