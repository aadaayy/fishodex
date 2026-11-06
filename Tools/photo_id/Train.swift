// Trains FishoDex's photo ID model with Create ML, then tests it on the
// photos held back from training. Runs on a GitHub Actions Mac.
//
//   swiftc -O Tools/photo_id/Train.swift -o train
//   ./train <train folder> <test folder> <output folder>
//
// Each folder has one subfolder per fish (named by its dex id) full of photos.
// The model uses Apple's built-in scene print feature extractor, which ships
// with iOS, so the model file itself is small. Output:
//   FishID.mlmodel     the model
//   evaluation.json    top-1 and top-3 results per fish, for each way of fitting the photo
//   predictions.json   the top guesses for every test photo
import CoreML
import CreateML
import Foundation
import Vision

let arguments = CommandLine.arguments
guard arguments.count >= 4 else {
    print("usage: train <train folder> <test folder> <output folder> [iterations]")
    exit(2)
}
let trainURL = URL(fileURLWithPath: arguments[1], isDirectory: true)
let testURL = URL(fileURLWithPath: arguments[2], isDirectory: true)
let outURL = URL(fileURLWithPath: arguments[3], isDirectory: true)
let iterations = arguments.count > 4 ? Int(arguments[4]) ?? 120 : 120
try FileManager.default.createDirectory(at: outURL, withIntermediateDirectories: true)

func log(_ text: String) {
    print(text)
    fflush(stdout)
}

let started = Date()
log("Training with \(iterations) iterations")
let parameters = MLImageClassifier.ModelParameters(
    validation: .split(strategy: .automatic),
    maxIterations: iterations,
    augmentation: [.flip, .crop],
    algorithm: .transferLearning(featureExtractor: .scenePrint(revision: 2), classifier: .logisticRegressor)
)
let classifier = try MLImageClassifier(trainingData: .labeledDirectories(at: trainURL), parameters: parameters)
log(String(format: "Trained in %.0f s. Training error %.3f, validation error %.3f",
           Date().timeIntervalSince(started),
           classifier.trainingMetrics.classificationError,
           classifier.validationMetrics.classificationError))

let metadata = MLModelMetadata(
    author: "FishoDex",
    shortDescription: "Names South Florida fish from a photo, for FishoDex's dex. Label 'other' means a fish that isn't in the dex.",
    license: "Trained on openly licensed photos (CC0, public domain, CC BY, CC BY-SA); see Tools/photo_id/CREDITS.md in the FishoDex repository.",
    version: "1"
)
let modelURL = outURL.appendingPathComponent("FishID.mlmodel")
try? FileManager.default.removeItem(at: modelURL)
try classifier.write(to: modelURL, metadata: metadata)
log("Wrote \(modelURL.path)")

// Test with Vision, the same way the app will, so the numbers match the phone.
let compiled = try MLModel.compileModel(at: modelURL)
let model = try VNCoreMLModel(for: MLModel(contentsOf: compiled, configuration: MLModelConfiguration()))

struct Guess: Codable { var id: String; var confidence: Double }
struct Prediction: Codable { var file: String; var truth: String; var fit: String; var guesses: [Guess] }
struct ClassResult: Codable { var count: Int; var top1: Int; var top3: Int }
struct FitResult: Codable {
    var fit: String
    var count: Int
    var top1: Double
    var top3: Double
    /// Of the photos where the first guess was at least this sure, how many were right.
    var sureAt: [String: [String: Double]]
    var perClass: [String: ClassResult]
}

let fm = FileManager.default
var tests: [(URL, String)] = []
for folder in (try fm.contentsOfDirectory(at: testURL, includingPropertiesForKeys: nil)).sorted(by: { $0.path < $1.path }) {
    let label = folder.lastPathComponent
    guard (try? folder.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { continue }
    for file in (try fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)).sorted(by: { $0.path < $1.path })
    where ["jpg", "jpeg", "png"].contains(file.pathExtension.lowercased()) {
        tests.append((file, label))
    }
}
log("Testing on \(tests.count) held-back photos")

let fits: [(String, VNImageCropAndScaleOption)] = [("centerCrop", .centerCrop), ("scaleFit", .scaleFit), ("scaleFill", .scaleFill)]
var results: [FitResult] = []
var allPredictions: [Prediction] = []
for (name, option) in fits {
    var perClass: [String: ClassResult] = [:]
    var top1 = 0, top3 = 0
    var sure: [Double: (Int, Int)] = [0.3: (0, 0), 0.5: (0, 0), 0.7: (0, 0), 0.85: (0, 0)]
    for (file, truth) in tests {
        let request = VNCoreMLRequest(model: model)
        request.imageCropAndScaleOption = option
        let handler = VNImageRequestHandler(url: file, options: [:])
        try? handler.perform([request])
        let observations = (request.results as? [VNClassificationObservation]) ?? []
        let guesses = observations.prefix(5).map { Guess(id: $0.identifier, confidence: Double($0.confidence)) }
        var r = perClass[truth] ?? ClassResult(count: 0, top1: 0, top3: 0)
        r.count += 1
        if guesses.first?.id == truth { r.top1 += 1; top1 += 1 }
        if guesses.prefix(3).contains(where: { $0.id == truth }) { r.top3 += 1; top3 += 1 }
        perClass[truth] = r
        if let first = guesses.first {
            for level in sure.keys where first.confidence >= level {
                sure[level]!.0 += 1
                if first.id == truth { sure[level]!.1 += 1 }
            }
        }
        allPredictions.append(Prediction(file: file.lastPathComponent, truth: truth, fit: name, guesses: Array(guesses)))
    }
    let n = max(tests.count, 1)
    var sureAt: [String: [String: Double]] = [:]
    for (level, counts) in sure {
        sureAt[String(format: "%.2f", level)] = [
            "share": Double(counts.0) / Double(n),
            "right": counts.0 == 0 ? 0 : Double(counts.1) / Double(counts.0),
        ]
    }
    let result = FitResult(fit: name, count: tests.count, top1: Double(top1) / Double(n), top3: Double(top3) / Double(n),
                           sureAt: sureAt, perClass: perClass)
    log(String(format: "%@: top-1 %.1f%%, top-3 %.1f%%", name, result.top1 * 100, result.top3 * 100))
    results.append(result)
}

let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
struct Evaluation: Codable {
    var trainingError: Double
    var validationError: Double
    var iterations: Int
    var seconds: Double
    var fits: [FitResult]
}
let evaluation = Evaluation(trainingError: classifier.trainingMetrics.classificationError,
                            validationError: classifier.validationMetrics.classificationError,
                            iterations: iterations, seconds: Date().timeIntervalSince(started), fits: results)
try encoder.encode(evaluation).write(to: outURL.appendingPathComponent("evaluation.json"))
try encoder.encode(allPredictions).write(to: outURL.appendingPathComponent("predictions.json"))
log("Done in \(Int(Date().timeIntervalSince(started))) s")
