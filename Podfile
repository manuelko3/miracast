# Uncomment the next line to define a global platform for your project
platform :ios, '15.0'

target 'Miracast' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Samsung Smart View SDK for real TV connection
  pod 'smart-view-sdk', '~> 3.1'

end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'

      # Отключаем Bitcode (Samsung SDK не поддерживает)
      config.build_settings['ENABLE_BITCODE'] = 'NO'

      # Исправляем проблему с BCSymbolMaps
      config.build_settings['STRIP_SWIFT_SYMBOLS'] = 'NO'
      config.build_settings['COPY_PHASE_STRIP'] = 'NO'
      config.build_settings['STRIP_INSTALLED_PRODUCT'] = 'NO'
    end
  end

  # Удаляем BCSymbolMaps из фреймворка если они есть
  installer.pods_project.targets.each do |target|
    if target.name == 'smart-view-sdk'
      target.build_configurations.each do |config|
        config.build_settings['BCYMBOLMAP_DIR'] = ''
      end
    end
  end
end
