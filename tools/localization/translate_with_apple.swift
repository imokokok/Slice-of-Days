import Foundation
import AppKit
import SwiftUI
import Translation

private let placeholderPattern = #"%[-+0-9.]*[sdif]|\{[A-Za-z_][^}]*\}|\[/?[A-Za-z][^\]]*\]"#
private let statusURL = URL(fileURLWithPath: "/tmp/solmere_translation_status.txt")

private func writeStatus(_ message: String) {
    try? (message + "\n").write(to: statusURL, atomically: true, encoding: .utf8)
}

private struct ProtectedText {
    let text: String
    let placeholders: [String: String]
}

private func protectPlaceholders(_ source: String) -> ProtectedText {
    guard let expression = try? NSRegularExpression(pattern: placeholderPattern) else {
        return ProtectedText(text: source, placeholders: [:])
    }
    let range = NSRange(source.startIndex..<source.endIndex, in: source)
    let matches = expression.matches(in: source, range: range)
    var result = source
    var placeholders: [String: String] = [:]
    for (index, match) in matches.enumerated().reversed() {
        guard let swiftRange = Range(match.range, in: result) else { continue }
        let original = String(result[swiftRange])
        let token = "ZXQPH\(index)QXZ"
        placeholders[token] = original
        result.replaceSubrange(swiftRange, with: token)
    }
    return ProtectedText(text: result, placeholders: placeholders)
}

private func restorePlaceholders(_ translated: String, placeholders: [String: String]) -> String? {
    var result = translated
    for (token, original) in placeholders {
        guard result.range(of: token, options: [.caseInsensitive]) != nil else {
            return nil
        }
        result = result.replacingOccurrences(of: token, with: original, options: [.caseInsensitive])
    }
    return result
}

private func loadJSONDictionary<Value>(at url: URL, as: Value.Type) throws -> Value where Value: Decodable {
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode(Value.self, from: data)
}

private func saveCatalog(_ catalog: [String: String], to url: URL) throws {
    let data = try JSONSerialization.data(
        withJSONObject: catalog,
        options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    )
    var output = data
    output.append(0x0A)
    try output.write(to: url, options: .atomic)
}

private struct TranslationJob {
    let root: URL
    let sources: [String: [String]]
    var catalog: [String: String]

    init() throws {
        let argument = CommandLine.arguments.dropFirst().first
        let rootPath = argument ?? FileManager.default.currentDirectoryPath
        root = URL(fileURLWithPath: rootPath, isDirectory: true)
        sources = try loadJSONDictionary(
            at: root.appendingPathComponent("localization/source_strings.json"),
            as: [String: [String]].self
        )
        let catalogURL = root.appendingPathComponent("localization/en.json")
        catalog = (try? loadJSONDictionary(at: catalogURL, as: [String: String].self)) ?? [:]
    }

    var outputURL: URL {
        root.appendingPathComponent("localization/en.json")
    }

    var missing: [String] {
        sources.keys.filter { catalog[$0]?.isEmpty != false }.sorted {
            if $0.count == $1.count { return $0 < $1 }
            return $0.count < $1.count
        }
    }
}

struct TranslationToolView: View {
    @State private var status = "Preparing on-device translation…"
    @State private var configuration = TranslationSession.Configuration(
        source: Locale.Language(identifier: "zh-Hans"),
        target: Locale.Language(identifier: "en")
    )

    var body: some View {
        VStack(spacing: 12) {
            Text("Solmere Localization")
                .font(.headline)
            Text(status)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(width: 460, height: 150)
        .onAppear {
            writeStatus("window visible; waiting for translation session")
            NSApplication.shared.setActivationPolicy(.regular)
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
        .translationTask(configuration) { session in
            do {
                writeStatus("translation session ready; preparing language pack")
                try await session.prepareTranslation()
                writeStatus("language pack ready; loading source catalog")
                var job = try TranslationJob()
                let missing = job.missing
                if missing.isEmpty {
                    status = "English catalog is already complete."
                    print(status)
                    fflush(stdout)
                    try? await Task.sleep(for: .seconds(1))
                    exit(0)
                }

                let batchSize = 64
                var completed = 0
                while completed < missing.count {
                    let upperBound = min(completed + batchSize, missing.count)
                    let batchSources = Array(missing[completed..<upperBound])
                    var protectedByID: [String: ProtectedText] = [:]
                    var sourceByID: [String: String] = [:]
                    var requests: [TranslationSession.Request] = []
                    for (offset, source) in batchSources.enumerated() {
                        let identifier = String(completed + offset)
                        let protected = protectPlaceholders(source)
                        protectedByID[identifier] = protected
                        sourceByID[identifier] = source
                        requests.append(.init(sourceText: protected.text, clientIdentifier: identifier))
                    }

                    let responses = try await session.translations(from: requests)
                    for response in responses {
                        guard
                            let identifier = response.clientIdentifier,
                            let source = sourceByID[identifier],
                            let protected = protectedByID[identifier],
                            let restored = restorePlaceholders(response.targetText, placeholders: protected.placeholders)
                        else { continue }
                        job.catalog[source] = restored
                    }
                    completed = upperBound
                    try saveCatalog(job.catalog, to: job.outputURL)
                    status = "Translated \(completed) of \(missing.count) missing strings"
                    writeStatus(status)
                    print(status)
                    fflush(stdout)
                }

                status = "English catalog complete: \(job.catalog.count) strings"
                writeStatus(status)
                print(status)
                fflush(stdout)
                try? await Task.sleep(for: .seconds(2))
                exit(0)
            } catch {
                status = "Translation failed: \(error.localizedDescription)"
                writeStatus(status)
                fputs("\(status)\n", stderr)
                fflush(stderr)
                exit(1)
            }
        }
    }
}

final class TranslationToolDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        writeStatus("application launched; creating translation window")
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 150),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Solmere Translator"
        window.contentView = NSHostingView(rootView: TranslationToolView())
        window.center()
        window.delegate = self
        window.makeKeyAndOrderFront(nil)
        self.window = window
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        NSApplication.shared.terminate(nil)
    }
}

@main
struct TranslationToolApp {
    @MainActor
    static func main() {
        let application = NSApplication.shared
        let delegate = TranslationToolDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.regular)
        application.run()
        _ = delegate
    }
}
