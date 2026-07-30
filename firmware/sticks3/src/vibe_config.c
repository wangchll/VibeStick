#include "vibe_config.h"

#include <ctype.h>
#include <string.h>

#include "esp_check.h"
#include "esp_log.h"
#include "nvs.h"
#include "nvs_flash.h"

static const char *TAG = "vibe_config";

static bool valid_token(const char *value, size_t minimum, size_t maximum)
{
    size_t length = strlen(value);
    if (length < minimum || length > maximum) return false;
    for (size_t index = 0; index < length; ++index) {
        unsigned char character = (unsigned char)value[index];
        if (!isalnum(character) && character != '.' && character != '_' &&
            character != '~' && character != '-') {
            return false;
        }
    }
    return true;
}

static bool valid_wifi_password(const char *value)
{
    size_t length = strlen(value);
    if (length >= 8 && length <= 63) return true;
    if (length != 64) return false;
    for (size_t index = 0; index < length; ++index) {
        if (!isxdigit((unsigned char)value[index])) return false;
    }
    return true;
}

static esp_err_t read_string(nvs_handle_t handle, const char *key, char *value, size_t capacity)
{
    size_t required = capacity;
    ESP_RETURN_ON_ERROR(nvs_get_str(handle, key, value, &required), TAG, "read %s", key);
    ESP_RETURN_ON_FALSE(required > 1 && required <= capacity, ESP_ERR_INVALID_SIZE,
                        TAG, "invalid %s length", key);
    return ESP_OK;
}

esp_err_t vibe_config_load(vibe_config_t *config)
{
    ESP_RETURN_ON_FALSE(config != NULL, ESP_ERR_INVALID_ARG, TAG, "config is required");
    memset(config, 0, sizeof(*config));
    config->bridge_port = 8765;
    config->speaker_volume = 85;

    esp_err_t err = nvs_flash_init_partition(VIBE_CONFIG_PARTITION);
    if (err == ESP_ERR_NVS_NO_FREE_PAGES || err == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_LOGW(TAG, "configuration partition is unreadable; waiting for installer");
        return ESP_ERR_INVALID_STATE;
    }
    ESP_RETURN_ON_ERROR(err, TAG, "init configuration partition");

    nvs_handle_t handle;
    ESP_RETURN_ON_ERROR(
        nvs_open_from_partition(VIBE_CONFIG_PARTITION, VIBE_CONFIG_NAMESPACE,
                                NVS_READONLY, &handle),
        TAG, "open configuration");

    err = nvs_get_u16(handle, "schema", &config->schema);
    if (err == ESP_OK) err = read_string(handle, "wifi_ssid", config->wifi_ssid, sizeof(config->wifi_ssid));
    if (err == ESP_OK) err = read_string(handle, "wifi_pass", config->wifi_password, sizeof(config->wifi_password));
    if (err == ESP_OK) err = read_string(handle, "bridge_host", config->bridge_host, sizeof(config->bridge_host));
    if (err == ESP_OK) err = nvs_get_u16(handle, "bridge_port", &config->bridge_port);
    if (err == ESP_OK) err = read_string(handle, "bridge_token", config->bridge_token, sizeof(config->bridge_token));
    if (err == ESP_OK) err = read_string(handle, "deploy_nonce", config->deployment_nonce, sizeof(config->deployment_nonce));
    if (err == ESP_OK) err = nvs_get_u8(handle, "volume", &config->speaker_volume);
    nvs_close(handle);

    if (err != ESP_OK || config->schema != VIBE_CONFIG_SCHEMA_VERSION ||
        config->bridge_port == 0 || config->speaker_volume > 100 ||
        strlen(config->wifi_ssid) > 32 || !valid_wifi_password(config->wifi_password) ||
        !valid_token(config->bridge_token, 32, 256) ||
        !valid_token(config->deployment_nonce, 32, 128)) {
        memset(config, 0, sizeof(*config));
        config->bridge_port = 8765;
        config->speaker_volume = 85;
        ESP_LOGW(TAG, "configuration missing or invalid; waiting for installer");
        return err == ESP_OK ? ESP_ERR_INVALID_STATE : err;
    }

    config->configured = true;
    ESP_LOGI(TAG, "loaded configuration schema=%u host=%s:%u volume=%u",
             config->schema, config->bridge_host, config->bridge_port,
             config->speaker_volume);
    return ESP_OK;
}
