import SwiftUI

// Vue principale
struct ContentView: View {
    
    var body: some View {
        NavigationStack {
            ScrollView {
                Spacer()
                NavigationLink(destination: DashboardView()) {
                    Text("Go to Dashboard")
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                Spacer()
                NavigationLink(destination: RemoteControllerView()) {
                    Text("Go to Remote controller view")
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                Spacer()
            }
        }
    }
}
