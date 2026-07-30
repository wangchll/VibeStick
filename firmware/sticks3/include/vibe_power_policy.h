#pragma once

#include <stdbool.h>
#include <stdint.h>

typedef enum {
    VIBE_POWER_DISPLAY_ACTIVE,
    VIBE_POWER_DISPLAY_DIMMED,
    VIBE_POWER_DISPLAY_OFF,
} vibe_power_display_state_t;

int64_t vibe_power_dim_after_ms(int64_t off_after_ms,
                                int64_t maximum_dim_after_ms);

vibe_power_display_state_t vibe_power_display_state(bool active_work,
                                                     int64_t now_ms,
                                                     int64_t last_activity_ms,
                                                     int64_t dim_after_ms,
                                                     int64_t off_after_ms);

bool vibe_power_should_deep_sleep(bool active_work,
                                  bool external_powered,
                                  bool display_off,
                                  int64_t now_ms,
                                  int64_t last_activity_ms,
                                  int64_t deep_sleep_after_ms);

bool vibe_power_completion_watch_update(bool current_watch,
                                        bool valid_state,
                                        const char *status,
                                        int active_conversations);

int64_t vibe_power_adaptive_interval_ms(bool display_off,
                                        bool completion_watch,
                                        int64_t active_interval_ms,
                                        int64_t watch_interval_ms);
