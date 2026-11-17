package com.jstack.jwallet

import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyPermanentlyInvalidatedException
import android.security.keystore.KeyProperties
import android.util.Base64
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.PrivateKey
import java.security.Signature
import java.security.spec.ECGenParameterSpec
import java.util.UUID

class MainActivity : FlutterFragmentActivity() {
    private val deviceAlias = "jwallet.device.signing.v1"
    private val keyStore by lazy { KeyStore.getInstance("AndroidKeyStore").apply { load(null) } }
    private var pending: MethodChannel.Result? = null
    private var prompt: BiometricPrompt? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.jstack.jwallet/device_keys")
            .setMethodCallHandler(::handle)
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "devicePublicKey" -> {
                    ensureKey(deviceAlias, false)
                    result.success(publicKey(deviceAlias))
                }
                "signDevice" -> result.success(sign(deviceAlias, required(call, "payload")))
                "biometricAvailable" -> result.success(available())
                "hasBiometricKey" -> {
                    val alias = biometricAlias(call)
                    val exists = if (!keyStore.containsAlias(alias)) false else try {
                        signer(alias)
                        true
                    } catch (_: KeyPermanentlyInvalidatedException) { false }
                    result.success(exists)
                }
                "enrollBiometricKey" -> authenticate(call, result, true)
                "signBiometric" -> authenticate(call, result, false)
                else -> result.notImplemented()
            }
        } catch (_: KeyPermanentlyInvalidatedException) {
            result.error("KEY_INVALIDATED", "Biometrics changed. Please set up biometric approval again.", null)
        } catch (_: MissingKey) {
            result.error("KEY_MISSING", "This device's signing key is missing.", null)
        } catch (_: Exception) {
            result.error("SECURITY_ERROR", "Unable to access device security. Please try again.", null)
        }
    }

    private fun required(call: MethodCall, name: String): String =
        requireNotNull(call.argument<String>(name)).also { require(it.isNotEmpty() && it.length <= 16384) }

    private fun biometricAlias(call: MethodCall): String {
        val userId = required(call, "userId")
        require(userId.matches(Regex("[A-Za-z0-9_-]{1,128}")))
        return "jwallet.biometric.$userId"
    }

    private fun available() = BiometricManager.from(this).canAuthenticate(
        BiometricManager.Authenticators.BIOMETRIC_STRONG
    ) == BiometricManager.BIOMETRIC_SUCCESS

    private fun ensureKey(alias: String, biometric: Boolean) {
        if (keyStore.containsAlias(alias)) return
        val spec = KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_SIGN or KeyProperties.PURPOSE_VERIFY)
            .setAlgorithmParameterSpec(ECGenParameterSpec("secp256r1"))
            .setDigests(KeyProperties.DIGEST_SHA256)
            .setUserAuthenticationRequired(biometric)
        if (biometric) {
            spec.setInvalidatedByBiometricEnrollment(true)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                spec.setUserAuthenticationParameters(0, KeyProperties.AUTH_BIOMETRIC_STRONG)
            } else {
                @Suppress("DEPRECATION")
                spec.setUserAuthenticationValidityDurationSeconds(-1)
            }
        }
        KeyPairGenerator.getInstance(KeyProperties.KEY_ALGORITHM_EC, "AndroidKeyStore").apply {
            initialize(spec.build())
            generateKeyPair()
        }
    }

    private fun publicKey(alias: String): String = Base64.encodeToString(
        (keyStore.getCertificate(alias) ?: throw MissingKey()).publicKey.encoded, Base64.NO_WRAP
    )

    private fun signer(alias: String): Signature {
        val privateKey = keyStore.getKey(alias, null) as? PrivateKey ?: throw MissingKey()
        return Signature.getInstance("SHA256withECDSA").apply { initSign(privateKey) }
    }

    private fun sign(alias: String, payload: String): String = signer(alias).run {
        update(payload.toByteArray(Charsets.UTF_8))
        Base64.encodeToString(sign(), Base64.NO_WRAP)
    }

    private fun authenticate(call: MethodCall, result: MethodChannel.Result, enrolling: Boolean) {
        if (pending != null) { result.error("BUSY", "A biometric prompt is already open.", null); return }
        if (!available()) { result.error("UNAVAILABLE", "Set up a supported fingerprint or face in your device settings first.", null); return }
        val alias = biometricAlias(call)
        if (enrolling) ensureKey(alias, true)
        val signature = try { signer(alias) } catch (error: KeyPermanentlyInvalidatedException) {
            if (!enrolling) throw error
            keyStore.deleteEntry(alias)
            ensureKey(alias, true)
            signer(alias)
        }
        val payload = if (enrolling) "JWALLET-ENROLL\n${UUID.randomUUID()}" else required(call, "payload")
        pending = result
        prompt = BiometricPrompt(this, ContextCompat.getMainExecutor(this), object : BiometricPrompt.AuthenticationCallback() {
            override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                val reply = pending ?: return
                pending = null
                val cancelled = errorCode == BiometricPrompt.ERROR_USER_CANCELED ||
                    errorCode == BiometricPrompt.ERROR_NEGATIVE_BUTTON || errorCode == BiometricPrompt.ERROR_CANCELED
                reply.error(if (cancelled) "BIOMETRIC_CANCELLED" else "BIOMETRIC_ERROR", errString.toString(), null)
            }

            override fun onAuthenticationSucceeded(auth: BiometricPrompt.AuthenticationResult) {
                val reply = pending ?: return
                pending = null
                try {
                    val unlocked = auth.cryptoObject?.signature ?: throw MissingKey()
                    unlocked.update(payload.toByteArray(Charsets.UTF_8))
                    val signed = Base64.encodeToString(unlocked.sign(), Base64.NO_WRAP)
                    reply.success(if (enrolling) publicKey(alias) else signed)
                } catch (_: Exception) {
                    reply.error("SECURITY_ERROR", "Unable to complete biometric approval. Please try again.", null)
                }
            }
        })
        try {
            prompt!!.authenticate(BiometricPrompt.PromptInfo.Builder()
                .setTitle(if (enrolling) "Enable biometric approval" else "Approve with biometrics")
                .setSubtitle("Confirm it is you to use jWallet securely")
                .setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_STRONG)
                .setNegativeButtonText("Cancel")
                .build(), BiometricPrompt.CryptoObject(signature))
        } catch (error: Exception) { pending = null; throw error }
    }

    override fun onDestroy() {
        prompt?.cancelAuthentication()
        pending?.error("BIOMETRIC_CANCELLED", "Biometric approval was cancelled.", null)
        pending = null
        super.onDestroy()
    }

    private class MissingKey : Exception()
}
