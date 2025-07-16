// File: VideoCapture.swift

/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Convenience class that configures the video capture session and
 creates a (video) frame publisher.
*/

import UIKit
import Combine
import AVFoundation

/// - Tag: Frame
typealias Frame = CMSampleBuffer
typealias FramePublisher = AnyPublisher<Frame, Never>

protocol VideoCaptureDelegate: AnyObject {
    /// Informs the delegate when the Video Capture creates a new publisher.
    /// - Parameters:
    ///   - framePublisher: The new frame publisher.
    func videoCapture(_ videoCapture: VideoCapture,
                      didCreate framePublisher: FramePublisher)
}

/// Creates and maintains a capture session that publishes video frames.
class VideoCapture: NSObject {
    weak var delegate: VideoCaptureDelegate! {
        didSet { createVideoFramePublisher() }
    }

    var isEnabled = true {
        didSet { isEnabled ? enableCaptureSession() : disableCaptureSession() }
    }

    private var cameraPosition = AVCaptureDevice.Position.front {
        didSet { createVideoFramePublisher() }
    }

    private var orientation = AVCaptureVideoOrientation.portrait {
        didSet { createVideoFramePublisher() }
    }

    private let captureSession = AVCaptureSession()
    private var framePublisher: PassthroughSubject<Frame, Never>?
    private let videoCaptureQueue = DispatchQueue(label: "Video Capture Queue",
                                                  qos: .userInitiated)

    private var horizontalFlip: Bool {
        cameraPosition == .front
    }

    private var videoStabilizationEnabled = false

    func toggleCameraSelection() {
        cameraPosition = cameraPosition == .back ? .front : .back
    }

    func updateDeviceOrientation() {
        let currentPhysicalOrientation = UIDevice.current.orientation
        switch currentPhysicalOrientation {
        case .portrait, .faceUp, .faceDown, .unknown:
            orientation = .portrait
        case .portraitUpsideDown:
            orientation = .portraitUpsideDown
        case .landscapeLeft:
            orientation = .landscapeRight
        case .landscapeRight:
            orientation = .landscapeLeft
        @unknown default:
            orientation = .portrait
        }
    }

    private func enableCaptureSession() {
        if !captureSession.isRunning { captureSession.startRunning() }
    }

    private func disableCaptureSession() {
        if captureSession.isRunning { captureSession.stopRunning() }
    }
}

extension VideoCapture: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput frame: Frame,
                       from connection: AVCaptureConnection) {
        framePublisher?.send(frame)
    }
}

extension VideoCapture {
    private func createVideoFramePublisher() {
        guard let videoDataOutput = configureCaptureSession() else { return }

        let passthroughSubject = PassthroughSubject<Frame, Never>()
        framePublisher = passthroughSubject
        videoDataOutput.setSampleBufferDelegate(self, queue: videoCaptureQueue)
        let genericFramePublisher = passthroughSubject.eraseToAnyPublisher()
        delegate.videoCapture(self, didCreate: genericFramePublisher)
    }

    private func configureCaptureSession() -> AVCaptureVideoDataOutput? {
        disableCaptureSession()
        guard isEnabled else { return nil }
        defer { enableCaptureSession() }
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        // Update here to use your new model’s frame rate
        let modelFrameRate = PoltekActionClassifierORGINAL.frameRate

        let input = AVCaptureDeviceInput.createCameraInput(position: cameraPosition,
                                                           frameRate: modelFrameRate)
        let output = AVCaptureVideoDataOutput.withPixelFormatType(kCVPixelFormatType_32BGRA)
        let success = configureCaptureConnection(input, output)
        return success ? output : nil
    }

    private func configureCaptureConnection(_ input: AVCaptureDeviceInput?,
                                            _ output: AVCaptureVideoDataOutput?) -> Bool {

        guard let input = input, let output = output else { return false }

        captureSession.inputs.forEach(captureSession.removeInput)
        captureSession.outputs.forEach(captureSession.removeOutput)

        guard captureSession.canAddInput(input) else {
            print("The camera input isn't compatible with the capture session.")
            return false
        }
        guard captureSession.canAddOutput(output) else {
            print("The video output isn't compatible with the capture session.")
            return false
        }

        captureSession.addInput(input)
        captureSession.addOutput(output)

        guard let connection = captureSession.connections.first,
              captureSession.connections.count == 1 else {
            print("The capture session has unexpected number of connections.")
            return false
        }

        if connection.isVideoOrientationSupported {
            connection.videoOrientation = orientation
        }
        if connection.isVideoMirroringSupported {
            connection.isVideoMirrored = horizontalFlip
        }
        if connection.isVideoStabilizationSupported {
            connection.preferredVideoStabilizationMode = videoStabilizationEnabled
                ? .standard : .off
        }

        output.alwaysDiscardsLateVideoFrames = true
        return true
    }
}
