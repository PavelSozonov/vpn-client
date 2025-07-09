# vpn-client

Этот проект содержит примеры кода и пошаговую инструкцию по созданию минимального iOS‑VPN‑клиента, подключающегося к VLESS серверу с помощью библиотеки **libXray** (обёртка над [Xray-core](https://github.com/XTLS/Xray-core)).

## Архитектура

- **UI‑приложение** (SwiftUI) — отображает единственный переключатель включения VPN и отправляет команды расширению через `NEVPNManager`.
- **Network Extension** (Packet Tunnel Provider) — запускает libXray, который перенаправляет трафик на сервер.
- **libXray** — собранный в виде `LibXray.xcframework` Xray-core с поддержкой протокола VLESS + Reality.

Обе части используют общий App Group для доступа к файлу конфигурации.

## Структура репозитория

```
ios/
  VPNClient/            # исходники основного приложения
  VPNTunnelExtension/   # исходники Packet Tunnel Provider
  Shared/               # сюда помещается файл config.json (не хранится в git)
.gitkeep                # пустышки для сохранения каталогов в репозитории
scripts/
  generate_config.py    # генерация config.json из переменных окружения
.env.example            # пример переменных для настройки соединения
```

## Сборка libXray

1. Установите [Go](https://go.dev/dl/) ≥1.20 и Python ≥3.7.
2. Склонируйте репозиторий libXray и соберите xcframework:
   ```bash
   git clone https://github.com/XTLS/libXray.git
   cd libXray
   python3 build/main.py apple go
   ```
   Готовая `LibXray.xcframework` появится в каталоге `output`.
3. Скопируйте `LibXray.xcframework` в папку `ios/` текущего проекта и добавьте её в оба таргета в Xcode.

## Подготовка конфигурации

Файл `config.json`, который читает расширение, генерируется скриптом `scripts/generate_config.py`. Настройки берутся из переменных окружения. Создайте `.env` на основе `.env.example` и заполните параметры вашего сервера:

```bash
cp .env.example .env
# отредактируйте .env, указав реальные значения
```

Перед сборкой выполните:

```bash
source .env
python3 scripts/generate_config.py ios/Shared/config.json
```

В результате файл `ios/Shared/config.json` будет создан и включён как ресурс обоих таргетов.

## Создание проекта в Xcode

1. Откройте Xcode и выберите **File → New → Project…**. Создайте приложение **App** (SwiftUI, Swift).
2. В меню **File → New → Target…** добавьте **Network Extension → Packet Tunnel Provider**. Для Bundle Identifier расширения задайте `com.example.vpnclient.VPNTunnelExtension` (можно изменить на свой, но не забудьте обновить его в коде).
3. В обоих таргетах (приложение и расширение) на вкладке **Signing & Capabilities** добавьте:
   - **App Groups** → `group.vpnclient` (название можно изменить, но оно должно совпадать в коде).
   - Для расширения включите capability **Personal VPN**.
4. Добавьте `LibXray.xcframework` в секцию **Frameworks, Libraries, and Embedded Content** обоих таргетов.
5. Добавьте созданный `ios/Shared/config.json` в оба таргета как ресурс (drag&drop в Project Navigator → выберите оба таргета).
6. Убедитесь, что в настройках схемы приложение и расширение подписываются одной командой разработчика.

## Минимальный UI

В каталоге `ios/VPNClient` размещены файлы:
- `VPNClientApp.swift` — точка входа приложения.
- `ContentView.swift` — белый экран с переключателем, который управляет туннелем.
- `VPNManager.swift` — класс‑обёртка над `NEVPNManager`.

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

`ios/VPNTunnelExtension/PacketTunnelProvider.swift` содержит запуск libXray. Расширение ищет `config.json` в контейнере App Group:

```swift
class PacketTunnelProvider: NEPacketTunnelProvider {
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.vpnclient")!.appendingPathComponent("config.json")
        libxray_start(url.path)
        completionHandler(nil)
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        libxray_stop()
        completionHandler()
    }
}
```

## Запуск приложения

1. Сгенерируйте `config.json` как описано выше.
2. Откройте `ios` каталог как проект в Xcode.
3. Выберите схему основного приложения и подключенный iPhone.
4. Нажмите **Run**. При первом запуске система попросит разрешить создание VPN‑конфигурации.
5. Переключатель в приложении включает и выключает VPN.

## Дополнительные материалы

- Документация Xray-core: <https://xtls.github.io>
- Пример Network Extension от Apple: [SimpleTunnel](https://github.com/networkextension/SimpleTunnel)
