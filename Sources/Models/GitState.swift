import Foundation

@Observable
final class GitState {
    var currentBranch: String = ""
    var branches: [String] = []
    var stagedChanges: [GitFileChange] = []
    var unstagedChanges: [GitFileChange] = []
    var untrackedFiles: [String] = []
    var aheadCount: Int = 0
    var behindCount: Int = 0
    var isRefreshing: Bool = false
    var lastRefreshed: Date? = nil

    var stagedCount: Int {
        stagedChanges.count
    }

    var unstagedCount: Int {
        unstagedChanges.count + untrackedFiles.count
    }
}
