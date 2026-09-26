package tech.mbkm.energrow.alarm

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import android.util.Log
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
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
 */
object AlarmTokenStore {
    private const val TAG = "EnerGrowAlarmToken"
    private const val PREFS = "energrow_alarm_credentials"
    private const val KEY_ALIAS = "energrow_alarm_credentials_key"
    private const val TRANSFORMATION = "AES/GCM/NoPadding"
    private const val TAG_BITS = 128

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
        val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (keyStore.getEntry(KEY_ALIAS, null) as? KeyStore.SecretKeyEntry)
            ?.let { return it.secretKey }

        val generator = KeyGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_AES,
            "AndroidKeyStore",
        )
        val spec = KeyGenParameterSpec.Builder(
            KEY_ALIAS,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256)
            .setUserAuthenticationRequired(false)
            .build()
        generator.init(spec)
        return generator.generateKey()
    }
}
