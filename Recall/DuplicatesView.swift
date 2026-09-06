import SwiftUI

/// Повторы: серии почти одинаковых кадров. Один оставляем, остальные удаляем.
struct DuplicatesView: View {
    @EnvironmentObject var model: AppModel
    @State private var keepChoice: [String: String] = [:]   // id группы → id кадра, который оставляем
    @State private var skipped: Set<String> = []            // группы, которые пользователь пропустил
    @State private var working = false
    @State private var freedNow: Int64 = 0
    @State private var confirming = false

    private var groups: [AppModel.DuplicateGroup] {
        model.duplicateGroups.filter { !skipped.contains($0.id) }
    }
    /// Что уйдёт: в каждой серии всё, кроме выбранного кадра.
    private var doomed: [Screenshot] {
        groups.flatMap { g in g.all.filter { $0.id != keepID(g) } }
    }
    private var doomedSize: Int64 { model.totalSize(doomed) }

    var body: some View {
        List {
            if groups.isEmpty {
                Section {
                    VStack(spacing: 10) {
                        Image(systemName: "square.on.square.dashed").font(.largeTitle).foregroundStyle(.secondary)
                        Text("Повторов нет").font(.headline)
                        Text("Recall сравнивает кадры между собой и собирает сюда серии почти одинаковых скриншотов.")
                            .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 24)
                }
            }

            if !groups.isEmpty {
                Section {
                    Text("Нажмите на кадр, чтобы оставить именно его. По умолчанию Recall оставляет тот, где больше распознанного текста.")
                        .font(.caption).foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                }
            }

            ForEach(groups) { group in
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(group.all) { s in
                                frame(s, isKept: s.id == keepID(group))
                                    .onTapGesture { keepChoice[group.id] = s.id }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    HStack {
                        Text("Оставляем 1, удаляем \(group.all.count - 1)")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button("Пропустить серию") { skipped.insert(group.id) }
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

        }
        .navigationTitle("Повторы")
        .navigationBarTitleDisplayMode(.inline)
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
                    Text("Выбранные кадры останутся в галерее. Остальные уйдут в «Недавно удалённые».")
                        .font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                .padding(.horizontal).padding(.bottom, 8)
                .background(.bar)
            }
        }
        .confirmationDialog("Удалить \(doomed.count) повторов?", isPresented: $confirming, titleVisibility: .visible) {
            Button("Удалить и освободить \(bytes(doomedSize))", role: .destructive) { Task { await run() } }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("В каждой серии останется выбранный кадр. Остальные система положит в «Недавно удалённые» на 30 дней.")
        }
        .task { await model.measure(groups.flatMap(\.all)) }
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

    private func keepID(_ g: AppModel.DuplicateGroup) -> String { keepChoice[g.id] ?? g.keep.id }

    private func frame(_ s: Screenshot, isKept: Bool) -> some View {
        VStack(spacing: 6) {
            Thumb(shotID: s.id)
                .frame(width: 92, height: 128)
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isKept ? Color.accentColor : Color.clear, lineWidth: 3)
                }
                .overlay(alignment: .topTrailing) {
                    if isKept {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.white, Color.accentColor)
                            .padding(4)
                    }
                }
            Text(isKept ? "Оставить" : bytes(model.sizes[s.id] ?? 0))
                .font(.caption2)
                .foregroundStyle(isKept ? Color.accentColor : .secondary)
        }
    }

    private func run() async {
        working = true
        let freed = await model.free(doomed, keepCards: false)
        working = false
        if freed > 0 {
            freedNow = freed
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            freedNow = 0
        }
    }

    private func bytes(_ v: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: v, countStyle: .file)
    }
}
