import SwiftUI

struct ContentView: View {
    @State private var isOn = false
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            Toggle("VPN", isOn: $isOn)
                .padding()
                .onChange(of: isOn) { value in
                    if value {
                        VPNManager.shared.start()
                    } else {
                        VPNManager.shared.stop()
                    }
                }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
