//
//  Copyright (c) 2020 Open Whisper Systems. All rights reserved.
//

import Foundation
import UIKit

// TODO: We should describe which state updates & when it is committed.
extension ConversationSettingsViewController {

    private var subtitlePointSize: CGFloat {
        return 12
    }

    private var threadName: String {
        var threadName = contactsManager.displayNameWithSneakyTransaction(thread: thread)

        if let contactThread = thread as? TSContactThread {
            if let phoneNumber = contactThread.contactAddress.phoneNumber,
                phoneNumber == threadName {
                threadName = PhoneNumber.bestEffortFormatPartialUserSpecifiedText(toLookLikeAPhoneNumber: phoneNumber)
            }
        }

        return threadName
    }

    private struct HeaderBuilder {
        let viewController: ConversationSettingsViewController

        var subviews = [UIView]()

        init(viewController: ConversationSettingsViewController) {
            self.viewController = viewController

            addFirstSubviews()
        }

        mutating func addFirstSubviews() {
            let avatarView = buildAvatarView()

            let avatarWrapper = UIView.container()
            avatarWrapper.addSubview(avatarView)
            avatarView.autoPinEdgesToSuperviewEdges()

            if let groupThread = viewController.thread as? TSGroupThread,
                groupThread.groupModel.groupAvatarData == nil,
                viewController.canEditConversationAttributes {
                let cameraButton = GroupAttributesEditorHelper.buildCameraButtonForCorner()
                avatarWrapper.addSubview(cameraButton)
                cameraButton.autoPinEdge(toSuperviewEdge: .trailing)
                cameraButton.autoPinEdge(toSuperviewEdge: .bottom)
            }

            subviews.append(avatarWrapper)
            subviews.append(UIView.spacer(withHeight: 8))
            subviews.append(buildThreadNameLabel())
        }

        func buildAvatarView() -> UIView {
            let avatarSize: UInt = kLargeAvatarSize
            let avatarImage = OWSAvatarBuilder.buildImage(thread: viewController.thread,
                                                          diameter: avatarSize)
            let avatarView = AvatarImageView(image: avatarImage)
            avatarView.autoSetDimensions(to: CGSize(square: CGFloat(avatarSize)))
            // Track the most recent avatar view.
            viewController.avatarView = avatarView
            return avatarView
        }

        func buildThreadNameLabel() -> UILabel {
            let label = UILabel()
            label.text = viewController.threadName
            label.textColor = Theme.youshGoldColor
            label.font = UIFont.ows_dynamicTypeTitle2.ows_semibold()
            label.lineBreakMode = .byTruncatingTail
            return label
        }

        mutating func addSubtitleLabel(text: String, font: UIFont? = nil) {
            addSubtitleLabel(attributedText: NSAttributedString(string: text), font: font)
        }

        mutating func addSubtitleLabel(attributedText: NSAttributedString, font: UIFont? = nil) {
            subviews.append(UIView.spacer(withHeight: 2))
            subviews.append(buildHeaderSubtitleLabel(attributedText: attributedText, font: font))
        }

        func buildHeaderSubtitleLabel(attributedText: NSAttributedString,
                                      font: UIFont?) -> UILabel {
            let label = UILabel()

            // Defaults need to be set *before* assigning the attributed text,
            // or the attributes will get overriden
            label.textColor = Theme.secondaryTextAndIconColor
            label.lineBreakMode = .byTruncatingTail
            if let font = font {
                label.font = font
            } else {
                label.font = UIFont.ows_regularFont(withSize: viewController.subtitlePointSize)
            }

            label.attributedText = attributedText

            return label
        }

        mutating func addLastSubviews() {
            // TODO Message Request: In order to debug the profile is getting shared in the right moments,
            // display the thread whitelist state in settings. Eventually we can probably delete this.
            #if DEBUG
            let viewController = self.viewController
            let isThreadInProfileWhitelist =
                viewController.databaseStorage.uiRead { transaction in
                    return viewController.profileManager.isThread(inProfileWhitelist: viewController.thread,
                                                                  transaction: transaction)
            }
            let hasSharedProfile = String(format: "Whitelisted: %@", isThreadInProfileWhitelist ? "Yes" : "No")
            addSubtitleLabel(text: hasSharedProfile)
            #endif
        }

        func build() -> UIView {
            let headerView = UIView()
            headerView.backgroundColor = Theme.backgroundColor
            headerView.frame = CGRect(x: 0, y: 0, width: WIDTH_SCREEN, height: 120)
            headerView.autoSetDimension(.height, toSize: 120)
            
            let firstView = subviews.first!
            let otherViews = Array(subviews[2...subviews.count-1])
            
            let avatarStackView = UIStackView(arrangedSubviews: [firstView])
            avatarStackView.axis = .horizontal
            avatarStackView.alignment = .fill
            avatarStackView.spacing = 30
            avatarStackView.autoSetDimension(.height, toSize: CGFloat(kLargeAvatarSize))
            
            let labelStackView = UIStackView(arrangedSubviews: otherViews)
            labelStackView.axis = .vertical
            labelStackView.alignment = .fill
            let containerView = UIView()
            containerView.backgroundColor = .clear
            containerView.addSubview(labelStackView)
            labelStackView.autoPinEdge(toSuperviewEdge: .top, withInset: 25)
            labelStackView.autoPinEdge(toSuperviewEdge: .left, withInset: 0)
            labelStackView.autoPinEdge(toSuperviewEdge: .right, withInset: 0)
            
            avatarStackView.addArrangedSubview(containerView)
            
            headerView.addSubview(avatarStackView)
            
            avatarStackView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 8, leading: 18, bottom: 16, trailing: 18))
            avatarStackView.addBackgroundView(withBackgroundColor: ConversationSettingsViewController.headerBackgroundColor)
            
            headerView.isUserInteractionEnabled = true
            headerView.accessibilityIdentifier = UIView.accessibilityIdentifier(in: viewController, name: "mainSectionHeader")
            if viewController.canEditConversationAttributes {
                headerView.addGestureRecognizer(UITapGestureRecognizer(target: viewController, action: #selector(conversationNameTouched)))
            }
            
            let mainStackView = UIStackView(arrangedSubviews: [headerView])
            mainStackView.axis = .vertical
            mainStackView.alignment = .fill
            mainStackView.isLayoutMarginsRelativeArrangement = true

            return mainStackView
        }
    }

    private func buildHeaderForGroup(groupThread: TSGroupThread) -> UIView {
        var builder = HeaderBuilder(viewController: self)

        let memberCount = groupThread.groupModel.groupMembership.nonPendingMembers.count
        let groupMembersText = GroupViewUtils.formatGroupMembersLabel(memberCount: memberCount)
        builder.addSubtitleLabel(text: groupMembersText,
                                 font: .ows_dynamicTypeSubheadline)

        builder.addLastSubviews()

        let header = builder.build()

        // This will not appear in public builds.
        if DebugFlags.groupsV2showV2Indicator {
            let indicatorLabel = UILabel()
            indicatorLabel.text = thread.isGroupV2Thread ? "v2" : "v1"
            indicatorLabel.textColor = Theme.secondaryTextAndIconColor
            indicatorLabel.font = .ows_dynamicTypeBody
            header.addSubview(indicatorLabel)
            indicatorLabel.autoPinEdge(toSuperviewMargin: .trailing)
            indicatorLabel.autoPinEdge(toSuperviewMargin: .bottom)
        }

        return header
    }

    private func buildHeaderForContact(contactThread: TSContactThread) -> UIView {
        var builder = HeaderBuilder(viewController: self)

        let threadName = contactsManager.displayNameWithSneakyTransaction(thread: contactThread)
        let recipientAddress = contactThread.contactAddress
        if let phoneNumber = recipientAddress.phoneNumber {
            let formattedPhoneNumber =
                PhoneNumber.bestEffortFormatPartialUserSpecifiedText(toLookLikeAPhoneNumber: phoneNumber)
            if threadName != formattedPhoneNumber {
                builder.addSubtitleLabel(text: formattedPhoneNumber)
            }
        }

        if let username = (databaseStorage.uiRead { transaction in
            return self.profileManager.username(for: recipientAddress, transaction: transaction)
        }),
            username.count > 0 {
            if let formattedUsername = CommonFormats.formatUsername(username),
                threadName != formattedUsername {
                builder.addSubtitleLabel(text: formattedUsername)
            }
        }

        if DebugFlags.showProfileKeyAndUuidsIndicator {
            let uuidText = String(format: "UUID: %@", contactThread.contactAddress.uuid?.uuidString ?? "Unknown")
            builder.addSubtitleLabel(text: uuidText)
        }

        let isVerified = identityManager.verificationState(for: recipientAddress) == .verified
        if isVerified {
            let subtitle = NSMutableAttributedString()
            // "checkmark"
            subtitle.append("\u{f00c} ",
                            attributes: [
                                .font: UIFont.ows_fontAwesomeFont(subtitlePointSize)
            ])
            subtitle.append(NSLocalizedString("PRIVACY_IDENTITY_IS_VERIFIED_BADGE",
                                              comment: "Badge indicating that the user is verified."))
            builder.addSubtitleLabel(attributedText: subtitle)
        }

        // This will not appear in public builds.
        if DebugFlags.showProfileKeyAndUuidsIndicator {
            let hasProfileKey = self.databaseStorage.uiRead { transaction in
                self.profileManager.profileKeyData(for: recipientAddress, transaction: transaction) != nil
            }

            let subtitle = "Has Profile Key: \(hasProfileKey)"
            builder.addSubtitleLabel(attributedText: subtitle.asAttributedString)
        }

        builder.addLastSubviews()

        return builder.build()
    }

    func buildMainHeader() -> UIView {
        if let groupThread = thread as? TSGroupThread {
            return buildHeaderForGroup(groupThread: groupThread)
        } else if let contactThread = thread as? TSContactThread {
            return buildHeaderForContact(contactThread: contactThread)
        } else {
            owsFailDebug("Invalid thread.")
            return UIView()
        }
    }
}
