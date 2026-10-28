//
//  AppLocalization.swift
//  RClick
//
//  Created by Codex on 2026/7/3.
//

import Foundation
import SwiftUI
import os

// `nonisolated` because lookup is thread-safe and the default main-actor isolation
// makes it unreachable from `LocalizedError.errorDescription`, which has to stay
// nonisolated.
nonisolated enum AppLocalization {
    static let tableName = "Localizable"

    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "RClick", category: "l10n")

    /// 查表规则（代码在两个 target 共享，运行时 Bundle.main 指向各自 bundle）：
    /// - key 由哪个进程显示，就加到哪个 target 的 Localizable.xcstrings：
    ///   RClick/Localizable.xcstrings       → 主程序进程（设置页、toast 等）
    ///   FinderSyncExt/Localizable.xcstrings → 扩展进程（右键/工具栏菜单）
    /// key 加错表时表现为"显示英文原文"——此处用日志显式暴露，不再静默。
    private static var hostBundle: Bundle? {
        // 主程序进程里推导结果就是自身；扩展进程里从 appex 路径推出宿主 bundle
        // （RClick.app/Contents/PlugIns/X.appex → RClick.app），作为加错表时的兜底
        let hostURL = Bundle.main.bundleURL
            .deletingLastPathComponent()   // PlugIns/
            .deletingLastPathComponent()   // Contents/
            .deletingLastPathComponent()   // RClick.app
        if let host = Bundle(url: hostURL) {
            return host
        }
        // 路径推导失败时按 id 兜底：扩展 bundle id 比宿主多一段后缀
        let hostID = (Bundle.main.bundleIdentifier ?? "")
            .split(separator: ".")
            .dropLast()
            .joined(separator: ".")
        return hostID.isEmpty ? nil : Bundle(identifier: hostID)
    }

    static func localized(_ key: String) -> String {
        let own = Bundle.main.localizedString(forKey: key, value: nil, table: tableName)
        if own != key {
            return own
        }
        if let host = hostBundle {
            let hostValue = host.localizedString(forKey: key, value: key, table: tableName)
            if hostValue != key {
                return hostValue
            }
        }
        logger.warning("Missing localization: key \(key, privacy: .public) not found in \(Bundle.main.bundlePath, privacy: .public)")
        return key
    }
}

extension Text {
    init(appLocalized key: String) {
        self.init(AppLocalization.localized(key))
    }
}
