#ifndef MERAKI_QMLBAR_H
#define MERAKI_QMLBAR_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

void meraki_qml_start(void);
void meraki_qml_stop(void);
void meraki_bridge_start(void);
void meraki_bridge_stop(void);
int meraki_bridge_pop(uint32_t *type, char **payload);
void meraki_ipc_command(const char *cmd);

#ifdef __cplusplus
}
#endif

#endif
