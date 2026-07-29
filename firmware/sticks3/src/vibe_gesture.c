#include "vibe_gesture.h"

#include <stdatomic.h>
#include <stdlib.h>
#include <string.h>

#include "bmi270.h"
#include "esp_log.h"
#include "esp_rom_sys.h"
#include "esp_timer.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

#define BMI270_ADDRESS 0x68
#define BMI270_I2C_HZ 400000
#define BMI270_IO_TIMEOUT_MS 200
#define POLL_INTERVAL_MS 10

// A tap produces a short, sharp acceleration derivative.  We deliberately
// require distinct impacts and defer double-tap output until its timeout so a
// third impact always wins.  Values are BMI270 raw counts at +/-4 g.
#define TAP_MIN_GAP_MS 55
#define TAP_MAX_GAP_MS 330
#define DOUBLE_TAP_SETTLE_MS 360
#define SHAKE_MIN_GAP_MS 55
#define SHAKE_MAX_GAP_MS 260
#define SHAKE_SETTLE_MS 420

static const char *TAG = "vibe_gesture";
static struct bmi2_dev s_imu;
static i2c_master_dev_handle_t s_i2c_device;
static vibe_gesture_callback_t s_callback;
static void *s_context;
static atomic_bool s_enabled;
static atomic_bool s_arm_requested;
static atomic_int s_window_ms = 4000;
static atomic_int s_sensitivity = VIBE_GESTURE_SENSITIVITY_CONSERVATIVE;

static BMI2_INTF_RETURN_TYPE imu_read(uint8_t reg, uint8_t *data, uint32_t len,
                                      void *context)
{
    (void)context;
    esp_err_t err = i2c_master_transmit_receive(s_i2c_device, &reg, 1, data, len,
                                                BMI270_IO_TIMEOUT_MS);
    return err == ESP_OK ? BMI2_INTF_RET_SUCCESS : BMI2_E_COM_FAIL;
}

static BMI2_INTF_RETURN_TYPE imu_write(uint8_t reg, const uint8_t *data, uint32_t len,
                                       void *context)
{
    (void)context;
    uint8_t buffer[33];
    if (len > sizeof(buffer) - 1) return BMI2_E_COM_FAIL;
    buffer[0] = reg;
    memcpy(buffer + 1, data, len);
    esp_err_t err = i2c_master_transmit(s_i2c_device, buffer, len + 1,
                                        BMI270_IO_TIMEOUT_MS);
    return err == ESP_OK ? BMI2_INTF_RET_SUCCESS : BMI2_E_COM_FAIL;
}

static void imu_delay_us(uint32_t period, void *context)
{
    (void)context;
    esp_rom_delay_us(period);
}

static void emit(vibe_gesture_event_t event)
{
    if (s_callback) s_callback(event, s_context);
}

static int tap_threshold(void)
{
    switch (atomic_load(&s_sensitivity)) {
    case VIBE_GESTURE_SENSITIVITY_SENSITIVE: return 6200;
    case VIBE_GESTURE_SENSITIVITY_STANDARD: return 7800;
    default: return 9600;
    }
}

static int shake_threshold(void)
{
    switch (atomic_load(&s_sensitivity)) {
    case VIBE_GESTURE_SENSITIVITY_SENSITIVE: return 2700;
    case VIBE_GESTURE_SENSITIVITY_STANDARD: return 3400;
    default: return 4100;
    }
}

static int8_t configure_accelerometer(void)
{
    struct bmi2_sens_config config = {.type = BMI2_ACCEL};
    int8_t result = bmi270_get_sensor_config(&config, 1, &s_imu);
    if (result != BMI2_OK) return result;
    config.cfg.acc.odr = BMI2_ACC_ODR_100HZ;
    config.cfg.acc.bwp = BMI2_ACC_NORMAL_AVG4;
    config.cfg.acc.filter_perf = BMI2_PERF_OPT_MODE;
    config.cfg.acc.range = BMI2_ACC_RANGE_4G;
    return bmi270_set_sensor_config(&config, 1, &s_imu);
}

static int8_t set_accelerometer_enabled(bool enabled)
{
    uint8_t sensors[] = {BMI2_ACCEL};
    return enabled
        ? bmi270_sensor_enable(sensors, 1, &s_imu)
        : bmi270_sensor_disable(sensors, 1, &s_imu);
}

static void gesture_task(void *arg)
{
    (void)arg;
    bool have_previous = false;
    int16_t previous_x = 0, previous_y = 0, previous_z = 0;
    int tap_count = 0, shake_count = 0;
    int64_t last_tap_ms = 0, last_shake_ms = 0;
    int64_t armed_at_ms = 0;
    bool accelerometer_active = false;

    while (true) {
        vTaskDelay(pdMS_TO_TICKS(POLL_INTERVAL_MS));
        if (!atomic_load(&s_enabled)) {
            if (accelerometer_active) {
                int8_t result = set_accelerometer_enabled(false);
                if (result != BMI2_OK) {
                    ESP_LOGW(TAG, "accelerometer power-down failed: %d", result);
                } else {
                    accelerometer_active = false;
                    ESP_LOGI(TAG, "accelerometer powered down");
                }
            }
            have_previous = false;
            tap_count = shake_count = 0;
            armed_at_ms = 0;
            atomic_store(&s_arm_requested, false);
            continue;
        }

        if (atomic_exchange(&s_arm_requested, false)) {
            if (!accelerometer_active) {
                int8_t result = set_accelerometer_enabled(true);
                if (result != BMI2_OK) {
                    ESP_LOGW(TAG, "accelerometer power-up failed: %d", result);
                    continue;
                }
                accelerometer_active = true;
                // Allow two 100 Hz samples for the accelerometer output and
                // filter state to settle before opening the visible window.
                vTaskDelay(pdMS_TO_TICKS(20));
            }
            have_previous = false;
            tap_count = shake_count = 0;
            armed_at_ms = esp_timer_get_time() / 1000;
            emit(VIBE_GESTURE_ARMED);
            ESP_LOGI(TAG, "button chord armed tap/shake window");
        }
        if (armed_at_ms == 0) {
            if (accelerometer_active) {
                int8_t result = set_accelerometer_enabled(false);
                if (result != BMI2_OK) {
                    ESP_LOGW(TAG, "idle accelerometer power-down retry failed: %d", result);
                } else {
                    accelerometer_active = false;
                    ESP_LOGI(TAG, "accelerometer powered down after gesture window");
                }
            }
            continue;
        }

        int64_t now_ms = esp_timer_get_time() / 1000;
        if (now_ms - armed_at_ms > atomic_load(&s_window_ms)) {
            int8_t result = set_accelerometer_enabled(false);
            if (result != BMI2_OK) {
                ESP_LOGW(TAG, "accelerometer power-down failed: %d", result);
            } else {
                accelerometer_active = false;
            }
            emit(VIBE_GESTURE_EXPIRED);
            armed_at_ms = 0;
            have_previous = false;
            tap_count = shake_count = 0;
            continue;
        }

        struct bmi2_sens_data data = {0};
        if (bmi2_get_sensor_data(&data, &s_imu) != BMI2_OK) continue;
        int16_t x = data.acc.x, y = data.acc.y, z = data.acc.z;
        if (!have_previous) {
            previous_x = x; previous_y = y; previous_z = z;
            have_previous = true;
            continue;
        }
        int derivative = abs((int)x - previous_x) + abs((int)y - previous_y) + abs((int)z - previous_z);
        previous_x = x; previous_y = y; previous_z = z;
        if (tap_count == 2 && now_ms - last_tap_ms > DOUBLE_TAP_SETTLE_MS) {
            int8_t result = set_accelerometer_enabled(false);
            if (result != BMI2_OK) {
                ESP_LOGW(TAG, "accelerometer power-down failed: %d", result);
            } else {
                accelerometer_active = false;
            }
            emit(VIBE_GESTURE_DOUBLE_TAP);
            tap_count = 0;
            armed_at_ms = 0;
            have_previous = false;
            continue;
        }
        if (shake_count && now_ms - last_shake_ms > SHAKE_SETTLE_MS) shake_count = 0;

        if (derivative >= tap_threshold()) {
            if (tap_count == 0 || now_ms - last_tap_ms > TAP_MAX_GAP_MS) tap_count = 1;
            else if (now_ms - last_tap_ms >= TAP_MIN_GAP_MS) ++tap_count;
            last_tap_ms = now_ms;
            shake_count = 0;
            if (tap_count >= 3) {
                ESP_LOGI(TAG, "triple tap detected (derivative=%d)", derivative);
                int8_t result = set_accelerometer_enabled(false);
                if (result != BMI2_OK) {
                    ESP_LOGW(TAG, "accelerometer power-down failed: %d", result);
                } else {
                    accelerometer_active = false;
                }
                emit(VIBE_GESTURE_TRIPLE_TAP);
                tap_count = 0;
                armed_at_ms = 0;
                have_previous = false;
            }
            continue;
        }

        if (derivative >= shake_threshold()) {
            if (shake_count == 0 || now_ms - last_shake_ms > SHAKE_MAX_GAP_MS) shake_count = 1;
            else if (now_ms - last_shake_ms >= SHAKE_MIN_GAP_MS) ++shake_count;
            last_shake_ms = now_ms;
            tap_count = 0;
            if (shake_count >= 4) {
                ESP_LOGI(TAG, "shake detected (derivative=%d)", derivative);
                int8_t result = set_accelerometer_enabled(false);
                if (result != BMI2_OK) {
                    ESP_LOGW(TAG, "accelerometer power-down failed: %d", result);
                } else {
                    accelerometer_active = false;
                }
                emit(VIBE_GESTURE_SHAKE);
                shake_count = 0;
                armed_at_ms = 0;
                have_previous = false;
            }
        }
    }
}

esp_err_t vibe_gesture_init(i2c_master_bus_handle_t bus,
                            vibe_gesture_callback_t callback,
                            void *context)
{
    if (!bus || !callback) return ESP_ERR_INVALID_ARG;
    i2c_device_config_t device_config = {
        .dev_addr_length = I2C_ADDR_BIT_LEN_7,
        .device_address = BMI270_ADDRESS,
        .scl_speed_hz = BMI270_I2C_HZ,
    };
    esp_err_t err = i2c_master_bus_add_device(bus, &device_config, &s_i2c_device);
    if (err != ESP_OK) return err;
    memset(&s_imu, 0, sizeof(s_imu));
    s_imu.intf = BMI2_I2C_INTF;
    s_imu.intf_ptr = s_i2c_device;
    s_imu.read = imu_read;
    s_imu.write = imu_write;
    s_imu.delay_us = imu_delay_us;
    s_imu.read_write_len = 32;
    if (bmi270_init(&s_imu) != BMI2_OK || configure_accelerometer() != BMI2_OK) {
        ESP_LOGE(TAG, "BMI270 accelerometer setup failed");
        return ESP_FAIL;
    }
    s_callback = callback;
    s_context = context;
    if (xTaskCreate(gesture_task, "gesture", 4096, NULL, 5, NULL) != pdPASS) {
        return ESP_ERR_NO_MEM;
    }
    ESP_LOGI(TAG, "BMI270 tap/shake engine ready; accelerometer powered down");
    return ESP_OK;
}

void vibe_gesture_set_enabled(bool enabled, int window_ms,
                              vibe_gesture_sensitivity_t sensitivity)
{
    atomic_store(&s_window_ms, window_ms < 2000 ? 2000 : (window_ms > 8000 ? 8000 : window_ms));
    atomic_store(&s_sensitivity, sensitivity);
    atomic_store(&s_enabled, enabled);
    if (!enabled) atomic_store(&s_arm_requested, false);
}

bool vibe_gesture_is_enabled(void)
{
    return atomic_load(&s_enabled);
}

esp_err_t vibe_gesture_arm(void)
{
    if (!s_i2c_device || !atomic_load(&s_enabled)) return ESP_ERR_INVALID_STATE;
    atomic_store(&s_arm_requested, true);
    return ESP_OK;
}
