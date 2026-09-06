# Материалы для App Store

## Что здесь

- `screenshots/en`, `screenshots/ru` — готовые картинки 1320×2868 (6.9", iPhone 17 Pro Max).
  Этот размер App Store Connect принимает как основной и сам масштабирует под меньшие экраны.
- `samples/gen_en.swift`, `samples/gen_ru.swift` — генераторы тестовых скриншотов
  (чек, код из СМС, посадочный талон, Wi-Fi, переписка, рецепт, рилс с фильмом).
- `frame.swift` — оформление: подкладывает кадр из симулятора на фон с заголовком.

## Как пересобрать

```bash
# 1. тестовые скриншоты
swift samples/gen_en.swift          # положит PNG в текущую папку

# 2. кадры из симулятора: добавить их в галерею и снять
xcrun simctl addmedia <UDID> *.png
xcodebuild test -project Shotbin.xcodeproj -scheme Shotbin \
  -destination "id=<UDID>" -resultBundlePath /tmp/shots.xcresult \
  -only-testing:ShotbinUITests/ShotbinUITests/testStoreShotsEN
xcrun xcresulttool export attachments --path /tmp/shots.xcresult --output-path /tmp/att

# 3. оформление
swift frame.swift /tmp/att en screenshots/en
```

Тесты `testStoreShotsEN` и `testStoreShotsRU` сами проходят по экранам и снимают
главный экран, полку, карточку, уборку и поиск. Язык задаётся аргументами запуска
приложения, менять язык симулятора не нужно.

## Тексты для карточки

Подзаголовок (30 символов):
- ru: `Скриншоты сами по полкам`
- en: `Screenshots, sorted for you`

Ключевые слова:
- ru: `скриншот,распознать текст,OCR,очистка галереи,дубликаты,память,коды,чеки,билеты`
- en: `screenshot,OCR,text recognition,cleanup,duplicates,storage,codes,receipts,tickets`
