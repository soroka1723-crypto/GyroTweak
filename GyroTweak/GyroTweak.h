#pragma once

#ifdef __cplusplus
extern "C" {
#endif

// Экспорт символов из dylib (иначе Unity/dlsym могут их не увидеть).
#define GT_EXPORT __attribute__((visibility("default")))

// Инициализация гироскопа. Возвращает 0 при успехе, -1 при ошибке.
GT_EXPORT int GyroTweak_Init(void);

// Остановка и очистка.
GT_EXPORT void GyroTweak_Shutdown(void);

// Получить текущие данные гироскопа (рад/сек).
// Возвращает 0 при успехе, -1 если данных ещё нет / не инициализирован.
GT_EXPORT int GyroTweak_GetRotationRate(float* outX, float* outY, float* outZ);

// Получить данные акселерометра (в g).
GT_EXPORT int GyroTweak_GetAcceleration(float* outX, float* outY, float* outZ);

// Получить ориентацию устройства (quaternion).
GT_EXPORT int GyroTweak_GetAttitudeQuaternion(float* outX, float* outY, float* outZ, float* outW);

// Проверить, доступен ли гироскоп на устройстве.
GT_EXPORT int GyroTweak_IsAvailable(void);

// Чувствительность (мультипликатор для gyro/accel). Диапазон 0.1–5.0.
GT_EXPORT float GyroTweak_GetSensitivity(void);
GT_EXPORT void GyroTweak_SetSensitivity(float value);

#ifdef __cplusplus
}
#endif
