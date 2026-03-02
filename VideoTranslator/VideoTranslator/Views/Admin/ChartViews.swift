import UIKit

// MARK: - Simple Chart Views

class SimpleBarChartView: UIView {
    private var data: [(String, Int)] = []
    
    func setData(_ data: [(String, Int)]) {
        self.data = data
        setNeedsDisplay()
    }
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        guard !data.isEmpty else { return }
        
        let context = UIGraphicsGetCurrentContext()
        let maxValue = data.map { $0.1 }.max() ?? 1
        let barWidth = rect.width / CGFloat(data.count) - 10
        let barSpacing: CGFloat = 10
        
        for (index, (label, value)) in data.enumerated() {
            let barHeight = (CGFloat(value) / CGFloat(maxValue)) * (rect.height - 40)
            let x = CGFloat(index) * (barWidth + barSpacing) + barSpacing
            let y = rect.height - barHeight - 20
            
            // Draw bar
            context?.setFillColor(UIColor.systemBlue.cgColor)
            context?.fill(CGRect(x: x, y: y, width: barWidth, height: barHeight))
            
            // Draw label
            let labelText = NSString(string: label)
            let labelAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10),
                .foregroundColor: UIColor.label
            ]
            let labelSize = labelText.size(withAttributes: labelAttributes)
            let labelRect = CGRect(
                x: x + (barWidth - labelSize.width) / 2,
                y: rect.height - 18,
                width: labelSize.width,
                height: labelSize.height
            )
            labelText.draw(in: labelRect, withAttributes: labelAttributes)
            
            // Draw value
            let valueText = NSString(string: "\(value)")
            let valueAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10, weight: .medium),
                .foregroundColor: UIColor.label
            ]
            let valueSize = valueText.size(withAttributes: valueAttributes)
            let valueRect = CGRect(
                x: x + (barWidth - valueSize.width) / 2,
                y: y - 18,
                width: valueSize.width,
                height: valueSize.height
            )
            valueText.draw(in: valueRect, withAttributes: valueAttributes)
        }
    }
}

class SimpleLineChartView: UIView {
    private var data: [(String, Int)] = []
    
    func setData(_ data: [(String, Int)]) {
        self.data = data
        setNeedsDisplay()
    }
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        guard !data.isEmpty else { return }
        
        let context = UIGraphicsGetCurrentContext()
        let maxValue = data.map { $0.1 }.max() ?? 1
        let pointSpacing = rect.width / CGFloat(data.count - 1)
        
        // Draw line
        let path = UIBezierPath()
        for (index, (_, value)) in data.enumerated() {
            let x = CGFloat(index) * pointSpacing
            let y = rect.height - (CGFloat(value) / CGFloat(maxValue)) * (rect.height - 40) - 20
            
            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        context?.setStrokeColor(UIColor.systemBlue.cgColor)
        context?.setLineWidth(2)
        context?.addPath(path.cgPath)
        context?.strokePath()
        
        // Draw points and labels
        for (index, (label, value)) in data.enumerated() {
            let x = CGFloat(index) * pointSpacing
            let y = rect.height - (CGFloat(value) / CGFloat(maxValue)) * (rect.height - 40) - 20
            
            // Draw point
            context?.setFillColor(UIColor.systemBlue.cgColor)
            context?.fillEllipse(in: CGRect(x: x - 4, y: y - 4, width: 8, height: 8))
            
            // Draw label
            let labelText = NSString(string: label)
            let labelAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10),
                .foregroundColor: UIColor.label
            ]
            let labelSize = labelText.size(withAttributes: labelAttributes)
            let labelRect = CGRect(
                x: x - labelSize.width / 2,
                y: rect.height - 18,
                width: labelSize.width,
                height: labelSize.height
            )
            labelText.draw(in: labelRect, withAttributes: labelAttributes)
        }
    }
}

// MARK: - User Table View Cell

class UserTableViewCell: UITableViewCell {
    static let identifier = "UserCell"
    
    private let emailLabel = UILabel()
    private let nameLabel = UILabel()
    private let dateLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        emailLabel.font = .systemFont(ofSize: 16, weight: .medium)
        nameLabel.font = .systemFont(ofSize: 14)
        nameLabel.textColor = .secondaryLabel
        dateLabel.font = .systemFont(ofSize: 12)
        dateLabel.textColor = .tertiaryLabel
        
        let stackView = UIStackView(arrangedSubviews: [emailLabel, nameLabel, dateLabel])
        stackView.axis = .vertical
        stackView.spacing = 4
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }
    
    func configure(with user: AppUser) {
        emailLabel.text = user.email
        nameLabel.text = user.displayName
        dateLabel.text = "Joined: \(user.createdAt.formatted(date: .abbreviated, time: .omitted))"
    }
}
