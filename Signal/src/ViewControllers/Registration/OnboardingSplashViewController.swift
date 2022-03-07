//
//  Copyright (c) 2020 Open Whisper Systems. All rights reserved.
//

import UIKit
import PromiseKit
import SafariServices
import PureLayout

@objc
public class OnboardingSplashViewController: OnboardingBaseViewController {

    let modeSwitchButton = UIButton()

    override var primaryLayoutMargins: UIEdgeInsets {
        var defaultMargins = super.primaryLayoutMargins
        // we want the hero image a bit closer to the top than most
        // onboarding content
        defaultMargins.top = 16
        return defaultMargins
    }

    override public func loadView() {
        view = UIView()
        view.addSubview(primaryView)
        primaryView.autoPinEdgesToSuperviewEdges()

//        view.addSubview(modeSwitchButton)
//        modeSwitchButton.setTemplateImageName(
//            OnboardingController.defaultOnboardingMode == .registering ? "link-24" : "link-broken-24",
//            tintColor: .ows_gray25
//        )
//        modeSwitchButton.autoSetDimensions(to: CGSize(square: 40))
//        modeSwitchButton.autoPinEdge(toSuperviewMargin: .trailing)
//        modeSwitchButton.autoPinEdge(toSuperviewMargin: .top)
//        modeSwitchButton.addTarget(self, action: #selector(didTapModeSwitch), for: .touchUpInside)
//        modeSwitchButton.accessibilityIdentifier = "onboarding.splash.modeSwitch"
//
//        modeSwitchButton.isHidden = !UIDevice.current.isIPad && !FeatureFlags.linkedPhones

        
//        view.backgroundColor = Theme.backgroundColor
        

        let screenSize: CGRect = UIScreen.main.bounds
        let screenWidth = screenSize.width
        let screenHeight = screenSize.height
    
        let heroImage = UIImage(named: "0-dog-background")
        let heroImageView = UIImageView(image: heroImage)
        heroImageView.contentMode = .scaleAspectFill
        heroImageView.layer.minificationFilter = .trilinear
        heroImageView.layer.magnificationFilter = .trilinear
        heroImageView.setCompressionResistanceLow()
        heroImageView.setContentHuggingVerticalLow()
        heroImageView.accessibilityIdentifier = "onboarding.splash." + "heroImageView"
        heroImageView.frame = CGRect(x: 0, y: 0, width: screenWidth, height: screenHeight)
        primaryView.addSubview(heroImageView)
        
        // Logo
        let logoImage = UIImage(named: "0-you-sh")
        let logoImageView = UIImageView(image: logoImage)
        logoImageView.contentMode = .scaleAspectFit
        logoImageView.layer.minificationFilter = .trilinear
        logoImageView.layer.magnificationFilter = .trilinear
        logoImageView.setCompressionResistanceLow()
        logoImageView.setContentHuggingVerticalLow()
        logoImageView.accessibilityIdentifier = "onboarding.splash." + "logoImageView"
        logoImageView.frame = CGRect(x: 0, y: 0, width: screenHeight * (90/736) * (175.11/90), height: screenHeight * (90/736))
        logoImageView.center = CGPoint(x: screenWidth/2, y: screenHeight/5)
        primaryView.addSubview(logoImageView)
        

        let titleLabel = UILabel()
        titleLabel.text = NSLocalizedString("ONBOARDING_SPLASH_TITLE", comment: "Title of the 'onboarding splash' view.")
        titleLabel.font = UIFont(name: Fonts.Roboto_Medium, size: 20)
        titleLabel.textColor = Theme.youshGoldColor
        titleLabel.layer.opacity = 0.62
        titleLabel.numberOfLines = 0
        titleLabel.textAlignment = .center
        titleLabel.lineBreakMode = .byWordWrapping
        titleLabel.isUserInteractionEnabled = true
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.accessibilityIdentifier = "onboarding.splash." + "titleLabel"

        let explanationLabel = UILabel()
        explanationLabel.text = NSLocalizedString("ONBOARDING_SPLASH_TERM_AND_PRIVACY_POLICY",
                                                  comment: "Link to the 'terms and privacy policy' in the 'onboarding splash' view.")
        explanationLabel.textColor = Theme.youshGoldColor
        explanationLabel.font = UIFont(name: Fonts.Roboto_Medium, size: 14)
        explanationLabel.numberOfLines = 0
        explanationLabel.textAlignment = .center
        explanationLabel.lineBreakMode = .byWordWrapping
        explanationLabel.isUserInteractionEnabled = false
//        explanationLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(explanationLabelTapped)))
        explanationLabel.accessibilityIdentifier = "onboarding.splash." + "explanationLabel"

        let continueButton = self.primaryButton(title: "",
                                                    selector: #selector(continuePressed))
        continueButton.accessibilityIdentifier = "onboarding.splash." + "continueButton"
        continueButton.setBackgroundColors(upColor: Theme.youshGoldColor)
        continueButton.setTitle(title: CommonStrings.continueButton, font: UIFont(name: Fonts.Roboto_Medium, size: 20)!, titleColor: .white)
        let primaryButtonView = OnboardingBaseViewController.horizontallyWrap(primaryButton: continueButton)
        
        let stackView = UIStackView(arrangedSubviews: [
            UIView(),
            titleLabel,
            UIView.spacer(withHeight: screenHeight / 2.2),
            explanationLabel,
            UIView.spacer(withHeight: 24),
            primaryButtonView
        ])
        
        
        stackView.axis = .vertical
        stackView.alignment = .fill
        primaryView.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewMargins()
        
        //add debug gesture
        let hiddenView = UIView(frame: CGRect())
        hiddenView.backgroundColor = .clear
        view.addSubview(hiddenView)
        hiddenView.autoPinEdge(toSuperviewSafeArea: .top, withInset: 0)
        hiddenView.autoPinEdge(toSuperviewSafeArea: .right, withInset: 0)
        hiddenView.autoSetDimensions(to: CGSize(width: 100, height: 100))
        let gesture = UILongPressGestureRecognizer(target: self, action: #selector(debugTrigger(_:)))
        gesture.numberOfTapsRequired = 2
        gesture.minimumPressDuration = 1.5
        hiddenView.addGestureRecognizer(gesture)
    }
    
    @objc
    func debugTrigger(_ gesture: UILongPressGestureRecognizer) {
//        cloudtest093.xyz
//        testsignalchat.xyz
        guard gesture.state == .began else {
            return
        }
        func forceStaging() {
            TSConstants.forceStaging()
            OWSActionSheets.showActionSheet(
                title: "Đổi qua server cloudtest093 thành công",
                message: "Tắt app để mở lại"
            ) { _ in
                SignalApp.resetAppData(false)
                //To save enviroment in user default
                TSConstants.forceStaging()
                exit(0)
            }
        }
        
        func forceProduction() {
            TSConstants.forceProduction()
            OWSActionSheets.showActionSheet(
                title: "Đổi qua server testsignalchat thành công",
                message: "Tắt app để mở lại"
            ) { _ in
                SignalApp.resetAppData(false)
                //To save enviroment in user default
                TSConstants.forceProduction()
                exit(0)
            }
        }
        
        func forceDev() {
            TSConstants.forceDev()
            OWSActionSheets.showActionSheet(
                title: "Đổi qua server dev-signal-chat thành công",
                message: "Tắt app để mở lại"
            ) { _ in
                SignalApp.resetAppData(false)
                //To save enviroment in user default
                TSConstants.forceDev()
                exit(0)
            }
        }
        
        let url = TSConstants.textSecureServerURL
        let actionSheet = ActionSheetController(title: "Đang dùng server \(url)", message: nil)
        actionSheet.addAction(OWSActionSheets.cancelAction)
        
        let proAction = ActionSheetAction(title: "Đổi qua server testsignalchat.xyz?", accessibilityIdentifier: nil, style: .default) { _ in
            forceProduction()
        }
        let stgAction = ActionSheetAction(title: "Đổi qua server cloudtest093.xyz?", accessibilityIdentifier: nil, style: .default) { _ in
            forceStaging()
        }
        let devAction = ActionSheetAction(title: "Đổi qua server dev-signal-chat?", accessibilityIdentifier: nil, style: .default) { _ in
            forceDev()
        }
        
        if url.contains("testsignalchat.xyz") {
            actionSheet.addAction(stgAction)
            actionSheet.addAction(devAction)
        }
        else if url.contains("cloudtest093.xyz") {
            actionSheet.addAction(proAction)
            actionSheet.addAction(devAction)
        }else {
            actionSheet.addAction(proAction)
            actionSheet.addAction(stgAction)
        }
        
        CurrentAppContext().frontmostViewController()?.present(actionSheet, animated: true)
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        
    }

    // MARK: - Events

    @objc func didTapModeSwitch() {
        Logger.info("")

        onboardingController.onboardingSplashRequestedModeSwitch(viewController: self)
    }

    @objc func explanationLabelTapped(sender: UIGestureRecognizer) {
        guard sender.state == .recognized else {
            return
        }
        guard let url = URL(string: kLegalTermsUrlString) else {
            owsFailDebug("Invalid URL.")
            return
        }
        let safariVC = SFSafariViewController(url: url)
        present(safariVC, animated: true)
    }

    @objc func continuePressed() {
        Logger.info("")

        onboardingController.onboardingSplashDidComplete(viewController: self)
    }
}

extension UIStackView {
    func addBorder(color: UIColor, backgroundColor: UIColor, thickness: CGFloat) {
        let insetView = UIView(frame: bounds)
        insetView.backgroundColor = backgroundColor
        insetView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        insertSubview(insetView, at: 0)

        let borderBounds = CGRect(
            x: thickness,
            y: thickness,
            width: frame.size.width - thickness * 2,
            height: frame.size.height - thickness * 2)

        let borderView = UIView(frame: borderBounds)
        borderView.backgroundColor = color
        borderView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        insertSubview(borderView, at: 0)
    }
}
