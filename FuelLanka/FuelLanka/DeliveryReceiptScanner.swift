import SwiftUI
import Vision
import VisionKit

struct DeliveryReceiptScanResult: Equatable, Sendable {
    let reference: String?
    let quantity: String?
    let fuel: FuelGrade?
    let recognizedText: String
}

enum DeliveryReceiptTextParser {
    static func parse(_ text: String) -> DeliveryReceiptScanResult {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let normalized = text.lowercased()

        return DeliveryReceiptScanResult(
            reference: reference(in: lines),
            quantity: quantity(in: lines),
            fuel: fuel(in: normalized),
            recognizedText: text
        )
    }

    private static func reference(in lines: [String]) -> String? {
        let labels = ["invoice", "receipt", "reference", "ref", "delivery no", "delivery note"]
        for line in lines where labels.contains(where: { line.localizedCaseInsensitiveContains($0) }) {
            let components = line.split(whereSeparator: { $0 == ":" || $0 == "#" })
            if let candidate = components.dropFirst().first?.trimmingCharacters(in: .whitespacesAndNewlines),
               !candidate.isEmpty {
                return String(candidate.prefix(60))
            }
        }
        return nil
    }

    private static func quantity(in lines: [String]) -> String? {
        let pattern = #"([0-9]{1,3}(?:[, ][0-9]{3})*(?:[.][0-9]{1,3})?|[0-9]+(?:[.][0-9]{1,3})?)\s*(?:l|ltr|litre|litres|liter|liters)\b"#
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        for line in lines {
            let range = NSRange(line.startIndex..., in: line)
            guard let match = expression.firstMatch(in: line, range: range),
                  let valueRange = Range(match.range(at: 1), in: line) else { continue }
            let value = line[valueRange].replacingOccurrences(of: ",", with: "")
                .replacingOccurrences(of: " ", with: "")
            if let litres = Double(value), litres.isFinite, litres > 0 {
                return value
            }
        }
        return nil
    }

    private static func fuel(in text: String) -> FuelGrade? {
        if text.contains("super diesel") || text.contains("euro 4 diesel") { return .superDiesel }
        if text.contains("petrol 95") || text.contains("octane 95") || text.contains("xp95") { return .petrol95 }
        if text.contains("petrol 92") || text.contains("octane 92") { return .petrol92 }
        if text.contains("diesel") { return .diesel }
        return nil
    }
}

struct DeliveryReceiptScanner: UIViewControllerRepresentable {
    let onResult: (DeliveryReceiptScanResult) -> Void
    let onCancel: () -> Void
    let onFailure: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onResult: onResult, onCancel: onCancel, onFailure: onFailure)
    }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        private let onResult: (DeliveryReceiptScanResult) -> Void
        private let onCancel: () -> Void
        private let onFailure: (String) -> Void

        init(
            onResult: @escaping (DeliveryReceiptScanResult) -> Void,
            onCancel: @escaping () -> Void,
            onFailure: @escaping (String) -> Void
        ) {
            self.onResult = onResult
            self.onCancel = onCancel
            self.onFailure = onFailure
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true, completion: onCancel)
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: any Error
        ) {
            controller.dismiss(animated: true) {
                self.onFailure(error.localizedDescription)
            }
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            let images = (0..<scan.pageCount).map(scan.imageOfPage(at:))
            controller.dismiss(animated: true) {
                Task {
                    do {
                        let text = try await Self.recognizeText(in: images)
                        await MainActor.run { self.onResult(DeliveryReceiptTextParser.parse(text)) }
                    } catch {
                        await MainActor.run { self.onFailure(error.localizedDescription) }
                    }
                }
            }
        }

        private static func recognizeText(in images: [UIImage]) async throws -> String {
            try await Task.detached(priority: .userInitiated) {
                var lines: [String] = []
                for image in images {
                    guard let cgImage = image.cgImage else { continue }
                    let request = VNRecognizeTextRequest()
                    request.recognitionLevel = .accurate
                    request.usesLanguageCorrection = true
                    request.recognitionLanguages = ["en-US"]
                    try VNImageRequestHandler(cgImage: cgImage).perform([request])
                    lines.append(contentsOf: (request.results ?? []).compactMap {
                        $0.topCandidates(1).first?.string
                    })
                }
                return lines.joined(separator: "\n")
            }.value
        }
    }
}
