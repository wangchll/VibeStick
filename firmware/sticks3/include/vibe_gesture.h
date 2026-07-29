#pragma once

#include <stdbool.h>

#include "driver/i2c_master.h"
#include "esp_err.h"

typedef enum {
    VIBE_GESTURE_NONE,
    VIBE_GESTURE_ARMED,
    VIBE_GESTURE_EXPIRED,
    VIBE_GESTURE_DOUBLE_TAP,
    VIBE_GESTURE_TRIPLE_TAP,
    VIBE_GESTURE_SHAKE,
} vibe_gesture_event_t;

typedef enum {
    VIBE_GESTURE_SENSITIVITY_CONSERVATIVE,
    VIBE_GESTURE_SENSITIVITY_STANDARD,
    VIBE_GESTURE_SENSITIVITY_SENSITIVE,
} vibe_gesture_sensitivity_t;

typedef void (*vibe_gesture_callback_t)(vibe_gesture_event_t event, void *context);

esp_err_t vibe_gesture_init(i2c_master_bus_handle_t bus,
                            vibe_gesture_callback_t callback,
                            void *context);
void vibe_gesture_set_enabled(bool enabled, int window_ms,
                              vibe_gesture_sensitivity_t sensitivity);
bool vibe_gesture_is_enabled(void);
esp_err_t vibe_gesture_arm(void);
