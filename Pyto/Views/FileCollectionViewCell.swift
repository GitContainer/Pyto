//
//  FileCollectionViewCell.swift
//  Pyto
//
//  Created by Adrian Labbe on 10/12/18.
//  Copyright © 2018 Adrian Labbé. All rights reserved.
//

import UIKit
import SavannaKit
import SourceEditor

/// A cell for displaying a file.
class FileCollectionViewCell: UICollectionViewCell, UIDocumentPickerDelegate, SyntaxTextViewDelegate, UICollectionViewDataSource {
    
    /// The view contaning the filename.
    @IBOutlet weak var titleView: UILabel!
    
    /// The view containing the code's preview.
    @IBOutlet weak var previewContainerView: UIView?
    
    /// A Collection view displaying folder's content.
    @IBOutlet weak var folderContentCollectionView: UICollectionView?
    
    @IBOutlet weak private var noFilesView: UILabel?
    
    /// The Document browser view controller containing this Collection view.
    var documentBrowser: DocumentBrowserViewController?
    
    private var isDirectory: ObjCBool = false
    
    private var directoryContents: (Int, [URL]) {
        guard isDirectory.boolValue, let file = file else {
            return (0, [])
        }
        
        var files = (try? FileManager.default.contentsOfDirectory(at: file, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)) ?? []
        
        var dirs = 0
        
        var i = 0
        for file in files {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: file.path, isDirectory: &isDir) {
                if file.pathExtension.lowercased() != "py" || isDir.boolValue {
                    
                    if isDir.boolValue {
                        dirs += 1
                    }
                    
                    files.remove(at: i)
                } else {
                    i += 1
                }
            } else {
                files.remove(at: i)
            }
        }
        
        return (dirs, files)
    }
    
    /// The URL to represent.
    var file: URL? {
        didSet {
            
            guard file != nil else {
                return
            }
            
            if FileManager.default.fileExists(atPath: file!.path, isDirectory: &isDirectory) {
                if isDirectory.boolValue {
                    noFilesView?.isHidden = !directoryContents.1.isEmpty
                    if directoryContents.0 > 0 {
                        noFilesView?.text = Localizable.Folders.noFilesButDirs(countOfDirs: directoryContents.0)
                    } else {
                        noFilesView?.text = Localizable.Folders.noFiles
                    }
                    folderContentCollectionView?.isHidden = !(noFilesView?.isHidden ?? false)
                    folderContentCollectionView?.dataSource = self
                    folderContentCollectionView?.reloadData()
                    titleView.text = file!.lastPathComponent
                } else if file!.pathExtension.lowercased() == "py", let container = previewContainerView {
                    
                    var textView = SyntaxTextView(frame: container.frame)

                    for view in (previewContainerView?.subviews ?? []) {
                        if let syntaxTextView = view as? SyntaxTextView {
                            textView = syntaxTextView
                        }
                    }
                    
                    textView.delegate = self
                    if let code = try? String(contentsOf: file!) {
                        var smallerCode = ""
                        
                        for (i, line) in code.components(separatedBy: "\n").enumerated() {
                            
                            guard i < 20 else {
                                break
                            }
                            
                            smallerCode += line+"\n"
                        }
                        
                        textView.text = smallerCode
                    }
                    
                    struct ReadonlyTheme: SourceCodeTheme {
                        let defaultTheme = EditorTheme()
                        
                        var lineNumbersStyle: LineNumbersStyle? {
                            return nil
                        }
                        let gutterStyle = GutterStyle(backgroundColor: .clear, minimumWidth: 0)
                        var font: Font {
                            return defaultTheme.font
                        }
                        var backgroundColor: Color {
                            return defaultTheme.backgroundColor
                        }
                        func color(for syntaxColorType: SourceCodeTokenType) -> Color {
                            return defaultTheme.color(for: syntaxColorType)
                        }
                        func globalAttributes() -> [NSAttributedString.Key : Any] {
                            return defaultTheme.globalAttributes()
                        }
                    }
                    textView.theme = ReadonlyTheme()
                    textView.contentTextView.font = textView.contentTextView.font?.withSize(5)
                    textView.contentTextView.isEditable = false
                    textView.contentTextView.isSelectable = false
                    textView.isUserInteractionEnabled = false
                    
                    textView.backgroundColor = .clear
                    textView.contentTextView.backgroundColor = .clear
                    textView.subviews.first?.backgroundColor = .clear
                    
                    if textView.window == nil {
                        container.addSubview(textView)
                    }
                    container.layer.borderColor = UIColor.gray.cgColor
                    container.layer.borderWidth = 0.25
                    titleView.text = file!.deletingPathExtension().lastPathComponent
                }
            }
        }
    }
    
    /// Removes file.
    @objc func remove(_ sender: Any) {
        if let file = file {
            do {
                try FileManager.default.removeItem(at: file)
            } catch {
                let alert = UIAlertController(title: Localizable.Errors.errorRemovingFile, message: error.localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: Localizable.ok, style: .cancel, handler: nil))
                UIApplication.shared.keyWindow?.topViewController?.present(alert, animated: true, completion: nil)
            }
        }
    }
    
    /// Renames file.
    @objc func rename(_ sender: Any) {
        
        guard let file = file else {
            return
        }
        
        var textField: UITextField?
        let alert = UIAlertController(title: Localizable.Renaming.title, message: Localizable.Renaming.message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: Localizable.Renaming.rename, style: .default, handler: { (_) in
            guard let filename = textField?.text else {
                return
            }
            guard !filename.hasSuffix(".") && !filename.isEmpty else {
                let alert = UIAlertController(title: Localizable.Errors.errorRenamingFile, message: Localizable.Errors.emptyName, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: Localizable.ok, style: .cancel, handler: nil))
                DocumentBrowserViewController.visible?.present(alert, animated: true, completion: nil)
                return
            }
            var newFileURL = file.deletingLastPathComponent().appendingPathComponent(filename)
            if !self.isDirectory.boolValue {
                newFileURL.appendPathExtension(file.pathExtension)
            }
            do {
                try FileManager.default.moveItem(at: file, to: newFileURL)
            } catch {
                let alert = UIAlertController(title: Localizable.Errors.errorRenamingFile, message: error.localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: Localizable.ok, style: .cancel, handler: nil))
                UIApplication.shared.keyWindow?.topViewController?.present(alert, animated: true, completion: nil)
            }
        }))
        alert.addAction(UIAlertAction(title: Localizable.cancel, style: .cancel, handler: nil))
        alert.addTextField { (textField_) in
            textField = textField_
            textField?.text = self.file?.deletingPathExtension().lastPathComponent
        }
        documentBrowser?.present(alert, animated: true, completion: nil)
    }
    
    /// Runs script.
    @objc func run(_ sender: Any) {
        if let file = file {
           DocumentBrowserViewController.visible?.openDocument(file, run: true)
        }
    }
    
    /// Opens file.
    @objc func open(_ sender: Any) {
        if let file = file {
            DocumentBrowserViewController.visible?.openDocument(file, run: false)
        }
    }
    
    /// Copies file.
    @objc func copyFile(_ sender: Any) {
        if let file = file {
            let picker = UIDocumentPickerViewController(url: file, in: .exportToService)
            picker.delegate = self
            documentBrowser?.present(picker, animated: true, completion: nil)
        }
    }
    
    /// Moves file.
    @objc func move(_ sender: Any) {
        if let file = file {
            let picker = UIDocumentPickerViewController(url: file, in: .moveToService)
            picker.delegate = self
            documentBrowser?.present(picker, animated: true, completion: nil)
        }
    }
    
    // MARK: - Collection view cell
    
    override var canBecomeFirstResponder: Bool {
        return true
    }
    
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if isDirectory.boolValue {
            return (
                action == #selector(remove(_:)) ||
                    action == #selector(rename(_:)) ||
                    action == #selector(copyFile(_:)) ||
                    action == #selector(move(_:))
            )
        } else {
            return (
                action == #selector(remove(_:)) ||
                action == #selector(run(_:)) ||
                action == #selector(open(_:)) ||
                action == #selector(rename(_:)) ||
                action == #selector(copyFile(_:)) ||
                action == #selector(move(_:))
            )
        }
    }
    
    // MARK: - Document picker view controller delegate
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        //documentBrowser?.collectionView.reloadData()
    }
    
    // MARK: - Syntax text view delegate
    
    func didChangeText(_ syntaxTextView: SyntaxTextView) {}
    
    func didChangeSelectedRange(_ syntaxTextView: SyntaxTextView, selectedRange: NSRange) {}
    
    func lexerForSource(_ source: String) -> Lexer {
        return Python3Lexer()
    }
    
    // MARK: - Collection view data source
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        
        let files = directoryContents.1.count
        if files <= 4 {
            return files
        } else {
            return 4
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "File", for: indexPath) as! FileCollectionViewCell
        cell.file = directoryContents.1[indexPath.row]
        
        return cell
    }
}
