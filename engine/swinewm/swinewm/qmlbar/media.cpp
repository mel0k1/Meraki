#include "media.h"

#include <QMetaObject>

#include <winrt/base.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Media.Control.h>
#include <winrt/Windows.Storage.Streams.h>

#include <mutex>
#include <utility>

namespace wmcs = winrt::Windows::Media::Control;

struct MerakiMedia::Impl {
        wmcs::GlobalSystemMediaTransportControlsSessionManager manager{nullptr};
        wmcs::GlobalSystemMediaTransportControlsSession session{nullptr};
        winrt::event_token sessionsToken{};
        winrt::event_token currentToken{};
        winrt::event_token infoToken{};
        winrt::event_token propsToken{};
        std::mutex lock;
        bool has = false;
        bool playing = false;
        QString title;
        QString artist;
        bool started = false;

        static void emitChanged(MerakiMedia *m) {
                QMetaObject::invokeMethod(m, [m]() { emit m->mediaChanged(); },
                        Qt::QueuedConnection);
        }

        void readProperties(MerakiMedia *m) {
                wmcs::GlobalSystemMediaTransportControlsSession s{nullptr};
                {
                        std::lock_guard<std::mutex> guard(lock);
                        s = session;
                }
                if (!s) {
                        return;
                }
                try {
                        auto props = s.TryGetMediaPropertiesAsync().get();
                        auto info = s.GetPlaybackInfo();
                        std::lock_guard<std::mutex> guard(lock);
                        has = true;
                        title = QString::fromWCharArray(props.Title().c_str());
                        artist = QString::fromWCharArray(props.Artist().c_str());
                        playing = info && info.PlaybackStatus() ==
                                wmcs::GlobalSystemMediaTransportControlsSessionPlaybackStatus::Playing;
                } catch (...) {
                }
                emitChanged(m);
        }

        void listen(MerakiMedia *m) {
                if (!session) {
                        return;
                }
                try {
                        infoToken = session.PlaybackInfoChanged(
                                [this, m](auto &&, auto &&) { readProperties(m); });
                        propsToken = session.MediaPropertiesChanged(
                                [this, m](auto &&, auto &&) { readProperties(m); });
                } catch (...) {
                }
        }

        void unlisten() {
                if (!session) {
                        return;
                }
                try {
                        session.PlaybackInfoChanged(infoToken);
                        session.MediaPropertiesChanged(propsToken);
                } catch (...) {
                }
        }

        void pickSession(MerakiMedia *m) {
                wmcs::GlobalSystemMediaTransportControlsSession next{nullptr};
                try {
                        if (manager) {
                                next = manager.GetCurrentSession();
                        }
                } catch (...) {
                        next = nullptr;
                }
                if (!next && manager) {
                        try {
                                auto all = manager.GetSessions();
                                if (all.Size() > 0) {
                                        next = all.GetAt(0);
                                }
                        } catch (...) {
                                next = nullptr;
                        }
                }
                {
                        std::lock_guard<std::mutex> guard(lock);
                        if (winrt::get_abi(next) == winrt::get_abi(session)) {
                                if (next) {
                                        readProperties(m);
                                }
                                return;
                        }
                }
                unlisten();
                {
                        std::lock_guard<std::mutex> guard(lock);
                        session = next;
                        if (!next) {
                                has = false;
                                playing = false;
                                title.clear();
                                artist.clear();
                        }
                }
                listen(m);
                if (next) {
                        readProperties(m);
                } else {
                        emitChanged(m);
                }
        }

        void subscribe(MerakiMedia *m) {
                try {
                        sessionsToken = manager.SessionsChanged(
                                [this, m](auto &&, auto &&) { pickSession(m); });
                        currentToken = manager.CurrentSessionChanged(
                                [this, m](auto &&, auto &&) { pickSession(m); });
                } catch (...) {
                }
                pickSession(m);
        }

        wmcs::GlobalSystemMediaTransportControlsSession current() {
                std::lock_guard<std::mutex> guard(lock);
                return session;
        }
};

MerakiMedia::MerakiMedia(QObject *parent) : QObject(parent), d(new Impl) {}

MerakiMedia::~MerakiMedia() {
        d->unlisten();
        try {
                if (d->manager) {
                        d->manager.SessionsChanged(d->sessionsToken);
                        d->manager.CurrentSessionChanged(d->currentToken);
                }
        } catch (...) {
        }
        delete d;
}

void MerakiMedia::start() {
        if (d->started) {
                return;
        }
        d->started = true;
        try {
                auto op = wmcs::GlobalSystemMediaTransportControlsSessionManager
                        ::RequestAsync();
                op.Completed([this](auto &&async, auto &&) {
                        try {
                                d->manager = async.GetResults();
                        } catch (...) {
                                return;
                        }
                        d->subscribe(this);
                });
        } catch (...) {
        }
}

bool MerakiMedia::hasSession() const {
        std::lock_guard<std::mutex> guard(d->lock);
        return d->has;
}

bool MerakiMedia::playing() const {
        std::lock_guard<std::mutex> guard(d->lock);
        return d->playing;
}

QString MerakiMedia::title() const {
        std::lock_guard<std::mutex> guard(d->lock);
        return d->title;
}

QString MerakiMedia::artist() const {
        std::lock_guard<std::mutex> guard(d->lock);
        return d->artist;
}

void MerakiMedia::togglePlay() {
        auto s = d->current();
        if (!s) {
                return;
        }
        try {
                s.TryTogglePlayPauseAsync();
        } catch (...) {
        }
}

void MerakiMedia::next() {
        auto s = d->current();
        if (!s) {
                return;
        }
        try {
                s.TrySkipNextAsync();
        } catch (...) {
        }
}

void MerakiMedia::previous() {
        auto s = d->current();
        if (!s) {
                return;
        }
        try {
                s.TrySkipPreviousAsync();
        } catch (...) {
        }
}

#include "moc_media.cpp"
