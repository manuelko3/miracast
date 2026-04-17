# Настройка Broadcast Upload Extension

Весь код extension уже готов в папке `MiracastBroadcast/`:
- `SampleHandler.swift` — захват + кодирование + HTTP + отправка URL на TV
- `Info.plist`
- `MiracastBroadcast.entitlements`

Осталось добавить target в Xcode (5 минут) — это нельзя сделать из командной строки
безопасно, поэтому шаги ниже нужно выполнить вручную.

---

## 1. Создать target в Xcode

1. Открой `Miracast.xcodeproj` в Xcode
2. **File → New → Target…**
3. iOS → Application Extension → **Broadcast Upload Extension** → Next
4. Заполни:
   - **Product Name**: `MiracastBroadcast` (ровно так, с большой M и B)
   - **Language**: Swift
   - **Include UI Extension**: *сними галочку*
   - **Embed in Application**: `Miracast`
5. Finish → Xcode предложит **Activate** новую схему — жми Activate.

Xcode создаст папку `MiracastBroadcast/` с дефолтными `SampleHandler.swift` и `Info.plist`.
**Они у нас уже есть в той же папке** — Xcode спросит "Replace?" → Replace.

Если не спросит — вручную:
- В навигаторе правый клик по авто-сгенерированным `SampleHandler.swift`, `Info.plist`
  → **Delete → Move to Trash**
- Перетащи мои файлы из Finder в папку `MiracastBroadcast` в навигаторе Xcode:
  - `SampleHandler.swift`
  - `Info.plist`
  - `MiracastBroadcast.entitlements`
  При добавлении: `Copy items if needed` — НЕТ (файлы уже там), `Add to targets` — **только `MiracastBroadcast`**.

## 2. Подключить общий код к extension target

Extension'у нужны эти файлы из `Miracast/`:

- `Miracast/Services/HLSStreamServer.swift`
- `Miracast/Services/DLNARenderer.swift`
- `Miracast/Services/DLNAController.swift`
- `Miracast/Services/BroadcastPreferences.swift`

Для каждого:
1. Выбери файл в навигаторе
2. В правом инспекторе → раздел **Target Membership**
3. Поставь галочку у `MiracastBroadcast` (галочка у `Miracast` должна остаться).

## 3. App Group (самое важное)

Без этого extension не сможет прочитать, куда стримить.

Для **каждого** из двух таргетов (`Miracast` и `MiracastBroadcast`):

1. Project navigator → корневой проект → таргет
2. Вкладка **Signing & Capabilities**
3. **+ Capability** → **App Groups**
4. В появившемся разделе жми **+** и введи: `group.miracast.Miracast`
5. Поставь галочку у созданной группы

Если Xcode пишет "Failed to register bundle identifier" — он сам предложит Fix,
жми Fix. Для free-аккаунта может потребоваться пересоздать provisioning profile
(Automatically manage signing → toggle off/on).

## 4. Entitlements файлы

После шага 3 Xcode автоматически создаст `Miracast.entitlements` и
`MiracastBroadcast.entitlements`. Если он создал их в каких-то странных местах
или без App Group внутри — у нас уже лежат правильные:

- `Miracast/Miracast.entitlements`
- `MiracastBroadcast/MiracastBroadcast.entitlements`

В Build Settings каждого таргета проверь:
- **CODE_SIGN_ENTITLEMENTS** указывает на правильный entitlements-файл.

## 5. Сигнатура на реальном устройстве

Broadcast Upload Extension **невозможно протестировать в симуляторе** — только на
реальном iPhone.

1. Подключи iPhone, выбери его как destination
2. В **Signing & Capabilities** обоих таргетов:
   - Team — твоя команда Apple Developer
   - Automatically manage signing — включено
3. Жми ▶️ Run

Если Xcode ругается на "doesn't support Broadcast Upload Extension capability"
для free-аккаунта — это известная проблема Apple ID без paid-членства. Для
разработки достаточно free Apple ID, но иногда нужно:
- Очистить провижн: `~/Library/MobileDevice/Provisioning Profiles/` → удалить всё
- Перезапустить Xcode
- Перепересобрать: Product → Clean Build Folder (⌘⇧K)

## 6. Как пользоваться

1. В приложении открой Home → Connect device → выбери TV (Samsung Tizen DLNA)
2. Open "Screen Cast" → Start Broadcast
3. Появится системный лист с "Miracast" → тап Start Broadcast → 3, 2, 1…
4. Свернись в главный экран, открой Safari / YouTube / любое приложение — звук и
   картинка идут на TV с задержкой 3-5 секунд
5. Stop: красный индикатор сверху → Stop, либо в нашем приложении кнопка Stop

## Частые проблемы

**"TV не играет стрим"**
- Проверь, что iPhone и TV в одной Wi-Fi (2.4/5 ГГц один SSID, без изоляции клиентов)
- Логи Xcode: подключи iPhone, в `Console.app` выбери устройство, фильтр по `Miracast` — покажет, что делает extension
- Старые Samsung не всегда умеют HLS через DLNA — если чёрный экран, можно вместо HLS отдать progressive MP4 (отдельная доработка, пиши)

**"Extension крашится через 10 секунд"**
- Лимит памяти 50 MB. Пониженные настройки уже в `SampleHandler`, но если всё
  ещё — проверь, что `AVVideoWidthKey=720`, `AVVideoHeightKey=1280`,
  `AVVideoAverageBitRateKey=2_500_000`.

**"Чёрный экран на TV при просмотре Netflix/Disney+"**
- Это защита от DRM, работает на уровне iOS и обойти нельзя.

**"Extension не видит TV info"**
- App Group не совпадает у main app и extension, или `suiteName` в
  `BroadcastPreferences.swift` ≠ `group.miracast.Miracast`. Проверь оба места.
