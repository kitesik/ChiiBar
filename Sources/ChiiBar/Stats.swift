import ChiiCore
import Foundation

enum Stats {
    static func run() {
        guard let state = Store.load(Store.defaultURL) else { print("활동 기록 없음"); return }
        for (day, seconds) in (state.workActivity?.secondsByDay ?? [:]).sorted(by: { $0.key > $1.key }) {
            print("\(day): \(WorkTimeFormat.duration(seconds))")
        }
    }
}
