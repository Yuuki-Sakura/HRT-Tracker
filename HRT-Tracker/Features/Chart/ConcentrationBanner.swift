import SwiftUI
import HRTModels

struct ConcentrationBanner: View {
    let concentration: Double?

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("banner.currentLevel")
                    .font(.caption).foregroundStyle(.secondary)
                if let conc = concentration {
                    Text(String(format: "%.1f pg/mL", conc))
                        .font(.title2.bold())
                        .foregroundStyle(.pink)
                } else {
                    Text("banner.noData")
                        .font(.title2).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    VStack {
        ConcentrationBanner(concentration: 85.3)
        ConcentrationBanner(concentration: nil)
    }
    .padding()
}
