// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

import UIKit
import Flutter
import datadog_session_replay

class FirstViewController: UIViewController {

    private let sliderValueLabel = UILabel()
    private let switchStateLabel = UILabel()
    private let segmentedValueLabel = UILabel()
    private let radioValueLabel = UILabel()
    private let iconStatusLabel = UILabel()

    private let radioOptions = ["Small", "Medium", "Large"]
    private var radioButtons: [UIButton] = []
    private var selectedRadioIndex = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Native iOS Controls"
        buildUI()
    }

    // MARK: - UI

    private func buildUI() {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 24
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: safe.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: safe.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: safe.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: safe.bottomAnchor),

            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -20),
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -40),
        ])

        stack.addArrangedSubview(makeHeader("Welcome", subtitle: "Try the native controls below"))
        stack.addArrangedSubview(makeSliderSection())
        stack.addArrangedSubview(makeSwitchSection())
        stack.addArrangedSubview(makeSegmentedSection())
        stack.addArrangedSubview(makeEmbeddedFlutterSection())
        stack.addArrangedSubview(makeRadioSection())
        stack.addArrangedSubview(makeIconButtonsSection())
        stack.addArrangedSubview(makeFlutterButton())
    }

    private func makeHeader(_ title: String, subtitle: String) -> UIView {
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 28, weight: .bold)

        let subtitleLabel = UILabel()
        subtitleLabel.text = subtitle
        subtitleLabel.font = .systemFont(ofSize: 15)
        subtitleLabel.textColor = .secondaryLabel

        let stack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        stack.axis = .vertical
        stack.spacing = 4
        return stack
    }

    private func makeSliderSection() -> UIView {
        sliderValueLabel.text = "Value: 50"
        sliderValueLabel.font = .systemFont(ofSize: 15, weight: .medium)

        let slider = UISlider()
        slider.minimumValue = 0
        slider.maximumValue = 100
        slider.value = 50
        slider.minimumTrackTintColor = .systemBlue
        slider.addTarget(self, action: #selector(sliderChanged(_:)), for: .valueChanged)

        return cardSection(title: "Slider", valueLabel: sliderValueLabel, control: slider)
    }

    private func makeSwitchSection() -> UIView {
        switchStateLabel.text = "State: OFF"
        switchStateLabel.font = .systemFont(ofSize: 15, weight: .medium)

        let toggle = UISwitch()
        toggle.isOn = false
        toggle.onTintColor = .systemGreen
        toggle.addTarget(self, action: #selector(switchToggled(_:)), for: .valueChanged)

        let row = UIStackView(arrangedSubviews: [makeLabel("Enable notifications"), UIView(), toggle])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 8

        return cardSection(title: "Switch", valueLabel: switchStateLabel, control: row)
    }

    private func makeSegmentedSection() -> UIView {
        segmentedValueLabel.text = "Selected: One"
        segmentedValueLabel.font = .systemFont(ofSize: 15, weight: .medium)

        let segmented = UISegmentedControl(items: ["One", "Two", "Three"])
        segmented.selectedSegmentIndex = 0
        segmented.addTarget(self, action: #selector(segmentChanged(_:)), for: .valueChanged)

        return cardSection(title: "Segmented Control", valueLabel: segmentedValueLabel, control: segmented)
    }

    private func makeRadioSection() -> UIView {
        radioValueLabel.text = "Selected: \(radioOptions[selectedRadioIndex])"
        radioValueLabel.font = .systemFont(ofSize: 15, weight: .medium)

        let radioStack = UIStackView()
        radioStack.axis = .vertical
        radioStack.spacing = 8

        for (index, option) in radioOptions.enumerated() {
            let button = UIButton(type: .system)
            button.tag = index
            button.contentHorizontalAlignment = .leading
            button.tintColor = .systemBlue
            button.setTitleColor(.label, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 16)
            button.addTarget(self, action: #selector(radioTapped(_:)), for: .touchUpInside)
            updateRadioButton(button, title: option, selected: index == selectedRadioIndex)
            radioButtons.append(button)
            radioStack.addArrangedSubview(button)
        }

        return cardSection(title: "Radio Buttons", valueLabel: radioValueLabel, control: radioStack)
    }

    private func makeIconButtonsSection() -> UIView {
        iconStatusLabel.text = "Tap an icon"
        iconStatusLabel.font = .systemFont(ofSize: 15, weight: .medium)

        let icons: [(symbol: String, name: String, color: UIColor)] = [
            ("heart.fill", "Heart", .systemPink),
            ("star.fill", "Star", .systemYellow),
            ("bell.fill", "Bell", .systemOrange),
            ("bookmark.fill", "Bookmark", .systemPurple),
            ("paperplane.fill", "Send", .systemBlue),
        ]

        let row = UIStackView()
        row.axis = .horizontal
        row.distribution = .equalSpacing
        row.alignment = .center

        for icon in icons {
            let button = UIButton(type: .system)
            let config = UIImage.SymbolConfiguration(pointSize: 26, weight: .semibold)
            button.setImage(UIImage(systemName: icon.symbol, withConfiguration: config), for: .normal)
            button.tintColor = icon.color
            button.accessibilityLabel = icon.name
            button.addAction(UIAction { [weak self] _ in
                self?.iconStatusLabel.text = "Tapped: \(icon.name)"
            }, for: .touchUpInside)
            row.addArrangedSubview(button)
        }

        return cardSection(title: "Icon Buttons", valueLabel: iconStatusLabel, control: row)
    }

    private func makeEmbeddedFlutterSection() -> UIView {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let flutterVC = FlutterViewController(
            engine: appDelegate.embeddedFlutterEngine,
            nibName: nil,
            bundle: nil
        )
        // Opts the embedded Flutter view in to the native Session Replay, so its content is
        // composited into this screen's replay where the panel sits.
        flutterVC.dd.enableSessionReplay()

        addChild(flutterVC)
        flutterVC.view.translatesAutoresizingMaskIntoConstraints = false
        flutterVC.view.heightAnchor.constraint(equalToConstant: 220).isActive = true
        flutterVC.view.layer.cornerRadius = 8
        flutterVC.view.clipsToBounds = true
        flutterVC.didMove(toParent: self)

        let titleLabel = UILabel()
        titleLabel.text = "Embedded Flutter Panel"
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)

        let stack = UIStackView(arrangedSubviews: [titleLabel, flutterVC.view])
        stack.axis = .vertical
        stack.spacing = 12
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        stack.backgroundColor = .secondarySystemBackground
        stack.layer.cornerRadius = 12
        return stack
    }

    private func makeFlutterButton() -> UIView {
        var config = UIButton.Configuration.filled()
        config.title = "Open Flutter View"
        config.image = UIImage(systemName: "arrow.right.circle.fill")
        config.imagePadding = 8
        config.baseBackgroundColor = .systemIndigo
        config.cornerStyle = .large

        let button = UIButton(configuration: config)
        button.addTarget(self, action: #selector(openFlutterView(_:)), for: .touchUpInside)
        button.heightAnchor.constraint(equalToConstant: 50).isActive = true
        return button
    }

    // MARK: - Helpers

    private func cardSection(title: String, valueLabel: UILabel, control: UIView) -> UIView {
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)

        let stack = UIStackView(arrangedSubviews: [titleLabel, control, valueLabel])
        stack.axis = .vertical
        stack.spacing = 12
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        stack.backgroundColor = .secondarySystemBackground
        stack.layer.cornerRadius = 12
        return stack
    }

    private func makeLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 16)
        return label
    }

    private func updateRadioButton(_ button: UIButton, title: String, selected: Bool) {
        let symbolName = selected ? "largecircle.fill.circle" : "circle"
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .regular)
        button.setImage(UIImage(systemName: symbolName, withConfiguration: config), for: .normal)
        button.setTitle("  \(title)", for: .normal)
    }

    // MARK: - Actions

    @objc private func sliderChanged(_ sender: UISlider) {
        sliderValueLabel.text = "Value: \(Int(sender.value))"
    }

    @objc private func switchToggled(_ sender: UISwitch) {
        switchStateLabel.text = "State: \(sender.isOn ? "ON" : "OFF")"
    }

    @objc private func segmentChanged(_ sender: UISegmentedControl) {
        let title = sender.titleForSegment(at: sender.selectedSegmentIndex) ?? ""
        segmentedValueLabel.text = "Selected: \(title)"
    }

    @objc private func radioTapped(_ sender: UIButton) {
        selectedRadioIndex = sender.tag
        for (index, button) in radioButtons.enumerated() {
            updateRadioButton(button, title: radioOptions[index], selected: index == selectedRadioIndex)
        }
        radioValueLabel.text = "Selected: \(radioOptions[selectedRadioIndex])"
    }

    @IBAction func openFlutterView(_ sender: Any) {
        let flutterEngine = (UIApplication.shared.delegate as! AppDelegate).flutterEngine
        let flutterViewController = FlutterViewController(engine: flutterEngine, nibName: nil, bundle: nil)
        // Opts this Flutter view in to the native Session Replay. Flutter must also be configured
        // with `isEmbedded: true` on the Dart side.
        flutterViewController.dd.enableSessionReplay()
        flutterViewController.modalPresentationStyle = .overFullScreen

        // The Flutter "Back to native" button asks to close this view.
        let channel = FlutterMethodChannel(
            name: "hybrid_session_replay_example/navigation",
            binaryMessenger: flutterViewController.binaryMessenger
        )
        channel.setMethodCallHandler { [weak flutterViewController] call, result in
            if call.method == "dismiss" {
                flutterViewController?.dismiss(animated: true)
                result(nil)
            } else {
                result(FlutterMethodNotImplemented)
            }
        }

        present(flutterViewController, animated: true)
    }
}
