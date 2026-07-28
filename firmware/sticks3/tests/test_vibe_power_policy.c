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
    return 0;
}
