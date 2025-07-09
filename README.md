# vpn-client

Этот проект содержит примеры кода и пошаговую инструкцию по созданию минимального iOS VPN‑клиента, подключающегося к VLESS серверу с помощью библиотеки **libXray** (обёртка над [Xray-core](https://github.com/XTLS/Xray-core)).

## Архитектура

- **UI‑приложение** (SwiftUI) — отображает переключатель включения VPN и отправляет команды расширению через `NEVPNManager`.
- **Network Extension** (Packet Tunnel Provider) — запускает libXray, который перенаправляет трафик на сервер.
- **libXray** — собранный в виде `LibXray.xcframework` Xray-core с поддержкой протокола VLESS + Reality.

Обе части используют общий App Group для доступа к `config.json`.

## Структура репозитория

```text
ios/
  VPNClient/            # исходники основного приложения
  VPNTunnelExtension/   # исходники Packet Tunnel Provider
  Shared/               # сюда помещается файл config.json (не хранится в git)
scripts/
  generate_config.py    # генерация config.json из переменных окружения
.env.example            # пример переменных для настройки соединения
```

## Сборка libXray
1. Установите [Go](https://go.dev/dl/) ≥1.20 и Python ≥3.7.
2. Клонируйте репозиторий и соберите `xcframework`:
   ```bash
   git clone https://github.com/XTLS/libXray.git
   cd libXray
   python3 build/main.py apple go
   ```
   Готовая `LibXray.xcframework` появится в каталоге `output`.
3. Скопируйте `LibXray.xcframework` в папку `ios/` проекта и добавьте её в оба таргета в Xcode.

## Подготовка конфигурации
Файл `config.json` генерируется скриптом `scripts/generate_config.py`. Создайте `.env` на основе `.env.example` и заполните параметры сервера:

```bash
cp .env.example .env
# отредактируйте .env
```

Перед сборкой приложения выполните:

```bash
source .env
python3 scripts/generate_config.py ios/Shared/config.json
```

Скрипт создаст `ios/Shared/config.json`, который добавляется в оба таргета как ресурс.

## Создание проекта в Xcode
1. Создайте новое iOS‑приложение (SwiftUI, Swift).
2. Добавьте таргет **Network Extension → Packet Tunnel Provider**.
3. В обоих таргетах на вкладке **Signing & Capabilities** включите:
   - **App Groups** (например, `group.vpnclient`);
   - для расширения также **Personal VPN**.
4. Подключите `LibXray.xcframework` к обоим таргетам.
5. Добавьте `ios/Shared/config.json` в проект и отметьте оба таргета.

## Минимальный UI
`ios/VPNClient` содержит простой экран с переключателем:

```swift
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
```

## Packet Tunnel Provider
`ios/VPNTunnelExtension/PacketTunnelProvider.swift` запускает libXray и читает `config.json` из App Group:

```swift
class PacketTunnelProvider: NEPacketTunnelProvider {
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.vpnclient")!
            .appendingPathComponent("config.json")
        libxray_start(url.path)
        completionHandler(nil)
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        libxray_stop()
        completionHandler()
    }
}
```

Функции `libxray_start` и `libxray_stop` предоставляются библиотекой libXray.

Для управления туннелем в основном приложении используется `NEVPNManager`:

```swift
let manager = NEVPNManager.shared()
manager.loadFromPreferences { _ in
    let proto = NETunnelProviderProtocol()
    proto.providerBundleIdentifier = "com.example.vpnclient.VPNTunnelExtension"
    proto.providerConfiguration = ["group": "group.vpnclient"]
    manager.protocolConfiguration = proto
    manager.localizedDescription = "VLESS VPN"
    manager.isEnabled = true
    manager.saveToPreferences { _ in
        try? manager.connection.startVPNTunnel()
    }
}
```

Отключение: `manager.connection.stopVPNTunnel()`.

## Запуск приложения
1. Сгенерируйте `config.json` как описано выше.
2. Откройте каталог `ios` в Xcode.
3. Выберите схему приложения и подключённый iPhone.
4. Нажмите **Run** и разрешите создание VPN‑конфигурации при первом запуске.
5. Включайте и выключайте VPN переключателем.

## Настройка сервера
При генерации `config.json` укажите реальные значения `server`, `UUID`, `PUBLIC_KEY` и `SHORT_ID` вашего VLESS сервера.

## Дополнительные материалы
- Документация Xray-core: <https://xtls.github.io>
- Пример Network Extension от Apple: [SimpleTunnel](https://github.com/networkextension/SimpleTunnel)
