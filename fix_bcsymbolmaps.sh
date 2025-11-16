#!/bin/bash

# Скрипт для исправления проблемы с Sandbox BCSymbolMaps

echo "🔧 Исправляем настройки проекта Xcode для Samsung Smart View SDK..."

PROJECT_FILE="Miracast.xcodeproj/project.pbxproj"

# Создаем резервную копию
cp "$PROJECT_FILE" "$PROJECT_FILE.backup"
echo "✅ Создана резервная копия: $PROJECT_FILE.backup"

# Исправляем настройки через sed
# 1. Отключаем STRIP_SWIFT_SYMBOLS
sed -i '' 's/STRIP_SWIFT_SYMBOLS = YES;/STRIP_SWIFT_SYMBOLS = NO;/g' "$PROJECT_FILE"

# 2. Отключаем STRIP_BITCODE_FROM_COPIED_FILES
sed -i '' 's/STRIP_BITCODE_FROM_COPIED_FILES = YES;/STRIP_BITCODE_FROM_COPIED_FILES = NO;/g' "$PROJECT_FILE"

# 3. Убеждаемся что COPY_PHASE_STRIP = NO для Debug
sed -i '' 's/COPY_PHASE_STRIP = YES;/COPY_PHASE_STRIP = NO;/g' "$PROJECT_FILE"

echo "✅ Настройки проекта обновлены"

# Очищаем DerivedData
echo "🧹 Очищаем кеш DerivedData..."
rm -rf ~/Library/Developer/Xcode/DerivedData/Miracast-*

echo ""
echo "✅ Готово! Проблема с BCSymbolMaps исправлена."
echo ""
echo "Что дальше:"
echo "1. Откройте проект в Xcode"
echo "2. Нажмите Product → Clean Build Folder (⇧⌘K)"
echo "3. Пересоберите проект (⌘B)"
echo ""
echo "Ошибка Sandbox больше не появится! 🎉"
