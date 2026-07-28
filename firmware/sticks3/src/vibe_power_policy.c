#include "vibe_power_policy.h"

int64_t vibe_power_dim_after_ms(int64_t off_after_ms,
                                int64_t maximum_dim_after_ms)
{
    if (off_after_ms <= 0) {
        return 0;
    }
    const int64_t half = off_after_ms / 2;
    return half < maximum_dim_after_ms ? half : maximum_dim_after_ms;
}

vibe_power_display_state_t vibe_power_display_state(bool active_work,
                                                     int64_t now_ms,
                                                     int64_t last_activity_ms,
                                                     int64_t dim_after_ms,
                                                     int64_t off_after_ms)
{
    if (active_work || off_after_ms <= 0 || last_activity_ms <= 0 ||
        now_ms < last_activity_ms) {
        return VIBE_POWER_DISPLAY_ACTIVE;
    }
    const int64_t idle_ms = now_ms - last_activity_ms;
    if (idle_ms >= off_after_ms) {
        return VIBE_POWER_DISPLAY_OFF;
    }
    if (idle_ms >= dim_after_ms) {
        return VIBE_POWER_DISPLAY_DIMMED;
    }
    return VIBE_POWER_DISPLAY_ACTIVE;
}

bool vibe_power_should_deep_sleep(bool active_work,
                                  bool external_powered,
                                  bool display_off,
                                  int64_t now_ms,
                                  int64_t last_activity_ms,
                                  int64_t deep_sleep_after_ms)
{
    return !active_work && !external_powered && display_off &&
           last_activity_ms > 0 && now_ms >= last_activity_ms &&
           now_ms - last_activity_ms >= deep_sleep_after_ms;
}
