import SwiftUI

/// Уборка галереи: скриншот отработал, данные лежат в карточке, картинка больше не нужна.
/// Показываем, сколько места вернём, даём снять галочки и удаляем одной пачкой.
struct CleanupView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<String> = []
    @State private var working = false
    @State private var freedNow: Int64 = 0
    @State private var confirming = false

    private var groups: [(AppModel.FreeReason, [Screenshot])] { model.cleanupGroups }
    private var chosen: [Screenshot] { groups.flatMap(\.1).filter { selected.contains($0.id) } }
    private var chosenSize: Int64 { model.totalSize(chosen) }

    var body: some View {
        List {
            if groups.isEmpty {
                Section {
                    VStack(spacing: 10) {
                        Image(systemName: "sparkles").font(.largeTitle).foregroundStyle(.secondary)
                        Text("Убирать нечего").font(.headline)
                        Text("Разберите скриншоты — отмеченные «разобрался» появятся здесь.")
                            .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 24)
                }
            }

            ForEach(groups, id: \.0) { reason, list in
                Section {
                    ForEach(list) { s in
                        HStack(spacing: 0) {
                            Button { toggle(s.id) } label: { row(s) }
                                .buttonStyle(.plain)
                            NavigationLink { DetailView(shotID: s.id) } label: { EmptyView() }
                                .frame(width: 24)
                        }
                    }
                } header: {
                    HStack {
                        Text(reason.rawValue)
                        Spacer()
                        Button(allSelected(list) ? "Снять" : "Все") { toggleAll(list) }
                            .font(.caption.weight(.semibold)).textCase(nil)
                    }
                } footer: {
                    Text(reason.hint)
                }
            }

            if model.freedCount > 0 {
                Section {
                    HStack {
                        Label("Освобождено всего", systemImage: "internaldrive")
                        Spacer()
                        Text(bytes(model.freedTotal)).foregroundStyle(.secondary).monospacedDigit()
                    }
                    .font(.subheadline)
                }
            }
        }
        .navigationTitle("Уборка")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if !chosen.isEmpty {
                VStack(spacing: 6) {
                    Button {
                        confirming = true
                    } label: {
                        HStack {
                            if working { ProgressView().tint(.white) }
                            Text(working ? "Удаляю…" : "Освободить \(bytes(chosenSize))")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                    }
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
                    .disabled(working)

                    Text("\(chosen.count) шт. уйдёт в «Недавно удалённые» на 30 дней. Данные останутся в Shotbin.")
                        .font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                .padding(.horizontal).padding(.bottom, 8)
                .background(.bar)
            }
        }
        .confirmationDialog("Удалить \(chosen.count) скриншотов из галереи?",
                            isPresented: $confirming, titleVisibility: .visible) {
            Button("Удалить и освободить \(bytes(chosenSize))", role: .destructive) { Task { await run() } }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Распознанный текст, коды и даты останутся в Shotbin. Сами картинки система положит в «Недавно удалённые».")
        }
        .task {
            await model.measure(groups.flatMap(\.1))
            if selected.isEmpty { selected = Set(groups.flatMap(\.1).map(\.id)) }
        }
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

    private func row(_ s: Screenshot) -> some View {
        HStack(spacing: 12) {
            Image(systemName: selected.contains(s.id) ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(selected.contains(s.id) ? Color.accentColor : Color.secondary)
                .imageScale(.large)
            Thumb(shotID: s.id)
                .frame(width: 40, height: 56)
                .clipped()
            VStack(alignment: .leading, spacing: 2) {
                Text(s.summary.isEmpty ? s.category.rawValue : s.summary)
                    .lineLimit(1).truncationMode(.tail)
                Text(s.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let size = model.sizes[s.id] {
                Text(bytes(size)).font(.caption).foregroundStyle(.secondary)
                    .monospacedDigit().layoutPriority(1).fixedSize()
            }
        }
        .contentShape(Rectangle())
    }

    private func allSelected(_ list: [Screenshot]) -> Bool { list.allSatisfy { selected.contains($0.id) } }
    private func toggle(_ id: String) {
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
    }
    private func toggleAll(_ list: [Screenshot]) {
        if allSelected(list) { list.forEach { selected.remove($0.id) } }
        else { list.forEach { selected.insert($0.id) } }
    }

    private func run() async {
        working = true
        let freed = await model.free(chosen)
        working = false
        selected.removeAll()
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
