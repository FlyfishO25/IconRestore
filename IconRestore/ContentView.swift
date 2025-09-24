//
//  ContentView.swift
//  IconRestore
//
//  Created by Mark Zhou on 2025/9/23.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct AppRowView: View {
    let app: AppInfo
    let onRestore: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // 应用图标
            if let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 48, height: 48)
                    .cornerRadius(8)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: "app")
                            .foregroundColor(.secondary)
                    )
            }
            
            // 应用信息
            VStack(alignment: .leading, spacing: 4) {
                Text(app.name)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(app.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                if let version = app.version {
                    Text("版本: \(version)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // 恢复按钮
            Button(action: onRestore) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.counterclockwise")
                    Text("恢复")
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            
            // 删除按钮
            Button(action: onDelete) {
                HStack(spacing: 4) {
                    Image(systemName: "trash")
                    Text("删除")
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
    }
}

struct ContentView: View {
    @State private var selectedApps: [AppInfo] = []
    @State private var isScanning = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var progress = 0.0
    @State private var currentOperation = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            // Main Content
            ZStack {
                if selectedApps.isEmpty && !isScanning {
                    emptyStateView
                } else {
                    appListView
                }
                
                if isScanning {
                    scanningOverlay
                }
            }
            
            // Bottom Controls
            bottomControlsView
        }
        .frame(minWidth: 600, minHeight: 500)
        .background(Color(NSColor.windowBackgroundColor))
        .alert("提示", isPresented: $showAlert) {
            Button("确定") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "app.badge.checkmark")
                    .font(.system(size: 32))
                    .foregroundColor(.accentColor)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("图标恢复器")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("恢复 macOS 应用程序的原始图标")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            if isScanning {
                ProgressView(value: progress, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle())
                    .padding(.horizontal, 20)
                
                Text(currentOperation)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
            }
            
            Divider()
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("选择需要恢复图标的应用")
                    .font(.headline)
                
                Text("点击下方按钮扫描应用程序文件夹")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var appListView: some View {
        List(selectedApps, id: \.path) {
            app in
                AppRowView(app: app) {
                    restoreAppIcon(app)
                } onDelete: {
                    if let index = selectedApps.firstIndex(where: { $0.path == app.path }) {
                        selectedApps.remove(at: index)
                    }
                }
        }
        .listStyle(PlainListStyle())
    }
    
    private var scanningOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                
                Text("正在扫描应用程序...")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            .padding(30)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
            .shadow(radius: 10)
        }
    }
    
    private var bottomControlsView: some View {
        HStack(spacing: 12) {
            Button(action: scanApplications) {
                HStack {
                    Image(systemName: "magnifyingglass")
                    Text("扫描应用")
                }
            }
            .buttonStyle(.bordered)
            .disabled(isScanning)
            
            Button(action: selectApplications) {
                HStack {
                    Image(systemName: "folder")
                    Text("选择应用")
                }
            }
            .buttonStyle(.bordered)
            .disabled(isScanning)
            
            Spacer()
            
            Button(action: restoreAllIcons) {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("恢复全部")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedApps.isEmpty || isScanning)
            
            Button(action: clearSelection) {
                HStack {
                    Image(systemName: "trash")
                    Text("清空")
                }
            }
            .buttonStyle(.bordered)
            .disabled(selectedApps.isEmpty || isScanning)
        }
        .padding(20)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - Actions
    
    private func scanApplications() {
        isScanning = true
        progress = 0.0
        currentOperation = "开始扫描..."
        
        DispatchQueue.global(qos: .userInitiated).async {
            let appsFolderURL = URL(fileURLWithPath: "/Applications")
            var foundApps: [AppInfo] = []
            
            do {
                let contents = try FileManager.default.contentsOfDirectory(at: appsFolderURL, includingPropertiesForKeys: [.isDirectoryKey, .localizedNameKey], options: [.skipsHiddenFiles])
                
                let apps = contents.filter { $0.pathExtension == "app" }
                let totalApps = apps.count
                
                for (index, appURL) in apps.enumerated() {
                    DispatchQueue.main.async {
                        self.progress = Double(index) / Double(totalApps)
                        self.currentOperation = "正在处理: \(appURL.lastPathComponent)"
                    }
                    
                    if let appInfo = AppInfo.from(url: appURL) {
                        foundApps.append(appInfo)
                    }
                    
                    // 添加小延迟以显示进度
                    usleep(10000) // 0.01秒
                }
                
                DispatchQueue.main.async {
                    self.selectedApps = foundApps
                    self.isScanning = false
                    self.progress = 1.0
                    self.currentOperation = "扫描完成！"
                    
                    // 延迟清除进度信息
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        self.currentOperation = ""
                        self.progress = 0
                    }
                }
                
            } catch {
                DispatchQueue.main.async {
                    self.isScanning = false
                    self.alertMessage = "扫描失败: \(error.localizedDescription)"
                    self.showAlert = true
                }
            }
        }
    }
    
    private func selectApplications() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [UTType.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        
        panel.begin { response in
            if response == .OK {
                let newApps = panel.urls.compactMap { AppInfo.from(url: $0) }
                selectedApps.append(contentsOf: newApps)
                selectedApps = Array(Set(selectedApps)) // 去重
            }
        }
    }
    
    private func restoreAppIcon(_ app: AppInfo) {
        do {
            try IconRestorer.restoreIcon(for: app)
            IconRestorer.refreshIcon()
            alertMessage = "成功恢复 \(app.name) 的图标"
            showAlert = true
        } catch {
            alertMessage = "恢复 \(app.name) 图标失败: \(error.localizedDescription)"
            showAlert = true
        }
    }
    
    private func restoreAllIcons() {
        isScanning = true
        progress = 0.0
        currentOperation = "正在恢复应用图标..."
        
        DispatchQueue.global(qos: .userInitiated).async {
            var successCount = 0
            var failureCount = 0
            let totalApps = selectedApps.count
            
            for (index, app) in selectedApps.enumerated() {
                DispatchQueue.main.async {
                    self.progress = Double(index) / Double(totalApps)
                    self.currentOperation = "正在恢复: \(app.name)"
                }
                
                do {
                    try IconRestorer.restoreIcon(for: app)
                    successCount += 1
                } catch {
                    failureCount += 1
                }
                
                usleep(10000) // 小延迟用于显示进度
            }
            
            DispatchQueue.main.async {
                IconRestorer.refreshIcon()
                self.isScanning = false
                self.progress = 1.0
                self.alertMessage = "恢复完成！成功: \(successCount)，失败: \(failureCount)"
                self.showAlert = true
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self.currentOperation = ""
                    self.progress = 0
                }
            }
        }
    }
    
    private func clearSelection() {
        selectedApps.removeAll()
    }
}

#Preview {
    ContentView()
}
