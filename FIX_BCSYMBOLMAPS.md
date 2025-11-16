# Исправление ошибки Sandbox BCSymbolMaps

## Проблема
```
Sandbox: deny(1) file-read-data /Users/.../SmartView.framework/BCSymbolMaps
```

## Что это значит?
Это **НЕ критичная ошибка** - Xcode пытается получить доступ к файлам отладочных символов (BCSymbolMaps) Samsung Smart View SDK, но sandbox блокирует это. Приложение работает нормально, это только предупреждение.

## Решение 1: Отключить битcode в настройках проекта (РЕКОМЕНДУЕТСЯ)

### Шаг 1: Откройте настройки проекта в Xcode
1. Выберите проект **Miracast** в навигаторе слева
2. Выберите таргет **Miracast**
3. Перейдите на вкладку **Build Settings**
4. В поиске введите `bitcode`

### Шаг 2: Отключите Bitcode
1. Найдите настройку **Enable Bitcode**
2. Установите значение в **No** для Debug и Release

### Шаг 3: Настройте Strip Settings
В поиске Build Settings введите `strip` и установите:
- **Strip Debug Symbols During Copy** → **No**
- **Strip Linked Product** → **No** (только для Debug)
- **Strip Swift Symbols** → **No**

### Шаг 4: Очистите проект
1. В Xcode: **Product** → **Clean Build Folder** (⇧⌘K)
2. Закройте Xcode
3. Удалите DerivedData:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData/Miracast-*
   ```
4. Откройте Xcode снова и пересоберите проект

## Решение 2: Обновить CocoaPods (если нужно)

Ваша версия CocoaPods (1.15.2) несовместима с Xcode 15+ из-за нового типа группы файлов `PBXFileSystemSynchronizedRootGroup`.

### Обновление CocoaPods:
```bash
sudo gem install cocoapods --pre
```

Или используйте Bundler:
```bash
bundle update cocoapods
```

## Решение 3: Игнорировать предупреждение

Если приложение работает нормально (что должно быть так), можно просто игнорировать это предупреждение. BCSymbolMaps используются только для символизации креш-репортов, что не критично во время разработки.

## Проверка

После применения исправлений запустите приложение. Вы больше не должны видеть ошибку Sandbox с BCSymbolMaps в консоли Xcode.

## Дополнительная информация

**BCSymbolMaps** - это файлы, которые содержат информацию для де-обфускации символов в креш-репортах когда включен Bitcode. Samsung Smart View SDK не использует Bitcode, поэтому эти файлы не нужны.
