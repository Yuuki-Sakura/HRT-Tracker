import SwiftUI
import HRTModels

struct DayGroup: Identifiable {
    var id: String { day }
    let day: String
    let events: [DoseEvent]
}

struct DayGroupSection: View {
    let dayGroup: DayGroup
    let onEdit: (DoseEvent) -> Void
    let onDelete: ([DoseEvent]) -> Void

    var body: some View {
        Section(header: Text(dayGroup.day)) {
            ForEach(dayGroup.events) { event in
                Button {
                    onEdit(event)
                } label: {
                    TimelineRowView(event: event)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
            }
            .onDelete { indexSet in
                let eventsToDelete = indexSet.map { dayGroup.events[$0] }
                onDelete(eventsToDelete)
            }
        }
    }
}

#Preview {
    let events = [
        DoseEvent(route: .injection, timestamp: Int64(Date().timeIntervalSince1970), doseMG: 5.0, ester: .EV),
        DoseEvent(route: .oral, timestamp: Int64(Date().timeIntervalSince1970) - 2 * 3600, doseMG: 2.0, ester: .E2),
    ]
    List {
        DayGroupSection(dayGroup: DayGroup(day: "Today", events: events), onEdit: { _ in }, onDelete: { _ in })
    }
}
