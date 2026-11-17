import Flutter
import UIKit
import LocalAuthentication
import Security

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "JWalletDeviceKeys") {
      JWalletDeviceKeys.register(with: registrar)
    }
  }
}

/// Native keys are never returned to Dart; only SPKI public keys and DER signatures.
final class JWalletDeviceKeys: NSObject, FlutterPlugin {
  private let queue = DispatchQueue(label: "com.jstack.jwallet.keys")
  private let deviceTag = "jwallet.device.signing.v1"

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "com.jstack.jwallet/device_keys", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(JWalletDeviceKeys(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    queue.async {
      do {
        let value: Any
        switch call.method {
        case "devicePublicKey":
          value = try self.publicKey(self.key(tag: self.deviceTag, create: true, biometric: false))
        case "signDevice":
          value = try self.sign(self.key(tag: self.deviceTag, create: false, biometric: false), payload: self.argument(args, "payload"))
        case "biometricAvailable":
          value = self.available()
        case "hasBiometricKey":
          let tag = try self.biometricTag(args)
          let context = LAContext()
          context.interactionNotAllowed = true
          value = (try? self.key(tag: tag, create: false, biometric: true, context: context)) != nil
        case "enrollBiometricKey", "signBiometric":
          guard self.available() else { throw KeyFailure("UNAVAILABLE", "Set up Face ID or Touch ID in your device settings first.") }
          let enrolling = call.method == "enrollBiometricKey"
          let tag = try self.biometricTag(args)
          let context = LAContext()
          context.localizedFallbackTitle = ""
          context.touchIDAuthenticationAllowableReuseDuration = 0
          defer { context.invalidate() }
          let key = try self.key(tag: tag, create: enrolling, biometric: true, context: context)
          let payload = enrolling ? "JWALLET-ENROLL\n\(UUID().uuidString)" : try self.argument(args, "payload")
          let signature = try self.sign(key, payload: payload)
          value = enrolling ? try self.publicKey(key) : signature
        default:
          DispatchQueue.main.async { result(FlutterMethodNotImplemented) }
          return
        }
        DispatchQueue.main.async { result(value) }
      } catch let error as KeyFailure {
        DispatchQueue.main.async { result(FlutterError(code: error.code, message: error.message, details: nil)) }
      } catch {
        let native = error as NSError
        let cancelled = native.code == Int(errSecUserCanceled) ||
          (native.domain == LAError.errorDomain && [LAError.userCancel.rawValue, LAError.appCancel.rawValue, LAError.systemCancel.rawValue].contains(native.code))
        DispatchQueue.main.async {
          result(FlutterError(code: cancelled ? "BIOMETRIC_CANCELLED" : "SECURITY_ERROR",
            message: cancelled ? "Biometric approval was cancelled." : "Unable to access device security. Please try again.", details: nil))
        }
      }
    }
  }

  private func argument(_ args: [String: Any], _ name: String) throws -> String {
    guard let value = args[name] as? String, !value.isEmpty, value.count <= 16384 else {
      throw KeyFailure("INVALID_ARGUMENT", "Invalid security request.")
    }
    return value
  }

  private func biometricTag(_ args: [String: Any]) throws -> String {
    let user = try argument(args, "userId")
    guard user.range(of: "^[A-Za-z0-9_-]{1,128}$", options: .regularExpression) != nil else {
      throw KeyFailure("INVALID_ARGUMENT", "Invalid account identifier.")
    }
    return "jwallet.biometric.\(user)"
  }

  private func available() -> Bool {
    LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
  }

  private func key(tag: String, create: Bool, biometric: Bool, context: LAContext? = nil) throws -> SecKey {
    let tagData = Data(tag.utf8)
    var query: [String: Any] = [kSecClass as String: kSecClassKey,
      kSecAttrApplicationTag as String: tagData, kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
      kSecReturnRef as String: true]
    if let context = context {
      query[kSecUseAuthenticationContext as String] = context
      query[kSecUseOperationPrompt as String] = "Approve with Face ID or Touch ID to secure your jWallet."
    }
    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    if status == errSecSuccess, let item = item { return item as! SecKey }
    guard create && status == errSecItemNotFound else {
      if status == errSecItemNotFound { throw KeyFailure("KEY_MISSING", "This device's signing key is missing.") }
      throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
    }
    var error: Unmanaged<CFError>?
    var privateAttributes: [String: Any] = [kSecAttrIsPermanent as String: true, kSecAttrApplicationTag as String: tagData]
    var attributes: [String: Any] = [kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom, kSecAttrKeySizeInBits as String: 256]
    if biometric {
      guard let access = SecAccessControlCreateWithFlags(nil, kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        [.privateKeyUsage, .biometryCurrentSet], &error) else { throw error!.takeRetainedValue() as Error }
      privateAttributes[kSecAttrAccessControl as String] = access
      attributes[kSecAttrTokenID as String] = kSecAttrTokenIDSecureEnclave
    } else {
      privateAttributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    }
    attributes[kSecPrivateKeyAttrs as String] = privateAttributes
    guard let generated = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else { throw error!.takeRetainedValue() as Error }
    // Reload with a fresh authentication context, including for first enrollment.
    if biometric { return try key(tag: tag, create: false, biometric: true, context: context) }
    return generated
  }

  private func publicKey(_ key: SecKey) throws -> String {
    var error: Unmanaged<CFError>?
    guard let publicKey = SecKeyCopyPublicKey(key), let raw = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
      throw KeyFailure("SECURITY_ERROR", "Unable to read the public signing key.")
    }
    // P-256 SubjectPublicKeyInfo prefix followed by the 65-byte X9.63 point.
    let prefix: [UInt8] = [0x30,0x59,0x30,0x13,0x06,0x07,0x2a,0x86,0x48,0xce,0x3d,0x02,0x01,0x06,0x08,0x2a,0x86,0x48,0xce,0x3d,0x03,0x01,0x07,0x03,0x42,0x00]
    guard raw.count == 65 else { throw KeyFailure("SECURITY_ERROR", "Unexpected public key format.") }
    return (Data(prefix) + raw).base64EncodedString()
  }

  private func sign(_ key: SecKey, payload: String) throws -> String {
    var error: Unmanaged<CFError>?
    guard let signature = SecKeyCreateSignature(key, .ecdsaSignatureMessageX962SHA256, Data(payload.utf8) as CFData, &error) as Data? else {
      throw error!.takeRetainedValue() as Error
    }
    return signature.base64EncodedString()
  }

  private struct KeyFailure: Error {
    let code: String
    let message: String
    init(_ code: String, _ message: String) { self.code = code; self.message = message }
  }
}
