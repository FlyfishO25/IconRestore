import SwiftUI


@main
struct IconRestorerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(DefaultWindowStyle())
        .windowResizability(.contentSize)
    }
}

// MARK: - Models

struct AppInfo: Hashable {
    let name: String
    let path: String
    let version: String?
    let icon: NSImage?
    let bundleIdentifier: String?
    
    static func from(url: URL) -> AppInfo? {
        guard url.pathExtension == "app" else { return nil }
        
        let name = url.deletingPathExtension().lastPathComponent
        let path = url.path
        
        // 读取 Info.plist
        let infoPlistURL = url.appendingPathComponent("Contents/Info.plist")
        var version: String?
        var bundleIdentifier: String?
        
        if let plistData = try? Data(contentsOf: infoPlistURL),
           let plist = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any] {
            version = plist["CFBundleShortVersionString"] as? String
            bundleIdentifier = plist["CFBundleIdentifier"] as? String
        }
        
        // 获取应用图标
        let icon = NSWorkspace.shared.icon(forFile: path)
        
        return AppInfo(
            name: name,
            path: path,
            version: version,
            icon: icon,
            bundleIdentifier: bundleIdentifier
        )
    }
}

// MARK: - Icon Restorer

enum IconRestorer {
    enum RestoreError: Error, LocalizedError {
        case bundleNotFound
        case infoPlistNotFound
        case iconFileNotFound
        case restoreOperationFailed
        
        var errorDescription: String? {
            switch self {
            case .bundleNotFound:
                return NSLocalizedString("找不到应用程序包", comment: "找不到应用程序包")
            case .infoPlistNotFound:
                return NSLocalizedString("找不到 Info.plist 文件", comment: "找不到 Info.plist 文件")
            case .iconFileNotFound:
                return NSLocalizedString("找不到图标文件", comment: "找不到图标文件")
            case .restoreOperationFailed:
                return NSLocalizedString("恢复操作失败", comment: "恢复操作失败")
            }
        }
    }
    
    static func restoreIcon(for app: AppInfo) throws {
        let appURL = URL(fileURLWithPath: app.path)
        let contentsURL = appURL.appendingPathComponent("Contents")
        let resourcesURL = contentsURL.appendingPathComponent("Resources")
        let infoPlistURL = contentsURL.appendingPathComponent("Info.plist")
        
        // 检查路径是否存在
        guard FileManager.default.fileExists(atPath: contentsURL.path) else {
            throw RestoreError.bundleNotFound
        }
        
        guard FileManager.default.fileExists(atPath: infoPlistURL.path) else {
            throw RestoreError.infoPlistNotFound
        }
        
        // 读取 Info.plist 获取图标文件名
        guard let plistData = try? Data(contentsOf: infoPlistURL),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any],
              let iconFileName = plist["CFBundleIconFile"] as? String else {
            throw RestoreError.infoPlistNotFound
        }
        
        // 构建图标文件路径
        let iconName = iconFileName.hasSuffix(".icns") ? iconFileName : "\(iconFileName).icns"
        let iconURL = resourcesURL.appendingPathComponent(iconName)
        
        guard FileManager.default.fileExists(atPath: iconURL.path) else {
            throw RestoreError.iconFileNotFound
        }
        
        // 执行图标恢复操作
        // 使用 shell 脚本替代 AppleScript 来执行图标替换操作
        let tempIconPath = "/tmp/tempIcon.icns"
        let tempRsrcPath = "/tmp/tempIcon.rsrc"
        let appPath = app.path.replacingOccurrences(of: " ", with: "\\ ")
        let iconPath = iconURL.path.replacingOccurrences(of: " ", with: "\\ ")
        
        let shellScript = """
        cp \(iconPath) \(tempIconPath);
        sips -i \(tempIconPath);
        DeRez -only icns \(tempIconPath) > \(tempRsrcPath);
        [ -f \(appPath)/Icon? ] && rm \(appPath)/Icon?
        SetFile -a C \(appPath);
        touch \(appPath)/$\'Icon\\r\'
        Rez -append \(tempRsrcPath) -o \(appPath)/Icon?
        SetFile -a V \(appPath)/Icon?
        rm \(tempIconPath) \(tempRsrcPath);
        """
        
        //print(shellScript)
        
        let process = Process()
        process.launchPath = "/bin/sh"
        process.arguments = ["-c", shellScript]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        process.launch()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            //let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
            //let resultInformation = String(data: outputData, encoding: .utf8)
            //print(resultInformation)
            throw RestoreError.restoreOperationFailed
        }
    }
    
    static func refreshIcon() {
        let refreshScript =
        """
        tell application "Finder" to quit
        delay 2
        tell application "Finder" to activate
        delay 1
        do shell script "killall Finder"
        """
        
        if let refreshScriptObject = NSAppleScript(source: refreshScript) {
            refreshScriptObject.executeAndReturnError(nil)
        }
    }
}
