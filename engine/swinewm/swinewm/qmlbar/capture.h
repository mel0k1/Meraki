#ifndef MERAKI_CAPTURE_H
#define MERAKI_CAPTURE_H

#include <QImage>
#include <QObject>
#include <QQuickPaintedItem>
#include <QRectF>
#include <QTimer>
#include <QUrl>
#include <QVariant>

#include <map>
#include <memory>

class QQuickView;
class QTimerEvent;

class Grabber {
public:
    Grabber() = default;
    ~Grabber();
    Grabber(const Grabber &) = delete;
    Grabber &operator=(const Grabber &) = delete;

    bool start(void *hwnd);
    bool pump();
    const QImage &image() const { return m_image; }
    void stop();
    bool running() const { return m_running; }

private:
    struct Impl;
    std::unique_ptr<Impl> d;
    QImage m_image;
    bool m_running = false;
};

class LiveThumb : public QQuickPaintedItem {
    Q_OBJECT
    Q_PROPERTY(qint64 hwnd READ hwnd WRITE setHwnd NOTIFY hwndChanged)

public:
    explicit LiveThumb(QQuickItem *parent = nullptr);

    qint64 hwnd() const { return m_hwnd; }
    void setHwnd(qint64 hwnd);
    void paint(QPainter *painter) override;

signals:
    void hwndChanged();

protected:
    void timerEvent(QTimerEvent *event) override;

private:
    void stopTimer();

    qint64 m_hwnd = 0;
    Grabber m_grab;
    QImage m_image;
    int m_timerId = 0;
};

class MerakiFx : public QObject {
    Q_OBJECT
    Q_PROPERTY(QUrl snapshotUrl READ snapshotUrl NOTIFY snapshotUrlChanged)

public:
    explicit MerakiFx(QObject *parent = nullptr);

    void show();
    QUrl snapshotUrl() const { return m_snapshotUrl; }

    Q_INVOKABLE void beginMinimize(qint64 hwnd, qint64 id, qreal wx, qreal wy,
        qreal ww, qreal wh, qreal tx, qreal ty, qreal tw, qreal th);
    Q_INVOKABLE void beginRestore(qint64 hwnd, qint64 id, qreal tx, qreal ty,
        qreal tw, qreal th);
    Q_INVOKABLE void commitMinimize(qint64 hwnd);
    Q_INVOKABLE void commitRestore(qint64 hwnd, qint64 id);
    Q_INVOKABLE void finishJob(qint64 hwnd);
    Q_INVOKABLE void cancelJob(qint64 hwnd);

signals:
    void snapshotUrlChanged();
    void jobStarted(const QVariantMap &job);

private slots:
    void pump();

private:
    void restoreNow();

    struct Cache {
        QImage image;
        QRectF win;
    };

    QQuickView *m_view = nullptr;
    QObject *m_provider = nullptr;
    std::unique_ptr<Grabber> m_grab;
    QTimer *m_timer = nullptr;
    QVariantMap m_job;
    QUrl m_snapshotUrl;
    std::map<void *, Cache> m_cache;
    qreal m_dpr = 1.0;
    quint64 m_gen = 0;
    quint64 m_deadline = 0;
    bool m_busy = false;
    bool m_reverse = false;
};

#endif
