//
//  ToastController.swift
//  RClick
//
//  轻量 toast 提示：屏幕底部居中的非激活浮动条，短暂显示后自动消失。
//  用于替代模态弹窗做非阻断式引导（如"按住 ⌘ 再点击直接删除"）。
//

import AppKit

@MainActor
final class ToastController {
    static let shared = ToastController()

    private var panel: NSPanel?
    private var hideTask: Task<Void, Never>?

    func show(_ message: String) {
        let panel = ensurePanel()
        updateContent(of: panel, message: message)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            panel.animator().alphaValue = 1
        }
        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard !Task.isCancelled else { return }
            self?.dismiss(panel)
        }
    }

    private func dismiss(_ panel: NSPanel) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
        })
    }

    private func ensurePanel() -> NSPanel {
        if let panel {
            return panel
        }
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.ignoresMouseEvents = true // 纯提示，不拦截任何点击
        self.panel = panel
        return panel
    }

    private func updateContent(of panel: NSPanel, message: String) {
        let text = NSTextField(labelWithString: message)
        text.font = .systemFont(ofSize: 15, weight: .semibold)
        // HUD 深色材质上固定用白字，明暗模式下都醒目
        text.textColor = .white
        text.translatesAutoresizingMaskIntoConstraints = false

        let effect = NSVisualEffectView()
        // 系统 HUD 材质：深色高对比，无论系统明暗模式都够醒目
        effect.material = .hudWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 14
        effect.layer?.masksToBounds = true
        effect.translatesAutoresizingMaskIntoConstraints = false
        effect.addSubview(text)
        panel.contentView = effect

        NSLayoutConstraint.activate([
            text.topAnchor.constraint(equalTo: effect.topAnchor, constant: 12),
            text.bottomAnchor.constraint(equalTo: effect.bottomAnchor, constant: -12),
            text.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 22),
            text.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -22),
        ])

        // 尺寸随文字自适应，位置：主屏正中
        let size = effect.fittingSize
        panel.setContentSize(size)
        if let screen = NSScreen.main {
            let x = screen.frame.midX - size.width / 2
            let y = screen.frame.midY - size.height / 2
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }
    }
}
