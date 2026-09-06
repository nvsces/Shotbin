# Материалы для App Store

## Что здесь

- `screenshots/en`, `screenshots/ru` — готовые картинки 1284×2778 (6.5", iPhone 11 Pro Max
  и аналоги). App Store Connect принимает этот набор как основной и сам масштабирует
  его под остальные размеры экранов. Допустимые размеры для этого набора:
  1284×2778, 2778×1284, 1242×2688, 2688×1242 — другие отклоняются с ошибкой
  «Неверные размеры одного или нескольких снимков экрана».
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

Все поля App Store Connect с готовыми значениями и лимитами — в `fields.md`.
Описания приложения — в `description-ru.txt` и `description-en.txt`.

## Политика конфиденциальности

Страница лежит в `docs/index.html` (русский и английский на одной странице,
язык выбирается по системному и переключается вручную).

Опубликовать: Settings → Pages → Deploy from a branch → main, папка `/docs`.
Адрес для App Store Connect: `https://nvsces.github.io/Shotbin/`

В App Store Connect в разделе App Privacy отвечать «Data Not Collected»:
приложение не собирает ничего, включая идентификаторы и диагностику.
