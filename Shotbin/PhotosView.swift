import SwiftUI

/// Раздел обычных фотографий. Отдельно от скриншотов и только по желанию:
/// здесь не читают текст, а ищут серии почти одинаковых кадров.
struct PhotosView: View {
    @EnvironmentObject var photos: PhotoScanner
    @State private var keepChoice: [String: String] = [:]
    @State private var skipped: Set<String> = []
    @State private var working = false
    @State private var freedNow: Int64 = 0
    @State private var confirming = false

    private var series: [PhotoScanner.Series] { photos.series.filter { !skipped.contains($0.id) } }
    private var doomed: [PhotoScanner.Frame] { series.flatMap { s in s.all.filter { $0.id != keepID(s) } } }
    private var doomedSize: Int64 { photos.totalSize(doomed) }

    var body: some View {
        List {
            if photos.isScanning {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Сравниваю фотографии…").font(.subheadline.weight(.medium))
                                Text("\(photos.progress.done) из \(photos.progress.total)")
                                    .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                            }
                            Spacer()
                            Button("Пауза") { photos.cancel() }.font(.caption.weight(.semibold))
                        }
                        if photos.progress.total > 0 {
                            ProgressView(value: Double(photos.progress.done), total: Double(photos.progress.total))
                        }
                    }
                }
            } else if photos.neverScanned {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.stack").font(.largeTitle).foregroundStyle(.secondary)
                        Text("Проверить фотографии").font(.headline)
                        Text("Shotbin сравнит кадры между собой и покажет серии почти одинаковых. Текст на фотографиях не читается — только поиск повторов.")
                            .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        Button { photos.scan() } label: {
                            Text("Начать").fontWeight(.semibold).frame(maxWidth: .infinity).padding(.vertical, 12)
                        }
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 20)
                }
            } else if photos.wasInterrupted {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "pause.circle").foregroundStyle(.orange).frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Проверка на паузе").font(.subheadline.weight(.medium))
                            Text("Осталось \(photos.remaining)").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Продолжить") { photos.scan() }.font(.caption.weight(.semibold))
                    }
                }
            }

            if !photos.neverScanned && !photos.isScanning && series.isEmpty {
                Section {
                    VStack(spacing: 10) {
                        Image(systemName: "checkmark.circle").font(.largeTitle).foregroundStyle(.secondary)
                        Text("Повторов нет").font(.headline)
                        Text("Проверено фотографий: \(photos.scannedCount).")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 20)
                }
            }

            ForEach(series) { group in
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(group.all) { f in
                                frame(f, isKept: f.id == keepID(group))
                                    .onTapGesture { keepChoice[group.id] = f.id }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    HStack {
                        Text("Оставляем 1, удаляем \(group.all.count - 1)")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button("Пропустить") { skipped.insert(group.id) }
                            .font(.caption.weight(.semibold))
                    }
                } header: {
                    HStack {
                        Text("\(group.all.count) почти одинаковых").lineLimit(1)
                        Spacer(minLength: 8)
                        Text(group.keep.createdAt.formatted(date: .abbreviated, time: .omitted))
                            .textCase(nil).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
            }

            if photos.freedBytes > 0 {
                Section {
                    HStack {
                        Label("Освобождено на фото", systemImage: "internaldrive")
                        Spacer()
                        Text(bytes(photos.freedBytes)).foregroundStyle(.secondary).monospacedDigit()
                    }
                    .font(.subheadline)
                }
            }
        }
        .navigationTitle("Фотографии")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !photos.neverScanned && !photos.isScanning {
                Button { photos.scan() } label: { Image(systemName: "arrow.clockwise") }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !doomed.isEmpty {
                VStack(spacing: 6) {
                    Button { confirming = true } label: {
                        HStack {
                            if working { ProgressView().tint(.white) }
                            Text(working ? "Удаляю…" : "Удалить \(doomed.count) повторов · \(bytes(doomedSize))")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                    }
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
                    .disabled(working)
                    Text("Выбранные кадры останутся. Остальные уйдут в «Недавно удалённые» на 30 дней.")
                        .font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                .padding(.horizontal).padding(.bottom, 8)
                .background(.bar)
            }
        }
        .confirmationDialog("Удалить \(doomed.count) повторов?", isPresented: $confirming, titleVisibility: .visible) {
            Button("Удалить и освободить \(bytes(doomedSize))", role: .destructive) { Task { await run() } }
            Button("Отмена", role: .cancel) {}
        }
        // Замер привязан к самим сериям: при открытии их ещё нет,
        // они появляются только после проверки.
        .task(id: series.map(\.id).joined()) { await photos.measure(series.flatMap(\.all)) }
        .overlay(alignment: .top) {
            if freedNow > 0 {
                Label("Освободили \(bytes(freedNow))", systemImage: "checkmark.circle.fill")
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(.green.opacity(0.9), in: Capsule())
                    .foregroundStyle(.white).font(.subheadline.weight(.semibold))
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: freedNow)
    }

    private func keepID(_ g: PhotoScanner.Series) -> String { keepChoice[g.id] ?? g.keep.id }

    private func frame(_ f: PhotoScanner.Frame, isKept: Bool) -> some View {
        VStack(spacing: 6) {
            PhotoThumb(assetID: f.id)
                .frame(width: 92, height: 92)
                .overlay { RoundedRectangle(cornerRadius: 8).stroke(isKept ? Color.accentColor : .clear, lineWidth: 3) }
                .overlay(alignment: .topTrailing) {
                    if isKept {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.white, Color.accentColor).padding(4)
                    }
                }
            Text(isKept ? "Оставить" : bytes(photos.sizes[f.id] ?? 0))
                .font(.caption2).foregroundStyle(isKept ? Color.accentColor : .secondary)
        }
    }

    private func run() async {
        working = true
        let freed = await photos.delete(doomed)
        working = false
        if freed > 0 {
            freedNow = freed
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            freedNow = 0
        }
    }

    private func bytes(_ v: Int64) -> String { ByteCountFormatter.string(fromByteCount: v, countStyle: .file) }
}

/// Миниатюра фотографии прямо из галереи — карточек мы для них не заводим.
struct PhotoThumb: View {
    let assetID: String
    @State private var image: UIImage?
    var body: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(Color(.secondarySystemFill))
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height).clipped()
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .task(id: assetID) {
            guard let a = PhotoLibrary.shared.asset(id: assetID) else { return }
            image = await PhotoLibrary.shared.thumbnail(for: a)
        }
    }
}
