import SwiftUI

struct InjectionGuideView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(String(localized: "inj.guide.title"), systemImage: "syringe")
                .font(.subheadline.bold())

            // Safety warning
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Text("inj.guide.safety")
                    .font(.caption.bold())
                    .foregroundStyle(.red)
            }

            Divider()

            // Route methods
            Text("inj.guide.route_methods")
                .font(.caption)
            Text("inj.guide.route_warn")
                .font(.caption.bold())
                .foregroundStyle(.orange)

            Divider()

            // Dosage
            Text("inj.guide.dosage_title")
                .font(.caption.bold())
            Text("inj.guide.dosage_ev")
                .font(.caption)
            Text("inj.guide.dosage_ec")
                .font(.caption)

            // Simulator link
            if let url = URL(string: "https://transfemscience.org/misc/injectable-e2-simulator/") {
                Link(destination: url) {
                    HStack(spacing: 4) {
                        Image(systemName: "link")
                        Text("inj.guide.sim_link")
                    }
                    .font(.caption)
                }
            }

            Divider()

            // Notes
            Text("inj.guide.notes_title")
                .font(.caption.bold())

            VStack(alignment: .leading, spacing: 4) {
                NoteItem(text: String(localized: "inj.guide.note_1"))
                NoteItem(text: String(localized: "inj.guide.note_2"))
                NoteItem(text: String(localized: "inj.guide.note_3"), color: .red)
                NoteItem(text: String(localized: "inj.guide.note_4"), color: .orange)
                NoteItem(text: String(localized: "inj.guide.note_5"))
                NoteItem(text: String(localized: "inj.guide.note_6"))
                NoteItem(text: String(localized: "inj.guide.note_7"))
                NoteItem(text: String(localized: "inj.guide.note_8"))
                NoteItem(text: String(localized: "inj.guide.note_9"))
            }

            Divider()

            // Source
            if let url = URL(string: "https://mtf.wiki/zh-cn/docs/medicine/estrogen/injection") {
                Link(destination: url) {
                    Text("inj.guide.source")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct NoteItem: View {
    let text: String
    var color: Color = .primary

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•").font(.caption).foregroundStyle(color)
            Text(text).font(.caption).foregroundStyle(color)
        }
    }
}

#Preview {
    ScrollView {
        InjectionGuideView()
            .padding()
    }
}
