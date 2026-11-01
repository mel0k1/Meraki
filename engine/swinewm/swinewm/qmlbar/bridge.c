#include <windows.h>
#include <stdlib.h>
#include "ipc-client.h"
#include "ipc.h"
#include "qmlbar.h"

#define MERAKI_QUEUE_MAX 64

struct meraki_item {
	uint32_t type;
	char *payload;
};

static struct meraki_item queue[MERAKI_QUEUE_MAX];
static size_t queue_head;
static size_t queue_len;
static CRITICAL_SECTION queue_lock;
static HANDLE thread;
static volatile LONG running;

static void queue_push(uint32_t type, char *payload) {
	if (!payload) {
		return;
	}
	EnterCriticalSection(&queue_lock);
	if (queue_len == MERAKI_QUEUE_MAX) {
		free(queue[queue_head].payload);
		queue[queue_head].payload = NULL;
		queue_head = (queue_head + 1) % MERAKI_QUEUE_MAX;
		--queue_len;
	}
	size_t tail = (queue_head + queue_len) % MERAKI_QUEUE_MAX;
	queue[tail].type = type;
	queue[tail].payload = payload;
	++queue_len;
	LeaveCriticalSection(&queue_lock);
}

int meraki_bridge_pop(uint32_t *type, char **payload) {
	int got = 0;
	EnterCriticalSection(&queue_lock);
	if (queue_len > 0) {
		struct meraki_item item = queue[queue_head];
		queue[queue_head].payload = NULL;
		queue_head = (queue_head + 1) % MERAKI_QUEUE_MAX;
		--queue_len;
		got = 1;
		*type = item.type;
		*payload = item.payload;
	}
	LeaveCriticalSection(&queue_lock);
	return got;
}

static DWORD WINAPI bridge_main(LPVOID arg) {
	(void)arg;
	while (InterlockedCompareExchange(&running, 1, 1)) {
		char *error = NULL;
		void *connection = ipc_connect(NULL, &error);
		if (error) {
			free(error);
			error = NULL;
		}
		if (!connection) {
			Sleep(1000);
			continue;
		}
		if (!ipc_send(connection, IPC_SUBSCRIBE,
				"[\"workspace\",\"window\"]")) {
			ipc_close(connection);
			Sleep(1000);
			continue;
		}
		for (;;) {
			uint32_t type = 0;
			char *payload = ipc_receive(connection, &type);
			if (!payload) {
				break;
			}
			queue_push(type, payload);
		}
		ipc_close(connection);
		if (!InterlockedCompareExchange(&running, 1, 1)) {
			break;
		}
		Sleep(1000);
	}
	return 0;
}

void meraki_bridge_start(void) {
	InitializeCriticalSection(&queue_lock);
	running = 1;
	thread = CreateThread(NULL, 0, bridge_main, NULL, 0, NULL);
}

void meraki_bridge_stop(void) {
	running = 0;
	if (thread) {
		WaitForSingleObject(thread, 3000);
		CloseHandle(thread);
		thread = NULL;
	}
}
