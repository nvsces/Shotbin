import SwiftUI

struct DetailView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let shotID: String
    @State private var image: UIImage?
    @State private var showText = false
    @State private var confirmDelete = false
    @State private var copied: String?

    private var shot: Screenshot? { model.items[shotID] }

    var body: some View {
        if let shot {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemFill))
                        if let image { Image(uiImage: image).resizable().aspectRatio(contentMode: .fit) }
                    }
                    .frame(maxHeight: 360).clipShape(RoundedRectangle(cornerRadius: 12))

                    HStack {
                        Menu {
                            ForEach(Category.allCases) { c in
                                Button { model.setCategory(shot, c) } label: { Label(c.rawValue, systemImage: c.symbol) }
                            }
                        } label: {
                            Label(shot.category.rawValue, systemImage: shot.category.symbol)
                                .font(.subheadline.weight(.medium)).padding(.horizontal, 10).padding(.vertical, 6)
                                .background(Color.accentColor.opacity(0.12), in: Capsule())
                        }
                        Spacer()
                        Text(shot.createdAt, format: .dateTime.day().month().year()).font(.caption).foregroundStyle(.secondary)
                    }

                    if !shot.extracted.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Найдено на скриншоте").font(.caption).foregroundStyle(.secondary)
                            ForEach(shot.extracted) { e in
                                Button { act(e, shot) } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: e.symbol).foregroundStyle(Color.accentColor).frame(width: 24)
                                        VStack(alignment: .leading, spacing: 1) {
                                            if let l = e.label { Text(l).font(.caption).foregroundStyle(.secondary) }
                                            Text(e.value).font(.body).lineLimit(2).multilineTextAlignment(.leading)
                                        }
                                        Spacer()
                                        Text(copied == e.id ? "Готово" : e.actionTitle).font(.caption.weight(.medium))
                                            .foregroundStyle(copied == e.id ? .green : Color.accentColor)
                                    }
                                    .padding(12).background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                                }
                                .buttonStyle(.plain).foregroundStyle(.primary)
                            }
                        }
                    }

                    DisclosureGroup("Весь текст", isExpanded: $showText) {
                        Text(shot.text.isEmpty ? "Текст не распознан" : shot.text)
                            .font(.callout).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 6)
                    }
                    .font(.subheadline)

                    if shot.isFreed {
                        HStack(spacing: 8) {
                            Image(systemName: "internaldrive").foregroundStyle(.green)
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Место освобождено").font(.subheadline.weight(.medium))
                                Text(freedNote(shot)).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(12)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                    } else {
                        HStack(spacing: 10) {
                            Button { model.markDone(shot, !shot.isDone); if !shot.isDone { dismiss() } } label: {
                                Label(shot.isDone ? "Вернуть" : "Разобрался", systemImage: shot.isDone ? "arrow.uturn.left" : "checkmark")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent).controlSize(.large)
                            Button(role: .destructive) { confirmDelete = true } label: {
                                Image(systemName: "trash").frame(width: 44)
                            }
                            .buttonStyle(.bordered).controlSize(.large)
                        }
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .task { image = await model.fullImage(for: shot) }
            .confirmationDialog("Удалить скриншот из галереи?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Удалить, данные оставить", role: .destructive) { Task { await model.free([shot]); dismiss() } }
                Button("Удалить вместе с карточкой", role: .destructive) { Task { await model.delete(shot); dismiss() } }
                Button("Отмена", role: .cancel) {}
            } message: { Text("Картинка попадёт в «Недавно удалённые» на 30 дней. Распознанный текст и находки можно оставить в Recall.") }
        } else {
            ContentUnavailableView("Скриншот удалён", systemImage: "photo")
        }
    }

    private func freedNote(_ shot: Screenshot) -> String {
        let size = shot.freedBytes > 0 ? ByteCountFormatter.string(fromByteCount: shot.freedBytes, countStyle: .file) : nil
        let when = shot.freedAt?.formatted(date: .abbreviated, time: .omitted)
        return [size.map { "Вернули \($0)" }, when.map { "Картинки нет с \($0)" }]
            .compactMap { $0 }.joined(separator: " · ")
    }

    private func act(_ e: Extracted, _ shot: Screenshot) {
        model.perform(e, from: shot)
        if [.code, .wifi, .orderNumber, .amount, .flight].contains(e.kind) {
            copied = e.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = nil }
        }
    }
}
