import CoreML
import UIKit
import Vision

/// Names the fish in a photo with FishoDex's own model, right on the phone.
/// The photo never leaves the phone and no internet is needed.
actor FishIdentifier {
    static let shared = FishIdentifier()

    enum Failure: Error {
        /// This build has no photo ID model in it.
        case noModel
        /// The photo couldn't be read.
        case badPhoto
    }

    /// How the photo is fitted to the model's square: the middle of the photo,
    /// cropped square. It tested best (Tools/photo_id/REPORT.md).
    static let fit: VNImageCropAndScaleOption = .centerCrop

    private var model: VNCoreMLModel?

    private func loadModel() throws -> VNCoreMLModel {
        if let model { return model }
        guard let url = Bundle.main.url(forResource: "FishID", withExtension: "mlmodelc") else { throw Failure.noModel }
        let configuration = MLModelConfiguration()
        #if targetEnvironment(simulator)
        configuration.computeUnits = .cpuOnly
        #endif
        let loaded = try VNCoreMLModel(for: MLModel(contentsOf: url, configuration: configuration))
        model = loaded
        return loaded
    }

    /// The model's labels with how sure it is of each, most likely first.
    func labels(for image: UIImage) throws -> [(label: String, confidence: Double)] {
        let model = try loadModel()
        guard let cgImage = image.cgImage ?? Self.render(image) else { throw Failure.badPhoto }
        let request = VNCoreMLRequest(model: model)
        request.imageCropAndScaleOption = Self.fit
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: Self.orientation(image.imageOrientation), options: [:])
        try handler.perform([request])
        let observations = (request.results as? [VNClassificationObservation]) ?? []
        return observations.map { (label: $0.identifier, confidence: Double($0.confidence)) }
    }

    private static func render(_ image: UIImage) -> CGImage? {
        UIGraphicsImageRenderer(size: image.size).image { _ in image.draw(at: .zero) }.cgImage
    }

    private static func orientation(_ o: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch o {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}
