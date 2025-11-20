# SmartView SDK - Руководство по API

## 📱 Как работает SmartView SDK для Samsung TV

### Основные концепции:

1. **Service** - представляет Samsung TV в сети
   - Готов к использованию сразу после обнаружения через `ServiceSearch`
   - Не требует явного "подключения" - это не Bluetooth!
   - Используется для создания каналов и плееров

2. **Channel** - двусторонний канал связи с TV
   - Создается через `service.createChannel("channel-id")`
   - Используется для отправки произвольных данных
   - Требует вызова `connect()` для установки соединения

3. **Application** - приложение на TV
   - Создается через `service.createApplication()`
   - Используется для запуска специфических приложений на TV
   - **Не требуется для обычного кастинга!**

4. **Специализированные плееры**:
   - `VideoPlayer` - для воспроизведения видео
   - `PhotoPlayer` - для показа фото
   - `AudioPlayer` - для воспроизведения аудио

---

## 🔄 Правильный workflow подключения

### Шаг 1: Поиск устройств
```swift
let search = Service.search()
search.delegate = self
search.start()

// Делегат получит найденные устройства:
func onServiceFound(_ service: Service) {
    // service готов к использованию!
}
```

### Шаг 2: "Подключение" к TV
**ВАЖНО**: Service не требует подключения! Он готов к использованию сразу.

Для проверки связи можно создать тестовый канал:
```swift
let testChannel = service.createChannel("test")
testChannel.connect(nil) { client, error in
    if error == nil {
        print("TV доступен!")
    }
}
```

### Шаг 3: Отправка контента

#### Отправка фото:
```swift
let photoPlayer = service.createPhotoPlayer("AppName")
photoPlayer.standbyConnect(nil) { error in
    if error == nil {
        photoPlayer.playContent(imageURL) { error in
            print("Фото отправлено!")
        }
    }
}
```

#### Отправка видео:
```swift
let videoPlayer = service.createVideoPlayer("AppName")
videoPlayer.standbyConnect(nil) { error in
    if error == nil {
        videoPlayer.playContent(videoURL) { error in
            print("Видео отправлено!")
        }
    }
}
```

#### Отправка произвольных данных:
```swift
let channel = service.createChannel("channel-id")
channel.connect(nil) { client, error in
    if error == nil {
        channel.publish(event: "eventName", message: data)
    }
}
```

---

## ⚠️ Частые ошибки

### ❌ Неправильно:
```swift
// Application НЕ нужен для обычного кастинга!
let app = service.createApplication("id", channelURI: "uri", args: nil)
app.start() // Этого метода не существует!
```

### ✅ Правильно:
```swift
// Service готов сразу - просто сохраняем его
self.connectedService = service

// Используем специализированные плееры для контента
let photoPlayer = service.createPhotoPlayer("Miracast")
photoPlayer.standbyConnect(nil) { error in
    // Теперь можно отправлять фото
}
```

---

## 🎯 Когда использовать что?

| Задача | Используйте |
|--------|-------------|
| Показать фото на TV | `PhotoPlayer` |
| Воспроизвести видео | `VideoPlayer` |
| Воспроизвести музыку | `AudioPlayer` |
| Открыть URL/веб-страницу | `Channel` + custom protocol |
| Запустить специальное приложение на TV | `Application` |

---

## 🔧 Важные детали

### 1. Service не требует disconnect
- Service автоматически освобождается при обнулении переменной
- Не нужно вызывать какой-то специальный метод отключения

### 2. Плееры используют standbyConnect
- Метод `standbyConnect` подключается к DMP экрану TV
- После подключения можно отправлять контент через `playContent`
- Можно передать до 3 фоновых изображений для заставки

### 3. Каналы требуют connect
- Channel создается через `createChannel("id")`
- Требуется вызов `connect(delegate) { }` перед отправкой данных
- Можно установить делегат для получения событий

### 4. Нет явного "запроса разрешения"
- В отличие от AirPlay, SmartView не показывает popup на TV
- TV должен быть настроен для приема SmartView подключений
- В настройках TV включите "Smart View" / "Screen Mirroring"

---

## 📋 Требования

### На стороне TV:
1. Samsung Smart TV (2015 года или новее)
2. Smart View включен в настройках
3. TV и iPhone в одной Wi-Fi сети

### В приложении:
1. Info.plist разрешения:
   - `NSLocalNetworkUsageDescription`
   - `NSBonjourServices` (включая `_smartview._tcp`)
2. Реальное iOS устройство (не симулятор)

---

## 🐛 Troubleshooting

### Проблема: Устройства не находятся
**Решение:**
- Проверьте Wi-Fi сеть (должна быть одна и та же)
- Проверьте разрешения в Info.plist
- Убедитесь, что используете реальное устройство

### Проблема: Ошибка при подключении к каналу
**Решение:**
- Убедитесь, что Smart View включен на TV
- Проверьте, нет ли фаервола на TV
- Попробуйте перезагрузить TV

### Проблема: Фото/видео не отправляется
**Решение:**
- Убедитесь, что вызвали `standbyConnect` перед `playContent`
- Проверьте, что URL файла доступен (локальный файл)
- Для удаленных URL убедитесь, что TV может их загрузить

---

## 💡 Лучшие практики

1. **Всегда проверяйте ошибки** в completion handlers
2. **Используйте DispatchQueue.main** для обновления UI
3. **Очищайте временные файлы** после отправки
4. **Кешируйте Service** объект вместо повторного поиска
5. **Показывайте пользователю понятные ошибки**

---

**Версия**: SmartView SDK 3.1  
**Дата**: Ноябрь 2024  
**Платформа**: iOS 14.0+
