#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>

#include <QGuiApplication>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QMetaObject>
#include <QQmlContext>
#include <QQuickView>
#include <QRect>
#include <QScreen>
#include <QSurfaceFormat>
#include <QTimer>
#include <QUrl>
#include <QVariantMap>

#include <cstring>
#include <string>

extern "C" {
#include "ipc-client.h"
#include "ipc.h"
#include "qmlbar.h"
}

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
		char *error = nullptr;
		char *reply = ipc_request(nullptr, IPC_COMMAND, command.c_str(), &error);
		if (reply) {
			free(reply);
		}
		if (error) {
			free(error);
		}
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
	app.exec();
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
