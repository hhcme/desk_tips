import SwiftUI
import DeskTipsCore

/// History view — completed items grouped by date.
struct HistoryView: View {
    @ObservedObject var store: TodoStore

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("历史记录")
                    .font(.headline)
                Spacer()
                if !store.completedItems.isEmpty {
                    Button("清空历史") {
                        store.clearHistory()
                    }
                    .font(.caption)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Divider()

            if store.completedItems.isEmpty {
                emptyState
            } else {
                historyList
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("暂无历史记录")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("归档后的已完成待办会出现在这里")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - History List

    private var historyList: some View {
        List {
            ForEach(store.historyByDate, id: \.date) { group in
                Section(header: sectionHeader(group.date)) {
                    ForEach(group.items) { item in
                        HistoryRow(item: item, onRestore: {
                            store.restoreFromHistory(id: item.id)
                        }, onDelete: {
                            store.deleteFromHistory(id: item.id)
                        })
                    }
                }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }

    private func sectionHeader(_ date: Date) -> some View {
        HStack {
            Text(dateString(date))
                .font(.subheadline.weight(.medium))
            Spacer()
            Text("\(itemsForDate(date).count) 项")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func itemsForDate(_ date: Date) -> [TodoItem] {
        store.historyByDate.first { Calendar.current.isDate($0.date, inSameDayAs: date) }?.items ?? []
    }

    private func dateString(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "今天" }
        if calendar.isDateInYesterday(date) { return "昨天" }
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日 EEEE"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
}

// MARK: - History Row

private struct HistoryRow: View {
    let item: TodoItem
    let onRestore: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            // Completed indicator
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(.green)

            // Title
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.body)
                    .strikethrough()
                    .foregroundStyle(.secondary)
                if let completedAt = item.completedAt {
                    Text(completedAt.formatted(date: .omitted, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            // Restore button
            Button {
                onRestore()
            } label: {
                Image(systemName: "arrow.uturn.backward.circle")
                    .font(.system(size: 16))
                    .foregroundStyle(.tint)
            }
            .buttonStyle(.plain)
            .help("恢复到待办")

            // Delete button
            Button {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundStyle(.red.opacity(0.7))
            }
            .buttonStyle(.plain)
            .help("永久删除")
        }
        .padding(.vertical, 2)
    }
}
