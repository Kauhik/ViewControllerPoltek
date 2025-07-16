// File: MainViewController.swift

/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The app's main view controller.
*/

import UIKit
import Vision

@available(iOS 14.0, *)
class MainViewController: UIViewController {
    @IBOutlet var imageView: UIImageView!
    @IBOutlet weak var labelStack: UIStackView!
    @IBOutlet weak var actionLabel: UILabel!
    @IBOutlet weak var confidenceLabel: UILabel!
    @IBOutlet weak var buttonStack: UIStackView!
    @IBOutlet weak var summaryButton: UIButton!
    @IBOutlet weak var cameraButton: UIButton!

    var videoCapture: VideoCapture!
    var videoProcessingChain: VideoProcessingChain!
    var actionFrameCounts = [String: Int]()

    override func viewDidLoad() {
        super.viewDidLoad()
        UIApplication.shared.isIdleTimerDisabled = true

        let views = [labelStack, buttonStack, cameraButton, summaryButton]
        views.forEach { v in
            v?.layer.cornerRadius = 10
            v?.overrideUserInterfaceStyle = .dark
        }

        videoProcessingChain = VideoProcessingChain()
        videoProcessingChain.delegate = self

        videoCapture = VideoCapture()
        videoCapture.delegate = self

        updateUILabelsWithPrediction(.startingPrediction)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        videoCapture.updateDeviceOrientation()
    }

    override func viewWillTransition(to size: CGSize,
                                     with coordinator: UIViewControllerTransitionCoordinator) {
        videoCapture.updateDeviceOrientation()
    }

    @IBAction func onCameraButtonTapped(_: Any) {
        videoCapture.toggleCameraSelection()
    }

    @IBAction func onSummaryButtonTapped() {
        let sb = UIStoryboard(name: "Main", bundle: nil)
        let vc = sb.instantiateViewController(identifier: "SummaryViewController")
        guard let summaryVC = vc as? SummaryViewController else {
            fatalError("Couldn't cast SummaryViewController")
        }
        summaryVC.actionFrameCounts = actionFrameCounts
        summaryVC.dismissalClosure = { self.videoCapture.isEnabled = true }
        present(summaryVC, animated: true)
        videoCapture.isEnabled = false
    }
}

extension MainViewController: VideoCaptureDelegate {
    func videoCapture(_ videoCapture: VideoCapture,
                      didCreate framePublisher: FramePublisher) {
        updateUILabelsWithPrediction(.startingPrediction)
        videoProcessingChain.upstreamFramePublisher = framePublisher
    }
}

extension MainViewController: VideoProcessingChainDelegate {
    func videoProcessingChain(_ chain: VideoProcessingChain,
                              didPredict actionPrediction: ActionPrediction,
                              for frameCount: Int) {
        if actionPrediction.isModelLabel {
            let total = (actionFrameCounts[actionPrediction.label] ?? 0) + frameCount
            actionFrameCounts[actionPrediction.label] = total
        }
        updateUILabelsWithPrediction(actionPrediction)
    }

    func videoProcessingChain(_ chain: VideoProcessingChain,
                              didDetect poses: [Pose]?,
                              in frame: CGImage) {
        DispatchQueue.global(qos: .userInteractive).async {
            self.drawPoses(poses, onto: frame)
        }
    }
}

extension MainViewController {
    private func updateUILabelsWithPrediction(_ p: ActionPrediction) {
        DispatchQueue.main.async { self.actionLabel.text = p.label }
        let conf = p.confidenceString ?? "Observing..."
        DispatchQueue.main.async { self.confidenceLabel.text = conf }
    }

    private func drawPoses(_ poses: [Pose]?, onto frame: CGImage) {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let size = CGSize(width: frame.width, height: frame.height)
        let renderer = UIGraphicsImageRenderer(size: size, format: format)

        let img = renderer.image { ctx in
            let cg = ctx.cgContext
            let inv = cg.ctm.inverted()
            cg.concatenate(inv)
            cg.draw(frame, in: CGRect(origin: .zero, size: size))
            let transform = CGAffineTransform(scaleX: size.width,
                                              y: size.height)
            poses?.forEach { $0.drawWireframeToContext(cg, applying: transform) }
        }

        DispatchQueue.main.async { self.imageView.image = img }
    }
}
