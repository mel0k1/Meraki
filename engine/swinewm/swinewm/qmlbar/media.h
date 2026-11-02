#ifndef MERAKI_MEDIA_H
#define MERAKI_MEDIA_H

#include <QObject>
#include <QString>

class MerakiMedia : public QObject {
        Q_OBJECT
        Q_PROPERTY(bool hasSession READ hasSession NOTIFY mediaChanged)
        Q_PROPERTY(bool playing READ playing NOTIFY mediaChanged)
        Q_PROPERTY(QString title READ title NOTIFY mediaChanged)
        Q_PROPERTY(QString artist READ artist NOTIFY mediaChanged)

public:
        explicit MerakiMedia(QObject *parent = nullptr);
        ~MerakiMedia() override;
        void start();

        bool hasSession() const;
        bool playing() const;
        QString title() const;
        QString artist() const;

        Q_INVOKABLE void togglePlay();
        Q_INVOKABLE void next();
        Q_INVOKABLE void previous();

signals:
        void mediaChanged();

private:
        struct Impl;
        Impl *d;
};

#endif
