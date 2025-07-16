// File: VideoProcessingChain.swift

/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Builds a chain of Combine publisher-subscribers upon the video capture
 session's video frame publisher.
*/

import Vision
import Combine
import CoreImage

protocol VideoProcessingChainDelegate: AnyObject {
    func videoProcessingChain(_ chain: VideoProcessingChain,
                              didDetect poses: [Pose]?,
                              in frame: CGImage)
    func videoProcessingChain(_ chain: VideoProcessingChain,
                              didPredict actionPrediction: ActionPrediction,
                              for frames: Int)
}

struct VideoProcessingChain {
    weak var delegate: VideoProcessingChainDelegate?

    var upstreamFramePublisher: AnyPublisher<Frame, Never>! {
        didSet { buildProcessingChain() }
    }

    private var frameProcessingChain: AnyCancellable?

    private let humanBodyPoseRequest = VNDetectHumanBodyPoseRequest()
    private let actionClassifier = PoltekActionClassifierORGINAL.shared
    private let predictionWindowSize: Int
    private let windowStride = 10
    private var performanceReporter = PerformanceReporter()

    init() {
        predictionWindowSize = actionClassifier.calculatePredictionWindowSize()
    }
}

extension VideoProcessingChain {
    private mutating func buildProcessingChain() {
        guard upstreamFramePublisher != nil else { return }

        frameProcessingChain = upstreamFramePublisher
            .compactMap(imageFromFrame)
            .map(findPosesInFrame)
            .map(isolateLargestPose)
            .map(multiArrayFromPose)
            .scan([MLMultiArray?](), gatherWindow)
            .filter(gateWindow)
            .map(predictActionWithWindow)
            .sink(receiveValue: sendPrediction)
    }
}

extension VideoProcessingChain {
    private func imageFromFrame(_ buffer: Frame) -> CGImage? {
        performanceReporter?.incrementFrameCount()
        guard let imageBuffer = buffer.imageBuffer else { return nil }
        let ciContext = CIContext(options: nil)
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        return ciContext.createCGImage(ciImage, from: ciImage.extent)
    }

    private func findPosesInFrame(_ frame: CGImage) -> [Pose]? {
        let handler = VNImageRequestHandler(cgImage: frame)
        do { try handler.perform([humanBodyPoseRequest]) }
        catch { assertionFailure("Pose request failed: \(error)") }
        let poses = Pose.fromObservations(humanBodyPoseRequest.results)
        DispatchQueue.main.async {
            self.delegate?.videoProcessingChain(self,
                                                didDetect: poses,
                                                in: frame)
        }
        return poses
    }

    private func isolateLargestPose(_ poses: [Pose]?) -> Pose? {
        poses?.max(by: { $0.area < $1.area })
    }

    private func multiArrayFromPose(_ item: Pose?) -> MLMultiArray? {
        item?.multiArray
    }

    private func gatherWindow(previousWindow: [MLMultiArray?],
                              multiArray: MLMultiArray?) -> [MLMultiArray?] {
        var window = previousWindow
        if window.count == predictionWindowSize {
            window.removeFirst(windowStride)
        }
        window.append(multiArray)
        return window
    }

    private func gateWindow(_ window: [MLMultiArray?]) -> Bool {
        window.count == predictionWindowSize
    }

    private func predictActionWithWindow(_ window: [MLMultiArray?]) -> ActionPrediction {
        var count = 0
        let filled = window.map { arr -> MLMultiArray in
            if let arr = arr { count += 1; return arr }
            else { return Pose.emptyPoseMultiArray }
        }
        let minSamples = predictionWindowSize * 60 / 100
        guard count >= minSamples else {
            return ActionPrediction.noPersonPrediction
        }
        let merged = MLMultiArray(concatenating: filled, axis: 0, dataType: .float)
        let prediction = actionClassifier.predictActionFromWindow(merged)
        return prediction.confidence < 0.6
            ? ActionPrediction.lowConfidencePrediction
            : prediction
    }

    private func sendPrediction(_ prediction: ActionPrediction) {
        DispatchQueue.main.async {
            self.delegate?.videoProcessingChain(self,
                                                didPredict: prediction,
                                                for: self.windowStride)
        }
        performanceReporter?.incrementPrediction()
    }
}
