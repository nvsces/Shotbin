import XCTest

/// Сквозной прогон в симуляторе: даёт доступ к фото, ждёт распознавание,
/// проходит по экранам и снимает скриншоты.
final class RecallUITests: XCTestCase {
    /// Скриншоты кладём во вложения теста; достать: xcrun xcresulttool export attachments.
    private func shot(_ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        a.name = "recall-\(name)"
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

        // поиск
        let search = app.searchFields.firstMatch
        if search.waitForExistence(timeout: 5) {
            search.tap(); search.typeText("код"); sleep(2); shot("search")
        }
        XCTAssertTrue(app.staticTexts["Полки"].exists || app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Найдено'")).firstMatch.exists)
    }
}
