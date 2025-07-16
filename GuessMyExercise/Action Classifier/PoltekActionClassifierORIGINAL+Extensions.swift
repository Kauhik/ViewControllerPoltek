// File: PoltekActionClassifierORIGINAL+Extensions.swift

/*
 Extensions to wire up your new Core ML model.
*/

import CoreML

// MARK: - Singleton

extension PoltekActionClassifierORGINAL {
    /// Shared instance initialized at launch.
    static let shared: PoltekActionClassifierORGINAL = {
        let config = MLModelConfiguration()
        guard let m = try? PoltekActionClassifierORGINAL(configuration: config) else {
            fatalError("Unable to initialize PoltekActionClassifierORIGINAL")
        }
        m.checkLabels()
        return m
    }()
}

// MARK: - Class Label Enum

extension PoltekActionClassifierORGINAL {
    enum Label: String, CaseIterable {
        case id   = "ID"
        case rest = "Rest"
        case sg   = "SG"

        init(_ raw: String) {
            guard let lbl = Label(rawValue: raw) else {
                fatalError("Add `\(raw)` to PoltekActionClassifierORIGINAL.Label")
            }
            self = lbl
        }
    }
}

// MARK: - Label Check (runtime)

extension PoltekActionClassifierORGINAL {
    /// Ensures model labels match the enum.
    func checkLabels() {
        let desc = model.modelDescription
        guard let classLabels = desc.classLabels as? [String] else {
            fatalError("Model is not a classifier")
        }
        for lbl in classLabels {
            _ = Label(lbl)  // will fatalError if missing
        }
        if Label.allCases.count != classLabels.count {
            print("Warning: label count mismatch")
        }
    }
}

// MARK: - Prediction Convenience

extension PoltekActionClassifierORGINAL {
    /// Run prediction on a concatenated MLMultiArray window.
    func predictActionFromWindow(_ window: MLMultiArray) -> ActionPrediction {
        do {
            let out = try prediction(poses: window)
            let lbl = Label(out.label)
            let conf = out.labelProbabilities[out.label]!
            return ActionPrediction(label: lbl.rawValue, confidence: conf)
        } catch {
            fatalError("Prediction error: \(error)")
        }
    }
}

// MARK: - Frame Rate & Window Size

extension PoltekActionClassifierORGINAL {
    /// Matches the model’s training frame rate.
    static let frameRate: Double = 120.0

    /// Reads the model’s window size from its input description.
    func calculatePredictionWindowSize() -> Int {
        let inputs = model.modelDescription.inputDescriptionsByName
        guard inputs.count == 1,
              let desc = inputs.first?.value,
              desc.type == .multiArray,
              let constraint = desc.multiArrayConstraint
        else {
            fatalError("Unexpected model input format")
        }
        let dims = constraint.shape
        guard dims.count == 3 else {
            fatalError("Expected 3D multiarray input")
        }
        let windowSize = Int(truncating: dims[0])
        let span = Double(windowSize) / Self.frameRate
        print("Window: \(windowSize) frames (~\(span)s at \(Self.frameRate)fps)")
        return windowSize
    }
}
