#include "capture.h"

#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#include <d3d11.h>
#include <dxgi1_2.h>

#include <QQmlContext>
#include <QQmlEngine>
#include <QPainter>
#include <QQuickImageProvider>
#include <QQuickView>
#include <QScreen>
#include <QTimerEvent>
#include <QVariantMap>

#include <algorithm>
#include <cstdio>
#include <cstring>
#include <utility>

#include <dwmapi.h>

#include <winrt/base.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Graphics.Capture.h>
#include <winrt/Windows.Graphics.DirectX.h>
#include <winrt/Windows.Graphics.DirectX.Direct3D11.h>
#include <windows.graphics.capture.interop.h>
#include <windows.graphics.directx.direct3d11.interop.h>

extern "C" {
#include "qmlbar.h"
}

using namespace winrt;
using namespace winrt::Windows::Graphics::Capture;
namespace wgdx = winrt::Windows::Graphics::DirectX;
namespace wgd3d = winrt::Windows::Graphics::DirectX::Direct3D11;

static winrt::com_ptr<ID3D11Device> capture_device() {
        static winrt::com_ptr<ID3D11Device> dev;
        static bool done = false;
        if (done) {
                return dev;
        }
        done = true;
        UINT flags = D3D11_CREATE_DEVICE_BGRA_SUPPORT;
        D3D_FEATURE_LEVEL fl = D3D_FEATURE_LEVEL_11_0;
        winrt::com_ptr<ID3D11DeviceContext> ctx;
        HRESULT hr = D3D11CreateDevice(nullptr, D3D_DRIVER_TYPE_HARDWARE, nullptr, flags,
                nullptr, 0, D3D11_SDK_VERSION, dev.put(), &fl, ctx.put());
        if (FAILED(hr)) {
                D3D11CreateDevice(nullptr, D3D_DRIVER_TYPE_WARP, nullptr, flags, nullptr, 0,
                        D3D11_SDK_VERSION, dev.put(), &fl, ctx.put());
        }
        return dev;
}

static wgdx::Direct3D11::IDirect3DDevice wrap_device(ID3D11Device *dev) {
        winrt::com_ptr<IDXGIDevice> dxgi;
        winrt::check_hresult(dev->QueryInterface(IID_IDXGIDevice, dxgi.put_void()));
        winrt::com_ptr<::IInspectable> insp;
        winrt::check_hresult(CreateDirect3D11DeviceFromDXGIDevice(dxgi.get(), insp.put()));
        return insp.as<wgdx::Direct3D11::IDirect3DDevice>();
}

static GraphicsCaptureItem item_for_window(HWND hwnd) {
        auto interop = winrt::get_activation_factory<GraphicsCaptureItem,
                IGraphicsCaptureItemInterop>();
        GraphicsCaptureItem item{nullptr};
        winrt::check_hresult(interop->CreateForWindow(hwnd,
                winrt::guid_of<GraphicsCaptureItem>(),
                reinterpret_cast<void **>(winrt::put_abi(item))));
        return item;
}

struct Grabber::Impl {
        winrt::com_ptr<ID3D11Device> device;
        winrt::com_ptr<ID3D11DeviceContext> context;
        wgdx::Direct3D11::IDirect3DDevice d3d{nullptr};
        GraphicsCaptureItem item{nullptr};
        Direct3D11CaptureFramePool pool{nullptr};
        GraphicsCaptureSession session{nullptr};
        winrt::com_ptr<ID3D11Texture2D> staging;
        UINT w = 0;
        UINT h = 0;
        INT poolW = 0;
        INT poolH = 0;
};

Grabber::~Grabber() {
        stop();
}

bool Grabber::start(void *handle) {
        stop();
        HWND hwnd = (HWND)handle;
        if (!hwnd || !IsWindow(hwnd) || IsIconic(hwnd)) {
                return false;
        }
        try {
                winrt::init_apartment(winrt::apartment_type::multi_threaded);
                winrt::com_ptr<ID3D11Device> dev = capture_device();
                if (!dev) {
                        return false;
                }
                d = std::make_unique<Impl>();
                d->device = dev;
                d->device->GetImmediateContext(d->context.put());
                d->d3d = wrap_device(dev.get());
                d->item = item_for_window(hwnd);
                auto size = d->item.Size();
                d->pool = Direct3D11CaptureFramePool::CreateFreeThreaded(d->d3d,
                        wgdx::DirectXPixelFormat::B8G8R8A8UIntNormalized, 2, size);
                d->poolW = size.Width;
                d->poolH = size.Height;
                d->session = d->pool.CreateCaptureSession(d->item);
                try {
                        d->session.IsCursorCaptureEnabled(false);
                } catch (...) {
                }
                try {
                        d->session.IsBorderRequired(false);
                } catch (...) {
                }
                d->session.StartCapture();
                m_running = true;
                return true;
        } catch (...) {
                d.reset();
                return false;
        }
}

bool Grabber::pump() {
        if (!m_running || !d) {
                return false;
        }
        Direct3D11CaptureFrame last{nullptr};
        try {
                while (auto f = d->pool.TryGetNextFrame()) {
                        last = f;
                }
        } catch (...) {
                return false;
        }
        if (!last) {
                return false;
        }
        try {
                auto cs = last.ContentSize();
                if (d->poolW != cs.Width || d->poolH != cs.Height) {
                        d->pool.Recreate(d->d3d,
                                wgdx::DirectXPixelFormat::B8G8R8A8UIntNormalized, 2, cs);
                        d->poolW = cs.Width;
                        d->poolH = cs.Height;
                        return false;
                }
                UINT w = UINT(cs.Width < 1 ? 1 : cs.Width);
                UINT h = UINT(cs.Height < 1 ? 1 : cs.Height);
                auto access = last.Surface().as<wgd3d::IDirect3DDxgiInterfaceAccess>();
                winrt::com_ptr<ID3D11Texture2D> tex;
                winrt::check_hresult(access->GetInterface(__uuidof(ID3D11Texture2D),
                        tex.put_void()));
                if (d->w != w || d->h != h || !d->staging) {
                        D3D11_TEXTURE2D_DESC sd = {};
                        sd.Width = w;
                        sd.Height = h;
                        sd.MipLevels = 1;
                        sd.ArraySize = 1;
                        sd.Format = DXGI_FORMAT_B8G8R8A8_UNORM;
                        sd.SampleDesc.Count = 1;
                        sd.Usage = D3D11_USAGE_STAGING;
                        sd.CPUAccessFlags = D3D11_CPU_ACCESS_READ;
                        winrt::com_ptr<ID3D11Texture2D> st;
                        winrt::check_hresult(d->device->CreateTexture2D(&sd, nullptr,
                                st.put()));
                        d->staging = st;
                        d->w = w;
                        d->h = h;
                        m_image = QImage(int(w), int(h), QImage::Format_ARGB32);
                }
                d->context->CopyResource(d->staging.get(), tex.get());
                D3D11_MAPPED_SUBRESOURCE m = {};
                winrt::check_hresult(d->context->Map(d->staging.get(), 0, D3D11_MAP_READ, 0,
                        &m));
                for (UINT y = 0; y < h; ++y) {
                        std::memcpy(m_image.scanLine(int(y)),
                                (const uint8_t *)m.pData + size_t(y) * m.RowPitch,
                                size_t(w) * 4);
                }
                d->context->Unmap(d->staging.get(), 0);
                return true;
        } catch (...) {
                return false;
        }
}

void Grabber::stop() {
        if (d) {
                try {
                        if (d->session) {
                                d->session.Close();
                        }
                } catch (...) {
                }
                try {
                        if (d->pool) {
                                d->pool.Close();
                        }
                } catch (...) {
                }
        }
        d.reset();
        m_running = false;
        m_image = QImage();
}

LiveThumb::LiveThumb(QQuickItem *parent) : QQuickPaintedItem(parent) {
        setFillColor(Qt::transparent);
}

void LiveThumb::setHwnd(qint64 hwnd) {
        if (m_hwnd == hwnd) {
                return;
        }
        m_hwnd = hwnd;
        emit hwndChanged();
        m_grab.stop();
        m_image = QImage();
        stopTimer();
        if (m_hwnd && m_grab.start((void *)(size_t)m_hwnd)) {
                m_timerId = startTimer(60);
        }
        update();
}

void LiveThumb::stopTimer() {
        if (m_timerId) {
                killTimer(m_timerId);
                m_timerId = 0;
        }
}

void LiveThumb::timerEvent(QTimerEvent *event) {
        if (event->timerId() == m_timerId) {
                HWND h = (HWND)(size_t)m_hwnd;
                if (!h || !IsWindow(h)) {
                        stopTimer();
                        m_grab.stop();
                } else if (m_grab.pump()) {
                        m_image = m_grab.image();
                        update();
                }
        }
        QQuickPaintedItem::timerEvent(event);
}

void LiveThumb::paint(QPainter *painter) {
        if (m_image.isNull()) {
                painter->fillRect(boundingRect(), QColor(255, 255, 255, 22));
                return;
        }
        QRectF target = boundingRect();
        qreal s = std::min(target.width() / m_image.width(),
                target.height() / m_image.height());
        qreal w = m_image.width() * s;
        qreal h = m_image.height() * s;
        painter->setRenderHint(QPainter::SmoothPixmapTransform);
        painter->drawImage(QRectF(target.x() + (target.width() - w) / 2,
                target.y() + (target.height() - h) / 2, w, h), m_image);
}

class GenieProvider : public QQuickImageProvider {
public:
        GenieProvider() : QQuickImageProvider(QQuickImageProvider::Image) {}

        QImage requestImage(const QString &, QSize *size, const QSize &) override {
                if (size) {
                        *size = m_image.size();
                }
                return m_image;
        }

        void setImage(const QImage &image) {
                m_image = image;
        }

private:
        QImage m_image;
};

static QUrl bump_url(quint64 &gen) {
        ++gen;
        return QUrl(QStringLiteral("image://geniefx/%1").arg(gen));
}

MerakiFx::MerakiFx(QObject *parent) : QObject(parent) {
        m_grab = std::make_unique<Grabber>();
        m_timer = new QTimer(this);
        m_timer->setInterval(30);
        connect(m_timer, &QTimer::timeout, this, &MerakiFx::pump);
}

void MerakiFx::show() {
        QQuickView *view = new QQuickView();
        view->setFlags(Qt::FramelessWindowHint | Qt::WindowStaysOnTopHint | Qt::Tool |
                Qt::NoDropShadowWindowHint | Qt::WindowTransparentForInput);
        view->setColor(Qt::transparent);
        view->setResizeMode(QQuickView::SizeRootObjectToView);
        GenieProvider *provider = new GenieProvider();
        m_provider = provider;
        view->engine()->addImageProvider("geniefx", provider);
        view->rootContext()->setContextProperty("fx", this);
        view->setSource(QUrl(QStringLiteral("qrc:/qml/Meraki/MinimizeFx.qml")));
        if (QScreen *screen = QGuiApplication::primaryScreen()) {
                view->setGeometry(screen->geometry());
                m_dpr = screen->devicePixelRatio();
        }
        view->show();
        m_view = view;
}

void MerakiFx::beginMinimize(qint64 hwnd, qint64 id, qreal wx, qreal wy, qreal ww,
        qreal wh, qreal tx, qreal ty, qreal tw, qreal th) {
        if (m_busy) {
                return;
        }
        m_reverse = false;
        QVariantMap job;
        job.insert("hwnd", hwnd);
        job.insert("id", id);
        job.insert("win", QRectF(wx / m_dpr, wy / m_dpr, ww / m_dpr, wh / m_dpr));
        job.insert("target", QRectF(tx / m_dpr, ty / m_dpr, tw / m_dpr, th / m_dpr));
        job.insert("reverse", false);
        if (!m_grab->start((void *)(size_t)hwnd)) {
                commitMinimize(hwnd);
                finishJob(hwnd);
                return;
        }
        m_busy = true;
        m_job = job;
        m_deadline = GetTickCount64() + 900;
        m_timer->start();
        emit jobStarted(job);
}

void MerakiFx::beginRestore(qint64 hwnd, qint64 id, qreal tx, qreal ty, qreal tw,
        qreal th) {
        if (m_busy) {
                return;
        }
        auto it = m_cache.find((void *)(size_t)hwnd);
        if (it == m_cache.end() || it->second.image.isNull()) {
                QVariantMap job;
                job.insert("hwnd", hwnd);
                job.insert("id", id);
                m_job = job;
                restoreNow();
                finishJob(hwnd);
                return;
        }
        m_reverse = true;
        if (m_provider) {
                static_cast<GenieProvider *>(m_provider)->setImage(it->second.image);
        }
        m_snapshotUrl = bump_url(m_gen);
        emit snapshotUrlChanged();
        QVariantMap job;
        job.insert("hwnd", hwnd);
        job.insert("id", id);
        job.insert("win", it->second.win);
        job.insert("target", QRectF(tx / m_dpr, ty / m_dpr, tw / m_dpr, th / m_dpr));
        job.insert("reverse", true);
        m_busy = true;
        m_job = job;
        emit jobStarted(job);
}

void MerakiFx::pump() {
        if (!m_busy || m_reverse) {
                return;
        }
        if (m_grab->pump()) {
                if (m_provider) {
                        static_cast<GenieProvider *>(m_provider)->setImage(m_grab->image());
                }
                m_snapshotUrl = bump_url(m_gen);
                emit snapshotUrlChanged();
                m_timer->stop();
                return;
        }
        if (GetTickCount64() > m_deadline) {
                m_timer->stop();
                m_grab->stop();
                commitMinimize(m_job.value("hwnd").toLongLong());
                m_busy = false;
        }
}

void MerakiFx::commitMinimize(qint64 hwnd) {
        HWND h = (HWND)(size_t)hwnd;
        DWORD on = TRUE;
        DWORD off = FALSE;
        DwmSetWindowAttribute(h, DWMWA_TRANSITIONS_FORCEDISABLED, &on, sizeof(on));
        ShowWindow(h, SW_MINIMIZE);
        DwmSetWindowAttribute(h, DWMWA_TRANSITIONS_FORCEDISABLED, &off, sizeof(off));
        if (m_grab->running() && !m_grab->image().isNull()) {
                Cache c;
                c.image = m_grab->image();
                c.win = m_job.value("win").toRectF();
                m_cache[(void *)h] = c;
        }
}

void MerakiFx::restoreNow() {
        qlonglong hwnd = m_job.value("hwnd").toLongLong();
        qlonglong id = m_job.value("id").toLongLong();
        HWND h = (HWND)(size_t)hwnd;
        if (IsIconic(h)) {
                ShowWindow(h, SW_RESTORE);
        }
        if (id > 0) {
                char cmd[64];
                std::snprintf(cmd, sizeof(cmd), "[con_id=%lld] focus", (long long)id);
                meraki_ipc_command(cmd);
        }
}

void MerakiFx::commitRestore(qint64 hwnd, qint64 id) {
        m_job.insert("hwnd", hwnd);
        m_job.insert("id", id);
        restoreNow();
}

void MerakiFx::finishJob(qint64 hwnd) {
        m_busy = false;
        m_timer->stop();
        m_grab->stop();
        if (m_reverse) {
                m_cache.erase((void *)(size_t)hwnd);
        }
        m_reverse = false;
}

void MerakiFx::cancelJob(qint64 hwnd) {
        if (!m_busy) {
                return;
        }
        if (m_reverse) {
                restoreNow();
        } else {
                commitMinimize(hwnd);
        }
        finishJob(hwnd);
}
