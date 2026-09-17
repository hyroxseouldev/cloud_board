import AppIntents
import FirebaseAuth
import FirebaseCore
import Flutter
import Foundation

final class ClassControlsPlugin: NSObject, FlutterPlugin {
    static let bindingKey = "cloudboard.class-control-binding.v1"
    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.sunmkim.cloudboard/ios_class_controls", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(ClassControlsPlugin(), channel: channel)
    }
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "configure":
            guard let json = call.arguments as? String, let data = json.data(using: .utf8),
                  let value = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  value["ownerId"] is String, value["sessionId"] is String else {
                result(FlutterError(code: "invalid-binding", message: "잘못된 수업 정보입니다.", details: nil)); return
            }
            UserDefaults.standard.set(data, forKey: Self.bindingKey)
            result(nil)
        case "clear": UserDefaults.standard.removeObject(forKey: Self.bindingKey); result(nil)
        default: result(FlutterMethodNotImplemented)
        }
    }
}

@available(iOS 16.0, *)
actor ClassControlsService {
    static let shared = ClassControlsService()
    private var busy = false
    func execute(_ action: String) async throws {
        guard !busy else { throw ClassControlCommand.Failure(message: "앞선 명령을 처리 중입니다.") }
        busy = true
        let started = Date()
        defer { busy = false }
        guard let binding = UserDefaults.standard.data(forKey: ClassControlsPlugin.bindingKey),
              let config = try JSONSerialization.jsonObject(with: binding) as? [String: Any],
              let owner = config["ownerId"] as? String else {
            throw ClassControlCommand.Failure(message: "앱에서 연결 수업을 먼저 시작해 주세요.")
        }
        if FirebaseApp.app() == nil { FirebaseApp.configure() }
        guard let user = Auth.auth().currentUser, !user.isAnonymous, user.uid == owner else {
            throw ClassControlCommand.Failure(message: "앱에서 매장 계정으로 로그인해 주세요.")
        }
        let token = try await user.getIDToken()
        // Ephemeral HTTP only: never enqueue offline writes or persist tokens.
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 3
        configuration.timeoutIntervalForResource = 6
        let transport = URLSession(configuration: configuration)
        defer { transport.invalidateAndCancel() }
        var components = URLComponents(string: "https://cloud-board-stationd-default-rtdb.asia-southeast1.firebasedatabase.app")!
        components.path = "/users/\(owner)/activeSession.json"
        components.queryItems = [URLQueryItem(name: "auth", value: token)]
        var request = URLRequest(url: components.url!)
        request.setValue("true", forHTTPHeaderField: "X-Firebase-ETag")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await transport.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              let etag = http.value(forHTTPHeaderField: "ETag"),
              let dateHeader = http.value(forHTTPHeaderField: "Date"),
              let state = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ClassControlCommand.Failure(message: "수업 상태를 확인하지 못했습니다. 연결을 확인해 주세요.")
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        guard let serverDate = formatter.date(from: dateHeader) else {
            throw ClassControlCommand.Failure(message: "서버 시간을 확인하지 못했습니다.")
        }
        let updated = try ClassControlCommand.apply(state, config: config, action: action,
            now: Int64(serverDate.timeIntervalSince1970 * 1000))
        guard Date().timeIntervalSince(started) < 6, Auth.auth().currentUser?.uid == owner,
              UserDefaults.standard.data(forKey: ClassControlsPlugin.bindingKey) == binding else {
            throw ClassControlCommand.Failure(message: "계정 또는 수업이 변경되었습니다.")
        }
        request.httpMethod = "PUT"
        request.setValue(etag, forHTTPHeaderField: "if-match")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: updated)
        let (_, result) = try await transport.data(for: request)
        guard let committed = result as? HTTPURLResponse, committed.statusCode == 200 else {
            throw ClassControlCommand.Failure(message: "명령이 반영되지 않았습니다. 앱에서 현재 수업을 확인해 주세요.")
        }
    }
}

@available(iOS 16.0, *)
enum ClassControlAction: String, AppEnum {
    case pause, resume, nextSlide, previousSlide
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "수업 조작"
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .pause: "수업 일시정지", .resume: "수업 재개", .nextSlide: "다음 슬라이드", .previousSlide: "이전 슬라이드"
    ]
}

@available(iOS 16.0, *)
struct ControlClassIntent: AppIntent {
    static var title: LocalizedStringResource = "연결 수업 조작"
    static var description = IntentDescription("클라우드보드의 현재 연결 수업을 조작합니다. 음악 재생에는 영향을 주지 않습니다.")
    static var openAppWhenRun: Bool = false
    @Parameter(title: "동작") var action: ClassControlAction
    static var parameterSummary: some ParameterSummary { Summary("\(\.$action)") }
    init() {}
    init(_ action: ClassControlAction) { self.action = action }
    func perform() async throws -> some IntentResult {
        do { try await ClassControlsService.shared.execute(action.rawValue) }
        catch let error as ClassControlCommand.Failure { throw error }
        catch { throw ClassControlCommand.Failure(message: "명령 결과를 확인하지 못했습니다. 앱에서 연결과 수업 상태를 확인해 주세요.") }
        return .result()
    }
}

@available(iOS 16.0, *)
struct ClassControlShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: ControlClassIntent(.pause), phrases: ["\(.applicationName) 수업 일시정지"], shortTitle: "수업 일시정지", systemImageName: "pause.fill")
        AppShortcut(intent: ControlClassIntent(.resume), phrases: ["\(.applicationName) 수업 재개"], shortTitle: "수업 재개", systemImageName: "play.fill")
        AppShortcut(intent: ControlClassIntent(.nextSlide), phrases: ["\(.applicationName) 다음 슬라이드"], shortTitle: "다음 슬라이드", systemImageName: "forward.end.fill")
        AppShortcut(intent: ControlClassIntent(.previousSlide), phrases: ["\(.applicationName) 이전 슬라이드"], shortTitle: "이전 슬라이드", systemImageName: "backward.end.fill")
    }
}
