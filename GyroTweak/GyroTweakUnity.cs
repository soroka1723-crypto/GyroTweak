using System.Runtime.InteropServices;
using UnityEngine;

/// <summary>
/// Обёртка для вызова нативного GyroTweak.dylib из Unity.
/// Положи GyroTweak.dylib в Assets/Plugins/iOS/ (или используй DllImport с полным путем после инжекта).
/// </summary>
public static class GyroTweak
{
    // Имя библиотеки — как будет называться твой .dylib после сборки
    private const string LIB = "GyroTweak";

    [DllImport(LIB, CallingConvention = CallingConvention.Cdecl)]
    private static extern int GyroTweak_Init();

    [DllImport(LIB, CallingConvention = CallingConvention.Cdecl)]
    private static extern void GyroTweak_Shutdown();

    [DllImport(LIB, CallingConvention = CallingConvention.Cdecl)]
    private static extern int GyroTweak_GetRotationRate(out float x, out float y, out float z);

    [DllImport(LIB, CallingConvention = CallingConvention.Cdecl)]
    private static extern int GyroTweak_GetAcceleration(out float x, out float y, out float z);

    [DllImport(LIB, CallingConvention = CallingConvention.Cdecl)]
    private static extern int GyroTweak_GetAttitudeQuaternion(out float x, out float y, out float z, out float w);

    [DllImport(LIB, CallingConvention = CallingConvention.Cdecl)]
    private static extern int GyroTweak_IsAvailable();

    [DllImport(LIB, CallingConvention = CallingConvention.Cdecl)]
    private static extern float GyroTweak_GetSensitivity();

    [DllImport(LIB, CallingConvention = CallingConvention.Cdecl)]
    private static extern void GyroTweak_SetSensitivity(float value);

    public static bool IsInitialized { get; private set; }
    public static bool IsAvailable => GyroTweak_IsAvailable() == 1;

    /// <summary>
    /// Текущая чувствительность (мультипликатор для gyro/accel). Диапазон 0.1–5.0.
    /// </summary>
    public static float Sensitivity
    {
        get => GyroTweak_GetSensitivity();
        set => GyroTweak_SetSensitivity(Mathf.Clamp(value, 0.1f, 5f));
    }

    /// <summary>
    /// Инициализировать гироскоп. Вызови один раз при старте (Awake/Start).
    /// </summary>
    public static bool Init()
    {
        if (IsInitialized) return true;
        int result = GyroTweak_Init();
        IsInitialized = result == 0;
        if (!IsInitialized)
            Debug.LogError("[GyroTweak] Init failed");
        return IsInitialized;
    }

    /// <summary>
    /// Остановить и очистить ресурсы. Вызови в OnDestroy/OnApplicationQuit.
    /// </summary>
    public static void Shutdown()
    {
        if (!IsInitialized) return;
        GyroTweak_Shutdown();
        IsInitialized = false;
    }

    /// <summary>
    /// Получить угловую скорость (рад/сек) по осям X, Y, Z.
    /// </summary>
    public static bool GetRotationRate(out Vector3 rate)
    {
        rate = Vector3.zero;
        if (!IsInitialized) return false;
        return GyroTweak_GetRotationRate(out rate.x, out rate.y, out rate.z) == 0;
    }

    /// <summary>
    /// Получить ускорение (в g) по осям X, Y, Z.
    /// </summary>
    public static bool GetAcceleration(out Vector3 accel)
    {
        accel = Vector3.zero;
        if (!IsInitialized) return false;
        return GyroTweak_GetAcceleration(out accel.x, out accel.y, out accel.z) == 0;
    }

    /// <summary>
    /// Получить ориентацию устройства как Quaternion (fusion: gyro + accel + mag).
    /// Это то, что обычно нужно для управления камерой/персонажем.
    /// </summary>
    public static bool GetAttitude(out Quaternion attitude)
    {
        attitude = Quaternion.identity;
        if (!IsInitialized) return false;
        if (GyroTweak_GetAttitudeQuaternion(out float x, out float y, out float z, out float w) != 0)
            return false;
        // CoreMotion quaternion: x,y,z,w — Unity тоже x,y,z,w, но оси могут отличаться
        attitude = new Quaternion(x, y, z, w);
        return true;
    }
}

/// <summary>
/// Пример MonoBehaviour для теста в Unity.
/// </summary>
public class GyroTweakExample : MonoBehaviour
{
    void Start()
    {
        if (!GyroTweak.Init())
        {
            Debug.LogError("GyroTweak не доступен на этом устройстве");
            return;
        }
        Debug.Log($"GyroTweak готов. Доступен: {GyroTweak.IsAvailable}");
    }

    void Update()
    {
        if (!GyroTweak.IsInitialized) return;

        if (GyroTweak.GetAttitude(out Quaternion attitude))
        {
            // Пример: поворачиваем объект под ориентацию устройства
            transform.rotation = attitude;
        }

        if (GyroTweak.GetRotationRate(out Vector3 rate))
        {
            // rate — угловая скорость в рад/сек
        }
    }

    void OnDestroy()
    {
        GyroTweak.Shutdown();
    }
}
