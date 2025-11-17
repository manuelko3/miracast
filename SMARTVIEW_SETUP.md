# Инструкция по настройке SmartView SDK

## 📦 Что уже сделано:

1. ✅ SmartView.xcframework добавлен в проект и находится в папке `Frameworks/`
2. ✅ Фреймворк уже встроен в проект (Embed & Sign) через Xcode
3. ✅ Создан `SmartViewManager.swift` - обертка для работы с Samsung SDK
4. ✅ Обновлен `DeviceDiscoveryViewModel.swift` для использования SmartView SDK
5. ✅ Создан `Miracast-Bridging-Header.h` для интеграции Objective-C фреймворка
6. ✅ **CocoaPods полностью удален** - используется только XCFramework напрямую

## ✨ Преимущества работы без CocoaPods:

- 🚀 Нет зависимости от CocoaPods
- ⚡ Быстрая сборка проекта
- 🔧 Полная совместимость с новыми версиями Xcode
- 📦 Работаем напрямую с `.xcodeproj` файлом

## 🛠️ Что нужно проверить в Xcode:

### Шаг 1: Открыть проект

⚠️ **ВАЖНО**: Открывайте **Miracast.xcodeproj** (НЕ .xcworkspace)

```bash
cd /Users/msnuelkoq/Documents/Miracast
open Miracast.xcodeproj
```

### Шаг 2: Проверить что фреймворк добавлен

1. Выберите проект **Miracast** в навигаторе слева (синяя иконка)
2. Выберите таргет **Miracast**
3. Перейдите на вкладку **General**
4. Прокрутите вниз до секции **Frameworks, Libraries, and Embedded Content**
5. Убедитесь что **SmartView.xcframework** присутствует и помечен как **Embed & Sign**

✅ Если фреймворк уже там - отлично, идем дальше!

❌ Если фреймворка нет:
- Нажмите **+** → **Add Other** → **Add Files...**
- Выберите `Frameworks/SmartView.xcframework`
- Установите **Embed & Sign**

### Шаг 3: Проверить Bridging Header

1. В настройках таргета **Miracast** перейдите на вкладку **Build Settings**
2. В поисковой строке введите: `bridging`
3. Найдите **Objective-C Bridging Header**
4. Должно быть установлено значение: `Miracast/Miracast-Bridging-Header.h`

❌ Если не установлено - дважды кликните и введите: `Miracast/Miracast-Bridging-Header.h`

### Шаг 4: Настроить Info.plist

Откройте файл `Miracast/Info.plist` и убедитесь что есть следующие разрешения:

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>Приложение использует локальную сеть для поиска и подключения к Samsung Smart TV</string>

<key>NSBonjourServices</key>
<array>
    <string>_smartview._tcp</string>
    <string>_samsung._tcp</string>
    <string>_dial-multiscreen._tcp</string>
</array>
```

Эти разрешения нужны для обнаружения устройств Samsung в локальной сети.

### Шаг 5: Собрать проект

1. Нажмите **⌘ + B** (Cmd + B) для сборки проекта
2. Убедитесь что нет ошибок

Возможные проблемы и решения:
- ❌ **"No such module 'SmartView'"** → Проверьте что фреймворк добавлен (Шаг 2)
- ❌ **"Bridging header not found"** → Проверьте путь к bridging header (Шаг 3)
- ❌ **"Framework not found"** → Проверьте что Embed установлен в "Embed & Sign"

## 🎯 Как использовать SmartView SDK

После успешной сборки, приложение готово к работе с Samsung устройствами!

### Основные функции SmartViewManager:

```swift
// 1. Поиск Samsung устройств
let smartViewManager = SmartViewManager()
smartViewManager.startDiscovery { services in
    print("Найдено устройств: \(services.count)")
}

// 2. Подключение к Samsung TV
smartViewManager.connect(to: service) { success, error in
    if success {
        print("✅ Подключено к TV!")
    } else {
        print("❌ Ошибка: \(error?.localizedDescription ?? "")")
    }
}

// 3. Отправка фото на TV
let image = UIImage(named: "photo")!
smartViewManager.sendPhoto(image) { success, error in
    if success {
        print("✅ Фото отправлено!")
    }
}

// 4. Отправка видео на TV
let videoURL = URL(fileURLWithPath: "/path/to/video.mp4")
smartViewManager.sendVideo(videoURL) { success, error in
    if success {
        print("✅ Видео отправлено!")
    }
}

// 5. Открыть URL на TV
smartViewManager.sendURL("https://www.youtube.com") { success, error in
    if success {
        print("✅ URL отправлен!")
    }
}

// 6. Отключение от TV
smartViewManager.disconnect()
```

## 🔍 Отладка

### Проверка что устройства находятся:

1. Убедитесь что **TV и iPhone в одной Wi-Fi сети**
2. Проверьте что **TV включен**
3. На Samsung TV включите **Smart View** / **Screen Mirroring**
4. Запустите приложение на реальном устройстве (не симуляторе)

### Что смотреть в консоли Xcode:

При успешной работе должны появляться логи:
```
🔍 Starting SmartView SDK discovery...
📱 SmartView found device: Samsung TV
✅ Added Samsung device via SmartView SDK: Samsung TV
```

При подключении:
```
🔗 Connecting to Samsung device: Samsung TV...
✅ Successfully connected to Samsung device!
```

### Частые проблемы:

| Проблема | Решение |
|----------|---------|
| Устройства не находятся | Проверьте Wi-Fi сеть, разрешения в Info.plist |
| "Module not found" | Пересоберите проект (Clean Build Folder: ⇧⌘K) |
| Не работает на симуляторе | Используйте реальное устройство iOS |
| TV не отвечает | Перезагрузите TV, проверьте что Smart View включен |

## 📱 Тестирование

### На реальном устройстве:

1. Подключите iPhone к Mac
2. Выберите ваш iPhone как устройство для запуска
3. Нажмите **⌘ + R** для запуска приложения
4. Перейдите на экран поиска устройств
5. Нажмите кнопку поиска

### Требования:

- iOS 14.0 или выше
- Реальное iOS устройство (не симулятор)
- Samsung Smart TV (2015 года или новее)
- Общая Wi-Fi сеть для iPhone и TV

## 🎬 Структура файлов проекта

```
Miracast/
├── Frameworks/
│   └── SmartView.xcframework/     # Samsung SDK
├── Miracast/
│   ├── Models/
│   │   └── SmartViewManager.swift # Обертка для SmartView SDK
│   └── Miracast-Bridging-Header.h # Для Objective-C фреймворка
└── Miracast.xcodeproj             # Открывать ЭТОТ файл
```

## ✅ Checklist перед запуском:

- [ ] Открыт `Miracast.xcodeproj` (не .xcworkspace)
- [ ] SmartView.xcframework добавлен в Frameworks с Embed & Sign
- [ ] Bridging Header настроен: `Miracast/Miracast-Bridging-Header.h`
- [ ] Info.plist содержит NSLocalNetworkUsageDescription и NSBonjourServices
- [ ] Проект собирается без ошибок (⌘ + B)
- [ ] Используется реальное iOS устройство (не симулятор)
- [ ] iPhone и TV в одной Wi-Fi сети

---

**Готово!** 🎉 Теперь ваше приложение может находить и подключаться к Samsung Smart TV без CocoaPods.

**Дата обновления:** 17 ноября 2025
