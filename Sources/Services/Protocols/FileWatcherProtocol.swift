import Foundation

protocol FileWatcherProtocol: AnyObject {
    func watch(directory: URL, callback: @escaping @MainActor () -> Void)
    func stopWatching(directory: URL)
    func stopAll()
}
