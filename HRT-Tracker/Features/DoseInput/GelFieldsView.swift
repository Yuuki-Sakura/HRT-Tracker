import SwiftUI
import HRTModels

struct GelFieldsView: View {
    @Binding var draft: DraftDoseEvent

    var body: some View {
        Section(String(localized: "input.gel.site")) {
            Picker(String(localized: "input.gel.site.label"), selection: $draft.applicationSite) {
                Text("input.gel.site.none").tag(ApplicationSite?.none)
                ForEach(ApplicationSite.gelSites) { site in
                    Text(site.localizedName).tag(ApplicationSite?.some(site))
                }
            }

            if draft.applicationSite?.isScrotal == true {
                Text("input.gel.site.scrotalNote")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    @Previewable @State var draft = DraftDoseEvent(route: .gel, ester: .E2)
    Form {
        GelFieldsView(draft: $draft)
    }
}
