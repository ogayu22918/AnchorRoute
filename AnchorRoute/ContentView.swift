import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationView {
            MainMenuView()
                .navigationBarTitle("AnchorRoute", displayMode: .inline)
        }
    }
}
