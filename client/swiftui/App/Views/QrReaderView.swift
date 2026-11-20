import SwiftUI
import AVFoundation

struct QrReaderView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Binding var navigationPath: NavigationPath
    @State private var assembler = QrChunkAssembler()
    @State private var scannedCount = 0
    @State private var totalCount = 0
    @State private var cameraDenied = false

    var body: some View {
        VStack(spacing: 0) {
            AmneziaNavigationBar(title: "QR code", onBack: { dismiss() })
            Text("Point the camera at the QR code and hold for a couple of seconds.")
                .font(AmneziaTheme.Font.body)
                .foregroundColor(AmneziaTheme.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 8)
            ZStack {
                QrCameraView(onScan: handleScan, onDenied: { cameraDenied = true })
                    .cornerRadius(16)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AmneziaTheme.accentLight, lineWidth: 2)
                    .frame(width: 240, height: 240)
                if cameraDenied {
                    Text("Camera access is required to scan QR codes. Allow it in Settings.")
                        .font(AmneziaTheme.Font.body)
                        .foregroundColor(AmneziaTheme.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
            if totalCount > 0 {
                Text("Scanned \(scannedCount) of \(totalCount).")
                    .font(AmneziaTheme.Font.body)
                    .foregroundColor(AmneziaTheme.textPrimary)
                    .padding(.top, 16)
                ProgressView(value: Double(scannedCount), total: Double(totalCount))
                    .tint(AmneziaTheme.accentLight)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }
            Spacer()
        }
        .background(AmneziaTheme.bgBase)
        .navigationBarHidden(true)
    }

    private func handleScan(_ text: String) {
        if let payload = assembler.feed(text) {
            finish(with: payload)
            return
        }
        if assembler.totalCount > 0 {
            scannedCount = assembler.scannedCount
            totalCount = assembler.totalCount
            return
        }
        finish(with: text)
    }

    private func finish(with data: Data) {
        do {
            let imported = try Importer.extractConfigFromQrData(data, fileName: "", nextServerName: appState.core.nextAvailableServerName())
            navigationPath.append(WizardDestination.viewConfig(imported))
        } catch {
            appState.showSnackbar(error.localizedDescription)
            assembler.reset()
            scannedCount = 0
            totalCount = 0
        }
    }

    private func finish(with text: String) {
        do {
            let imported = try Importer.extractConfigFromData(text, fileName: "", nextServerName: appState.core.nextAvailableServerName())
            navigationPath.append(WizardDestination.viewConfig(imported))
        } catch {
            appState.showSnackbar(error.localizedDescription)
            assembler.reset()
            scannedCount = 0
            totalCount = 0
        }
    }
}

struct QrCameraView: UIViewControllerRepresentable {
    let onScan: (String) -> Void
    let onDenied: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan, onDenied: onDenied)
    }

    func makeUIViewController(context: Context) -> QrCameraViewController {
        let controller = QrCameraViewController()
        controller.onScan = onScan
        controller.onDenied = onDenied
        return controller
    }

    func updateUIViewController(_ uiViewController: QrCameraViewController, context: Context) {}

    final class Coordinator {
        let onScan: (String) -> Void
        let onDenied: () -> Void

        init(onScan: @escaping (String) -> Void, onDenied: @escaping () -> Void) {
            self.onScan = onScan
            self.onDenied = onDenied
        }
    }
}

final class QrCameraViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onScan: ((String) -> Void)?
    var onDenied: (() -> Void)?

    private var captureSession: AVCaptureSession?
    private var lastScanned: String?
    private var lastScanDate = Date.distantPast

    override func viewDidLoad() {
        super.viewDidLoad()
        checkCameraPermission()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        captureSession?.stopRunning()
    }

    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.setupSession()
                    } else {
                        self?.onDenied?()
                    }
                }
            }
        default:
            onDenied?()
        }
    }

    private func setupSession() {
        let session = AVCaptureSession()
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)
        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        output.metadataObjectTypes = [.qr]
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        captureSession = session
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let text = object.stringValue, !text.isEmpty else { return }
        if text == lastScanned && Date().timeIntervalSince(lastScanDate) < 1.0 {
            return
        }
        lastScanned = text
        lastScanDate = Date()
        onScan?(text)
    }
}
