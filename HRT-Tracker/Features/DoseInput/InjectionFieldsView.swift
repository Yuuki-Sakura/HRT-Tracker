import SwiftUI
import HRTModels

struct InjectionFieldsView: View {
    @Binding var draft: DraftDoseEvent
    var focusedField: FocusState<FocusedDoseField?>.Binding

    var body: some View {
        Section(String(localized: "input.injection.site")) {
            Picker(String(localized: "input.injection.site.label"), selection: $draft.applicationSite) {
                Text("input.injection.site.none").tag(ApplicationSite?.none)
                ForEach(ApplicationSite.injectionSites) { site in
                    Text(site.localizedName).tag(ApplicationSite?.some(site))
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var draft = DraftDoseEvent(route: .injection, ester: .EV)
    @Previewable @FocusState var focus: FocusedDoseField?
    Form {
        InjectionFieldsView(draft: $draft, focusedField: $focus)
    }
}
