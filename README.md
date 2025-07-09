# vpn-client

Этот репозиторий содержит инструкции по созданию iOS‑клиента, способного подключаться к VLESS серверу с использованием библиотеки **libXray** (обёртка над [Xray‑core](https://github.com/XTLS/Xray-core), лицензия MPL‑2.0). Графическая часть приложения разрабатывается отдельно, здесь описывается только Network Extension.

## Архитектура

* **UI приложение** — основное приложение, отвечает только за отображение состояния подключения и переключатель «Вкл/Выкл». Это обычный iOS‑приложение (Swift/SwiftUI). Оно взаимодействует с VPN‑расширением через `NEVPNManager`.
* **Network Extension** (целевой тип *Packet Tunnel Provider*) — запускается системой, когда пользователь включает VPN. Внутри расширения вызывается библиотека libXray, которая поднимает туннель и перенаправляет трафик на сервер.
* **libXray** — скомпилированная как `xcframework` версия Xray-core. Поддерживает VLESS с `reality` и `xtls-rprx-vision`.

UI и Extension собираются в рамках одной схемы Xcode и подписываются одним App Group для обмена настройками.

## Сборка libXray

1. Установите [Go](https://go.dev/dl/) ≥1.20 и Python ≥3.7.
2. Клонируйте репозиторий:
   ```bash
   git clone https://github.com/XTLS/libXray.git
   cd libXray
   ```
3. Запустите скрипт сборки для платформ Apple:
   ```bash
   python3 build/main.py apple go
   ```
   В каталоге `output` появится `LibXray.xcframework`.
4. Скопируйте `LibXray.xcframework` в папку `ios/` текущего проекта и добавьте её в Xcode ("Add files to…").

## Настройка Xcode проекта

1. Создайте новое iOS‑приложение (если ещё не создано). Добавьте к нему целевой модуль **Network Extension** типа *Packet Tunnel Provider*.
2. В разделе "Signing & Capabilities" добавьте *App Groups* (например, `group.vpnclient`), чтобы приложение и расширение могли обмениваться данными.
3. Включите capability **Personal VPN** для расширения.
4. Добавьте `LibXray.xcframework` в оба таргета (приложение и расширение).

Минимальная реализация `PacketTunnelProvider` может выглядеть так:
```swift
import NetworkExtension
import libXray

class PacketTunnelProvider: NEPacketTunnelProvider {
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        // Конфиг пишется в файл в каталоге контейнера расширения
        let config = "{" +
            "\"log\":{\"loglevel\":\"warning\"}," +
            "\"inbounds\":[{\"type\":\"tun\",\"interface_name\":\"utun\"}]," +
            "\"outbounds\":[{\"type\":\"vless\",\"tag\":\"out\",\"server\":\"example.com\",\"server_port\":443,\"uuid\":\"<UUID>\",\"flow\":\"xtls-rprx-vision\",\"packet_encoding\":\"xudp\",\"security\":\"reality\",\"reality-opts\":{\"public_key\":\"<PUBLIC_KEY>\",\"short_id\":\"<SHORT_ID>\"}}]}";
        let configURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.vpnclient")!.appendingPathComponent("config.json")
        try? config.data(using: .utf8)?.write(to: configURL)
        libxray_start(configURL.path) // Функция из libXray
        completionHandler(nil)
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        libxray_stop()
        completionHandler()
    }
}
```
Для работы необходимы функции `libxray_start` и `libxray_stop`, предоставляемые библиотекой.

## Подключение из UI

В основном приложении используйте `NEVPNManager` для управления состоянием:
```swift
let manager = NEVPNManager.shared()
manager.loadFromPreferences { _ in
    let proto = NETunnelProviderProtocol()
    proto.providerBundleIdentifier = "com.example.vpnclient.VPNExtension"
    proto.providerConfiguration = ["group": "group.vpnclient"]
    manager.protocolConfiguration = proto
    manager.localizedDescription = "VLESS VPN"
    manager.isEnabled = true
    manager.saveToPreferences { _ in
        try? manager.connection.startVPNTunnel()
    }
}
```
Для отключения вызовите `manager.connection.stopVPNTunnel()`.

## Сборка и запуск

1. Откройте проект в Xcode.
2. Выберите схему основного приложения, устройство (физический iPhone) и выполните **Product → Run**.
3. При первом запуске система попросит разрешение на добавление VPN‑конфигурации.
4. Используйте переключатель в UI для включения и выключения туннеля.

## Настройка сервера

В конфигурации, передаваемой в `libxray_start`, замените `example.com`, `UUID`, `PUBLIC_KEY` и `SHORT_ID` на реальные значения вашего VLESS сервера.

## Дополнительные материалы

- Документация Xray-core: <https://xtls.github.io>
- Пример Network Extension от Apple: [SimpleTunnel](https://github.com/networkextension/SimpleTunnel)

