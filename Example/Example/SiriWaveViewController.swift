import UIKit
import SiriWave

/**
 * Demo view controller showcasing the SiriWaveView animation
 * Provides controls for amplitude, speed, and start/stop functionality
 */
class SiriWaveViewController: UIViewController {

    // MARK: - UI Elements
    private var waveView: SiriWaveView!
    private var containerView: UIView!
    private var controlsStackView: UIStackView!

    private var amplitudeSlider: UISlider!
    private var speedSlider: UISlider!
    private var amplitudeLabel: UILabel!
    private var speedLabel: UILabel!
    private var playPauseButton: UIButton!

    private var titleLabel: UILabel!

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupWaveView()
        setupConstraints()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        waveView.start()
    }

    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .black

        setupTitleLabel()
        setupContainerView()
        setupControls()
    }

    private func setupTitleLabel() {
        titleLabel = UILabel()
        titleLabel.text = "Siri Wave iOS9+"
        titleLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
    }

    private func setupContainerView() {
        containerView = UIView()
        containerView.backgroundColor = .black
        containerView.layer.cornerRadius = 12
        containerView.layer.borderWidth = 1
        containerView.layer.borderColor = UIColor.gray.withAlphaComponent(0.3).cgColor
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)
    }

    private func setupControls() {
        // Stack view for controls
        controlsStackView = UIStackView()
        controlsStackView.axis = .vertical
        controlsStackView.spacing = 20
        controlsStackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(controlsStackView)

        // Amplitude controls
        let amplitudeStack = createSliderStack(
            title: "Amplitude",
            minValue: 0.0,
            maxValue: 2.0,
            initialValue: 1.0,
            action: #selector(amplitudeChanged(_:))
        )
        amplitudeSlider = amplitudeStack.slider
        amplitudeLabel = amplitudeStack.label
        controlsStackView.addArrangedSubview(amplitudeStack.container)

        // Speed controls
        let speedStack = createSliderStack(
            title: "Speed",
            minValue: 0.0,
            maxValue: 1.0,
            initialValue: 0.2,
            action: #selector(speedChanged(_:))
        )
        speedSlider = speedStack.slider
        speedLabel = speedStack.label
        controlsStackView.addArrangedSubview(speedStack.container)

        // Play/Pause button
        setupPlayPauseButton()
        controlsStackView.addArrangedSubview(playPauseButton)
    }

    private func createSliderStack(
        title: String,
        minValue: Float,
        maxValue: Float,
        initialValue: Float,
        action: Selector
    ) -> (container: UIView, slider: UISlider, label: UILabel) {

        let container = UIView()

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let valueLabel = UILabel()
        valueLabel.text = String(format: "%.2f", initialValue)
        valueLabel.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        valueLabel.textColor = .lightGray
        valueLabel.textAlignment = .right
        valueLabel.translatesAutoresizingMaskIntoConstraints = false

        let slider = UISlider()
        slider.minimumValue = minValue
        slider.maximumValue = maxValue
        slider.value = initialValue
        slider.tintColor = .systemBlue
        slider.addTarget(self, action: action, for: .valueChanged)
        slider.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(titleLabel)
        container.addSubview(valueLabel)
        container.addSubview(slider)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),

            valueLabel.topAnchor.constraint(equalTo: container.topAnchor),
            valueLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            valueLabel.widthAnchor.constraint(equalToConstant: 60),

            slider.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            slider.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            slider.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            slider.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        return (container, slider, valueLabel)
    }

    private func setupPlayPauseButton() {
        playPauseButton = UIButton(type: .system)
        playPauseButton.setTitle("⏸ Pause", for: .normal)
        playPauseButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        playPauseButton.tintColor = .white
        playPauseButton.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.2)
        playPauseButton.layer.cornerRadius = 8
        playPauseButton.addTarget(self, action: #selector(playPauseButtonTapped), for: .touchUpInside)
        playPauseButton.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            playPauseButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    private func setupWaveView() {
        waveView = SiriWaveView.create(in: containerView, autoStart: false)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Title
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            // Container view (wave view container)
            containerView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 30),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            containerView.heightAnchor.constraint(equalToConstant: 200),

            // Controls
            controlsStackView.topAnchor.constraint(equalTo: containerView.bottomAnchor, constant: 40),
            controlsStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            controlsStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            controlsStackView.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
    }

    // MARK: - Actions
    @objc private func amplitudeChanged(_ sender: UISlider) {
        let value = sender.value
        amplitudeLabel.text = String(format: "%.2f", value)
        waveView.setAmplitude(Double(value))
    }

    @objc private func speedChanged(_ sender: UISlider) {
        let value = sender.value
        speedLabel.text = String(format: "%.2f", value)
        waveView.setSpeed(Double(value))
    }

    @objc private func playPauseButtonTapped() {
        if waveView.isRunning {
            waveView.stop()
            playPauseButton.setTitle("▶️ Play", for: .normal)
        } else {
            waveView.start()
            playPauseButton.setTitle("⏸ Pause", for: .normal)
        }
    }

    // MARK: - Status Bar
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
}

// MARK: - SceneDelegate Integration Helper
extension SiriWaveViewController {

    /**
     * Convenience method to create and present the demo
     */
    static func createDemo() -> UIViewController {
        let controller = SiriWaveViewController()
        controller.modalPresentationStyle = .fullScreen
        return controller
    }
}
