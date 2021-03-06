import UIKit

class TeamCell: BorderedCell {
    private var hasAwakened = false
    private var team: Team?

    @IBOutlet weak var teamCircle: TeamCircle!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var arrowImage: UIImageView!

    override func awakeFromNib() {
        self.hasAwakened = true
        self.updateView()
    }

    func setTeam(team: Team) {
        self.team = team
        self.updateView()
    }

    private func updateView() {
        if self.hasAwakened {
            if let team = self.team {
                self.teamCircle.setTeam(team)
                self.nameLabel.text = team.name
            }
        }
    }
}
