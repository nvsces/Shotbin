import SwiftUI
import Photos

struct RootView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        NavigationStack {
            Group {
                switch model.authorization {
                case .authorized, .limited: HomeView()
                case .denied, .restricted: deniedView
                default: welcomeView
                }
            }
            .navigationTitle("Shotbin")
            .navigationDestination(for: Category.self) { CategoryView(category: $0) }
            .navigationDestination(for: Screenshot.self) { DetailView(shotID: $0.id) }
        }
        .task {
            if model.authorization == .authorized || model.authorization == .limited { model.scan() }
            else if ProcessInfo.processInfo.arguments.contains("-autoRequest") { await model.requestAccess() }
        }
    }

    private var welcomeView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "photo.stack").font(.system(size: 64)).foregroundStyle(Color.accentColor)
            Text("Скриншоты, о которых вы забыли").font(.title2.bold()).multilineTextAlignment(.center)
            Text("Shotbin найдёт скриншоты в галерее, прочитает текст и разложит по полкам: коды, чеки, билеты, фильмы, адреса. Всё на устройстве — ничего никуда не отправляется.")
                .foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal, 24)
            Spacer()
            Button { Task { await model.requestAccess(); model.requestNotifications() } } label: {
                Text("Открыть галерею").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).controlSize(.large).padding(.horizontal, 24).padding(.bottom, 32)
        }
    }

    private var deniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.slash").font(.system(size: 48)).foregroundStyle(.secondary)
            Text("Нет доступа к фото").font(.headline)
            Text("Разрешите доступ в Настройках → Shotbin → Фото.").foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Открыть настройки") { if let u = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(u) } }
        }.padding()
    }
}

struct HomeView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var photos: PhotoScanner

    var body: some View {
        List {
            if model.isScanning {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Читаю скриншоты…").font(.subheadline.weight(.medium))
                                Text("\(model.progress.done) из \(model.progress.total)")
                                    .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                            }
                            Spacer()
                            Button("Пауза") { model.cancelScan() }.font(.caption.weight(.semibold))
                        }
                        if model.progress.total > 0 {
                            ProgressView(value: Double(model.progress.done),
                                         total: Double(model.progress.total))
                        }
                    }
                    .padding(.vertical, 2)
                }
            } else if model.wasInterrupted {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "pause.circle").foregroundStyle(.orange).frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Сканирование на паузе").font(.subheadline.weight(.medium))
                            Text("Осталось \(model.remaining) — разобранное сохранено")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Продолжить") { model.scan() }.font(.caption.weight(.semibold))
                    }
                }
            }

            if !model.search.isEmpty {
                Section("Найдено \(model.searchResults.count)") {
                    ForEach(model.searchResults) { s in NavigationLink(value: s) { ScreenshotRow(shot: s) } }
                }
            } else {
                let reminders = model.reminders
                if !reminders.isEmpty {
                    Section {
                        ForEach(reminders.prefix(5)) { r in
                            NavigationLink(value: r.screenshot) { ReminderRow(reminder: r) }
                        }
                        if reminders.count > 5 {
                            NavigationLink("Все напоминания (\(reminders.count))") { RemindersView() }
                        }
                    } header: { Label("Не забыть", systemImage: "bell") }
                }

                if !model.duplicateGroups.isEmpty {
                    Section {
                        NavigationLink { DuplicatesView() } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "square.on.square.dashed").foregroundStyle(.orange).frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Повторы").font(.subheadline.weight(.medium))
                                    Text("\(model.duplicateDropCount) почти одинаковых кадров в \(model.duplicateGroups.count) сериях")
                                        .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                                }
                            }
                        }
                    }
                }

                Section {
                    NavigationLink { PhotosView() } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "photo.stack").foregroundStyle(.purple).frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Фотографии").font(.subheadline.weight(.medium))
                                Text(model.photosNote(scanner: photos))
                                    .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                            }
                        }
                    }
                }

                if !model.cleanupGroups.isEmpty {
                    Section {
                        NavigationLink { CleanupView() } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "internaldrive").foregroundStyle(.green).frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Освободить место").font(.subheadline.weight(.medium))
                                    Text("\(model.cleanupGroups.reduce(0) { $0 + $1.1.count }) скриншотов отработали — можно удалить из галереи")
                                        .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                                }
                            }
                        }
                    }
                }

                Section {
                    ForEach(model.categoryCounts, id: \.0) { cat, n in
                        NavigationLink(value: cat) {
                            HStack {
                                Image(systemName: cat.symbol).foregroundStyle(Color.accentColor).frame(width: 28)
                                Text(cat.title)
                                Spacer()
                                Text("\(n)").foregroundStyle(.secondary).monospacedDigit()
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Полки")
                        Spacer()
                        Text(model.shelfSummary).textCase(nil)
                    }
                } footer: {
                    VStack(alignment: .leading, spacing: 6) {
                        if model.all.isEmpty && !model.isScanning {
                            Text("Скриншотов не найдено. Потяните вниз, чтобы пересканировать.")
                        }
                        if model.libraryCounts.all > 0 {
                            Text(model.libraryNote)
                        }
                    }
                    .textCase(nil)
                }
            }
        }
        .searchable(text: $model.search, prompt: "Слово со скриншота")
        .refreshable { model.scan() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { model.scan() } label: { Label("Пересканировать", systemImage: "arrow.clockwise") }
                    NavigationLink { DoneView() } label: { Label("Разобранное", systemImage: "checkmark.circle") }
                    NavigationLink { CleanupView() } label: { Label("Уборка галереи", systemImage: "internaldrive") }
                    NavigationLink { DuplicatesView() } label: { Label("Повторы", systemImage: "square.on.square.dashed") }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
    }
}

struct ReminderRow: View {
    let reminder: Reminder
    var body: some View {
        HStack(spacing: 12) {
            Thumb(shotID: reminder.screenshot.id).frame(width: 44, height: 60).clipped()
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Image(systemName: reminder.symbol).font(.caption).foregroundStyle(.orange)
                    Text(reminder.title.isEmpty ? reminder.screenshot.category.title : reminder.title).lineLimit(1).font(.subheadline.weight(.medium))
                }
                Text(reminder.subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct ScreenshotRow: View {
    let shot: Screenshot
    var body: some View {
        HStack(spacing: 12) {
            Thumb(shotID: shot.id).frame(width: 44, height: 60).clipped()
            VStack(alignment: .leading, spacing: 3) {
                Text(shot.summary.isEmpty ? "Без текста" : shot.summary)
                    .lineLimit(2).font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 6) {
                    Text(shot.createdAt, style: .date)
                    ForEach(shot.extracted.prefix(3)) { e in
                        Image(systemName: e.symbol)
                    }
                }.font(.caption).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if shot.isFreed { Image(systemName: "internaldrive").foregroundStyle(.secondary) }
            else if shot.isDone { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
        }
    }
}

/// Миниатюра из галереи; грузится лениво и кэшируется PHImageManager'ом.
struct Thumb: View {
    @EnvironmentObject var model: AppModel
    let shotID: String
    @State private var image: UIImage?
    var body: some View {
        // scaledToFill без clipped() внутри GeometryReader растягивает картинку
        // за пределы кадра и она наезжает на текст — обрезаем по своим границам.
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 6).fill(Color(.secondarySystemFill))
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .task(id: shotID) {
            if let s = model.items[shotID] { image = await model.thumbnail(for: s) }
        }
    }
}

struct CategoryView: View {
    @EnvironmentObject var model: AppModel
    let category: Category
    @State private var showDone = false
    var body: some View {
        let list = model.items(in: category).filter { showDone || !$0.isDone }
        List(list) { s in NavigationLink(value: s) { ScreenshotRow(shot: s) } }
            .navigationTitle(category.title)
            .toolbar { Toggle("Разобранные", isOn: $showDone).toggleStyle(.button).font(.caption) }
            .overlay { if list.isEmpty { ContentUnavailableView("Пусто", systemImage: category.symbol) } }
    }
}

struct RemindersView: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        List(model.reminders) { r in NavigationLink(value: r.screenshot) { ReminderRow(reminder: r) } }
            .navigationTitle("Не забыть")
    }
}

struct DoneView: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        List(model.all.filter(\.isDone)) { s in
            NavigationLink { DetailView(shotID: s.id) } label: { ScreenshotRow(shot: s) }
        }
        .navigationTitle("Разобранное")
        .overlay { if model.all.filter(\.isDone).isEmpty { ContentUnavailableView("Пока пусто", systemImage: "checkmark.circle") } }
    }
}
