package dev.vz.ljod.data.security

import android.content.Context
import android.content.SharedPreferences
import android.util.Base64
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import timber.log.Timber
import java.security.SecureRandom

object SecureStore {

    private const val FILE_NAME = "ljod_secure"

    private var appContext: Context? = null

    private val backing: SharedPreferences by lazy {
        val context = appContext ?: error("SecureStore.init(context) must be called first")
        try {
            val masterKey = MasterKey.Builder(context)
                .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
                .build()
            EncryptedSharedPreferences.create(
                context,
                FILE_NAME,
                masterKey,
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
            )
        } catch (e: Exception) {
            Timber.w(e, "Falling back to non-encrypted prefs")
            context.getSharedPreferences(FILE_NAME + "_fallback", Context.MODE_PRIVATE)
        }
    }

    fun init(context: Context) {
        if (appContext == null) appContext = context.applicationContext
    }

    fun putString(key: String, value: String?) {
        backing.edit().apply {
            if (value == null) remove(key) else putString(key, value)
        }.apply()
    }

    fun getString(key: String, default: String? = null): String? = backing.getString(key, default)

    fun putLong(key: String, value: Long) { backing.edit().putLong(key, value).apply() }
    fun getLong(key: String, default: Long = 0L): Long = backing.getLong(key, default)

    fun remove(key: String) { backing.edit().remove(key).apply() }
    fun clear() { backing.edit().clear().apply() }

    fun isHardwareBackedKeyStore(): Boolean = try {
        val ks = java.security.KeyStore.getInstance("AndroidKeyStore")
        ks.load(null)
        true
    } catch (e: Exception) {
        Timber.e(e, "KeyStore load failed")
        false
    }

    fun randomToken(byteCount: Int = 16): String {
        val random = SecureRandom()
        val bytes = ByteArray(byteCount)
        random.nextBytes(bytes)
        return Base64.encodeToString(bytes, Base64.NO_WRAP or Base64.URL_SAFE)
    }

    fun rotateSessionToken(): String {
        val token = randomToken(24)
        backing.edit().putString("session_token", token).apply()
        return token
    }
}
