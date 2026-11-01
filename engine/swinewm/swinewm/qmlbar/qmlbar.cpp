#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#include <shellapi.h>
#include <shlobj_core.h>
#include <commoncontrols.h>

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QImage>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QMetaObject>
#include <QQmlContext>
#include <QQuickImageProvider>
#include <QQuickView>
#include <QRect>
#include <QScreen>
#include <QSurfaceFormat>
#include <QTimer>
#include <QUrl>
#include <QVariantMap>

#include <algorithm>
#include <cmath>
#include <cstring>
#include <functional>
#include <map>
#include <string>

extern "C" {
#include "ipc-client.h"
#include "ipc.h"
#include "qmlbar.h"
}

static QString meraki_home_dir() {
        QString home = qEnvironmentVariable("USERPROFILE");
        if (home.isEmpty()) {
                home = qEnvironmentVariable("HOME");
        }
        return home;
}

static QString meraki_cache_dir() {
        QString dir = meraki_home_dir() + "/.swinewm/cache/icons";
        QDir().mkpath(dir);
        return dir;
}

static QImage meraki_hicon_to_image(HICON icon) {
        ICONINFO info = {};
        if (!GetIconInfo(icon, &info)) {
                return QImage();
        }
        BITMAP bm = {};
        QImage img;
        if (info.hbmColor && GetObjectW(info.hbmColor, sizeof(bm), &bm) && bm.bmWidth > 0) {
                img = QImage(bm.bmWidth, bm.bmHeight, QImage::Format_ARGB32);
                BITMAPINFOHEADER bi = {};
                bi.biSize = sizeof(bi);
                bi.biWidth = bm.bmWidth;
                bi.biHeight = -bm.bmHeight;
                bi.biPlanes = 1;
                bi.biBitCount = 32;
                bi.biCompression = BI_RGB;
                HDC dc = GetDC(nullptr);
                int rows = GetDIBits(dc, info.hbmColor, 0, bm.bmHeight, img.bits(),
                        (BITMAPINFO *)&bi, DIB_RGB_COLORS);
                ReleaseDC(nullptr, dc);
                if (rows != bm.bmHeight) {
                        img = QImage();
                }
        }
        if (info.hbmColor) {
                DeleteObject(info.hbmColor);
        }
        if (info.hbmMask) {
                DeleteObject(info.hbmMask);
        }
        if (!img.isNull()) {
                bool alpha = false;
                for (int y = 0; y < img.height() && !alpha; ++y) {
                        const QRgb *line = (const QRgb *)img.constScanLine(y);
                        for (int x = 0; x < img.width(); ++x) {
                                if (qAlpha(line[x]) != 0) {
                                        alpha = true;
                                        break;
                                }
                        }
                }
                if (!alpha) {
                        for (int y = 0; y < img.height(); ++y) {
                                QRgb *line = (QRgb *)img.scanLine(y);
                                for (int x = 0; x < img.width(); ++x) {
                                        int g = qGray(line[x]);
                                        line[x] = qRgba(qRed(line[x]), qGreen(line[x]),
                                                qBlue(line[x]), 255 - g);
                                }
                        }
                }
        }
        return img;
}

static std::map<std::string, std::string> g_exe_paths;
static std::map<std::string, QPixmap> g_icon_cache;

static QString meraki_exe_for(const QString &key) {
        std::string k = key.toLower().toStdString();
        auto it = g_exe_paths.find(k);
        if (it != g_exe_paths.end()) {
                return QString::fromStdString(it->second);
        }
        std::string alt = k + ".exe";
        it = g_exe_paths.find(alt);
        if (it != g_exe_paths.end()) {
                return QString::fromStdString(it->second);
        }
        QString probe = key.endsWith(".exe", Qt::CaseInsensitive) ? key : key + ".exe";
        wchar_t buf[MAX_PATH];
        if (SearchPathW(nullptr, (LPCWSTR)probe.utf16(), L".exe", MAX_PATH, buf, nullptr) > 0) {
                return QString::fromWCharArray(buf);
        }
        return QString();
}

static QImage meraki_extract_icon(const QString &exe) {
        if (exe.isEmpty()) {
                return QImage();
        }
        SHFILEINFOW sfi = {};
        if (!SHGetFileInfoW((LPCWSTR)exe.utf16(), 0, &sfi, sizeof(sfi), SHGFI_SYSICONINDEX)) {
                return QImage();
        }
        IImageList *list = nullptr;
        if (FAILED(SHGetImageList(SHIL_JUMBO, IID_IImageList, (void **)&list))) {
                return QImage();
        }
        HICON icon = nullptr;
        list->GetIcon(sfi.iIcon, ILD_TRANSPARENT, &icon);
        list->Release();
        if (!icon) {
                return QImage();
        }
        QImage img = meraki_hicon_to_image(icon);
        DestroyIcon(icon);
        return img;
}

static QPixmap meraki_icon_for(const QString &key) {
        QString k = key.toLower();
        std::string ks = k.toStdString();
        auto it = g_icon_cache.find(ks);
        if (it != g_icon_cache.end()) {
                return it->second;
        }
        QPixmap pm;
        QString safe;
        for (const QChar &c : k) {
                safe.append(c.isLetterOrNumber() ? c : QLatin1Char('_'));
        }
        QString cachePath = meraki_cache_dir() + "/" + safe + ".png";
        if (QFileInfo::exists(cachePath)) {
                pm = QPixmap(cachePath);
        }
        if (pm.isNull()) {
                QImage img = meraki_extract_icon(meraki_exe_for(k));
                if (!img.isNull()) {
                        img.save(cachePath, "PNG");
                        pm = QPixmap::fromImage(img);
                }
        }
        if (pm.isNull()) {
                HICON icon = (HICON)LoadImageW(nullptr, IDI_APPLICATION, IMAGE_ICON,
                        256, 256, LR_SHARED);
                if (icon) {
                        QImage img = meraki_hicon_to_image(icon);
                        if (!img.isNull()) {
                                pm = QPixmap::fromImage(img);
                        }
                }
        }
        g_icon_cache[ks] = pm;
        return pm;
}

class DockIconProvider : public QQuickImageProvider {
public:
        DockIconProvider() : QQuickImageProvider(QQuickImageProvider::Pixmap) {}

        QPixmap requestPixmap(const QString &id, QSize *size, const QSize &requested) override {
                QPixmap pm = meraki_icon_for(id);
                if (size) {
                        *size = pm.size();
                }
                if (requested.isValid() && requested.width() > 0 && requested.height() > 0) {
                        return pm.scaled(requested, Qt::KeepAspectRatio, Qt::SmoothTransformation);
                }
                return pm;
        }
};

class MerakiDock : public QObject {
        Q_OBJECT
        Q_PROPERTY(QVariantList windows READ windows NOTIFY windowsChanged)
        Q_PROPERTY(QVariantList pins MEMBER m_pins CONSTANT)
        Q_PROPERTY(QVariantMap launching READ launching NOTIFY launchingChanged)
        Q_PROPERTY(int screenWidth READ screenWidth CONSTANT)
        Q_PROPERTY(int screenHeight READ screenHeight CONSTANT)
        Q_PROPERTY(QUrl wallpaper READ wallpaper CONSTANT)
        Q_PROPERTY(qreal dockWidth MEMBER m_dockWidth)
        Q_PROPERTY(bool dockHovered MEMBER m_dockHovered)
        Q_PROPERTY(qreal dockRestHeight MEMBER m_restHeight)

public:
        explicit MerakiDock(QObject *parent = nullptr) : QObject(parent) {
                loadPins();
                m_regionTimer = new QTimer(this);
                m_regionTimer->setInterval(120);
                connect(m_regionTimer, &QTimer::timeout, this, &MerakiDock::updateRegion);
                m_regionTimer->start();
                m_pollTimer = new QTimer(this);
                m_pollTimer->setInterval(1500);
                connect(m_pollTimer, &QTimer::timeout, this, &MerakiDock::refresh);
                m_pollTimer->start();
                m_launchTimer = new QTimer(this);
                m_launchTimer->setInterval(300);
                connect(m_launchTimer, &QTimer::timeout, this, &MerakiDock::pruneLaunching);
                m_launchTimer->start();
        }

        void show() {
                if (QScreen *screen = QGuiApplication::primaryScreen()) {
                        const QRect g = screen->geometry();
                        m_screenWidth = g.width();
                        m_screenHeight = g.height();
                }
                wchar_t wp[MAX_PATH] = {};
                SystemParametersInfoW(SPI_GETDESKWALLPAPER, MAX_PATH, wp, 0);
                QString wall = QString::fromWCharArray(wp);
                if (!wall.isEmpty()) {
                        m_wallpaper = QUrl::fromLocalFile(wall);
                }

                m_view = new QQuickView();
                m_view->setFlags(Qt::FramelessWindowHint | Qt::WindowStaysOnTopHint |
                        Qt::Tool | Qt::NoDropShadowWindowHint);
                m_view->setColor(Qt::transparent);
                m_view->setResizeMode(QQuickView::SizeRootObjectToView);
                m_view->rootContext()->setContextProperty("bridge", this);
                m_view->engine()->addImageProvider("dockicon", new DockIconProvider());
                m_view->setSource(QUrl(QStringLiteral("qrc:/qml/Meraki/dock/Dock.qml")));
                const int h = 132;
                if (QScreen *screen = QGuiApplication::primaryScreen()) {
                        const QRect g = screen->geometry();
                        m_view->setGeometry(g.x(), g.y() + g.height() - h, g.width(), h);
                }
                m_view->show();
                refresh();
                updateRegion();
        }

        QVariantList windows() const {
                return m_windows;
        }

        QVariantMap launching() const {
                return m_launching;
        }

        int screenWidth() const {
                return m_screenWidth;
        }

        int screenHeight() const {
                return m_screenHeight;
        }

        QUrl wallpaper() const {
                return m_wallpaper;
        }

        Q_INVOKABLE void focusWindow(qint64 id) {
                runCommand("[con_id=" + std::to_string(id) + "] focus");
        }

        Q_INVOKABLE void launch(const QString &cmd) {
                runCommand("exec " + cmd.toStdString());
        }

        Q_INVOKABLE void noteLaunch(const QString &key) {
                m_launching.insert(key.toLower(), QDateTime::currentMSecsSinceEpoch() + 2600);
                emit launchingChanged();
        }

public slots:
        void refresh() {
                char *error = nullptr;
                char *payload = ipc_request(nullptr, IPC_GET_TREE, "", &error);
                if (!payload) {
                        if (error) {
                                free(error);
                        }
                        return;
                }
                const QJsonDocument document = QJsonDocument::fromJson(QByteArray(payload));
                free(payload);
                QVariantList list;
                std::function<void(const QJsonObject &)> walk = [&](const QJsonObject &o) {
                        const QString appId = o.value("app_id").toString();
                        if (!appId.isEmpty() && o.contains("id")) {
                                QVariantMap w;
                                w.insert("id", (qlonglong)o.value("id").toDouble());
                                w.insert("appId", appId);
                                w.insert("title", o.value("title").toString());
                                w.insert("focused", o.value("focused").toBool());
                                w.insert("urgent", o.value("urgent").toBool());
                                const QJsonObject rect = o.value("rect").toObject();
                                w.insert("x", rect.value("x").toInt());
                                w.insert("y", rect.value("y").toInt());
                                w.insert("w", rect.value("width").toInt());
                                w.insert("h", rect.value("height").toInt());
                                const long long pid = (long long)o.value("pid").toDouble();
                                if (pid > 0) {
                                        HANDLE p = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, (DWORD)pid);
                                        if (p) {
                                                wchar_t path[MAX_PATH];
                                                DWORD sz = MAX_PATH;
                                                if (QueryFullProcessImageNameW(p, 0, path, &sz)) {
                                                        g_exe_paths[appId.toLower().toStdString()] =
                                                                QString::fromWCharArray(path).toStdString();
                                                }
                                                CloseHandle(p);
                                        }
                                }
                                list.append(w);
                        }
                        const QJsonArray nodes = o.value("nodes").toArray();
                        for (const QJsonValue &c : nodes) {
                                walk(c.toObject());
                        }
                        const QJsonArray floating = o.value("floating_nodes").toArray();
                        for (const QJsonValue &c : floating) {
                                walk(c.toObject());
                        }
                };
                walk(document.object());
                if (list != m_windows) {
                        m_windows = list;
                        emit windowsChanged();
                }
        }

        void pruneLaunching() {
                if (m_launching.isEmpty()) {
                        return;
                }
                const qint64 now = QDateTime::currentMSecsSinceEpoch();
                bool changed = false;
                for (auto it = m_launching.begin(); it != m_launching.end();) {
                        if (it.value().toLongLong() < now) {
                                it = m_launching.erase(it);
                                changed = true;
                        } else {
                                ++it;
                        }
                }
                if (changed) {
                        emit launchingChanged();
                }
        }

        void updateRegion() {
                if (!m_view) {
                        return;
                }
                const int step = 64;
                int w = int(m_dockWidth) + 8;
                w = ((w + step - 1) / step) * step;
                if (!m_dockHovered) {
                        m_restW = w;
                } else {
                        w = std::max(w, m_restW);
                }
                w = std::min(w, m_screenWidth);
                int h = m_dockHovered ? m_view->height() : int(m_restHeight);
                if (w == m_lastW && h == m_lastH) {
                        return;
                }
                m_lastW = w;
                m_lastH = h;
                int x = (m_view->width() - w) / 2;
                int y = m_view->height() - h;
                HRGN rgn = CreateRoundRectRgn(x, y, x + w, m_view->height(), 20, 20);
                SetWindowRgn((HWND)m_view->winId(), rgn, FALSE);
        }

signals:
        void windowsChanged();
        void launchingChanged();

private:
        static void runCommand(const std::string &cmd) {
                char *error = nullptr;
                char *reply = ipc_request(nullptr, IPC_COMMAND, cmd.c_str(), &error);
                if (reply) {
                        free(reply);
                }
                if (error) {
                        free(error);
                }
        }

        void loadPins() {
                QString path = meraki_home_dir() + "/.swinewm/dock.json";
                QFile f(path);
                if (f.open(QIODevice::ReadOnly)) {
                        const QJsonArray arr = QJsonDocument::fromJson(f.readAll()).array();
                        for (const QJsonValue &v : arr) {
                                const QJsonObject o = v.toObject();
                                QVariantMap pin;
                                pin.insert("key", o.value("key").toString());
                                pin.insert("name", o.value("name").toString());
                                pin.insert("cmd", o.value("cmd").toString());
                                if (!pin.value("key").toString().isEmpty()) {
                                        m_pins.append(pin);
                                }
                                const QString exe = o.value("cmd").toString();
                                if (!exe.isEmpty()) {
                                        QString probe = exe.endsWith(".exe", Qt::CaseInsensitive) ? exe : exe + ".exe";
                                        wchar_t buf[MAX_PATH];
                                        if (SearchPathW(nullptr, (LPCWSTR)probe.utf16(), nullptr, MAX_PATH, buf, nullptr) > 0) {
                                                g_exe_paths[o.value("key").toString().toLower().toStdString()] =
                                                        QString::fromWCharArray(buf).toStdString();
                                        }
                                }
                        }
                }
                if (m_pins.isEmpty()) {
                        const char *defs[][2] = {
                                {"explorer.exe", "Files"},
                                {"msedge.exe", "Browser"},
                                {"cmd.exe", "Terminal"},
                                {"notepad.exe", "Notes"},
                        };
                        for (auto &d : defs) {
                                QVariantMap pin;
                                pin.insert("key", QString::fromLatin1(d[0]));
                                pin.insert("name", QString::fromLatin1(d[1]));
                                pin.insert("cmd", QString::fromLatin1(d[0]));
                                m_pins.append(pin);
                        }
                }
        }

        QQuickView *m_view = nullptr;
        QTimer *m_regionTimer = nullptr;
        QTimer *m_pollTimer = nullptr;
        QTimer *m_launchTimer = nullptr;
        QVariantList m_windows;
        QVariantList m_pins;
        QVariantMap m_launching;
        QUrl m_wallpaper;
        int m_screenWidth = 0;
        int m_screenHeight = 0;
        int m_lastW = -1;
        int m_lastH = -1;
        int m_restW = 0;
        qreal m_dockWidth = 0;
        qreal m_restHeight = 80;
        bool m_dockHovered = false;
};

static MerakiDock *g_dock = nullptr;

class MerakiBar : public QObject {
        Q_OBJECT
        Q_PROPERTY(QVariantList workspaces READ workspaces NOTIFY workspacesChanged)
        Q_PROPERTY(QString activeName READ activeName NOTIFY workspacesChanged)

public:
        explicit MerakiBar(QObject *parent = nullptr) : QObject(parent) {
                m_timer = new QTimer(this);
                m_timer->setInterval(120);
                connect(m_timer, &QTimer::timeout, this, &MerakiBar::poll);
                m_timer->start();
        }

        void show() {
                QSurfaceFormat format = QSurfaceFormat::defaultFormat();
                format.setAlphaBufferSize(8);
                QSurfaceFormat::setDefaultFormat(format);
                QQuickView::setDefaultAlphaBuffer(true);

                m_view = new QQuickView();
                m_view->setFlags(Qt::FramelessWindowHint | Qt::WindowStaysOnTopHint |
                        Qt::Tool | Qt::NoDropShadowWindowHint);
                m_view->setColor(Qt::transparent);
                m_view->setResizeMode(QQuickView::SizeRootObjectToView);
                m_view->rootContext()->setContextProperty("bridge", this);
                m_view->setSource(QUrl(QStringLiteral("qrc:/qml/Meraki/Main.qml")));
                if (QScreen *screen = QGuiApplication::primaryScreen()) {
                        const QRect geometry = screen->geometry();
                        m_view->setGeometry(geometry.x(), geometry.y(), geometry.width(), 36);
                }
                refresh();
                m_view->show();
        }

        QVariantList workspaces() const {
                return m_workspaces;
        }

        QString activeName() const {
                return m_activeName;
        }

        Q_INVOKABLE void switchTo(int num) {
                const std::string command = "workspace number " + std::to_string(num);
                runCommand(command);
                refresh();
        }

public slots:
        void poll() {
                bool got = false;
                for (;;) {
                        uint32_t type = 0;
                        char *payload = nullptr;
                        if (!meraki_bridge_pop(&type, &payload)) {
                                break;
                        }
                        got = true;
                        free(payload);
                }
                if (got) {
                        refresh();
                }
                if (g_dock) {
                        g_dock->refresh();
                }
        }

        void refresh() {
                char *error = nullptr;
                char *payload = ipc_request(nullptr, IPC_GET_WORKSPACES, "", &error);
                if (!payload) {
                        if (error) {
                                free(error);
                        }
                        return;
                }
                const QJsonDocument document = QJsonDocument::fromJson(QByteArray(payload));
                free(payload);
                QVariantList list;
                const QJsonArray array = document.array();
                for (const QJsonValue &value : array) {
                        const QJsonObject object = value.toObject();
                        QVariantMap workspace;
                        workspace.insert("num", object.value("num").toInt());
                        workspace.insert("name", object.value("name").toString());
                        workspace.insert("focused", object.value("focused").toBool());
                        workspace.insert("urgent", object.value("urgent").toBool());
                        list.append(workspace);
                }
                m_workspaces = list;
                for (const QVariant &item : list) {
                        const QVariantMap workspace = item.toMap();
                        if (workspace.value("focused").toBool()) {
                                m_activeName = workspace.value("name").toString();
                        }
                }
                emit workspacesChanged();
        }

signals:
        void workspacesChanged();

private:
        static void runCommand(const std::string &command) {
                char *error = nullptr;
                char *reply = ipc_request(nullptr, IPC_COMMAND, command.c_str(), &error);
                if (reply) {
                        free(reply);
                }
                if (error) {
                        free(error);
                }
        }

        QQuickView *m_view = nullptr;
        QTimer *m_timer = nullptr;
        QVariantList m_workspaces;
        QString m_activeName;
};

static HANDLE g_thread = nullptr;
static QGuiApplication *g_app = nullptr;

static DWORD WINAPI meraki_qml_main(LPVOID arg) {
        (void)arg;
        int argc = 0;
        char *argv[] = {nullptr};
        QGuiApplication app(argc, argv);
        g_app = &app;
        MerakiBar bar;
        bar.show();
        MerakiDock dock;
        g_dock = &dock;
        dock.show();
        app.exec();
        g_dock = nullptr;
        g_app = nullptr;
        return 0;
}

extern "C" void meraki_qml_start(void) {
        meraki_bridge_start();
        g_thread = CreateThread(nullptr, 0, meraki_qml_main, nullptr, 0, nullptr);
}

extern "C" void meraki_qml_stop(void) {
        if (g_app) {
                QMetaObject::invokeMethod(g_app, "quit", Qt::QueuedConnection);
        }
        if (g_thread) {
                WaitForSingleObject(g_thread, 3000);
                CloseHandle(g_thread);
                g_thread = nullptr;
        }
        meraki_bridge_stop();
}

#include "qmlbar.moc"
