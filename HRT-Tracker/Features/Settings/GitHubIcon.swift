import SwiftUI

struct GitHubIcon: View {
    var body: some View {
        Image("github")
            .renderingMode(.template)
            .resizable()
            .aspectRatio(contentMode: .fit)
    }
}
