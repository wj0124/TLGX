//
//  ShareViewController.swift
//  TLGXShareExtension
//
//  Share Extension entry point. Receives plain text or a URL from any host
//  app's share sheet (Notes, Safari, Messages, …), persists it as a new
//  `Reminder` in the shared App Group store, and dismisses immediately.
//
//  UX goal: zero-friction capture. We don't show a compose form — the
//  shared text becomes the reminder title verbatim. A tiny status banner
//  flashes for ~0.6s so the user gets confirmation before the share sheet
//  closes.
//

import UIKit
import UniformTypeIdentifiers

@objc(ShareViewController)
final class ShareViewController: UIViewController {

    /// Hard cap on imported text length. Long shares (whole articles) would
    /// make a useless reminder title — truncate defensively.
    private static let maxTitleLength = 500

    private let card = UIVisualEffectView(effect: UIBlurEffect(style: .systemThickMaterial))
    private let iconView = UIImageView()
    private let messageLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        setupCard()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Task { await run() }
    }

    // MARK: - Pipeline

    private func run() async {
        let raw = await extractSharedText()
        let trimmed = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            await flash(success: false, message: NSLocalizedString("未识别到可用文字", comment: "Share extension: no text found"))
            await finish(success: false)
            return
        }

        let title = String(trimmed.prefix(Self.maxTitleLength))
        let saved = await MainActor.run { () -> Bool in
            var all = ReminderStore.load()
            // De-dupe against the most recent entry to swallow accidental
            // double-taps on the share sheet.
            if let first = all.first, first.title == title {
                return false
            }
            let new = Reminder(title: title)
            all.insert(new, at: 0)
            ReminderStore.save(all)
            return true
        }

        await flash(success: true,
                    message: saved ? NSLocalizedString("已添加到提了个醒", comment: "Share: saved") : NSLocalizedString("已存在相同提醒", comment: "Share: duplicate"))
        await finish(success: true)
    }

    /// Pull a usable text payload out of the share request, in priority
    /// order: explicit plain text attachment → URL attachment (absolute
    /// string) → the item's `attributedContentText` (Safari selection,
    /// Notes paragraphs, etc.).
    private func extractSharedText() async -> String? {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            return nil
        }

        for item in items {
            if let attachments = item.attachments {
                for provider in attachments {
                    if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
                       let value = try? await provider.loadItem(
                            forTypeIdentifier: UTType.plainText.identifier, options: nil
                       ) {
                        if let s = value as? String { return s }
                        if let d = value as? Data,
                           let s = String(data: d, encoding: .utf8) { return s }
                    }
                    if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
                       let value = try? await provider.loadItem(
                            forTypeIdentifier: UTType.url.identifier, options: nil
                       ),
                       let url = value as? URL {
                        return url.absoluteString
                    }
                }
            }
            if let attr = item.attributedContentText?.string, !attr.isEmpty {
                return attr
            }
        }
        return nil
    }

    // MARK: - UI

    private func setupCard() {
        card.layer.cornerRadius = 18
        card.layer.cornerCurve = .continuous
        card.clipsToBounds = true
        card.translatesAutoresizingMaskIntoConstraints = false
        card.alpha = 0
        card.transform = CGAffineTransform(scaleX: 0.94, y: 0.94)
        view.addSubview(card)

        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(
            pointSize: 20, weight: .semibold
        )

        messageLabel.font = .systemFont(ofSize: 15, weight: .medium)
        messageLabel.textColor = .label
        messageLabel.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [iconView, messageLabel])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            card.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            stack.leadingAnchor.constraint(equalTo: card.contentView.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor, constant: -18),
            stack.topAnchor.constraint(equalTo: card.contentView.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: card.contentView.bottomAnchor, constant: -14),

            iconView.widthAnchor.constraint(equalToConstant: 22),
            iconView.heightAnchor.constraint(equalToConstant: 22),
        ])
    }

    @MainActor
    private func flash(success: Bool, message: String) async {
        iconView.image = UIImage(systemName: success
            ? "checkmark.circle.fill"
            : "exclamationmark.triangle.fill")
        iconView.tintColor = success ? .systemGreen : .systemOrange
        messageLabel.text = message

        UIView.animate(withDuration: 0.22,
                       delay: 0,
                       usingSpringWithDamping: 0.82,
                       initialSpringVelocity: 0.6) {
            self.card.alpha = 1
            self.card.transform = .identity
        }

        try? await Task.sleep(nanoseconds: 650_000_000)
    }

    @MainActor
    private func finish(success: Bool) async {
        UIView.animate(withDuration: 0.18) {
            self.card.alpha = 0
        }
        try? await Task.sleep(nanoseconds: 150_000_000)
        if success {
            extensionContext?.completeRequest(returningItems: nil)
        } else {
            extensionContext?.cancelRequest(withError: NSError(
                domain: "TLGXShareExtension", code: 1
            ))
        }
    }
}
