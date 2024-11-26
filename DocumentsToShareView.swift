import UIKit

// Define the protocol for the delegate
protocol DocumentsToShareViewDelegate: AnyObject {
    func didTapShareButton(selectedItems: [String])
    func didTapCancelButton()
}

class DocumentsToShareView: UIView {
    
    // Array of strings to display
    var items: [String]
    
    // Dictionary to track selected checkboxes
    var selectedItems: [Int: Bool] = [:]
    
    // Delegate property
    weak var delegate: DocumentsToShareViewDelegate?
    
    // TableView to display the list
    private let tableView = UITableView()
    
    // Labels above the tableView
    private let label1: UILabel = {
        let label = UILabel()
        label.text = "Verifier requests the following"
        label.font = UIFont.boldSystemFont(ofSize: 18)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let label2: UILabel = {
        let label = UILabel()
        label.text = "Tap SHARE to send these attributes to the Verifier"
        label.font = UIFont.systemFont(ofSize: 16)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // Share and Cancel buttons
    private let shareButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Approve", for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        button.backgroundColor = .systemBlue
        button.layer.cornerRadius = 10 // Rounded corners
        button.setTitleColor(.white, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let cancelButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Cancel", for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        button.backgroundColor = .systemGray
        button.layer.cornerRadius = 10 // Rounded corners
        button.setTitleColor(.white, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // Initializer
    init(items: [String]) {
        self.items = items
        super.init(frame: .zero)
        
        // Initialize all items as selected by default
        for index in 0..<items.count {
            selectedItems[index] = true
        }
        
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // Setup the view
    private func setupView() {
        backgroundColor = .white
        
        // Configure the labels
        addSubview(label1)
        addSubview(label2)
        
        // Configure the table view
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        addSubview(tableView)
        
        // Add Share and Cancel buttons
        addSubview(shareButton)
        addSubview(cancelButton)
        
        // Set constraints
        NSLayoutConstraint.activate([
            // Label1 constraints
            label1.topAnchor.constraint(equalTo: topAnchor, constant: 60),
            label1.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            label1.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            
            // Label2 constraints
            label2.topAnchor.constraint(equalTo: label1.bottomAnchor, constant: 10),
            label2.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            label2.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            
            // TableView constraints
            tableView.topAnchor.constraint(equalTo: label2.bottomAnchor, constant: 60),
            tableView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            tableView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            tableView.bottomAnchor.constraint(equalTo: shareButton.topAnchor, constant: -20),
            
            // Share button constraints
            shareButton.heightAnchor.constraint(equalToConstant: 50),
            shareButton.widthAnchor.constraint(equalToConstant: 150),
            shareButton.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -20),
            
            // Cancel button constraints
            cancelButton.heightAnchor.constraint(equalToConstant: 50),
            cancelButton.widthAnchor.constraint(equalToConstant: 150),
            cancelButton.bottomAnchor.constraint(equalTo: shareButton.bottomAnchor),
            
            // Position Share and Cancel buttons side-by-side
            shareButton.trailingAnchor.constraint(equalTo: centerXAnchor, constant: -10),
            cancelButton.leadingAnchor.constraint(equalTo: centerXAnchor, constant: 10)
        ])
        
        // Add actions to buttons
        shareButton.addTarget(self, action: #selector(shareItems), for: .touchUpInside)
        cancelButton.addTarget(self, action: #selector(cancelAction), for: .touchUpInside)
    }
    
    // Share action
    @objc private func shareItems() {
        // Get selected items
        let selected = items.enumerated().compactMap { index, item in
            selectedItems[index] == true ? item : nil
        }
        
        // Notify the delegate
        delegate?.didTapShareButton(selectedItems: selected)
        
        self.removeFromSuperview()
    }
    
    // Cancel action
    @objc private func cancelAction() {
        // Remove this view or dismiss
        print("Cancel button pressed")
        // Notify the delegate
        delegate?.didTapCancelButton()
        
        self.removeFromSuperview()
    }
}

// MARK: - UITableViewDataSource and UITableViewDelegate

extension DocumentsToShareView: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.textLabel?.text = items[indexPath.row]
        
        // Add a checkbox button
        let checkbox = UIButton(type: .custom)
        checkbox.setImage(UIImage(systemName: "square"), for: .normal)
        checkbox.setImage(UIImage(systemName: "checkmark.square.fill"), for: .selected)
        checkbox.tag = indexPath.row
        checkbox.isSelected = selectedItems[indexPath.row] ?? false // Pre-select based on the dictionary
        checkbox.addTarget(self, action: #selector(toggleCheckbox(_:)), for: .touchUpInside)
        checkbox.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
        cell.accessoryView = checkbox
        
        return cell
    }
    
    @objc private func toggleCheckbox(_ sender: UIButton) {
        sender.isSelected.toggle()
        selectedItems[sender.tag] = sender.isSelected
    }
}
