import AppKit
import UniformTypeIdentifiers

protocol LibraryPicking {
    func chooseLibrary(prompt: String, message: String?, completion: @escaping (URL?) -> Void)
}

protocol StorageLocationPicking {
    func chooseStorageLocation(prompt: String, completion: @escaping (URL?) -> Void)
}

final class AppPanelService: LibraryPicking, StorageLocationPicking {
    func chooseLibrary(prompt: String, message: String?, completion: @escaping (URL?) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.folder, .zip]
        panel.prompt = prompt
        panel.message = message ?? ""
        panel.begin { response in
            completion(response == .OK ? panel.url : nil)
        }
    }

    func chooseStorageLocation(prompt: String, completion: @escaping (URL?) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = prompt
        panel.begin { response in
            completion(response == .OK ? panel.url : nil)
        }
    }
}
