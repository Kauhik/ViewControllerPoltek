// File: SummaryViewController.swift

/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The summary view shows a list of the actions paired with the aggregate times.
*/

import UIKit

class SummaryViewController: UIViewController {
    @IBOutlet weak var tableView: UITableView!

    private var sortedActions = [String]()
    var actionFrameCounts: [String: Int]? {
        didSet {
            guard let counts = actionFrameCounts else { return }
            sortedActions = counts.sorted { $0.value > $1.value }
                                   .map { $0.key }
        }
    }

    var dismissalClosure: (() -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        view?.overrideUserInterfaceStyle = .dark
        tableView.dataSource = self
        tableView.reloadData()
    }

    override func viewDidDisappear(_ animated: Bool) {
        dismissalClosure?()
        super.viewDidDisappear(animated)
    }
}

extension SummaryViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView,
                   numberOfRowsInSection section: Int) -> Int {
        sortedActions.count
    }

    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let cell = tableView.dequeueReusableCell(
            withIdentifier: "SummaryCellPrototype",
            for: indexPath)

        guard let summaryCell = cell as? SummaryTableViewCell else {
            fatalError("Not a SummaryTableViewCell")
        }

        if let counts = actionFrameCounts {
            let action = sortedActions[indexPath.row]
            let frames = counts[action] ?? 0
            let duration = Double(frames) / PoltekActionClassifierORGINAL.frameRate
            summaryCell.actionLabel.text = action
            summaryCell.timeLabel.text = String(format: "%0.1fs", duration)
        }

        return summaryCell
    }
}

class SummaryTableViewCell: UITableViewCell {
    @IBOutlet weak var actionLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!
}
