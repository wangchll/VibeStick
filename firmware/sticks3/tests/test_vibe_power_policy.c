#include "vibe_power_policy.h"

#include <assert.h>

int main(void)
{
    assert(vibe_power_dim_after_ms(10000, 30000) == 5000);
    assert(vibe_power_dim_after_ms(60000, 30000) == 30000);
    assert(vibe_power_dim_after_ms(300000, 30000) == 30000);
    assert(vibe_power_dim_after_ms(0, 30000) == 0);
    assert(vibe_power_display_state(false, 10, 0, 30, 60) ==
           VIBE_POWER_DISPLAY_ACTIVE);
    assert(vibe_power_display_state(false, 29, 1, 30, 60) ==
           VIBE_POWER_DISPLAY_ACTIVE);
    assert(vibe_power_display_state(false, 31, 1, 30, 60) ==
           VIBE_POWER_DISPLAY_DIMMED);
    assert(vibe_power_display_state(false, 61, 1, 30, 60) ==
           VIBE_POWER_DISPLAY_OFF);
    assert(vibe_power_display_state(true, 100, 1, 30, 60) ==
           VIBE_POWER_DISPLAY_ACTIVE);
    assert(vibe_power_display_state(false, 1, 2, 30, 60) ==
           VIBE_POWER_DISPLAY_ACTIVE);
    assert(vibe_power_display_state(false, 100000, 1, 0, 0) ==
           VIBE_POWER_DISPLAY_ACTIVE);
    assert(vibe_power_should_deep_sleep(false, false, true, 301, 1, 300));
    assert(!vibe_power_should_deep_sleep(true, false, true, 301, 1, 300));
    assert(!vibe_power_should_deep_sleep(false, true, true, 301, 1, 300));
    assert(!vibe_power_should_deep_sleep(false, false, false, 301, 1, 300));
    assert(vibe_power_completion_watch_update(false, true, "RUNNING", 0));
    assert(vibe_power_completion_watch_update(false, true, "APPROVAL", 0));
    assert(vibe_power_completion_watch_update(false, true, "ERROR", 1));
    assert(!vibe_power_completion_watch_update(true, true, "DONE", 0));
    assert(!vibe_power_completion_watch_update(true, true, "ERROR", 0));
    assert(vibe_power_completion_watch_update(true, false, "OFFLINE", 0));
    assert(!vibe_power_completion_watch_update(false, false, "RUNNING", 1));
    bool completion_watch =
        vibe_power_completion_watch_update(false, true, "RUNNING", 1);
    assert(!vibe_power_should_deep_sleep(completion_watch, false, true,
                                         301, 1, 300));
    completion_watch =
        vibe_power_completion_watch_update(completion_watch, true, "DONE", 0);
    assert(vibe_power_should_deep_sleep(completion_watch, false, true,
                                        301, 1, 300));
    assert(vibe_power_adaptive_interval_ms(false, true, 2000, 30000) == 2000);
    assert(vibe_power_adaptive_interval_ms(true, false, 2000, 30000) == 2000);
    assert(vibe_power_adaptive_interval_ms(true, true, 2000, 30000) == 30000);
    assert(vibe_power_adaptive_interval_ms(true, true, 60000, 300000) == 300000);
    return 0;
}
