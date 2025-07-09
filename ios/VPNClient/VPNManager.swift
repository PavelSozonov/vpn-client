import NetworkExtension

final class VPNManager {
    static let shared = VPNManager()
    private let manager = NEVPNManager.shared()

    private init() {
        load()
    }

    private func load() {
        manager.loadFromPreferences { error in
            if let error = error {
                print("Load error: \(error)")
            }
        }
    }

    func start() {
        manager.loadFromPreferences { [weak self] _ in
            guard let self = self else { return }
            let proto = NETunnelProviderProtocol()
            proto.providerBundleIdentifier = "com.example.vpnclient.VPNTunnelExtension"
            proto.providerConfiguration = ["group": "group.vpnclient"]
            self.manager.protocolConfiguration = proto
            self.manager.localizedDescription = "VLESS VPN"
            self.manager.isEnabled = true
            self.manager.saveToPreferences { error in
                if let error = error {
                    print("Save error: \(error)")
                    return
                }
                do {
                    try self.manager.connection.startVPNTunnel()
                } catch {
                    print("Start error: \(error)")
                }
            }
        }
    }

    func stop() {
        manager.connection.stopVPNTunnel()
    }
}
