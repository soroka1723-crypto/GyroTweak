# GyroTweak — нативный гироскоп для Unity iOS

Нативный твик (`.dylib`), читающий гироскоп/акселерометр через **CoreMotion** и отдающий данные в Unity через чистый **C-API**.

## Файлы

| Файл | Назначение |
|------|------------|
| `GyroTweak.h` | C-заголовок (API) |
| `GyroTweak.xm` | Реализация на Objective-C++ (Theos/tweak) |
| `Makefile` | Сборка через Theos |
| `control` | Метаданные пакета |
| `GyroTweakUnity.cs` | C# обёртка для Unity |

## Сборка (на macOS с Theos)

```bash
# 1. Установи Theos (если нет): https://github.com/theos/theos
# 2. Зайди в папку GyroTweak
cd GyroTweak

# 3. Собери
make clean
make package   # создаст .deb в packages/
# или просто:
make           # создаст .dylib в .theos/obj/
```

Результат: `GyroTweak.dylib` (архитектуры `arm64` + `arm64e`).

## Инжект в .ipa (твоя часть)

1. Положи `GyroTweak.dylib` в `Payload/YourApp.app/Frameworks/` (или в корень `.app`).
2. Пропиши в `Info.plist` приложения:
   ```xml
   <key>UIRequiredDeviceCapabilities</key>
   <array><string>arm64</string></array>
   ```
3. Подпиши дylib и приложение твоим сертификатом:
   ```bash
   codesign -f -s "Apple Development: Name (TEAMID)" --entitlements entitlements.plist GyroTweak.dylib
   codesign -f -s "Apple Development: Name (TEAMID)" --entitlements entitlements.plist Payload/YourApp.app
   ```
4. Упакуй обратно в `.ipa`.

> **Важно:** Для CoreMotion нужны разрешения в `Info.plist` приложения:
> ```xml
> <key>NSMotionUsageDescription</key>
> <string>Нужен для управления игрой через гироскоп</string>
> ```

## Использование в Unity

1. Положи `GyroTweakUnity.cs` в `Assets/Scripts/`.
2. Положи собранный `GyroTweak.dylib` в `Assets/Plugins/iOS/` (Unity автоматически добавит в Xcode-проект).
3. В коде:

```csharp
void Start()
{
    if (!GyroTweak.Init()) return;
}

void Update()
{
    if (GyroTweak.GetAttitude(out Quaternion attitude))
    {
        transform.rotation = attitude; // или Camera.main.transform.rotation = attitude;
    }
}

void OnDestroy()
{
    GyroTweak.Shutdown();
}
```

## API (C)

| Функция | Описание |
|---------|----------|
| `GyroTweak_Init()` | Запуск CoreMotion. Возвращает 0 = ок. |
| `GyroTweak_Shutdown()` | Остановка и очистка. |
| `GyroTweak_GetRotationRate(out x,y,z)` | Угловая скорость (рад/сек). Сырые данные гироскопа. |
| `GyroTweak_GetAcceleration(out x,y,z)` | Ускорение (g). Сырые данные акселерометра. |
| `GyroTweak_GetAttitudeQuaternion(out x,y,z,w)` | **Главное**: ориентация устройства (fusion). Кватернион. |
| `GyroTweak_IsAvailable()` | Есть ли гироскоп на девайсе. |

## Частые проблемы

| Проблема | Решение |
|----------|---------|
| `dyld: Library not loaded` | Дylib не подписан или не в `Frameworks/`. Проверь `otool -L`. |
| `GyroTweak_Init() = -1` | Нет `NSMotionUsageDescription` в Info.plist приложения. |
| Данные не обновляются | Проверь, что `GyroTweak_Init()` вызван ДО первого `Get*`. |
| Кватернион "перевернут" | CoreMotion: X вправо, Y вверх, Z к пользователю. Unity: X вправо, Y вверх, Z вперёд. Можно пересобрать оси в C#. |

## Лицензия

MIT — делай что хочешь.
