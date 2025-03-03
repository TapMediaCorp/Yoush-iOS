//
//  Copyright (c) 2020 Open Whisper Systems. All rights reserved.
//

import Foundation

@objc
public extension OWSTableItem {

    static var primaryLabelFont: UIFont {
        return UIFont.ows_dynamicTypeBodyClamped
    }

    static var accessoryLabelFont: UIFont {
        return UIFont.ows_dynamicTypeBodyClamped
    }

    static var iconSpacing: CGFloat {
        return 16
    }

    static func buildCell(name: String, iconView: UIView) -> UITableViewCell {
        return buildCell(name: name, iconView: iconView, iconSpacing: self.iconSpacing)
    }

    static func buildCell(name: String, iconView: UIView, iconSpacing: CGFloat) -> UITableViewCell {
        assert(name.count > 0)

        let cell = OWSTableItem.newCell()
        cell.preservesSuperviewLayoutMargins = true
        cell.contentView.preservesSuperviewLayoutMargins = true

        let rowLabel = UILabel()
        rowLabel.text = name
        rowLabel.textColor = Theme.primaryTextColor
        rowLabel.font = OWSTableItem.primaryLabelFont
        rowLabel.lineBreakMode = .byTruncatingTail

        let contentRow = UIStackView(arrangedSubviews: [ iconView, rowLabel ])
        contentRow.spacing = iconSpacing

        cell.contentView.addSubview(contentRow)
        contentRow.autoPinEdgesToSuperviewMargins()

        return cell
    }

    static func imageView(forIcon icon: ThemeIcon,
                          iconSize: CGFloat = 24) -> UIImageView {
        let iconImage = Theme.iconImage(icon)
        let iconView = UIImageView(image: iconImage)
//        iconView.tintColor = Theme.primaryIconColor
        iconView.tintColor = Theme.youshGoldColor;
        iconView.contentMode = .scaleAspectFit
        iconView.layer.minificationFilter = .trilinear
        iconView.layer.magnificationFilter = .trilinear
        iconView.autoSetDimensions(to: CGSize(square: iconSize))
        return iconView
    }

    static func buildCell(name: String,
                          icon: ThemeIcon,
                          accessibilityIdentifier: String? = nil) -> UITableViewCell {
        let iconView = imageView(forIcon: icon)
        let cell = buildCell(name: name, iconView: iconView)
        cell.accessibilityIdentifier = accessibilityIdentifier
        return cell
    }

    static func buildDisclosureCell(name: String,
                                    icon: ThemeIcon,
                                    accessibilityIdentifier: String) -> UITableViewCell {
        let cell = buildCell(name: name, icon: icon)
        if let stackView = cell.contentView.subviews.last as? UIStackView,
           let rowLabel = stackView.arrangedSubviews.last as? UILabel {
            rowLabel.textColor = Theme.youshGoldColor
        }
        
        cell.accessoryType = .disclosureIndicator
        cell.accessibilityIdentifier = accessibilityIdentifier
        return cell
    }

    static func buildLabelCell(name: String,
                               icon: ThemeIcon,
                               accessibilityIdentifier: String) -> UITableViewCell {
        let cell = buildCell(name: name, icon: icon)
        cell.accessoryType = .none
        cell.accessibilityIdentifier = accessibilityIdentifier
        return cell
    }

    static func buildCellWithAccessoryLabel(icon: ThemeIcon,
                                            itemName: String,
                                            accessoryText: String? = nil,
                                            accessibilityIdentifier: String? = nil) -> UITableViewCell {
        let cell = buildIconNameCell(icon: icon,
                                     itemName: itemName,
                                     accessoryText: accessoryText,
                                     accessibilityIdentifier: accessibilityIdentifier)
        cell.accessoryType = .disclosureIndicator
        return cell

    }

    static func buildIconNameCell(icon: ThemeIcon,
                                  itemName: String,
                                  accessoryText: String? = nil,
                                  customColor: UIColor? = nil,
                                  accessibilityIdentifier: String? = nil) -> UITableViewCell {

        // We can't use the built-in UITableViewCell with CellStyle.value1,
        // because if the content of the primary label and the accessory label
        // overflow the cell layout, their contents will overlap.  We want
        // the labels to truncate in that scenario.
        let cell = OWSTableItem.newCell()
        cell.preservesSuperviewLayoutMargins = true
        cell.contentView.preservesSuperviewLayoutMargins = true

        let iconView = self.imageView(forIcon: icon)
        iconView.setCompressionResistanceHorizontalHigh()

        let nameLabel = UILabel()
        nameLabel.text = itemName
        nameLabel.textColor = Theme.primaryTextColor
        nameLabel.font = OWSTableItem.primaryLabelFont
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.setCompressionResistanceHorizontalLow()

        if let customColor = customColor {
            iconView.tintColor = customColor
            nameLabel.textColor = customColor
        }

        var arrangedSubviews = [ iconView, nameLabel ]

        if let accessoryText = accessoryText {
            let accessoryLabel = UILabel()
            accessoryLabel.text = accessoryText
            accessoryLabel.textColor = Theme.secondaryTextAndIconColor
            accessoryLabel.font = OWSTableItem.accessoryLabelFont
            accessoryLabel.lineBreakMode = .byTruncatingTail
            arrangedSubviews += [ UIView.hStretchingSpacer(), accessoryLabel ]
        }

        let contentRow = UIStackView(arrangedSubviews: arrangedSubviews)
        contentRow.spacing = self.iconSpacing
        contentRow.alignment = .center
        cell.contentView.addSubview(contentRow)
        contentRow.autoPinEdgesToSuperviewMargins()

        cell.accessibilityIdentifier = accessibilityIdentifier

        return cell
    }

    static func buildIconInCircleView(icon: ThemeIcon,
                                      innerIconSize: CGFloat) -> UIView {
        return buildIconInCircleView(icon: icon,
                                     iconSize: nil,
                                     innerIconSize: innerIconSize,
                                     iconTintColor: nil)
    }

    static func buildIconInCircleView(icon: ThemeIcon,
                                      innerIconSize: CGFloat,
                                      iconTintColor: UIColor) -> UIView {
        return buildIconInCircleView(icon: icon,
                                     iconSize: nil,
                                     innerIconSize: innerIconSize,
                                     iconTintColor: iconTintColor)
    }
}

// MARK: -

public extension OWSTableItem {
    static func buildIconInCircleView(icon: ThemeIcon,
                                      iconSize iconSizeParam: UInt? = nil,
                                      innerIconSize innerIconSizeParam: CGFloat? = nil,
                                      iconTintColor: UIColor? = nil) -> UIView {
        let iconSize = CGFloat(iconSizeParam ?? kStandardAvatarSize)
        let innerIconSize: CGFloat
        if let innerIconSizeParam = innerIconSizeParam {
            innerIconSize = innerIconSizeParam
        } else {
            innerIconSize = CGFloat(iconSize) * 0.6
        }
        let iconView = OWSTableItem.imageView(forIcon: icon, iconSize: innerIconSize)
        if let iconTintColor = iconTintColor {
            iconView.tintColor = iconTintColor
        } else {
            iconView.tintColor = Theme.accentBlueColor
        }
        let iconWrapper = UIView.container()
        iconWrapper.addSubview(iconView)
        iconView.autoCenterInSuperview()
        iconWrapper.backgroundColor = Theme.isDarkThemeEnabled ? UIColor.ows_gray80 : Theme.washColor
        iconWrapper.layer.cornerRadius = iconSize * 0.5
        iconWrapper.autoSetDimensions(to: CGSize(square: iconSize))
        iconWrapper.setCompressionResistanceHigh()
        iconWrapper.setContentHuggingHigh()
        return iconWrapper
    }
}
