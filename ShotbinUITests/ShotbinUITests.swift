import XCTest

/// Сквозной прогон в симуляторе: даёт доступ к фото, ждёт распознавание,
/// проходит по экранам и снимает скриншоты.
final class ShotbinUITests: XCTestCase {
    /// Раздел фотографий: отдельный запуск, поиск серий, удаление лишних.
    func testPhotosSection() {
        let app = XCUIApplication()
        app.launchArguments = ["-autoRequest"]
        app.launch()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for title in ["Разрешить полный доступ", "Allow Full Access"] {
            let b = springboard.buttons[title]
            if b.waitForExistence(timeout: 8) { b.tap(); break }
        }
        let scanning = app.staticTexts["Читаю скриншоты…"]
        _ = scanning.waitForExistence(timeout: 15)
        wait(for: [expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: scanning)], timeout: 180)
        sleep(2)

        let entry = app.cells.containing(.staticText, identifier: "Фотографии").firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 10), "на главном есть раздел фотографий")
        entry.tap(); sleep(1)
        shot("photos-start")

        // раздел не сканирует сам — запускает пользователь
        let start = app.buttons["Начать"]
        XCTAssertTrue(start.waitForExistence(timeout: 5), "проверка запускается вручную")
        start.tap()

        let busy = app.staticTexts["Сравниваю фотографии…"]
        _ = busy.waitForExistence(timeout: 10)
        wait(for: [expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: busy)], timeout: 180)
        sleep(2)
        shot("photos-result")

        let del = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Удалить '")).firstMatch
        if del.waitForExistence(timeout: 5) {
            del.tap(); sleep(1)
            let confirm = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Удалить и освободить'")).firstMatch
            if confirm.waitForExistence(timeout: 5) {
                confirm.tap()
                for label in ["Delete", "Удалить"] {
                    let b = springboard.buttons[label]
                    if b.waitForExistence(timeout: 8) { b.tap(); break }
                }
                sleep(4); shot("photos-done")
            }
        }
    }

    /// Снимки для App Store на русском.
    func testStoreShotsRU() { captureStoreShots(lang: "ru") }
    /// Снимки для App Store на английском.
    func testStoreShotsEN() { captureStoreShots(lang: "en") }

    private func captureStoreShots(lang: String) {
        let app = XCUIApplication()
        app.launchArguments = ["-autoRequest",
                               "-AppleLanguages", "(\(lang))",
                               "-AppleLocale", lang == "en" ? "en_US" : "ru_RU"]
        app.launch()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for title in ["Разрешить полный доступ", "Allow Full Access"] {
            let b = springboard.buttons[title]
            if b.waitForExistence(timeout: 8) { b.tap(); break }
        }
        let scanning = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Читаю' OR label BEGINSWITH 'Reading'")).firstMatch
        _ = scanning.waitForExistence(timeout: 20)
        wait(for: [expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: scanning)], timeout: 240)
        sleep(3)
        shot("\(lang)-1-home")

        // полка с кодами
        for name in ["Коды и пароли", "Codes and passwords"] {
            let cell = app.cells.containing(.staticText, identifier: name).firstMatch
            if cell.waitForExistence(timeout: 3) {
                cell.tap(); sleep(2); shot("\(lang)-2-shelf")
                let first = app.cells.firstMatch
                if first.waitForExistence(timeout: 3) { first.tap(); sleep(3); shot("\(lang)-3-detail")
                    app.navigationBars.buttons.element(boundBy: 0).tap(); sleep(1) }
                app.navigationBars.buttons.element(boundBy: 0).tap(); sleep(1)
                break
            }
        }

        // повторы
        for name in ["Повторы", "Duplicates"] {
            let cell = app.cells.containing(.staticText, identifier: name).firstMatch
            if cell.waitForExistence(timeout: 3) {
                cell.tap(); sleep(3); shot("\(lang)-4-duplicates")
                app.navigationBars.buttons.element(boundBy: 0).tap(); sleep(1)
                break
            }
        }

        // уборка
        for name in ["Освободить место", "Free up space"] {
            let cell = app.cells.containing(.staticText, identifier: name).firstMatch
            if cell.waitForExistence(timeout: 3) {
                cell.tap(); sleep(3); shot("\(lang)-5-cleanup")
                app.navigationBars.buttons.element(boundBy: 0).tap(); sleep(1)
                break
            }
        }

        // поиск
        let search = app.searchFields.firstMatch
        if search.waitForExistence(timeout: 5) {
            search.tap()
            search.typeText(lang == "en" ? "code" : "код")
            sleep(3); shot("\(lang)-6-search")
        }
    }

    /// Пауза посреди скана и продолжение с того же места.
    func testPauseAndResume() {
        let app = XCUIApplication()
        app.launchArguments = ["-autoRequest"]
        app.launch()

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for title in ["Разрешить полный доступ", "Allow Full Access"] {
            let b = springboard.buttons[title]
            if b.waitForExistence(timeout: 8) { b.tap(); break }
        }

        let pause = app.buttons["Пауза"]
        XCTAssertTrue(pause.waitForExistence(timeout: 20), "во время скана должна быть кнопка паузы")
        // интерфейс жив во время скана: кнопка отвечает без ожидания
        pause.tap()

        let resume = app.buttons["Продолжить"]
        XCTAssertTrue(resume.waitForExistence(timeout: 15), "после паузы предлагаем продолжить")
        let leftText = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Осталось'")).firstMatch
        XCTAssertTrue(leftText.exists, "показываем, сколько осталось")
        shot("paused")

        resume.tap()
        // скан заканчивается сам, и «Продолжить» больше не появляется
        let gone = NSPredicate(format: "exists == false")
        wait(for: [expectation(for: gone, evaluatedWith: app.buttons["Пауза"])], timeout: 180)
        XCTAssertFalse(app.buttons["Продолжить"].exists, "после завершения паузы нет")
        sleep(1)
        shot("resumed")
    }

    /// Скриншоты кладём во вложения теста; достать: xcrun xcresulttool export attachments.
    private func shot(_ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        a.name = "shotbin-\(name)"
        a.lifetime = .keepAlways
        add(a)
    }

    func testWalkthrough() {
        let app = XCUIApplication()
        app.launchArguments = ["-autoRequest"]
        app.launch()

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for title in ["Разрешить полный доступ", "Allow Full Access"] {
            let b = springboard.buttons[title]
            if b.waitForExistence(timeout: 8) { b.tap(); break }
        }

        // ждём конца сканирования (пропадает строка «Читаю скриншоты…»)
        let scanning = app.staticTexts["Читаю скриншоты…"]
        _ = scanning.waitForExistence(timeout: 10)
        let gone = NSPredicate(format: "exists == false")
        let done = expectation(for: gone, evaluatedWith: scanning)
        wait(for: [done], timeout: 180)
        sleep(2)
        shot("home")

        // первая полка
        let shelf = app.cells.containing(.staticText, identifier: "Коды и пароли").firstMatch
        if shelf.waitForExistence(timeout: 5) {
            shelf.tap(); sleep(1); shot("category")
            let first = app.cells.firstMatch
            if first.waitForExistence(timeout: 5) { first.tap(); sleep(2); shot("detail") }
            app.navigationBars.buttons.element(boundBy: 0).tap(); sleep(1)
            app.navigationBars.buttons.element(boundBy: 0).tap(); sleep(1)
        }

        // напоминания
        let reminders = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Все напоминания'")).firstMatch
        if reminders.exists { reminders.tap(); sleep(1); shot("reminders"); app.navigationBars.buttons.element(boundBy: 0).tap() }

        // повторы
        let dups = app.cells.containing(.staticText, identifier: "Повторы").firstMatch
        if dups.waitForExistence(timeout: 5) {
            dups.tap(); sleep(3); shot("duplicates")
            let del = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Удалить '")).firstMatch
            if del.waitForExistence(timeout: 5) {
                del.tap(); sleep(1)
                let confirm = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Удалить и освободить'")).firstMatch
                if confirm.waitForExistence(timeout: 5) {
                    confirm.tap()
                    for label in ["Delete", "Удалить"] {
                        let b = springboard.buttons[label]
                        if b.waitForExistence(timeout: 8) { b.tap(); break }
                    }
                    sleep(5); shot("duplicates-done")
                }
            }
            app.navigationBars.buttons.element(boundBy: 0).tap(); sleep(1)
        }

        // уборка: отмечаем «разобрался» на первой карточке, чтобы появился кандидат
        let shelf2 = app.cells.containing(.staticText, identifier: "Рецепты").firstMatch
        if shelf2.waitForExistence(timeout: 5) {
            shelf2.tap(); sleep(1)
            let first = app.cells.firstMatch
            if first.waitForExistence(timeout: 5) {
                first.tap(); sleep(2)
                let done = app.buttons["Разобрался"]
                if done.waitForExistence(timeout: 5) { done.tap(); sleep(1) }
            }
            app.navigationBars.buttons.element(boundBy: 0).tap(); sleep(1)
        }
        let cleanup = app.cells.containing(.staticText, identifier: "Освободить место").firstMatch
        if cleanup.waitForExistence(timeout: 5) {
            cleanup.tap(); sleep(3); shot("cleanup")
            let free = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Освободить '")).firstMatch
            if free.waitForExistence(timeout: 5) {
                free.tap(); sleep(1)
                let confirm = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Удалить и освободить'")).firstMatch
                if confirm.waitForExistence(timeout: 5) {
                    confirm.tap()
                    for label in ["Delete", "Удалить"] {
                        let b = springboard.buttons[label]
                        if b.waitForExistence(timeout: 8) { b.tap(); break }
                    }
                    sleep(5); shot("cleanup-done")
                }
            }
            app.navigationBars.buttons.element(boundBy: 0).tap(); sleep(1)
        }

        // карточка, у которой картинку уже удалили: данные должны остаться
        let menu = app.navigationBars.buttons.element(boundBy: app.navigationBars.buttons.count - 1)
        if menu.waitForExistence(timeout: 5) {
            menu.tap(); sleep(1)
            let doneItem = app.descendants(matching: .any).matching(NSPredicate(format: "label == 'Разобранное'")).firstMatch
            if doneItem.waitForExistence(timeout: 5) {
                doneItem.tap(); sleep(2)
                shot("freed-list")
                let first = app.cells.containing(.staticText, identifier: "Шакшука за 20 минут").firstMatch
                if first.waitForExistence(timeout: 5) {
                    first.tap(); sleep(3)
                    shot("freed-detail")
                    XCTAssertTrue(app.staticTexts["Место освобождено"].waitForExistence(timeout: 5),
                                  "карточка должна пережить удаление картинки")
                }
                app.navigationBars.buttons.element(boundBy: 0).tap(); sleep(1)
                app.navigationBars.buttons.element(boundBy: 0).tap(); sleep(1)
            }
        }

        // поиск
        let search = app.searchFields.firstMatch
        if search.waitForExistence(timeout: 5) {
            search.tap(); search.typeText("код"); sleep(2); shot("search")
        }
        XCTAssertTrue(app.staticTexts["Полки"].exists || app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Найдено'")).firstMatch.exists)
    }
}
