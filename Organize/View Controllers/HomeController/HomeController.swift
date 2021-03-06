//
//  HomeViewController.swift
//  Organize
//
//  Created by Daniel Valencia on 7/14/21.
//

import UIKit
import FirebaseAuth
import FirebaseStorage
import FirebaseFirestore
import PhotosUI

class HomeController: UIViewController, UITextFieldDelegate, SelectListDelegate, EditToDoItemDelegate, CreateItemDelegate, CompletionStatusDelegate, CompletionStatusFromSearchControllerDelegate, PHPickerViewControllerDelegate {
    
    // MARK: - Properties
    
    var haveItemsBeenFetched = false
    
    var sortOrder: SortOrder = .ascending {
        didSet {
            toDoItemsCollectionView.reloadSections(IndexSet(0...1))
        }
    }
        
    unowned let baseController: BaseController
    
    lazy var currentlyViewedList: ToDoItemList? = nil {
        didSet {
            if currentlyViewedList != nil {
                listTasksLabel.attributedText = NSAttributedString(string: "Tasks for \(currentlyViewedList!.name)".uppercased(), attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 15, weight: .medium), NSAttributedString.Key.kern: 1.5, NSAttributedString.Key.foregroundColor: UIColor.subheadingLabelFontColor])
                addTaskTextField.isEnabled = true
                editListButton.isEnabled = true
                
                currentlyViewedList?.toDoItems.sort(by: {sortOrder == .ascending ? $0.created < $1.created : $0.created > $1.created})
                currentlyViewedList?.completedToDoItems.sort(by: {sortOrder == .ascending ? $0.created < $1.created : $0.created > $1.created})
            } else {
                addTaskTextField.isEnabled = false
                editListButton.isEnabled = false
            }
        }
    }
    
    var totalNumberOfListsFetchedSoFar = 0
    
    var totalNumberOfListsToBeFetched = 0
    
    var toDoItemLists = [ToDoItemList]() {
        didSet {
            if !toDoItemLists.isEmpty {
                currentlyViewedList = toDoItemLists[0]
            }
        }
    }
            
    lazy var menuSwipeLimit = view.frame.width * 0.6
    
    let borderView = UIView.makeHorizontalBorderView()
    
    private lazy var headerIconsNavigationBarContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .elevatedBackgroundColor
        view.translatesAutoresizingMaskIntoConstraints = false
        
        borderView.backgroundColor = traitCollection.userInterfaceStyle == .light ? .clear : UIColor(red: 45/255, green: 55/255, blue: 72/255, alpha: 1)
        view.addSubview(borderView)
        
        borderView.anchor(topAnchor: nil, rightAnchor: view.trailingAnchor, bottomAnchor: view.bottomAnchor, leftAnchor: view.leadingAnchor, topPadding: 0, rightPadding: 0, bottomPadding: 0, leftPadding: 0, height: 0, width: 0)
        
        return view
    }()
                
    private lazy var headerIconsNavigationBar =
        UIStackView.makeHorizontalStackView(with: [
            UIStackView.makeVerticalStackView(with: [UIView.makeVerticalStackViewSpacerView(with: 12.5), slideOutControllerButton, UIView.makeVerticalStackViewSpacerView(with: 12.5)], distribution: .fill, spacing: 0),
            UIView(),
            UIStackView.makeVerticalStackView(with: [UIView.makeVerticalStackViewSpacerView(with: 12.5), searchForTaskButton, UIView.makeVerticalStackViewSpacerView(with: 12.5)], distribution: .fill, spacing: 0),
            UIStackView.makeVerticalStackView(with: [UIView.makeVerticalStackViewSpacerView(with: 12.5), sortListButton, UIView.makeVerticalStackViewSpacerView(with: 12.5)], distribution: .fill, spacing: 0),
            UIStackView.makeVerticalStackView(with: [UIView.makeVerticalStackViewSpacerView(with: 12.5), editListButton, UIView.makeVerticalStackViewSpacerView(with: 12.5)], distribution: .fill, spacing: 0),
            profileButton
        ], distribution: .fill, spacing: 12.5)
        
    private let slideOutControllerButton: UIButton = {
        let button = UIButton(type: .system)
        button.setBackgroundImage(UIImage(named: "line.horizontal.3"), for: .normal)
        button.imageView!.contentMode = .scaleAspectFill
        button.tintColor = .titleLabelFontColor
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 25).isActive = true
        button.widthAnchor.constraint(equalToConstant: 25).isActive = true
        return button
    }()
    
    private let searchForTaskButton: UIButton = {
        let button = UIButton(type: .system)
        button.setBackgroundImage(UIImage(named: "magnifyingglass"), for: .normal)
        button.imageView!.contentMode = .scaleAspectFill
        button.tintColor = .titleLabelFontColor
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 25).isActive = true
        button.widthAnchor.constraint(equalToConstant: 25).isActive = true
        return button
    }()
    
    private let sortListButton: UIButton = {
        let button = UIButton(type: .system)
        button.setBackgroundImage(UIImage(named: "arrow.up.arrow.down"), for: .normal)
        button.imageView!.contentMode = .scaleToFill
        button.tintColor = .titleLabelFontColor
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 25).isActive = true
        button.widthAnchor.constraint(equalToConstant: 25).isActive = true
        return button
    }()
    
    private let editListButton: UIButton = {
        let button = UIButton(type: .system)
        button.setBackgroundImage(UIImage(named: "pencil"), for: .normal)
        button.imageView!.contentMode = .scaleAspectFill
        button.tintColor = .titleLabelFontColor
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 25).isActive = true
        button.widthAnchor.constraint(equalToConstant: 25).isActive = true
        return button
    }()
    
    let profileButton: UIButton = {
        let button = UIButton(type: .system)
        button.setBackgroundImage(UIImage(named: "person.crop.circle"), for: .normal)
        button.layoutIfNeeded()
        button.subviews.first?.contentMode = .scaleAspectFill
        button.tintColor = .titleLabelFontColor
        button.heightAnchor.constraint(equalToConstant: 50).isActive = true
        button.widthAnchor.constraint(equalToConstant: 50).isActive = true
        button.layer.cornerRadius = 25
        button.layer.masksToBounds = true
        return button
    }()
    
    private var listTasksLabel: UILabel = {
        let label = UILabel.makeSubheadingLabel(with: "")
        label.numberOfLines = 0
        label.textAlignment = .left
        return label
    }()
    
    var isEditingCollectionView = false {
        didSet {
            editListButton.isEnabled = !isEditingCollectionView
            performToolBarAnimation()
        }
    }
        
    let toDoItemsCollectionView: UICollectionView = {
        let collectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: UICollectionViewFlowLayout())
        collectionView.allowsMultipleSelection = true
        collectionView.showsVerticalScrollIndicator = false
        collectionView.alwaysBounceVertical = true
        collectionView.backgroundColor = .clear
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.register(ToDoListItemsCollectionViewCell.self, forCellWithReuseIdentifier: "cell")
        collectionView.register(ToDoItemsCollectionViewHeader.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "header")
        return collectionView
    }()
    
    let addTaskTextField: ExpandableTextField = {
        let expandableTextField = ExpandableTextField()
        expandableTextField.isEnabled = false
        return expandableTextField
    }()
    
    private var addTaskTextFieldBottomAnchor: NSLayoutConstraint!
    
    private var addTaskTextFieldInactiveXAnchor: NSLayoutConstraint!
    
    private var addTaskTextFieldActiveXAnchor: NSLayoutConstraint!
    
    private var addTaskTextFieldHiddenXAnchor: NSLayoutConstraint!

    private var firstResponderGradientLayer = CAGradientLayer()
    
    var menuGradientView = UIView()

    lazy var toolBar: UIToolbar = {
        let toolBar = UIToolbar()
        toolBar.tintColor = .black
        toolBar.translatesAutoresizingMaskIntoConstraints = false
        return toolBar
    }()
    
    private var toolBarHiddenAnchor: NSLayoutConstraint!
    
    private var toolBarDisplayedAnchor: NSLayoutConstraint!
    
    // MARK: - Initialization
    
    init(baseController: BaseController) {
        self.baseController = baseController
        super.init(nibName: nil, bundle: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
        
        print("HomeController deallocated")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .primaryBackgroundColor
        setupSubviews()
        setupToolbar()
        setSubviewsToInvisible()
        setupCollectionView()
        setupFirstResponderGradientLayer()
        setupMenuGradientLayer()
        setupNotificationCenter()
        setupTargets()
        setupDelegates()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !haveItemsBeenFetched {
            haveItemsBeenFetched = true
            fetchItemsFromDatabase()
            fetchUserProfileImageFromDatabase()
            
            let toolBarItem1 = UIBarButtonItem(image: UIImage(named: "trash"), style: .plain, target: self, action: #selector(handleDeleteSelectedItems))
            toolBarItem1.tintColor = .titleLabelFontColor
            let toolBarItem2 = UIBarButtonItem(title: "Cancel", style: .done, target: self, action: #selector(handleCloseToolBar))
            toolBarItem2.tintColor = .titleLabelFontColor

            toolBar.items = [toolBarItem1, toolBarItem2]
        }
    }
 
    private func setupSubviews() {
        view.addSubview(headerIconsNavigationBarContainerView)
        headerIconsNavigationBarContainerView.addSubview(headerIconsNavigationBar)
        view.addSubview(listTasksLabel)
        view.addSubview(toDoItemsCollectionView)
        view.addSubview(menuGradientView)
        view.addSubview(addTaskTextField)
        
        headerIconsNavigationBarContainerView.anchor(topAnchor: view.topAnchor, rightAnchor: view.trailingAnchor, bottomAnchor: nil, leftAnchor: view.leadingAnchor, topPadding: 0, rightPadding: 0, bottomPadding: 0, leftPadding: 0, height: 80 + UIApplication.shared.windows[0].safeAreaInsets.top, width: 0)
        
        headerIconsNavigationBar.anchor(topAnchor: nil, rightAnchor: headerIconsNavigationBarContainerView.trailingAnchor, bottomAnchor: headerIconsNavigationBarContainerView.bottomAnchor, leftAnchor: headerIconsNavigationBarContainerView.leadingAnchor, topPadding: 0, rightPadding: 30, bottomPadding: 10, leftPadding: 30, height: 0, width: 0)
        
        listTasksLabel.anchor(topAnchor: headerIconsNavigationBarContainerView.bottomAnchor, rightAnchor: view.trailingAnchor, bottomAnchor: nil, leftAnchor: view.leadingAnchor, topPadding: 0, rightPadding: 30, bottomPadding: 0, leftPadding: 30, height: 70, width: 0)
                
        toDoItemsCollectionView.anchor(topAnchor: listTasksLabel.bottomAnchor, rightAnchor: view.trailingAnchor, bottomAnchor: view.bottomAnchor, leftAnchor: view.leadingAnchor, topPadding: 0, rightPadding: 0, bottomPadding: 0, leftPadding: 0, height: 0, width: 0)
                
        addTaskTextFieldBottomAnchor = addTaskTextField.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        addTaskTextFieldBottomAnchor.isActive = true
        
        addTaskTextFieldInactiveXAnchor = addTaskTextField.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20)
        addTaskTextFieldInactiveXAnchor.isActive = true
        
        addTaskTextFieldHiddenXAnchor = addTaskTextField.leadingAnchor.constraint(equalTo: view.trailingAnchor)
        
        addTaskTextFieldActiveXAnchor = addTaskTextField.centerXAnchor.constraint(equalTo: view.centerXAnchor)
    }
    
    private func setupToolbar() {
        view.addSubview(toolBar)
        
        toolBarHiddenAnchor = toolBar.topAnchor.constraint(equalTo: view.bottomAnchor)
        toolBarHiddenAnchor.isActive = true

        toolBarDisplayedAnchor = toolBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        
        toolBar.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        toolBar.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
    }
    
    private func setSubviewsToInvisible() {
        headerIconsNavigationBarContainerView.alpha = 0
        slideOutControllerButton.alpha = 0
        searchForTaskButton.alpha = 0
        editListButton.alpha = 0
        profileButton.alpha = 0
                
        listTasksLabel.alpha = 0
        toDoItemsCollectionView.alpha = 0
        
        addTaskTextField.alpha = 0
    }
    
    func animateSubviews() {
        UIView.animate(withDuration: 1, delay: 0, options: .curveEaseOut) {
            self.headerIconsNavigationBarContainerView.alpha = 1
            self.slideOutControllerButton.alpha = 1
            self.searchForTaskButton.alpha = 1
            self.editListButton.alpha = 1
            self.profileButton.alpha = 1
        }
        
        UIView.animate(withDuration: 1, delay: 0.2, options: .curveEaseOut) {
            self.listTasksLabel.alpha = 1
            self.toDoItemsCollectionView.alpha = 1
        }
        
        UIView.animate(withDuration: 1, delay: 0.4, options: .curveEaseOut) {
            self.addTaskTextField.alpha = 1
        }
    }
    
    private func setupFirstResponderGradientLayer() {
        firstResponderGradientLayer.colors = [UIColor.clear.cgColor, UIColor.clear.cgColor]
        firstResponderGradientLayer.locations = [0, 0.4, 1]
        firstResponderGradientLayer.startPoint = CGPoint(x: 1, y: 0)
        firstResponderGradientLayer.endPoint = CGPoint(x: 1, y: 1)
        firstResponderGradientLayer.frame = CGRect(x: 0, y: 0, width: view.frame.width, height: view.frame.height)
    }
    
    private func setupMenuGradientLayer() {
        menuGradientView.translatesAutoresizingMaskIntoConstraints = false
        menuGradientView.anchorInCenterOfParent(parentView: view, topPadding: 0, rightPadding: 0, bottomPadding: 0, leftPadding: 0)
        menuGradientView.backgroundColor = UIColor.black
        menuGradientView.alpha = 0
    }
    
    private func setupTargets() {
        slideOutControllerButton.addTarget(baseController, action: #selector(baseController.handleOpenMenu), for: .touchUpInside)
        sortListButton.addTarget(self, action: #selector(handleSortList), for: .touchUpInside)
        searchForTaskButton.addTarget(self, action: #selector(presentTaskSearchViewController), for: .touchUpInside)
        editListButton.addTarget(self, action: #selector(handleEditList), for: .touchUpInside)
        profileButton.addTarget(self, action: #selector(handleEditProfile), for: .touchUpInside)
    }
    
    private func setupDelegates() {
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleMenuCloseTap))
        tapGestureRecognizer.delegate = self
        view.addGestureRecognizer(tapGestureRecognizer)
        
        addTaskTextField.delegate = self
        
        baseController.slideOutMenuController.selectListDelegate = self
        baseController.slideOutMenuController.createListDelegate = self
                
        addTaskTextField.createItemDelegate = self
    }
    
    private func setupNotificationCenter() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleKeyboardOpen), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleKeyboardClose), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    // MARK: - Selectors
    
    @objc private func handleDeleteSelectedItems() {
        if let selectedIndexPaths = toDoItemsCollectionView.indexPathsForSelectedItems {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            
            if let currentlyViewedList = currentlyViewedList {
                let sortedPaths = selectedIndexPaths.sorted(by: {$0 > $1})
                
                for index in sortedPaths {
                    if index.section == 0 {
                        currentlyViewedList.toDoItems[index.row].deleteFromDatabase()
                        currentlyViewedList.toDoItems.remove(at: index.row)
                    } else {
                        currentlyViewedList.completedToDoItems[index.row].deleteFromDatabase()
                        currentlyViewedList.completedToDoItems.remove(at: index.row)
                    }
                }
            }
            toDoItemsCollectionView.reloadSections(IndexSet(0...1))
        }
        
        isEditingCollectionView = false
    }
    
    @objc private func handleCloseToolBar() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        isEditingCollectionView = false
    }
    
    @objc private func presentTaskSearchViewController() {
        let searchForTaskController = SearchForTaskController()
        searchForTaskController.toDoItemLists = toDoItemLists
        searchForTaskController.delegate = self
        
        let navigationController = UINavigationController(rootViewController: searchForTaskController)
        navigationController.modalPresentationStyle = .fullScreen
        
        present(navigationController, animated: true)
    }
    
    @objc private func handleKeyboardOpen(notification: Notification) {
        if baseController.menuState == .opened {
            return
        }
        
        if addTaskTextField.isFirstResponder {
            if let notificationData = notification.userInfo {
                guard let animationDuration = notificationData["UIKeyboardAnimationDurationUserInfoKey"] as? Double else { return }
                guard let keyboardFrame = notificationData["UIKeyboardFrameEndUserInfoKey"] as? CGRect else { return }
                            
                let frameGap = view.frame.height - addTaskTextField.frame.maxY
                toDoItemsCollectionView.isUserInteractionEnabled = false
                
                if addTaskTextField.frame.maxY > (view.frame.height - keyboardFrame.height) {
                    performOpenKeyboardAnimation(animationDuration, keyboardFrame.height - frameGap + 50)
                }
            }
        }
    }
    
    @objc private func handleKeyboardClose(notification: Notification) {
        if baseController.menuState == .opened {
            return
        }
        
        if addTaskTextField.isFirstResponder {
            if let notificationData = notification.userInfo {
                guard let animationDuration = notificationData["UIKeyboardAnimationDurationUserInfoKey"] as? Double else { return }
                toDoItemsCollectionView.isUserInteractionEnabled = true
                
                performCloseKeyboardAnimation(animationDuration)
            }
        }
    }
    
    @objc private func handleSortList() {
        let actionSheet = UIAlertController(title: "Sort By", message: nil, preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: "Oldest (Created)", style: .default, handler: { _ in
            if let currentlyViewedList = self.currentlyViewedList {
                currentlyViewedList.toDoItems.sort(by: {$0.created < $1.created})
                currentlyViewedList.completedToDoItems.sort(by: {$0.created < $1.created})
                self.sortOrder = .ascending
            }
        }))
        actionSheet.addAction(UIAlertAction(title: "Newest (Created)", style: .default, handler: { _ in
            if let currentlyViewedList = self.currentlyViewedList {
                currentlyViewedList.toDoItems.sort(by: {$0.created > $1.created})
                currentlyViewedList.completedToDoItems.sort(by: {$0.created > $1.created})
                self.sortOrder = .descending
            }
        }))
        actionSheet.addAction(UIAlertAction(title: "Close", style: .cancel, handler: nil))
        present(actionSheet, animated: true)
    }
    
    @objc private func handleEditList() {
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: "Edit List Name", style: .default, handler: { (_) in
            self.presentEditToDoItemNameActionSheet()
        }))
        actionSheet.addAction(UIAlertAction(title: "Select Items", style: .default, handler: { (_) in
            self.isEditingCollectionView = true
        }))
        actionSheet.addAction(UIAlertAction(title: "Delete List", style: .destructive, handler: { (_) in
            self.deleteCurrentlyViewedList()
        }))
        actionSheet.addAction(UIAlertAction(title: "Close", style: .cancel))
        present(actionSheet, animated: true)
    }
    
    @objc func handleEditProfile() {
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alertController.addAction(UIAlertAction(title: "Logout", style: .destructive, handler: { (_) in
            do {
                try Auth.auth().signOut()
                self.dismiss(animated: true)
            } catch let error {
                print(error.localizedDescription)
            }
        }))
        alertController.addAction(UIAlertAction(title: "Change Photo", style: .default, handler: { (_) in
            self.presentPHPickerViewController()
        }))
        alertController.addAction(UIAlertAction(title: "Close", style: .cancel, handler: nil))
        present(alertController, animated: true)
    }
    
    // MARK: - UITextFieldDelegate
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        createToDoItem()
        
        textField.resignFirstResponder()
        
        return true
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        if let gestureRecognizers = view.gestureRecognizers {
            if let panGestureRecognizer = gestureRecognizers.first {
                panGestureRecognizer.isEnabled = false
            }
        }
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        if let gestureRecognizers = view.gestureRecognizers {
            if let panGestureRecognizer = gestureRecognizers.first {
                panGestureRecognizer.isEnabled = true
            }
        }
    }
    
    // MARK: - SelectListDelegate
    
    func didSelectList(list: ToDoItemList) {
        baseController.animateMenu(to: .closed)
        
        currentlyViewedList = list
        
        toDoItemsCollectionView.reloadSections(IndexSet(0...1))
    }
    
    // MARK: - CompletionStatusDelegate
    
    func didCompleteTask(task: ToDoItem) {
        var indexMoveFrom: IndexPath?
        var indexMoveTo: IndexPath?
        
        if let currentlyViewedList = currentlyViewedList {
            if task.isCompleted {
                
                if let index = currentlyViewedList.toDoItems.firstIndex(where: { (toDoItem) -> Bool in
                    return toDoItem === task
                }) {
                    indexMoveFrom = IndexPath(item: index, section: 0)
                    currentlyViewedList.toDoItems.remove(at: index)
                    
                    indexMoveTo = IndexPath(item: getToDoItemListInsertionPositionOrderedByDate(for: task, list: currentlyViewedList.completedToDoItems), section: 1)
                    
                    currentlyViewedList.completedToDoItems.insert(task, at: indexMoveTo!.item)
                }
                
            } else {
                
                if let index = currentlyViewedList.completedToDoItems.firstIndex(where: { (toDoItem) -> Bool in
                    return toDoItem === task
                }) {
                    indexMoveFrom = IndexPath(item: index, section: 1)
                    currentlyViewedList.completedToDoItems.remove(at: index)
                    
                    indexMoveTo = IndexPath(item: getToDoItemListInsertionPositionOrderedByDate(for: task, list: currentlyViewedList.toDoItems), section: 0)
                    
                    currentlyViewedList.toDoItems.insert(task, at: indexMoveTo!.item)
                }
                
            }
        }
        
        if let indexMoveFrom = indexMoveFrom, let indexMoveTo = indexMoveTo {
            if currentlyViewedList != nil {
                toDoItemsCollectionView.moveItem(at: indexMoveFrom, to: indexMoveTo)
            }
        }
    }
    
    // MARK: - CompletionStatusFromSearchControllerDelegate
    
    func didChangeTaskCompletionStatus() {
        toDoItemsCollectionView.reloadData()
    }
    
    // MARK: - CreateItemDelegate
    
    func didCreateItem() {
        createToDoItem()
    }
    
    // MARK: - EditItemProtocol
    
    func didEditItem(indexPath: IndexPath, toDoItem: ToDoItem) {
        if let currentlyViewedList = currentlyViewedList {
            if indexPath.section == 0 {
                currentlyViewedList.toDoItems[indexPath.row] = toDoItem
            } else {
                currentlyViewedList.completedToDoItems[indexPath.row] = toDoItem
            }
            toDoItemsCollectionView.reloadItems(at: [indexPath])
        }
    }
    
    func didDeleteItem(indexPath: IndexPath) {
        if let currentlyViewedList = currentlyViewedList {
            if indexPath.section == 0 {
                currentlyViewedList.toDoItems.remove(at: indexPath.row)
            } else {
                currentlyViewedList.completedToDoItems.remove(at: indexPath.row)
            }
            toDoItemsCollectionView.deleteItems(at: [indexPath])
        }
    }
    
    // MARK: - PHPickerViewControllerDelegate
    
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        results.forEach { result in
            let itemProvider = result.itemProvider
            
            if itemProvider.canLoadObject(ofClass: UIImage.self) {
                itemProvider.loadObject(ofClass: UIImage.self) { image, error in
                    if let error = error {
                        DispatchQueue.main.async {
                            self.present(makeAlertViewController(with: "Error", message: error.localizedDescription), animated: true)
                        }
                    } else {
                        if let image = image as? UIImage {
                            DispatchQueue.main.async {
                                self.setProfileImage(with: image)
                            }
                        }
                    }
                }
            }
        }
        picker.dismiss(animated: true)
    }
    
    // MARK: - TraitCollection
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if let previousTraitCollection = previousTraitCollection {
            if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                traitCollection.performAsCurrent {
                    borderView.backgroundColor = traitCollection.userInterfaceStyle == .light ? .clear : UIColor(red: 45/255, green: 55/255, blue: 72/255, alpha: 1)
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func setProfileImage(with image: UIImage) {
       UIView.transition(with: profileButton, duration: 0.5, options: .transitionCrossDissolve) {
           self.profileButton.setBackgroundImage(image, for: .normal)
       }
       
       saveFileToStorage(image)
   }
    
    private func saveFileToStorage(_ image: UIImage) {
            if let user = Auth.auth().currentUser {
                if let imageData = image.jpegData(compressionQuality: 0.8) {
                    let storageLocation = Storage.storage().reference().child("users").child(user.uid).child("profile_image")
                        
                    storageLocation.putData(imageData, metadata: nil) { (_, error) in
                        if let error = error {
                            print(error.localizedDescription)
                        } else {
                            Firestore.firestore().collection("users").document(user.uid).updateData(["profile_image_url": storageLocation.fullPath])
                        }
                    }
                }
            }
        }
    
    private func presentPHPickerViewController() {
        var configuration = PHPickerConfiguration()
        configuration.selectionLimit = 1
        
        let PHPickerViewController = PHPickerViewController(configuration: configuration)
        PHPickerViewController.delegate = self
        
        PHPhotoLibrary.requestAuthorization { status in
            DispatchQueue.main.async {
                if status == .authorized {
                    self.present(PHPickerViewController, animated: true)
                } else {
                    self.present(makeAlertViewController(with: "Error", message: "To set a profile image, access to your media library is required"), animated: true)

                }
            }
        }
    }
    
    private func presentEditToDoItemNameActionSheet() {
        let actionSheet = UIAlertController(title: nil, message: "Edit To Do List Name", preferredStyle: .alert)
        actionSheet.addTextField(configurationHandler: { textField in
            textField.autocorrectionType = .yes
            textField.autocapitalizationType = .sentences
        })
        actionSheet.addAction(UIAlertAction(title: "Save", style: .default, handler: { [unowned self] (_) in
            if let textField = actionSheet.textFields?[0] {
                textField.autocorrectionType = .yes
                textField.autocapitalizationType = .sentences
                if !textField.text!.isEmpty {
                    if let currentlyViewedList = self.currentlyViewedList {
                        currentlyViewedList.editName(with: textField.text!)
                        self.listTasksLabel.text = "TASKS FOR \(textField.text!.uppercased())"
                        
                        if let index = toDoItemLists.firstIndex(of: currentlyViewedList) {
                            baseController.slideOutMenuController.toDoItemLists[index].name = textField.text!
                            baseController.slideOutMenuController.tableView.reloadSections(IndexSet(integer: 0), with: .fade)
                            baseController.slideOutMenuController.indexPathOfPreviouslySelectedRow = IndexPath(row: index + 1, section: 0)
                        }
                    }
                }
            }
        }))
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(actionSheet, animated: true)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        view.endEditing(true)
    }
    
    private func createToDoItem() {
        let text = addTaskTextField.capturedText.trimmingCharacters(in: .whitespaces)
                
        if !text.isEmpty {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            
            if Auth.auth().currentUser != nil {
                
                let creationDate = Date()
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                
                let uuid = UUID().uuidString
                
                if currentlyViewedList != nil {
                    let path = currentlyViewedList!.path!.collection("items")
                    
                    path.document(uuid).setData(["name": text, "is_completed": false, "created": Timestamp(), "due_date": addTaskTextField.capturedDate ?? NSNull()])
                    
                    currentlyViewedList!.toDoItems.append(ToDoItem(name: text, isCompleted: false, created: creationDate, dueDate: addTaskTextField.capturedDate, path: path.document(uuid)))
                    toDoItemsCollectionView.insertItems(at: [IndexPath(item: currentlyViewedList!.toDoItems.count - 1, section: 0)])
                    toDoItemsCollectionView.scrollToItem(at: IndexPath(item: currentlyViewedList!.toDoItems.count - 1, section: 0), at: .top, animated: true)
                }
            }
        }
    }
    
    private func deleteCurrentlyViewedList() {
        if let currentlyViewedList = currentlyViewedList {
            currentlyViewedList.deleteListFromDatabase {
                if let listIndex = self.toDoItemLists.firstIndex(of: self.currentlyViewedList!) {
                    self.toDoItemLists.remove(at: listIndex)
                    self.baseController.slideOutMenuController.toDoItemLists.remove(at: listIndex)
                    
                    self.baseController.slideOutMenuController.tableView.deleteRows(at: [IndexPath(row: listIndex + 1, section: 0)], with: .automatic)
                                        
                    if !self.toDoItemLists.isEmpty {
                        self.currentlyViewedList = self.toDoItemLists[0]
                        self.toDoItemsCollectionView.reloadSections(IndexSet(integer: 0))
                        self.baseController.slideOutMenuController.indexPathOfPreviouslySelectedRow = IndexPath(row: 1, section: 0)
                    } else {
                        self.currentlyViewedList = nil
                        self.listTasksLabel.text = ""
                        self.toDoItemsCollectionView.reloadData()
                    }
                }
            }
        }
    }
    
    // MARK: - Animations
    
    private func performOpenKeyboardAnimation(_ duration: Double, _ height: CGFloat) {
        addTaskTextFieldBottomAnchor.constant = -height
        addTaskTextFieldInactiveXAnchor.isActive = false
        addTaskTextFieldActiveXAnchor.isActive = true

        UIView.animate(withDuration: duration, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 1, options: .curveEaseInOut) {
            self.view.layoutIfNeeded()
            self.menuGradientView.alpha = 0.25
        }

        let animation = CABasicAnimation(keyPath: "colors")
        animation.fromValue = [UIColor.clear.cgColor, UIColor.clear.cgColor]
        animation.toValue = [UIColor.clear.cgColor, UIColor.paragraphTextColor.withAlphaComponent(0.5).cgColor]
        animation.beginTime = CACurrentMediaTime() + duration
        animation.duration = duration
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false
        firstResponderGradientLayer.add(animation, forKey: nil)
    }
    
    private func performCloseKeyboardAnimation(_ duration: Double) {
        addTaskTextFieldBottomAnchor.constant = -20
        addTaskTextFieldActiveXAnchor.isActive = false
        addTaskTextFieldInactiveXAnchor.isActive = true

        UIView.animate(withDuration: duration, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 1, options: .curveEaseInOut) {
            self.view.layoutIfNeeded()
            self.menuGradientView.alpha = 0
        }

        let animation = CABasicAnimation(keyPath: "colors")
        animation.fromValue = [UIColor.clear.cgColor, UIColor.paragraphTextColor.withAlphaComponent(0.5).cgColor]
        animation.toValue = [UIColor.clear.cgColor, UIColor.clear.cgColor]
        animation.duration = duration / 4
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false
        firstResponderGradientLayer.add(animation, forKey: nil)
    }
    
    private func performToolBarAnimation() {
        if isEditingCollectionView {
            toolBarHiddenAnchor.isActive = false
            toolBarDisplayedAnchor.isActive = true
            
            addTaskTextFieldInactiveXAnchor.isActive = false
            addTaskTextFieldHiddenXAnchor.isActive = true
        } else {
            toolBarDisplayedAnchor.isActive = false
            toolBarHiddenAnchor.isActive = true
            
            addTaskTextFieldHiddenXAnchor.isActive = false
            addTaskTextFieldInactiveXAnchor.isActive = true
        }
        
        if let currentlyViewedList = currentlyViewedList {
            var indexPaths = [IndexPath]()
            
            if !currentlyViewedList.toDoItems.isEmpty {
                for row in 0...currentlyViewedList.toDoItems.count - 1 {
                    indexPaths.append(IndexPath(item: row, section: 0))
                }
            }
            
            if !currentlyViewedList.completedToDoItems.isEmpty {
                for row in 0...currentlyViewedList.completedToDoItems.count - 1 {
                    indexPaths.append(IndexPath(item: row, section: 1))
                }
            }
            
            toDoItemsCollectionView.reloadItems(at: indexPaths)
        }
        
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 1, options: .curveEaseOut) {
            self.view.layoutIfNeeded()
        }
    }
    
}

enum SortOrder: String {
    case descending, ascending
}
