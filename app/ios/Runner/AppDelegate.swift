import AVFoundation
import Flutter
import Speech
import UIKit
import Vision

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
  private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
  private var audioEngine = AVAudioEngine()
  private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
  private var recognitionTask: SFSpeechRecognitionTask?
  private var pendingResult: FlutterResult?
  private var pendingOcrResult: FlutterResult?
  private var latestTranscript: String = ""

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "SpeechBridge") {
      let speechChannel = FlutterMethodChannel(
        name: "com.hadz.hanzi_app/speech",
        binaryMessenger: registrar.messenger()
      )
      speechChannel.setMethodCallHandler { [weak self] call, result in
        guard let self = self else { return }
        switch call.method {
        case "isAvailable":
          result(self.speechRecognizer?.isAvailable ?? false)
        case "listen":
          self.startListening(result: result)
        case "stop":
          self.finishListening()
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }

      let ocrChannel = FlutterMethodChannel(
        name: "com.hadz.hanzi_app/ocr",
        binaryMessenger: registrar.messenger()
      )
      ocrChannel.setMethodCallHandler { [weak self] call, result in
        guard let self = self else { return }
        switch call.method {
        case "scanCamera":
          self.presentImagePicker(source: .camera, result: result)
        case "scanGallery":
          self.presentImagePicker(source: .photoLibrary, result: result)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
  }

  private func presentImagePicker(source: UIImagePickerController.SourceType, result: @escaping FlutterResult) {
    guard UIImagePickerController.isSourceTypeAvailable(source),
          let rootVC = window?.rootViewController else {
      result(FlutterError(code: "UNAVAILABLE", message: "Thiết bị không hỗ trợ nguồn ảnh này", details: nil))
      return
    }
    pendingOcrResult = result
    let picker = UIImagePickerController()
    picker.sourceType = source
    picker.delegate = self
    rootVC.present(picker, animated: true)
  }

  func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
    picker.dismiss(animated: true)
    pendingOcrResult?(FlutterError(code: "CANCELLED", message: "Đã huỷ chọn ảnh", details: nil))
    pendingOcrResult = nil
  }

  func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
    picker.dismiss(animated: true)
    guard let res = pendingOcrResult else { return }
    pendingOcrResult = nil
    guard let image = info[.originalImage] as? UIImage,
          let cgImage = image.cgImage else {
      res(FlutterError(code: "NO_IMAGE", message: "Không đọc được ảnh", details: nil))
      return
    }

    let request = VNRecognizeTextRequest { req, err in
      if let err = err {
        res(FlutterError(code: "OCR_ERROR", message: err.localizedDescription, details: nil))
        return
      }
      let observations = req.results as? [VNRecognizedTextObservation] ?? []
      let lines = observations.compactMap { $0.topCandidates(1).first?.string }
      let text = lines.joined(separator: "\n")
      let jpegData = image.jpegData(compressionQuality: 0.85)
      var payload: [String: Any] = ["text": text]
      if let jpegData = jpegData {
        payload["image"] = FlutterStandardTypedData(bytes: jpegData)
      }
      res(payload)
    }
    request.recognitionLevel = .accurate
    request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]
    request.usesLanguageCorrection = true

    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    DispatchQueue.global(qos: .userInitiated).async {
      do {
        try handler.perform([request])
      } catch {
        DispatchQueue.main.async {
          res(FlutterError(code: "OCR_FAILED", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  private func startListening(result: @escaping FlutterResult) {
    SFSpeechRecognizer.requestAuthorization { status in
      DispatchQueue.main.async {
        guard status == .authorized else {
          result(FlutterError(code: "PERMISSION", message: "Chưa cấp quyền nhận diện giọng nói", details: nil))
          return
        }
        self.beginRecording(result: result)
      }
    }
  }

  private func beginRecording(result: @escaping FlutterResult) {
    recognitionTask?.cancel()
    recognitionTask = nil
    pendingResult = result
    latestTranscript = ""

    let audioSession = AVAudioSession.sharedInstance()
    do {
      try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
      try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    } catch {
      pendingResult = nil
      result(FlutterError(code: "AUDIO", message: error.localizedDescription, details: nil))
      return
    }

    recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
    guard let recognitionRequest = recognitionRequest else {
      pendingResult = nil
      result(FlutterError(code: "REQUEST", message: "Không tạo được request", details: nil))
      return
    }
    recognitionRequest.shouldReportPartialResults = true
    if #available(iOS 13, *), speechRecognizer?.supportsOnDeviceRecognition == true {
      recognitionRequest.requiresOnDeviceRecognition = true
    }

    let inputNode = audioEngine.inputNode
    recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] res, err in
      guard let self = self else { return }
      if let res = res {
        self.latestTranscript = res.bestTranscription.formattedString
        if res.isFinal {
          self.completeResult()
        }
      }
      if err != nil {
        self.completeResult()
      }
    }

    let format = inputNode.outputFormat(forBus: 0)
    inputNode.removeTap(onBus: 0)
    inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
      self.recognitionRequest?.append(buffer)
    }
    audioEngine.prepare()
    do {
      try audioEngine.start()
      DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
        if self?.audioEngine.isRunning == true {
          self?.finishListening()
        }
      }
    } catch {
      pendingResult = nil
      result(FlutterError(code: "ENGINE", message: error.localizedDescription, details: nil))
    }
  }

  private func finishListening() {
    if audioEngine.isRunning {
      audioEngine.stop()
      audioEngine.inputNode.removeTap(onBus: 0)
      recognitionRequest?.endAudio()
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
      self?.completeResult()
    }
  }

  private func completeResult() {
    guard let r = pendingResult else { return }
    pendingResult = nil
    if audioEngine.isRunning {
      audioEngine.stop()
      audioEngine.inputNode.removeTap(onBus: 0)
    }
    recognitionRequest = nil
    recognitionTask = nil
    r(latestTranscript)
  }
}
