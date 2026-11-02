#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#include <shellapi.h>
#include <shlobj_core.h>
#include <commoncontrols.h>
#include <appmodel.h>
#include <objbase.h>
#include <propkey.h>
#include <propsys.h>
#include <shobjidl_core.h>

#include <QDateTime>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QImage>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QMetaObject>
#include <QMutex>
#include <QQmlContext>
#include <QQmlEngine>
#include <QQuickImageProvider>
#include <QQuickView>
#include <QRect>
#include <QScreen>
#include <QSurfaceFormat>
#include <QTimer>
#include <QUrl>
#include <QVariantMap>

#include "capture.h"
#include "media.h"

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
#include <list.h>
#include <swinewm/bar/tray.h>
}

extern "C" {
enum tray_hover {
        TRAY_HOVER_MOVE,
        TRAY_HOVER_POPUP,
        TRAY_HOVER_LEAVE
};
bool win32_tray_hover(uint64_t id, enum tray_hover what, POINT screen);
void win32_tray_mouse(uint64_t id, int button, bool down, POINT screen);
void win32_tray_set_host_rect(const RECT *screen);
void win32_tray_force(bool on);
void win32_tray_set_listener(void (*fn)(void));
bool win32_tray_icon_bits(uint64_t id, int size, int *w, int *h,
        unsigned char **out);
void win32_desktop_layer_register(HWND hwnd);
bool win32_desktop_layer_place(HWND hwnd);
}

extern "C" void meraki_ipc_command(const char *cmd) {
        char *error = nullptr;
        char *reply = ipc_request(nullptr, IPC_COMMAND, cmd, &error);
        if (reply) {
                free(reply);
        }
        if (error) {
                free(error);
        }
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
static std::map<QString, QString> g_uwp_names;

static void meraki_ensure_com() {
        CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
}

static QString meraki_aumid_for_hwnd(HWND hwnd) {
        static std::map<long long, QString> cache;
        const long long key = (long long)(intptr_t)hwnd;
        auto it = cache.find(key);
        if (it != cache.end()) {
                return it->second;
        }
        QString aumid;
        IPropertyStore *store = nullptr;
        if (SUCCEEDED(SHGetPropertyStoreForWindow(hwnd, IID_IPropertyStore,
                (void **)&store)) && store) {
                PROPVARIANT v;
                PropVariantInit(&v);
                if (SUCCEEDED(store->GetValue(PKEY_AppUserModel_ID, &v)) &&
                        v.vt == VT_LPWSTR && v.pwszVal) {
                        aumid = QString::fromWCharArray(v.pwszVal);
                }
                PropVariantClear(&v);
                store->Release();
        }
        if (aumid.isEmpty()) {
                HWND core = FindWindowExW(hwnd, nullptr,
                        L"Windows.UI.Core.CoreWindow", nullptr);
                DWORD pid = 0;
                if (core && GetWindowThreadProcessId(core, &pid) && pid) {
                        HANDLE p = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION,
                                FALSE, pid);
                        if (p) {
                                UINT32 len = 0;
                                if (GetApplicationUserModelId(p, &len, nullptr) ==
                                        ERROR_INSUFFICIENT_BUFFER) {
                                        std::wstring buf(len, L'\0');
                                        if (GetApplicationUserModelId(p, &len,
                                                buf.data()) == ERROR_SUCCESS) {
                                                aumid = QString::fromWCharArray(
                                                        buf.c_str());
                                        }
                                }
                                CloseHandle(p);
                        }
                }
        }
        if (cache.size() > 256) {
                cache.clear();
        }
        cache[key] = aumid;
        return aumid;
}

static QString meraki_uwp_name(const QString &aumid) {
        meraki_ensure_com();
        IShellItem *item = nullptr;
        const QString path = "shell:AppsFolder/" + aumid;
        if (FAILED(SHCreateItemFromParsingName((LPCWSTR)path.utf16(), nullptr,
                IID_PPV_ARGS(&item))) || !item) {
                return QString();
        }
        PWSTR name = nullptr;
        QString out;
        if (SUCCEEDED(item->GetDisplayName(SIGDN_NORMALDISPLAY, &name)) && name) {
                out = QString::fromWCharArray(name);
                CoTaskMemFree(name);
        }
        item->Release();
        return out;
}

static QImage meraki_hbitmap_to_image(HBITMAP bmp) {
        BITMAP bm = {};
        if (!bmp || !GetObjectW(bmp, sizeof(bm), &bm) || bm.bmWidth <= 0) {
                return QImage();
        }
        QImage img(bm.bmWidth, bm.bmHeight, QImage::Format_ARGB32);
        BITMAPINFOHEADER bi = {};
        bi.biSize = sizeof(bi);
        bi.biWidth = bm.bmWidth;
        bi.biHeight = -bm.bmHeight;
        bi.biPlanes = 1;
        bi.biBitCount = 32;
        bi.biCompression = BI_RGB;
        HDC dc = GetDC(nullptr);
        int rows = GetDIBits(dc, bmp, 0, bm.bmHeight, img.bits(),
                (BITMAPINFO *)&bi, DIB_RGB_COLORS);
        ReleaseDC(nullptr, dc);
        if (rows != bm.bmHeight) {
                return QImage();
        }
        bool premul = true;
        for (int y = 0; y < img.height() && premul; ++y) {
                const QRgb *line = (const QRgb *)img.constScanLine(y);
                for (int x = 0; x < img.width(); ++x) {
                        int a = qAlpha(line[x]);
                        if (qRed(line[x]) > a || qGreen(line[x]) > a ||
                                qBlue(line[x]) > a) {
                                premul = false;
                                break;
                        }
                }
        }
        if (premul) {
                for (int y = 0; y < img.height(); ++y) {
                        QRgb *line = (QRgb *)img.scanLine(y);
                        for (int x = 0; x < img.width(); ++x) {
                                int a = qAlpha(line[x]);
                                if (a == 0) {
                                        line[x] = 0;
                                } else if (a < 255) {
                                        line[x] = qRgba(
                                                qMin(255, qRed(line[x]) * 255 / a),
                                                qMin(255, qGreen(line[x]) * 255 / a),
                                                qMin(255, qBlue(line[x]) * 255 / a), a);
                                }
                        }
                }
        }
        return img;
}

static QImage meraki_uwp_image(const QString &aumid) {
        meraki_ensure_com();
        IShellItem *item = nullptr;
        const QString path = "shell:AppsFolder/" + aumid;
        if (FAILED(SHCreateItemFromParsingName((LPCWSTR)path.utf16(), nullptr,
                IID_PPV_ARGS(&item))) || !item) {
                return QImage();
        }
        IShellItemImageFactory *factory = nullptr;
        QImage out;
        if (SUCCEEDED(item->QueryInterface(IID_PPV_ARGS(&factory))) && factory) {
                HBITMAP bmp = nullptr;
                SIZE sz = {96, 96};
                if (SUCCEEDED(factory->GetImage(sz, SIIGBF_ICONONLY, &bmp)) && bmp) {
                        out = meraki_hbitmap_to_image(bmp);
                        DeleteObject(bmp);
                }
                factory->Release();
        }
        item->Release();
        return out;
}

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
                QImage img = k.contains('!') ? meraki_uwp_image(k)
                        : meraki_extract_icon(meraki_exe_for(k));
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

static QImage meraki_tray_image(qint64 id) {
        int w = 0, h = 0;
        unsigned char *bits = nullptr;
        if (!win32_tray_icon_bits((uint64_t)id, 32, &w, &h, &bits) || !bits) {
                return QImage();
        }
        QImage raw(bits, w, h, w * 4, QImage::Format_ARGB32);
        QImage out = raw.copy();
        free(bits);
        return out;
}

class TrayIconProvider : public QQuickImageProvider {
public:
        TrayIconProvider() : QQuickImageProvider(QQuickImageProvider::Pixmap) {}

        QPixmap requestPixmap(const QString &id, QSize *size,
                const QSize &requested) override {
                const QString key = id.section('?', 0, 0);
                QPixmap pm;
                auto it = m_cache.find(key);
                if (it != m_cache.end()) {
                        pm = it->second;
                } else {
                        QImage img = meraki_tray_image(key.toLongLong());
                        if (!img.isNull()) {
                                pm = QPixmap::fromImage(img);
                                if (m_cache.size() > 96) {
                                        m_cache.clear();
                                }
                                m_cache[key] = pm;
                        }
                }
                if (size) {
                        *size = pm.size();
                }
                if (requested.isValid() && requested.width() > 0 &&
                        requested.height() > 0) {
                        return pm.scaled(requested, Qt::KeepAspectRatio,
                                Qt::SmoothTransformation);
                }
                return pm;
        }

private:
        std::map<std::string, QPixmap> m_cache;
};

static QMutex g_tray_mutex;
static QByteArray g_tray_json;

static void meraki_tray_snapshot(void) {
        QJsonArray arr;
        list_t *items = tray_get_items();
        if (items) {
                for (int i = 0; i < (int)items->length; ++i) {
                        struct tray_item *item = (struct tray_item *)items->items[i];
                        if (item->passive) {
                                continue;
                        }
                        QJsonObject o;
                        o.insert("id", (qlonglong)item->id);
                        o.insert("appId", QString::fromUtf8(
                                item->app_id ? item->app_id : ""));
                        o.insert("title", QString::fromUtf8(
                                item->title ? item->title : ""));
                        arr.append(o);
                }
        }
        const QByteArray data = QJsonDocument(arr).toJson();
        QMutexLocker lock(&g_tray_mutex);
        g_tray_json = data;
}

static QString meraki_known_dir(REFKNOWNFOLDERID id) {
        PWSTR raw = nullptr;
        QString out;
        if (SUCCEEDED(SHGetKnownFolderPath(id, 0, nullptr, &raw)) && raw) {
                out = QString::fromWCharArray(raw);
                CoTaskMemFree(raw);
        }
        return out;
}

static std::map<QString, QString> g_appicon_paths;

class AppIconProvider : public QQuickImageProvider {
public:
        AppIconProvider() : QQuickImageProvider(QQuickImageProvider::Pixmap) {}

        QPixmap requestPixmap(const QString &id, QSize *size,
                const QSize &requested) override {
                QPixmap pm;
                auto it = m_cache.find(id);
                if (it != m_cache.end()) {
                        pm = it->second;
                } else {
                        auto pathIt = g_appicon_paths.find(id);
                        if (pathIt != g_appicon_paths.end()) {
                                SHFILEINFOW sfi = {};
                                if (SHGetFileInfoW((LPCWSTR)pathIt->second.utf16(),
                                        0, &sfi, sizeof(sfi), SHGFI_SYSICONINDEX)) {
                                        IImageList *list = nullptr;
                                        if (SUCCEEDED(SHGetImageList(SHIL_JUMBO,
                                                IID_IImageList, (void **)&list))) {
                                                HICON icon = nullptr;
                                                list->GetIcon(sfi.iIcon,
                                                        ILD_TRANSPARENT, &icon);
                                                list->Release();
                                                if (icon) {
                                                        QImage img = meraki_hicon_to_image(icon);
                                                        DestroyIcon(icon);
                                                        if (!img.isNull()) {
                                                                pm = QPixmap::fromImage(img);
                                                        }
                                                }
                                        }
                                }
                        }
                        if (pm.isNull()) {
                                pm = meraki_icon_for(QStringLiteral("unknown"));
                        }
                        if (m_cache.size() > 512) {
                                m_cache.clear();
                        }
                        m_cache[id] = pm;
                }
                if (size) {
                        *size = pm.size();
                }
                if (requested.isValid() && requested.width() > 0 &&
                        requested.height() > 0) {
                        return pm.scaled(requested, Qt::KeepAspectRatio,
                                Qt::SmoothTransformation);
                }
                return pm;
        }

private:
        std::map<QString, QPixmap> m_cache;
};

static MerakiFx *g_fx = nullptr;

class MerakiMenu : public QObject {
        Q_OBJECT
        Q_PROPERTY(QString key MEMBER m_key NOTIFY changed)
        Q_PROPERTY(QString name MEMBER m_name NOTIFY changed)
        Q_PROPERTY(bool pinned MEMBER m_pinned NOTIFY changed)
        Q_PROPERTY(bool running MEMBER m_running NOTIFY changed)

public:
        explicit MerakiMenu(QObject *parent = nullptr) : QObject(parent) {}
        QString m_key;
        QString m_name;
        bool m_pinned = false;
        bool m_running = false;

signals:
        void changed();
};

class MerakiDock : public QObject {
        Q_OBJECT
        Q_PROPERTY(QVariantList windows READ windows NOTIFY windowsChanged)
        Q_PROPERTY(QVariantList pins READ pins NOTIFY pinsChanged)
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
                if (g_fx) {
                        m_view->rootContext()->setContextProperty("fx", g_fx);
                }
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

        QVariantList pins() const {
                return m_pins;
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

        Q_INVOKABLE QString appName(const QString &key) {
                auto it = g_uwp_names.find(key);
                return it != g_uwp_names.end() ? it->second : key;
        }

        Q_INVOKABLE void launch(const QString &cmd) {
                runCommand("exec " + cmd.toStdString());
        }

        Q_INVOKABLE void noteLaunch(const QString &key) {
                m_launching.insert(key.toLower(), QDateTime::currentMSecsSinceEpoch() + 2600);
                emit launchingChanged();
        }

        Q_INVOKABLE void togglePin(const QString &key) {
                const QString lower = key.toLower();
                for (int i = 0; i < m_pins.size(); ++i) {
                        if (m_pins.at(i).toMap().value("key").toString().toLower() == lower) {
                                m_pins.removeAt(i);
                                savePins();
                                emit pinsChanged();
                                return;
                        }
                }
                QString exe = meraki_exe_for(key);
                QString name;
                if (key.contains('!')) {
                        auto it = g_uwp_names.find(key);
                        name = it != g_uwp_names.end() ? it->second
                                : meraki_uwp_name(key);
                        if (name.isEmpty()) {
                                name = key.section('!', 0, 0);
                        }
                        if (exe.isEmpty()) {
                                exe = "explorer.exe shell:AppsFolder/" + key;
                        }
                } else {
                        if (exe.isEmpty()) {
                                exe = key;
                        }
                        name = QFileInfo(exe).completeBaseName();
                        if (name.isEmpty()) {
                                name = key;
                        }
                }
                QVariantMap pin;
                pin.insert("key", key);
                pin.insert("name", name.left(1).toUpper() + name.mid(1));
                pin.insert("cmd", exe);
                m_pins.append(pin);
                savePins();
                emit pinsChanged();
        }

        Q_INVOKABLE void closeApp(const QString &key) {
                const QString lower = key.toLower();
                for (const QVariant &v : m_windows) {
                        const QVariantMap w = v.toMap();
                        if (w.value("appId").toString().toLower() == lower) {
                                runCommand("[con_id=" + std::to_string(
                                        (long long)w.value("id").toLongLong()) + "] kill");
                        }
                }
        }

        Q_INVOKABLE void showMenu(const QString &key, const QString &name,
                bool pinned, bool running, qreal ax, qreal ay) {
                ensureMenuView();
                m_menu->m_key = key;
                m_menu->m_name = name;
                m_menu->m_pinned = pinned;
                m_menu->m_running = running;
                emit m_menu->changed();
                const int w = 224;
                const int n = 1 + (running ? 1 : 0);
                const int h = 42 + n * 40 + (n - 1) * 2 + 12;
                int x = int(ax) - w / 2;
                x = std::max(8, std::min(m_screenWidth - w - 8, x));
                int y = std::max(8, int(ay) - h - 10);
                m_menuView->setGeometry(x, y, w, h);
                m_menuView->raise();
                m_menuView->show();
        }

public slots:
        void hideMenu() {
                if (m_menuView) {
                        m_menuView->hide();
                }
        }
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
                                const long long hwnd =
                                        (long long)o.value("window").toDouble();
                                w.insert("window", hwnd);
                                if (hwnd > 0) {
                                        w.insert("iconic",
                                                IsIconic((HWND)(size_t)hwnd) != FALSE);
                                }
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
                                if (hwnd > 0) {
                                        const QString aumid =
                                                meraki_aumid_for_hwnd(
                                                        (HWND)(size_t)hwnd);
                                        if (aumid.contains('!')) {
                                                w.insert("appId", aumid);
                                                if (!g_uwp_names.count(aumid)) {
                                                        const QString name =
                                                                meraki_uwp_name(aumid);
                                                        g_uwp_names[aumid] =
                                                                name.isEmpty()
                                                                ? aumid : name;
                                                }
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
        void pinsChanged();

private:
        static void runCommand(const std::string &cmd) {
                meraki_ipc_command(cmd.c_str());
        }

        void ensureMenuView() {
                if (m_menuView) {
                        return;
                }
                m_menu = new MerakiMenu(this);
                m_menuView = new QQuickView();
                m_menuView->setFlags(Qt::FramelessWindowHint | Qt::WindowStaysOnTopHint |
                        Qt::Tool | Qt::NoDropShadowWindowHint);
                m_menuView->setColor(Qt::transparent);
                m_menuView->setResizeMode(QQuickView::SizeRootObjectToView);
                m_menuView->rootContext()->setContextProperty("bridge", this);
                m_menuView->rootContext()->setContextProperty("menu", m_menu);
                m_menuView->setSource(QUrl(QStringLiteral("qrc:/qml/Meraki/dock/DockMenu.qml")));
                QObject::connect(m_menuView, &QQuickWindow::activeChanged, this, [this]() {
                        if (m_menuView && !m_menuView->isActive()) {
                                m_menuView->hide();
                        }
                });
                if (m_menuView->rootObject()) {
                        QObject::connect(m_menuView->rootObject(), SIGNAL(done()),
                                this, SLOT(hideMenu()));
                }
        }

        void savePins() {
                QJsonArray arr;
                for (const QVariant &v : m_pins) {
                        const QVariantMap p = v.toMap();
                        QJsonObject o;
                        o.insert("key", p.value("key").toString());
                        o.insert("name", p.value("name").toString());
                        o.insert("cmd", p.value("cmd").toString());
                        arr.append(o);
                }
                QFile f(meraki_home_dir() + "/.swinewm/dock.json");
                if (f.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
                        f.write(QJsonDocument(arr).toJson());
                }
        }

        void loadPins() {
                QString path = meraki_home_dir() + "/.swinewm/dock.json";
                QFile f(path);
                bool loaded = false;
                if (f.open(QIODevice::ReadOnly)) {
                        loaded = true;
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
                if (!loaded) {
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
        QQuickView *m_menuView = nullptr;
        MerakiMenu *m_menu = nullptr;
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

class MerakiCenter : public QObject {
        Q_OBJECT
        Q_PROPERTY(QVariantList notes READ notes NOTIFY notesChanged)
        Q_PROPERTY(int count READ count NOTIFY notesChanged)
        Q_PROPERTY(bool open READ isOpen NOTIFY openChanged)
        Q_PROPERTY(int screenWidth READ screenWidth CONSTANT)
        Q_PROPERTY(int screenHeight READ screenHeight CONSTANT)
        Q_PROPERTY(QUrl wallpaper READ wallpaper CONSTANT)
        Q_PROPERTY(QVariantList windows READ windows NOTIFY windowsChanged)
        Q_PROPERTY(qreal panelY MEMBER m_panelY)
        Q_PROPERTY(qreal panelH MEMBER m_panelH)

public:
        explicit MerakiCenter(QObject *parent = nullptr) : QObject(parent) {
                m_regionTimer = new QTimer(this);
                m_regionTimer->setInterval(90);
                connect(m_regionTimer, &QTimer::timeout, this,
                        &MerakiCenter::applyRegion);
                m_regionTimer->start();
        }

        void init() {
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
                m_view->engine()->addImageProvider("dockicon",
                        new DockIconProvider());
                m_view->setSource(QUrl(QStringLiteral(
                        "qrc:/qml/Meraki/center/Center.qml")));
                const int w = 384;
                const int h = std::min(620, std::max(320, m_screenHeight - 60));
                if (QScreen *screen = QGuiApplication::primaryScreen()) {
                        const QRect g = screen->geometry();
                        m_view->setGeometry(g.x() + g.width() - w - 12, g.y(), w, h);
                }
                syncWindows();
                refreshNotes();
        }

        QVariantList notes() const {
                return m_notes;
        }

        int count() const {
                return m_notes.size();
        }

        bool isOpen() const {
                return m_open;
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

        QVariantList windows() const {
                return m_windows;
        }

        Q_INVOKABLE void toggle() {
                if (!m_view) {
                        init();
                }
                if (m_open) {
                        setOpen(false);
                } else {
                        syncWindows();
                        refreshNotes();
                        m_view->show();
                        m_view->raise();
                        setOpen(true);
                }
        }

        Q_INVOKABLE void close() {
                setOpen(false);
        }

        Q_INVOKABLE void dismiss(qint64 id) {
                const std::string text = std::to_string(id);
                char *error = nullptr;
                char *reply = ipc_request(nullptr, SWINE_IPC_CLOSE_NOTIFICATION,
                        text.c_str(), &error);
                if (reply) {
                        free(reply);
                }
                if (error) {
                        free(error);
                }
                refreshNotes();
        }

        Q_INVOKABLE void clearAll() {
                for (const QVariant &v : m_activeIds) {
                        const qlonglong id = v.toLongLong();
                        char *error = nullptr;
                        char *reply = ipc_request(nullptr,
                                SWINE_IPC_CLOSE_NOTIFICATION,
                                std::to_string(id).c_str(), &error);
                        if (reply) {
                                free(reply);
                        }
                        if (error) {
                                free(error);
                        }
                }
                refreshNotes();
        }

        Q_INVOKABLE void focusApp(const QString &app) {
                if (!g_dock) {
                        return;
                }
                const QString lower = app.toLower();
                for (const QVariant &v : g_dock->windows()) {
                        const QVariantMap w = v.toMap();
                        if (w.value("appId").toString().toLower() == lower) {
                                runCommand("[con_id=" + std::to_string(
                                        (long long)w.value("id").toLongLong())
                                        + "] focus");
                                return;
                        }
                }
        }

public slots:
        void refreshNotes() {
                QVariantList list;
                std::map<qlonglong, bool> index;
                m_activeIds.clear();
                appendNotify(SWINE_IPC_GET_NOTIFICATIONS, list, index, true);
                appendNotify(SWINE_IPC_GET_NOTIFICATION_HISTORY, list, index,
                        false);
                if (list != m_notes) {
                        m_notes = list;
                        emit notesChanged();
                }
        }

signals:
        void notesChanged();
        void openChanged();
        void windowsChanged();

private:
        static void runCommand(const std::string &cmd) {
                meraki_ipc_command(cmd.c_str());
        }

        void appendNotify(uint32_t type, QVariantList &out,
                std::map<qlonglong, bool> &index, bool active) {
                char *error = nullptr;
                char *payload = ipc_request(nullptr, type, "", &error);
                if (!payload) {
                        if (error) {
                                free(error);
                        }
                        return;
                }
                const QJsonDocument document =
                        QJsonDocument::fromJson(QByteArray(payload));
                free(payload);
                QVariantList items;
                const QJsonArray array = document.array();
                for (const QJsonValue &v : array) {
                        const QJsonObject o = v.toObject();
                        const qlonglong id = (qlonglong)o.value("id").toDouble();
                        const QString app = o.value("app_name").toString();
                        const QString summary = o.value("summary").toString();
                        const QString body = o.value("body").toString();
                        if (app.isEmpty() && summary.isEmpty() && body.isEmpty()) {
                                continue;
                        }
                        if (index.count(id)) {
                                continue;
                        }
                        if (active) {
                                m_activeIds.append(id);
                        }
                        if (!m_seen.count(id)) {
                                if (m_seen.size() > 512) {
                                        m_seen.erase(m_seen.begin());
                                }
                                m_seen[id] = QDateTime::currentMSecsSinceEpoch();
                        }
                        QVariantMap n;
                        n.insert("id", id);
                        n.insert("app", app);
                        n.insert("summary", summary);
                        n.insert("body", body);
                        n.insert("urgency", o.value("urgency").toString());
                        n.insert("when", m_seen[id]);
                        index[id] = true;
                        items.append(n);
                }
                if (active) {
                        for (int i = items.size() - 1; i >= 0; --i) {
                                out.prepend(items.at(i));
                        }
                } else {
                        for (const QVariant &n : items) {
                                out.append(n);
                        }
                }
        }

        void setOpen(bool open) {
                if (m_open == open) {
                        return;
                }
                m_open = open;
                emit openChanged();
                if (!open) {
                        QTimer::singleShot(300, this, [this]() {
                                if (!m_open && m_view) {
                                        m_view->hide();
                                }
                        });
                }
        }

        void syncWindows() {
                QVariantList list = g_dock ? g_dock->windows() : QVariantList();
                if (list != m_windows) {
                        m_windows = list;
                        emit windowsChanged();
                }
        }

        void applyRegion() {
                if (!m_view || !m_view->isVisible()) {
                        return;
                }
                const int y0 = std::max(0, (int)m_panelY);
                const int y1 = std::min(m_view->height(),
                        (int)(m_panelY + m_panelH));
                if (y1 <= y0) {
                        SetWindowRgn((HWND)m_view->winId(),
                                CreateRectRgn(0, 0, 0, 0), FALSE);
                        return;
                }
                SetWindowRgn((HWND)m_view->winId(), CreateRoundRectRgn(0, y0,
                        m_view->width(), y1, 20, 20), FALSE);
        }

        QQuickView *m_view = nullptr;
        QTimer *m_regionTimer = nullptr;
        QVariantList m_notes;
        QVariantList m_windows;
        QVariantList m_activeIds;
        std::map<uint32_t, qint64> m_seen;
        QUrl m_wallpaper;
        int m_screenWidth = 0;
        int m_screenHeight = 0;
        qreal m_panelY = 0;
        qreal m_panelH = 0;
        bool m_open = false;
};

static MerakiCenter *g_center = nullptr;

class MerakiApps : public QObject {
        Q_OBJECT
        Q_PROPERTY(QVariantList filtered READ filtered NOTIFY filteredChanged)
        Q_PROPERTY(bool open READ isOpen NOTIFY openChanged)
        Q_PROPERTY(QString query READ query WRITE setQuery NOTIFY filteredChanged)
        Q_PROPERTY(int screenWidth READ screenWidth CONSTANT)
        Q_PROPERTY(int screenHeight READ screenHeight CONSTANT)
        Q_PROPERTY(QUrl wallpaper READ wallpaper CONSTANT)
        Q_PROPERTY(QVariantList windows READ windows NOTIFY windowsChanged)

public:
        explicit MerakiApps(QObject *parent = nullptr) : QObject(parent) {}

        QVariantList filtered() const {
                return m_filtered;
        }

        bool isOpen() const {
                return m_open;
        }

        QString query() const {
                return m_query;
        }

        void setQuery(const QString &q) {
                if (m_query == q) {
                        return;
                }
                m_query = q;
                applyFilter();
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

        QVariantList windows() const {
                return g_dock ? g_dock->windows() : QVariantList();
        }

        Q_INVOKABLE void toggle() {
                if (m_open) {
                        setOpen(false);
                        return;
                }
                ensureView();
                scan();
                m_view->show();
                m_view->raise();
                setOpen(true);
        }

        Q_INVOKABLE void close() {
                setOpen(false);
        }

        Q_INVOKABLE void launchFirst() {
                if (!m_filtered.isEmpty()) {
                        openApp(m_filtered.first().toMap()
                                .value("path").toString());
                }
        }

        Q_INVOKABLE void openApp(const QString &path) {
                setOpen(false);
                if (path.isEmpty()) {
                        return;
                }
                const std::wstring p = path.toStdWString();
                SHELLEXECUTEINFOW info = {};
                info.cbSize = sizeof(info);
                info.lpFile = p.c_str();
                info.nShow = SW_SHOWNORMAL;
                ShellExecuteExW(&info);
        }

signals:
        void filteredChanged();
        void openChanged();
        void windowsChanged();

private:
        void ensureView() {
                if (m_view) {
                        return;
                }
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
                m_view->engine()->addImageProvider("appicon",
                        new AppIconProvider());
                m_view->setSource(QUrl(QStringLiteral(
                        "qrc:/qml/Meraki/apps/Launchpad.qml")));
                if (QScreen *screen = QGuiApplication::primaryScreen()) {
                        const QRect g = screen->geometry();
                        m_view->setGeometry(g);
                }
                QObject::connect(m_view, &QQuickWindow::activeChanged, this, [this]() {
                        if (m_view && m_open && !m_view->isActive()) {
                                setOpen(false);
                        }
                });
        }

        void scan() {
                const QString dirs[] = { meraki_known_dir(FOLDERID_Programs),
                        meraki_known_dir(FOLDERID_CommonPrograms) };
                QVariantList list;
                std::map<QString, bool> seen;
                for (const QString &dir : dirs) {
                        if (dir.isEmpty()) {
                                continue;
                        }
                        QDirIterator it(dir, {"*.lnk", "*.url"}, QDir::Files,
                                QDirIterator::Subdirectories);
                        while (it.hasNext()) {
                                const QString path = it.next();
                                const QString name =
                                        QFileInfo(path).completeBaseName();
                                const QString key = name.toLower();
                                if (name.isEmpty() || seen.count(key) ||
                                        path.contains("/startup/",
                                                Qt::CaseInsensitive) ||
                                        path.contains(QString::fromUtf8(
                                                "/автозагрузка/"),
                                                Qt::CaseInsensitive)) {
                                        continue;
                                }
                                seen[key] = true;
                                const QString safe =
                                        "a" + QString::number(m_seq++);
                                g_appicon_paths[safe] = path;
                                QVariantMap app;
                                app.insert("name", name);
                                app.insert("path", path);
                                app.insert("icon", safe);
                                list.append(app);
                        }
                }
                std::sort(list.begin(), list.end(),
                        [](const QVariant &a, const QVariant &b) {
                                return a.toMap().value("name").toString()
                                        .compare(b.toMap().value("name")
                                                .toString(),
                                                Qt::CaseInsensitive) < 0;
                        });
                if (list != m_apps) {
                        m_apps = list;
                        applyFilter();
                } else {
                        applyFilter();
                }
        }

        void applyFilter() {
                QVariantList list;
                const QString needle = m_query.trimmed();
                for (const QVariant &v : m_apps) {
                        const QVariantMap a = v.toMap();
                        if (needle.isEmpty() || a.value("name").toString()
                                .contains(needle, Qt::CaseInsensitive)) {
                                list.append(a);
                        }
                }
                if (list != m_filtered) {
                        m_filtered = list;
                        emit filteredChanged();
                }
        }

        void setOpen(bool open) {
                if (m_open == open) {
                        return;
                }
                m_open = open;
                emit openChanged();
                if (!open) {
                        QTimer::singleShot(200, this, [this]() {
                                if (!m_open && m_view) {
                                        m_view->hide();
                                }
                        });
                }
        }

        QQuickView *m_view = nullptr;
        QVariantList m_apps;
        QVariantList m_filtered;
        QString m_query;
        QUrl m_wallpaper;
        int m_screenWidth = 0;
        int m_screenHeight = 0;
        int m_seq = 1;
        bool m_open = false;
};

static MerakiApps *g_apps = nullptr;

class MerakiWidgets : public QObject {
        Q_OBJECT
        Q_PROPERTY(QVariantMap config READ config CONSTANT)
        Q_PROPERTY(int screenWidth READ screenWidth CONSTANT)
        Q_PROPERTY(int screenHeight READ screenHeight CONSTANT)
        Q_PROPERTY(QUrl wallpaper READ wallpaper CONSTANT)
        Q_PROPERTY(QVariantList windows READ windows NOTIFY windowsChanged)

public:
        explicit MerakiWidgets(QObject *parent = nullptr) : QObject(parent) {
                m_regionTimer = new QTimer(this);
                m_regionTimer->setInterval(150);
                connect(m_regionTimer, &QTimer::timeout, this,
                        &MerakiWidgets::updateRegion);
                m_regionTimer->start();
                m_placeTimer = new QTimer(this);
                m_placeTimer->setInterval(2500);
                connect(m_placeTimer, &QTimer::timeout, this,
                        &MerakiWidgets::reposition);
                m_placeTimer->start();
        }

        void show() {
                if (QScreen *screen = QGuiApplication::primaryScreen()) {
                        const QRect g = screen->geometry();
                        m_screenWidth = g.width();
                        m_screenHeight = g.height();
                }
                loadConfig();
                wchar_t wp[MAX_PATH] = {};
                SystemParametersInfoW(SPI_GETDESKWALLPAPER, MAX_PATH, wp, 0);
                QString wall = QString::fromWCharArray(wp);
                if (!wall.isEmpty()) {
                        m_wallpaper = QUrl::fromLocalFile(wall);
                }
                m_media = new MerakiMedia(this);
                m_media->start();
                m_view = new QQuickView();
                m_view->setFlags(Qt::FramelessWindowHint | Qt::Tool |
                        Qt::NoDropShadowWindowHint);
                m_view->setColor(Qt::transparent);
                m_view->setResizeMode(QQuickView::SizeRootObjectToView);
                m_view->rootContext()->setContextProperty("bridge", this);
                m_view->rootContext()->setContextProperty("media", m_media);
                m_view->setSource(QUrl(QStringLiteral(
                        "qrc:/qml/Meraki/widgets/Widgets.qml")));
                if (QScreen *screen = QGuiApplication::primaryScreen()) {
                        const QRect g = screen->geometry();
                        m_view->setGeometry(g);
                }
                m_view->show();
                const HWND hwnd = (HWND)m_view->winId();
                win32_desktop_layer_register(hwnd);
                win32_desktop_layer_place(hwnd);
                m_hwnd = hwnd;
        }

        QVariantMap config() const {
                return m_config;
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

        QVariantList windows() const {
                return g_dock ? g_dock->windows() : QVariantList();
        }

        Q_INVOKABLE void setCards(const QVariantList &cards) {
                if (cards != m_cards) {
                        m_cards = cards;
                }
        }

signals:
        void windowsChanged();

public slots:
        void updateRegion() {
                if (!m_view) {
                        return;
                }
                HRGN rgn = CreateRectRgn(0, 0, 0, 0);
                for (const QVariant &v : m_cards) {
                        const QVariantMap c = v.toMap();
                        const int x = c.value("x").toInt();
                        const int y = c.value("y").toInt();
                        const int w = c.value("w").toInt();
                        const int h = c.value("h").toInt();
                        if (w <= 0 || h <= 0) {
                                continue;
                        }
                        HRGN r = CreateRoundRectRgn(x, y, x + w, y + h, 30, 30);
                        CombineRgn(rgn, rgn, r, RGN_OR);
                        DeleteObject(r);
                }
                SetWindowRgn((HWND)m_view->winId(), rgn, FALSE);
        }

        void reposition() {
                if (m_hwnd) {
                        win32_desktop_layer_place(m_hwnd);
                }
        }

private:
        void loadConfig() {
                m_config.insert("latitude", 55.7558);
                m_config.insert("longitude", 37.6173);
                m_config.insert("city", QString::fromUtf8("Москва"));
                QFile f(meraki_home_dir() + "/.swinewm/widgets.json");
                if (f.open(QIODevice::ReadOnly)) {
                        const QJsonObject o = QJsonDocument::fromJson(
                                f.readAll()).object();
                        if (o.contains("latitude")) {
                                m_config.insert("latitude",
                                        o.value("latitude").toDouble());
                        }
                        if (o.contains("longitude")) {
                                m_config.insert("longitude",
                                        o.value("longitude").toDouble());
                        }
                        if (o.contains("city")) {
                                m_config.insert("city",
                                        o.value("city").toString());
                        }
                }
        }

        QQuickView *m_view = nullptr;
        QTimer *m_regionTimer = nullptr;
        QTimer *m_placeTimer = nullptr;
        MerakiMedia *m_media = nullptr;
        QVariantMap m_config;
        QVariantList m_cards;
        QUrl m_wallpaper;
        HWND m_hwnd = nullptr;
        int m_screenWidth = 0;
        int m_screenHeight = 0;
};

static MerakiWidgets *g_widgets = nullptr;

class MerakiBar : public QObject {
        Q_OBJECT
        Q_PROPERTY(QVariantList workspaces READ workspaces NOTIFY workspacesChanged)
        Q_PROPERTY(QString activeName READ activeName NOTIFY workspacesChanged)
        Q_PROPERTY(bool centerOpen READ centerOpen NOTIFY centerChanged)
        Q_PROPERTY(int centerCount READ centerCount NOTIFY centerChanged)
        Q_PROPERTY(QVariantList trayItems READ trayItems NOTIFY trayChanged)
        Q_PROPERTY(int trayGen READ trayGen NOTIFY trayChanged)

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
                m_view->engine()->addImageProvider("trayicon",
                        new TrayIconProvider());
                m_view->setSource(QUrl(QStringLiteral("qrc:/qml/Meraki/Main.qml")));
                if (QScreen *screen = QGuiApplication::primaryScreen()) {
                        const QRect geometry = screen->geometry();
                        m_view->setGeometry(geometry.x(), geometry.y(), geometry.width(), 36);
                }
                refresh();
                m_view->show();
                syncTray();
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

        bool centerOpen() const {
                return g_center ? g_center->isOpen() : false;
        }

        int centerCount() const {
                return g_center ? g_center->count() : 0;
        }

        Q_INVOKABLE void toggleCenter() {
                if (g_center) {
                        g_center->toggle();
                }
        }

        Q_INVOKABLE void toggleApps() {
                if (g_apps) {
                        g_apps->toggle();
                }
        }

        QVariantList trayItems() const {
                return m_trayItems;
        }

        int trayGen() const {
                return m_trayGen;
        }

        Q_INVOKABLE void trayMouse(qint64 id, int button, bool down, qreal sx,
                qreal sy) {
                POINT p = { (long)sx, (long)sy };
                win32_tray_mouse((uint64_t)id, button, down, p);
        }

        Q_INVOKABLE void trayHover(qint64 id, int what, qreal sx, qreal sy) {
                POINT p = { (long)sx, (long)sy };
                win32_tray_hover((uint64_t)id, (enum tray_hover)what, p);
        }

        Q_INVOKABLE void trayRect(qreal x, qreal y, qreal w, qreal h) {
                RECT r = { (long)x, (long)y, (long)(x + w), (long)(y + h) };
                win32_tray_set_host_rect(&r);
        }

public slots:
        void syncTray() {
                QByteArray data;
                {
                        QMutexLocker lock(&g_tray_mutex);
                        data = g_tray_json;
                }
                QVariantList list;
                const QJsonArray arr = QJsonDocument::fromJson(data).array();
                for (const QJsonValue &v : arr) {
                        list.append(v.toObject().toVariantMap());
                }
                if (list != m_trayItems) {
                        m_trayItems = list;
                        ++m_trayGen;
                        emit trayChanged();
                }
        }

        void poll() {
                bool got = false;
                for (;;) {
                        uint32_t type = 0;
                        char *payload = nullptr;
                        if (!meraki_bridge_pop(&type, &payload)) {
                                break;
                        }
                        got = true;
                        if (type == (uint32_t)SWINE_IPC_EVENT_NOTIFICATION
                                && g_center) {
                                g_center->refreshNotes();
                        }
                        free(payload);
                }
                if (got) {
                        refresh();
                }
                if (g_center) {
                        const int cc = g_center->count();
                        const bool co = g_center->isOpen();
                        if (cc != m_centerCount || co != m_centerOpen) {
                                m_centerCount = cc;
                                m_centerOpen = co;
                                emit centerChanged();
                        }
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
        void centerChanged();
        void trayChanged();

private:
        static void runCommand(const std::string &command) {
                meraki_ipc_command(command.c_str());
        }

        QQuickView *m_view = nullptr;
        QTimer *m_timer = nullptr;
        QVariantList m_workspaces;
        QString m_activeName;
        int m_centerCount = 0;
        bool m_centerOpen = false;
        QVariantList m_trayItems;
        int m_trayGen = 0;
};

static MerakiBar *g_bar = nullptr;

static void meraki_tray_listener(void) {
        meraki_tray_snapshot();
        if (g_bar) {
                QMetaObject::invokeMethod(g_bar, "syncTray", Qt::QueuedConnection);
        }
}

static HANDLE g_thread = nullptr;
static QGuiApplication *g_app = nullptr;

static DWORD WINAPI meraki_qml_main(LPVOID arg) {
        (void)arg;
        int argc = 0;
        char *argv[] = {nullptr};
        QGuiApplication app(argc, argv);
        g_app = &app;
        qmlRegisterType<LiveThumb>("Meraki", 1, 0, "LiveThumb");
        MerakiFx fx;
        g_fx = &fx;
        fx.show();
        MerakiBar bar;
        g_bar = &bar;
        bar.show();
        MerakiDock dock;
        g_dock = &dock;
        dock.show();
        MerakiCenter center;
        g_center = &center;
        center.init();
        MerakiApps apps;
        g_apps = &apps;
        MerakiWidgets widgets;
        g_widgets = &widgets;
        widgets.show();
        app.exec();
        g_widgets = nullptr;
        g_apps = nullptr;
        g_bar = nullptr;
        g_center = nullptr;
        g_dock = nullptr;
        g_app = nullptr;
        g_fx = nullptr;
        return 0;
}

extern "C" void meraki_qml_start(void) {
        meraki_bridge_start();
        win32_tray_set_listener(meraki_tray_listener);
        win32_tray_force(true);
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
