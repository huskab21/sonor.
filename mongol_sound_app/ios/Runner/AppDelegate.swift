import AVFoundation
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var deviceChannel: FlutterMethodChannel?
  private var torchRun = 0
  private var savedBrightness: CGFloat?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "sonor/device",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      let args = call.arguments as? [String: Any] ?? [:]
      switch call.method {
      case "flash":
        result(
          self?.flashTorch(
            times: args["times"] as? Int ?? 2,
            onMs: args["onMs"] as? Int ?? 300,
            offMs: args["offMs"] as? Int ?? 300
          ) ?? false
        )
      case "keepAwake":
        // Хүлээх горим: дэлгэц өөрөө унтрахгүй
        UIApplication.shared.isIdleTimerDisabled = args["on"] as? Bool ?? false
        result(nil)
      case "brightness":
        self?.setBrightness(args["value"] as? Double)
        result(nil)
      case "openUrl":
        // Өөр апп руу үсрэх (жишээ нь Sign Bridge). Тэр апп суугаагүй бол false.
        guard let url = URL(string: args["url"] as? String ?? "") else {
          result(false)
          return
        }
        UIApplication.shared.open(url, options: [:]) { ok in result(ok) }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    deviceChannel = channel
  }

  // Дэлгэцийн гэрэлтүүлэг: утга өгвөл тохируулна, nil бол хэрэглэгчийн өмнөх утгыг сэргээнэ.
  private func setBrightness(_ value: Double?) {
    if let value = value {
      if savedBrightness == nil { savedBrightness = UIScreen.main.brightness }
      UIScreen.main.brightness = CGFloat(value)
    } else if let saved = savedBrightness {
      UIScreen.main.brightness = saved
      savedBrightness = nil
    }
  }

  // Арын гар чийдэнг анивчуулна. Шинэ дохио ирвэл өмнөх анивчилт зогсоно.
  private func flashTorch(times: Int, onMs: Int, offMs: Int) -> Bool {
    guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else {
      return false
    }
    torchRun += 1
    let run = torchRun
    for i in 0..<times {
      let start = i * (onMs + offMs)
      for (delay, on) in [(start, true), (start + onMs, false)] {
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(delay)) { [weak self] in
          guard self?.torchRun == run else { return }
          try? device.lockForConfiguration()
          device.torchMode = on ? .on : .off
          device.unlockForConfiguration()
        }
      }
    }
    return true
  }
}
