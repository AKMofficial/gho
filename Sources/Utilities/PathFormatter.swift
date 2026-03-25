import Foundation

extension URL {
    var abbreviatedPath: String {
        let homePath = FileManager.default.homeDirectoryForCurrentUser.path
        let fullPath = self.path
        if fullPath.hasPrefix(homePath) {
            return "~" + fullPath.dropFirst(homePath.count)
        }
        return fullPath
    }

    var lastPathComponentOrPath: String {
        let component = self.lastPathComponent
        if component.isEmpty || component == "/" {
            return abbreviatedPath
        }
        return component
    }
}
