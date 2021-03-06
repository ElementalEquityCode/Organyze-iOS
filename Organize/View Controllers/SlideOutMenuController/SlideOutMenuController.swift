//
//  SlideOutMenuController.swift
//  Organize
//
//  Created by Daniel Valencia on 7/15/21.
//

import UIKit
import PhotosUI
import FirebaseAuth
import FirebaseStorage
import FirebaseFirestore

class SlideOutMenuController: UITableViewController {
    
    // MARK: - Properties
    
    var indexPathOfPreviouslySelectedRow: IndexPath? {
        willSet {
            if let indexPathOfPreviouslySelectedRow = indexPathOfPreviouslySelectedRow {
                if let cell = tableView.cellForRow(at: indexPathOfPreviouslySelectedRow) {
                    cell.isSelected = false
                }
            }
        }
        didSet {
            if let indexPathOfPreviouslySelectedRow = indexPathOfPreviouslySelectedRow {
                if let cell = tableView.cellForRow(at: indexPathOfPreviouslySelectedRow) {
                    cell.isSelected = true
                }
            }
        }
    }
    
    unowned let baseController: BaseController
    
    weak var createListDelegate: CreateListDelegate?
    
    weak var selectListDelegate: SelectListDelegate?
    
    var toDoItemLists = [ToDoItemList]()
    
    // MARK: - Initailization
    
    init(baseController: BaseController) {
        self.baseController = baseController
        super.init(style: .grouped)
    }
    
    deinit {
        print("SlideOutMenuController deallocated")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .clear
        setupTableView()
    }
    
    // MARK: - Selectors
    
    @objc func handleSignout() {
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: "Sign Out", style: .destructive, handler: { (_) in
            if Auth.auth().currentUser != nil {
                do {
                    try Auth.auth().signOut()
                    
                    if let parent = self.parent {
                        parent.dismiss(animated: true, completion: nil)
                    }
                } catch let error {
                    print(error.localizedDescription)
                }
            }
        }))
        actionSheet.addAction(UIAlertAction(title: "Close", style: .cancel))
        present(actionSheet, animated: true)
    }
    
    @objc func handleCreateNewListTap() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                
        let alertViewController = UIAlertController(title: "Create a new List", message: "Enter a name for your new list", preferredStyle: .alert)
        alertViewController.addTextField { textfield in
            textfield.autocorrectionType = .yes
            textfield.autocapitalizationType = .sentences
        }
        alertViewController.addAction(UIAlertAction(title: "Create", style: .default, handler: { [unowned self] (_) in
            if let textField = alertViewController.textFields?[0] {
                if !textField.text!.trimmingCharacters(in: .whitespaces).isEmpty {
                    let uuid = UUID().uuidString
                    let toDoItemList = ToDoItemList(name: textField.text!, created: Date(), toDoItems: [])
                    
                    if let user = Auth.auth().currentUser {
                        let path = Firestore.firestore().collection("users").document(user.uid).collection("to_do_items").document(uuid)
                        
                        self.toDoItemLists.append(toDoItemList)
                        self.tableView.insertRows(at: [IndexPath(row: self.toDoItemLists.count, section: 0)], with: .automatic)
                        self.tableView.selectRow(at: IndexPath(row: self.toDoItemLists.count, section: 0), animated: true, scrollPosition: .top)
                      
                        self.indexPathOfPreviouslySelectedRow = IndexPath(row: self.toDoItemLists.count, section: 0)
                        
                        toDoItemList.path = path
                        
                        self.createListDelegate?.didCreateNewList(list: toDoItemList)
                        
                        path.setData(["list_name": toDoItemList.name, "created": Timestamp(date: toDoItemList.created)])
                    }
                }
            }
        }))
        alertViewController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                
        present(alertViewController, animated: true)
    }
    
    @objc func closeMenu() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        baseController.animateMenu(to: .closed)
    }
    
}
