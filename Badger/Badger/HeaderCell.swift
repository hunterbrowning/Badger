import UIKit

protocol HeaderCellDelegate: class {
    func headerCellButtonPressed(cell: HeaderCell)
}

class HeaderCell : BorderedCell {

    @IBOutlet weak var headerLabel: UILabel!
    @IBOutlet weak var headerButton: UIButton!
    @IBOutlet weak var buttonConstraint: NSLayoutConstraint!

    weak var delegate: HeaderCellDelegate?

    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.selectionStyle = .None
    }

    override func awakeFromNib() {
        self.showButton = false
    }

    var title: String? {
        get {
            return self.headerLabel.text
        }
        set(title) {
            self.headerLabel.text = title
        }
    }

    var labelColor: UIColor! {
        get {
            return self.headerLabel.textColor
        }
        set(color) {
            self.headerLabel.textColor = color
        }
    }

    var buttonText: String? {
        get {
            return self.headerButton.titleForState(.Normal)
        }
        set(title) {
            self.headerButton.setTitle(title, forState: .Normal)
            self.showButton = true
        }
    }

    var showButton: Bool {
        get {
            return !self.headerButton.hidden
        }
        set(show) {
            self.headerButton.hidden = !show
        }
    }

    var buttonInset: CGFloat {
        get {
            return self.buttonConstraint.constant
        }
        set(value) {
            self.buttonConstraint.constant = value
        }
    }

    @IBAction func buttonPressed(sender: AnyObject) {
        self.delegate?.headerCellButtonPressed(self)
    }
}