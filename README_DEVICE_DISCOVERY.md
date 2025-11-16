# 📱 Device Discovery - Важная информация

## ⚠️ КРИТИЧЕСКИ ВАЖНО

**Функция поиска устройств работает ТОЛЬКО на реальном iPhone/iPad!**

Симулятор iOS **НЕ ИМЕЕТ** доступа к локальной сети, поэтому все попытки поиска будут заканчиваться ошибкой:
```
POSIXErrorCode(rawValue: 50): Network is down
```

## 🚀 Как запустить на реальном iPhone:

### 1. Подключите iPhone к Mac через USB

### 2. В Xcode выберите ваш iPhone:
   - Вверху Xcode, слева от кнопки Run (▶️)
   - Кликните на выпадающий список устройств
   - Выберите ваш iPhone (например "Евгений's iPhone")

### 3. Нажмите Run (▶️) или Cmd+R

### 4. При первом запуске:
   - iOS покажет системный алерт:
     ```
     "Miracast" Would Like to Find and Connect to 
     Devices on Your Local Network
     
     [Don't Allow]  [Allow]
     ```
   - **ОБЯЗАТЕЛЬНО нажмите "Allow"!**

### 5. Убедитесь что:
   - ✅ iPhone подключен к Wi-Fi
   - ✅ Samsung TV включен и подключен к ЭТОЙ ЖЕ Wi-Fi сети
   - ✅ На Samsung TV включен SmartView/Screen Mirroring

## 📊 Что должно появиться в консоли (на реальном iPhone):

```
✅ SSDP connection ready, sending M-SEARCH...
✅ SSDP M-SEARCH sent successfully
📥 SSDP Response received:
HTTP/1.1 200 OK
LOCATION: http://192.168.x.x:xxxx/...
SERVER: Samsung...
🎯 Found UPnP device: Samsung TV at http://...
✅ Added SSDP device: Samsung TV (Samsung Smart TV)
```

## 🔧 Если устройства не находятся на реальном iPhone:

### Проверьте разрешения:
1. Настройки iPhone → прокрутите вниз → найдите "Miracast"
2. Убедитесь что включен переключатель **"Local Network"** / **"Локальная сеть"**

### Проверьте настройки Samsung TV:
1. **Settings** → **General** → **External Device Manager**
   - Включите **Device Connect Manager**

2. **Settings** → **General** → **Apple AirPlay Settings**
   - Включите **AirPlay**

3. На пульте нажмите **Source** и включите **Screen Mirroring**

### Проверьте сеть:
- iPhone и TV должны быть в ОДНОЙ Wi-Fi сети
- Не используйте гостевую сеть (Guest Network)
- Проверьте что роутер не блокирует multicast трафик

## 🎯 Поддерживаемые устройства:

- ✅ Samsung Smart TV (через SSDP/UPnP)
- ✅ LG Smart TV (через SSDP/UPnP)
- ✅ Sony BRAVIA (через SSDP/UPnP)
- ✅ Google Chromecast (через mDNS)
- ✅ Apple TV (через AirPlay/RAOP)
- ✅ Roku (через mDNS)

## 🐛 Отладка:

Если ничего не находится, откройте консоль в Xcode (Cmd+Shift+Y) и поищите:
- ❌ или ⚠️ - ошибки
- "Network is down" - значит запущено на симуляторе (нужен реальный iPhone!)
- "NoAuth" - нужно дать разрешение на локальную сеть
