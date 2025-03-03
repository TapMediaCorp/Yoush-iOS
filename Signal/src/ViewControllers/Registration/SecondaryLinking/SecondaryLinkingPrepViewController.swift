//
//  Copyright (c) 2020 Open Whisper Systems. All rights reserved.
//

import Foundation
import PromiseKit
import Lottie

@objc
public class SecondaryLinkingPrepViewController: OnboardingBaseViewController {

    lazy var animationView = UIImageView()
    let isTransferring: Bool

    public init(onboardingController: OnboardingController, isTransferring: Bool) {
        self.isTransferring = isTransferring
        super.init(onboardingController: onboardingController)
    }

    override public func loadView() {
        view = UIView()
        view.addSubview(primaryView)
        primaryView.autoPinEdgesToSuperviewEdges()

        view.backgroundColor = Theme.backgroundColor
        
        animationView.contentMode = .scaleAspectFit
        animationView.setContentHuggingHigh()
//        if isTransferring {
//            animationView.image = UIImage(named: "yoush-ipad")
//        }else {
//            animationView.image = UIImage(named: "yoush-iphone")
//        }
        animationView.image = UIImage(named: "yoush-ipad")
        let titleText: String
        if isTransferring {
            titleText = NSLocalizedString("SECONDARY_TRANSFER_GET_STARTED_BY_OPENING_IPAD",
                                          comment: "header text before the user can transfer to this device")

        } else {
            titleText = NSLocalizedString("SECONDARY_ONBOARDING_GET_STARTED_BY_OPENING_PRIMARY",
                                          comment: "header text before the user can link this device")
        }

        let titleLabel = self.titleLabel(text: titleText)
        primaryView.addSubview(titleLabel)
        titleLabel.accessibilityIdentifier = "onboarding.prelink.titleLabel"

        let dontHaveSignalButton = UILabel()
        dontHaveSignalButton.text = NSLocalizedString("SECONDARY_ONBOARDING_GET_STARTED_DO_NOT_HAVE_PRIMARY",
                                                      comment: "Link explaining what to do when trying to link a device before having a primary device.")
        dontHaveSignalButton.textColor = Theme.accentBlueColor
        dontHaveSignalButton.font = UIFont.ows_dynamicTypeSubheadlineClamped
        dontHaveSignalButton.numberOfLines = 0
        dontHaveSignalButton.textAlignment = .center
        dontHaveSignalButton.lineBreakMode = .byWordWrapping
        dontHaveSignalButton.isUserInteractionEnabled = true
        dontHaveSignalButton.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapExplanationLabel)))
        dontHaveSignalButton.accessibilityIdentifier = "onboarding.prelink.explanationLabel"
        dontHaveSignalButton.isHidden = isTransferring

        let nextButton = self.primaryButton(title: CommonStrings.nextButton,
                                            selector: #selector(didPressNext))
        nextButton.accessibilityIdentifier = "onboarding.prelink.nextButton"
        let primaryButtonView = OnboardingBaseViewController.horizontallyWrap(primaryButton: nextButton)

        let stackView = UIStackView(arrangedSubviews: [
            titleLabel,
            UIView.spacer(withHeight: 12),
            animationView,
            dontHaveSignalButton,
            UIView.vStretchingSpacer(minHeight: 12),
            primaryButtonView
            ])
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.spacing = 12
        primaryView.addSubview(stackView)

        stackView.autoPinEdgesToSuperviewMargins()
    }

    // MARK: - Events

    @objc
    func didTapExplanationLabel(sender: UIGestureRecognizer) {
        guard sender.state == .recognized else {
            owsFailDebug("unexpected state: \(sender.state)")
            return
        }

        let title = NSLocalizedString("SECONDARY_ONBOARDING_INSTALL_PRIMARY_FIRST_TITLE", comment: "alert title")
        let message = NSLocalizedString("SECONDARY_ONBOARDING_INSTALL_PRIMARY_FIRST_BODY", comment: "alert body")
        let alert = ActionSheetController(title: title, message: message)

        let dismissTitle = NSLocalizedString("ALERT_ACTION_ACKNOWLEDGE", comment: "generic button text to acknowledge that the corresponding text was read.")

        alert.addAction(
            ActionSheetAction(title: dismissTitle,
                          accessibilityIdentifier: UIView.accessibilityIdentifier(containerName: "alert", name: "acknowledge"),
                          style: .default)
        )

        presentActionSheet(alert)
    }

    @objc
    func didPressNext() {
        Logger.info("")

        if isTransferring {
            onboardingController.transferAccount(fromViewController: self)
        } else {
            let provisioningController = ProvisioningController(onboardingController: onboardingController)
            provisioningController.didConfirmSecondaryDevice(from: self)
        }
    }
}
