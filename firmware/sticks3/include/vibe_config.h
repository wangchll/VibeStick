#pragma once

#include <stdbool.h>
#include <stdint.h>

#include "esp_err.h"

#define VIBE_CONFIG_SCHEMA_VERSION 1
#define VIBE_CONFIG_PARTITION "vibe_cfg"
#define VIBE_CONFIG_NAMESPACE "vibe"

typedef struct {
    uint16_t schema;
    char wifi_ssid[33];
    char wifi_password[65];
    char bridge_host[254];
    uint16_t bridge_port;
    char bridge_token[257];
    char deployment_nonce[129];
    uint8_t speaker_volume;
    bool configured;
} vibe_config_t;

esp_err_t vibe_config_load(vibe_config_t *config);
