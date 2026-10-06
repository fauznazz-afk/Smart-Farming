package tech.mbkm.energrow.alarm

import android.content.Context
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyInfo
import android.security.keystore.KeyProperties
import android.util.Base64
import android.util.Log
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.GCMParameterSpec

/**
 * Holds the ThingsBoard credentials for the background check, encrypted with a
 * key that lives in the AndroidKeyStore.
 *
 * The canonical tokens belong to `flutter_secure_storage` and never leave
 * Dart. The background check cannot use that library, because reading it needs
 * a Flutter engine, which is the thing this whole design exists to avoid. So
 * Dart hands a copy over on launch, this encrypts it under a hardware-backed
 * AES key, and only this class can read it back.
 *
 * Nothing is written in plain text: both the access token and the refresh token
 * land on disk as ciphertext, and the key material stays inside the keystore.
 * A refresh performed here updates these copies only; Dart's copies are
 * authoritative and are re-pushed on the next launch.
 *
 * Scope of the hardware-backing claim, because it is easy to over-read: this
 * file makes *its own copy* of the token as likely-hardware-backed as it can,
 * and no more. The canonical token lives in `flutter_secure_storage`, which
 * generates its keys with its own defaults and is not touched here; so the
 * credentials this module is handed are only as protected as that plugin's key.
 * Reading a Flutter plugin's key requires a Flutter engine, which is the thing
 * this module exists to avoid, so there is no way to consolidate. Treat this
 * class as hardening one link in the chain, not as making the app
 * hardware-backed end to end.
 */
object AlarmTokenStore {
    private const val TAG = "EnerGrowAlarmToken"
    private const val PREFS = "energrow_alarm_credentials"
    private const val KEY_ALIAS = "energrow_alarm_credentials_key"
    private const val TRANSFORMATION = "AES/GCM/NoPadding"
    private const val TAG_BITS = 128

    /**
     * Named once because it now appears in three places — the lookup, the
     * generator and the key-spec query — and three copies of a magic string is
     * how one of them quietly ends up querying a different provider than the one
     * that holds the key.
     */
    private const val ANDROID_KEY_STORE = "AndroidKeyStore"

    private const val PREF_ACCESS_IV = "access_iv"
    private const val PREF_ACCESS_DATA = "access_data"
    private const val PREF_REFRESH_IV = "refresh_iv"
    private const val PREF_REFRESH_DATA = "refresh_data"

    /**
     * Encrypts and stores the credentials, replacing anything held before.
     *
     * A null or blank argument clears that credential, which is what logout
     * should do. Failures are logged and swallowed: losing the background
     * check is annoying, but throwing here would take down whatever the caller
     * was doing, which on a failed login is the user's ability to retry.
     */
    fun put(context: Context, accessToken: String?, refreshToken: String?) {
        val prefs = context.applicationContext
            .getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val editor = prefs.edit()
        try {
            store(editor, PREF_ACCESS_IV, PREF_ACCESS_DATA, accessToken)
            store(editor, PREF_REFRESH_IV, PREF_REFRESH_DATA, refreshToken)
            editor.apply()
        } catch (error: Exception) {
            Log.w(TAG, "could not store alarm credentials", error)
        }
    }

    /** Returns the stored access token, or null when there is none or it is unreadable. */
    fun accessToken(context: Context): String? = read(context, PREF_ACCESS_IV, PREF_ACCESS_DATA)

    /** Returns the stored refresh token, or null. */
    fun refreshToken(context: Context): String? =
        read(context, PREF_REFRESH_IV, PREF_REFRESH_DATA)

    /**
     * Replaces the stored access token after a successful refresh.
     *
     * Only the copy here is updated. Dart keeps its own copy and overwrites this
     * one on the next launch, so there is no chance of the two disagreeing for
     * long, and no chance of this side resurrecting a session the user ended.
     */
    fun updateAccessToken(context: Context, accessToken: String) {
        val prefs = context.applicationContext
            .getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        try {
            store(
                prefs.edit(),
                PREF_ACCESS_IV,
                PREF_ACCESS_DATA,
                accessToken,
            ).apply()
        } catch (error: Exception) {
            Log.w(TAG, "could not store refreshed access token", error)
        }
    }

    /** Forgets every credential. Called on logout and when a refresh is rejected. */
    fun clear(context: Context) {
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .clear()
            .apply()
    }

    private fun store(
        editor: android.content.SharedPreferences.Editor,
        prefIv: String,
        prefData: String,
        value: String?,
    ): android.content.SharedPreferences.Editor {
        val token = value?.takeIf { it.isNotBlank() }
            ?: return editor.remove(prefIv).remove(prefData)
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, secretKey())
        val ciphertext = cipher.doFinal(token.toByteArray(Charsets.UTF_8))
        return editor
            .putString(prefIv, Base64.encodeToString(cipher.iv, Base64.NO_WRAP))
            .putString(prefData, Base64.encodeToString(ciphertext, Base64.NO_WRAP))
    }

    private fun read(
        context: Context,
        prefIv: String,
        prefData: String,
    ): String? {
        val prefs = context.applicationContext
            .getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val ivEncoded = prefs.getString(prefIv, null) ?: return null
        val dataEncoded = prefs.getString(prefData, null) ?: return null
        return try {
            val cipher = Cipher.getInstance(TRANSFORMATION)
            cipher.init(
                Cipher.DECRYPT_MODE,
                secretKey(),
                GCMParameterSpec(TAG_BITS, Base64.decode(ivEncoded, Base64.NO_WRAP)),
            )
            val plaintext = cipher.doFinal(Base64.decode(dataEncoded, Base64.NO_WRAP))
            String(plaintext, Charsets.UTF_8).takeIf { it.isNotBlank() }
        } catch (error: Exception) {
            // The keystore entry can be invalidated by a screen-lock change or a
            // restore onto new hardware. Drop the unusable material so the next
            // app launch can push fresh credentials instead of retrying forever.
            Log.w(TAG, "could not read stored alarm credential", error)
            prefs.edit().remove(prefIv).remove(prefData).apply()
            null
        }
    }

    private fun secretKey(): SecretKey {
        val keyStore = KeyStore.getInstance(ANDROID_KEY_STORE).apply { load(null) }
        (keyStore.getEntry(KEY_ALIAS, null) as? KeyStore.SecretKeyEntry)
            ?.let { return it.secretKey }

        // Ask for StrongBox first, and fall back if the platform refuses.
        //
        // `setIsStrongBoxBacked(true)` is not a preference, it is a *demand*: on a
        // device with no StrongBox the generator throws instead of quietly
        // producing a software key, so setting it unconditionally would have made
        // `secretKey()` throw on every phone without a Secure Element and taken
        // background alarms down with it — silently, because both callers here
        // catch and log. A greenhouse on a cheap handset is a real device, and
        // losing notifications there is a worse outcome for the user than the
        // key living in the TEE instead of an SE. So StrongBox is the preferred
        // path and a TEE/software key is the floor, not the other way round.
        //
        // Rejected: gating the attempt on `FEATURE_STRONGBOX_KEYSTORE`. The
        // feature flag is advisory and has been reported lying on some OEM
        // builds, and it is not needed anyway — the try/catch below is the real
        // signal, because the failure actually surfaces at generation time.
        val key = generateKey(keyStore, strongBox = true)
            ?: generateKey(keyStore, strongBox = false)
            ?: throw IllegalStateException("could not generate an AES key for the alarm credentials")
        logKeyBacking(key)
        return key
    }

    /**
     * Generates the AES key, or returns null if the platform refused this attempt.
     *
     * A refused StrongBox request can leave a half-made entry behind under the
     * same alias, and the retry would then fail with `KeyStoreException: alias
     * already exists` rather than for the real reason, so the entry is cleared
     * before returning null. Doing it here rather than at the call site keeps the
     * fallback honest: if the fallback ever fails, the log says the fallback
     * failed, instead of blaming a stale alias.
     */
    private fun generateKey(keyStore: KeyStore, strongBox: Boolean): SecretKey? = try {
        val builder = KeyGenParameterSpec.Builder(
            KEY_ALIAS,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256)
            .setUserAuthenticationRequired(false)
            .apply {
                // StrongBox is API 28+. Below that the constant does not exist and
                // there is no Secure Element to ask for, so the plain request is
                // the only one that could succeed.
                if (strongBox && Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    setIsStrongBoxBacked(true)
                }
            }
            .build()

        KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEY_STORE)
            .apply { init(builder) }
            .generateKey()
    } catch (error: Exception) {
        // The exception class name only, never the object. This is the same rule
        // the rest of the module follows: `org.json` embeds a fragment of the
        // unconsumed response in its parse errors, and on the token path that
        // response is the credential itself. A keystore failure here is not that
        // path, but a rule that only holds on the paths where it has already
        // burned is not a rule.
        Log.w(
            TAG,
            if (strongBox) {
                "StrongBox rejected the alarm credential key (${error.javaClass.simpleName}); " +
                    "falling back to the platform keystore, which may be software-backed"
            } else {
                "could not generate the alarm credential key in the platform " +
                    "keystore (${error.javaClass.simpleName})"
            },
        )
        runCatching {
            if (keyStore.containsAlias(KEY_ALIAS)) keyStore.deleteEntry(KEY_ALIAS)
        }
        null
    }

    /**
     * Records where the key actually ended up: a Secure Element, the TEE, or
     * software.
     *
     * This is in production logging rather than a test, and that is a deliberate
     * trade in the other direction from the fallback above. The fallback decides
     * *policy* — what to do when StrongBox is unavailable — and needs no
     * measurement to do that. This is *evidence*: a keystore that reports
     * software-only is not visible from the UI, from the alarm results, or from
     * any Dart-side test, so without this line the only symptom would be nothing
     * at all. It is safe to log because it is a classification of a key's
     * location, never the key or the token: no secret value, no key bytes, no
     * cipher text, nothing to redact.
     *
     * Deliberately logged once per process, at generation. Re-asserting it on
     * every read would mean a line every time `AlarmCheckRunner` refreshed a
     * token, which is noise at best and a persistent reminder of a fact that
     * cannot change for the life of the alias — the key is created once and only
     * recreated after a keystore invalidation, which replaces it wholesale. It
     * also fires only when the fallback did *not* need to be used on a device
     * whose first launch predates this change, since an existing alias is
     * returned above before anything is generated.
     */
    private fun logKeyBacking(key: SecretKey) {
        Log.i(TAG, "alarm credential key backing: ${describeBacking(key)}")
    }

    /**
     * Describes where the key lives, or "unknown" if it cannot be determined.
     *
     * Three API levels, because there are three different questions and this
     * module targets `minSdk` far below all of them.
     *
     * API 36 gives `KeyInfo.getSecurityLevel()`, which answers precisely and
     * distinguishes a Secure Element from the TEE. That distinction is the whole
     * point here: a StrongBox key and a TEE key are different answers, and the
     * log has to be able to say which happened or it cannot tell whether the
     * StrongBox request above did anything. It also replaced
     * `isInsideSecureHardware`, which is deprecated at this level, so preferring
     * it clears that deprecation instead of suppressing it.
     *
     * API 31 to 35 only has the deprecated boolean, which collapses Secure
     * Element and TEE together. Reporting it as the API 36 fact would be the
     * over-claiming this class exists to avoid, so it is labelled for what it
     * actually answers.
     *
     * Below API 31 the only accessor was `KeyInfo.isSecure()`, which has been
     * *removed* from `android.jar` — so it cannot even be referenced, despite the
     * framework still implementing it on those devices. Reflection is the only
     * way to ask, and reflection on a member that may not exist is why this
     * returns "unknown" rather than defaulting to a negative: "software-only"
     * and "cannot tell" must not print the same string, or a platform that drops
     * the member becomes indistinguishable from a compromised keystore.
     *
     * Rejected: calling `getSecurityLevel()` unconditionally. It is API 36+, and
     * an uncaught `NoSuchMethodError` here would land in the caller's broad
     * `catch`, which deletes the stored credentials and waits for the next
     * launch to re-push them — all because a diagnostic line could not run. A
     * reporting bug must not become a data-loss path.
     */
    /**
     * The API 31 to 35 answer, split out so the deprecation suppression sits on
     * the one function that needs it rather than on a whole `when` or on
     * `describeBacking` itself — a deprecation added anywhere else in this
     * class would then still be reported instead of silently absorbed.
     */
    @Suppress("DEPRECATION")
    private fun hardwareBacking(keyInfo: KeyInfo): String = if (keyInfo.isInsideSecureHardware) {
        // Deliberately does not claim StrongBox: this accessor cannot tell it
        // from the TEE, and the whole point of the log is to say which one
        // actually answered.
        "hardware (strongbox or TEE, not distinguished on this API level)"
    } else {
        "SOFTWARE ONLY"
    }

    private fun describeBacking(key: SecretKey): String = try {
        // `getKeySpec` is declared to return the wider `KeySpec`, so the cast is
        // required rather than inferred. It cannot fail for a key this class
        // generated: the same `AndroidKeyStore` provider returns a `KeyInfo` for
        // any key it holds, and anything else throws into the handlers below.
        val keyInfo = SecretKeyFactory
            .getInstance(KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEY_STORE)
            .getKeySpec(key, KeyInfo::class.java) as KeyInfo

        when {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.BAKLAVA ->
                when (keyInfo.securityLevel) {
                    KeyProperties.SECURITY_LEVEL_STRONGBOX -> "strongbox"
                    KeyProperties.SECURITY_LEVEL_TRUSTED_ENVIRONMENT -> "trusted environment (TEE)"
                    KeyProperties.SECURITY_LEVEL_SOFTWARE -> "SOFTWARE ONLY"
                    else -> "unknown"
                }

            Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> hardwareBacking(keyInfo)

            // Pre-31 this accessor means TEE and cannot see a Secure Element at
            // all, so the result is labelled as the narrower claim it is.
            else -> (keyInfo.javaClass.getMethod("isSecure").invoke(keyInfo) as? Boolean)
                ?.let { if (it) "trusted environment (TEE)" else "SOFTWARE ONLY" }
                ?: "unknown"
        }
    } catch (error: Exception) {
        // The class name only, never the exception object. That is the standing
        // rule for this module: an exception thrown while querying the key can
        // embed a fragment of the provider's response, and on the sibling
        // refresh path that response is the JWT. The classification is a
        // diagnostic and does not need the stack.
        "unknown (${error.javaClass.simpleName})"
    } catch (error: LinkageError) {
        // A member absent on this platform surfaces as `NoSuchMethodError`, which
        // is an Error rather than an Exception. Deliberately swallowed: this is
        // a diagnostic, and a device that cannot answer must not lose its
        // credentials over the attempt.
        "unknown (${error.javaClass.simpleName})"
    }
}
