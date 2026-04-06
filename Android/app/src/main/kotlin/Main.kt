package orthodox.korea

import skip.lib.*
import skip.model.*
import skip.foundation.*
import skip.ui.*

import android.Manifest
import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.graphics.Color as AndroidColor
import android.webkit.CookieManager
import android.webkit.WebStorage
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.SystemBarStyle
import androidx.activity.ComponentActivity
import androidx.appcompat.app.AppCompatActivity
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.Box
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.saveable.rememberSaveableStateHolder
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.platform.LocalContext
import androidx.compose.material3.MaterialTheme
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.onesignal.OneSignal
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.xmlpull.v1.XmlPullParser
import org.xmlpull.v1.XmlPullParserFactory
import java.io.StringReader
import java.net.HttpURLConnection
import java.net.URL

internal val logger: SkipLogger = SkipLogger(subsystem = "orthodox.korea", category = "OrthodoxKorea")
private const val notificationURLExtra = "notification_url"
private const val appStatePreferences = "app_state"
private const val initialWebDataClearedKey = "initial_web_data_cleared"

private typealias AppRootView = OrthodoxKoreaRootView
private typealias AppDelegate = OrthodoxKoreaAppDelegate

// MARK: - Application

open class AndroidAppMain: Application {
    constructor() {
    }

    override fun onCreate() {
        super.onCreate()
        logger.info("starting app")
        ProcessInfo.launch(applicationContext)

        if (!getSharedPreferences(appStatePreferences, Context.MODE_PRIVATE).getBoolean(initialWebDataClearedKey, false)) {
            // Clear stale web content once on first launch after install.
            try {
                WebStorage.getInstance().deleteAllData()
                CookieManager.getInstance().removeAllCookies(null)
                CookieManager.getInstance().flush()
                cacheDir.listFiles()?.forEach { file ->
                    if (file.name.contains("WebView", ignoreCase = true) ||
                        file.name.contains("chromium", ignoreCase = true)) {
                        file.deleteRecursively()
                    }
                }
                getSharedPreferences(appStatePreferences, Context.MODE_PRIVATE)
                    .edit()
                    .putBoolean(initialWebDataClearedKey, true)
                    .apply()
            } catch (e: Exception) {
                logger.info("Cache clear: ${e.message}")
            }
        }

        // Initialize OneSignal (App ID from BuildConfig/gradle.properties)
        OneSignal.initWithContext(this, BuildConfig.ONESIGNAL_APP_ID)

        // Track push clicks to avoid duplicate RSS notifications
        OneSignal.Notifications.addClickListener(object : com.onesignal.notifications.INotificationClickListener {
            override fun onClick(event: com.onesignal.notifications.INotificationClickEvent) {
                val prefs = getSharedPreferences("post_check", Context.MODE_PRIVATE)
                prefs.edit().putLong("lastPushTime", System.currentTimeMillis()).apply()
                NotificationRouteBridge.shared.route(event.result.url)
            }
        })

        // Create notification channel for local notifications (RSS backup)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "new_posts",
                "New Posts",
                NotificationManager.IMPORTANCE_DEFAULT
            )
            channel.description = "Notifications when new posts are published"
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }

        AppDelegate.shared.onInit()
    }

    companion object {
    }
}

// MARK: - Activity

open class MainActivity: AppCompatActivity {
    constructor() {
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        UIApplication.launch(this)
        enableEdgeToEdge()

        setContent {
            val saveableStateHolder = rememberSaveableStateHolder()
            saveableStateHolder.SaveableStateProvider(true) {
                PresentationRootView(ComposeContext())
                SideEffect { saveableStateHolder.removeState(true) }
            }
        }

        AppDelegate.shared.onLaunch()
        handleNotificationIntent(intent)

        // Request notification permission on Android 13+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val permissions = kotlin.arrayOf(Manifest.permission.POST_NOTIFICATIONS)
            ActivityCompat.requestPermissions(this, permissions, 1001)
        }

        CoroutineScope(Dispatchers.IO).launch {
            OneSignal.Notifications.requestPermission(true)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleNotificationIntent(intent)
    }

    override fun onStart() {
        super.onStart()
    }

    override fun onResume() {
        super.onResume()
        AppDelegate.shared.onResume()
        CoroutineScope(Dispatchers.IO).launch {
            PostCheckHelper.checkForNewPosts(this@MainActivity)
        }
    }

    override fun onPause() {
        super.onPause()
        AppDelegate.shared.onPause()
    }

    override fun onStop() {
        super.onStop()
        AppDelegate.shared.onStop()
    }

    override fun onDestroy() {
        super.onDestroy()
        AppDelegate.shared.onDestroy()
    }

    override fun onLowMemory() {
        super.onLowMemory()
        AppDelegate.shared.onLowMemory()
    }

    override fun onRestart() {
        super.onRestart()
    }

    override fun onSaveInstanceState(outState: android.os.Bundle): Unit = super.onSaveInstanceState(outState)

    override fun onRestoreInstanceState(bundle: android.os.Bundle) {
        super.onRestoreInstanceState(bundle)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: kotlin.Array<String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 1001) {
            val granted = grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
            logger.info(if (granted) "Notification permission granted" else "Notification permission denied")
        }
    }

    private fun handleNotificationIntent(intent: Intent?) {
        val urlString = intent?.getStringExtra(notificationURLExtra) ?: intent?.dataString
        NotificationRouteBridge.shared.route(urlString)
    }

    companion object {
    }
}

// MARK: - RSS Feed Checker

object PostCheckHelper {
    private val languageCodes = listOf("en", "ko", "el", "ru", "uk")

    private val preferredLanguage: String
        get() {
            val deviceLang = java.util.Locale.getDefault().language.lowercase()
            return if (languageCodes.contains(deviceLang)) deviceLang else "en"
        }

    suspend fun checkForNewPosts(context: Context) {
        withContext(Dispatchers.IO) {
            try {
                val prefs = context.getSharedPreferences("post_check", Context.MODE_PRIVATE)
                var notificationTitle: String? = null
                var notificationUrl: String? = null

                val preferred = preferredLanguage
                val orderedCodes = listOf(preferred) + languageCodes.filter { it != preferred }

                for (code in orderedCodes) {
                    try {
                        val url = URL("https://orthodoxkorea.org/${code}/feed/")
                        val connection = url.openConnection() as HttpURLConnection
                        connection.requestMethod = "GET"
                        connection.connectTimeout = 15000
                        connection.readTimeout = 15000

                        val response = connection.inputStream.bufferedReader().readText()
                        connection.disconnect()

                        val post = parseLatestPost(response) ?: continue

                        val key = "lastSeenGuid_${code}"
                        val lastSeenGuid = prefs.getString(key, null)

                        if (lastSeenGuid == null) {
                            prefs.edit().putString(key, post.guid).apply()
                        } else if (post.guid != lastSeenGuid) {
                            prefs.edit().putString(key, post.guid).apply()
                            if (notificationTitle == null) {
                                notificationTitle = post.title
                                notificationUrl = post.url
                            }
                        }
                    } catch (e: Exception) {
                        // Network error — skip this language
                    }
                }

                if (notificationTitle != null) {
                    val lastPushTime = prefs.getLong("lastPushTime", 0L)
                    val hoursSinceLastPush = (System.currentTimeMillis() - lastPushTime) / 3600000.0
                    if (lastPushTime == 0L || hoursSinceLastPush > 2) {
                        sendNotification(context, notificationTitle, notificationUrl)
                    }
                }
            } catch (e: Exception) {
                // Post check failed
            }
        }
    }

    private data class RSSPost(val title: String, val guid: String, val url: String?)

    private fun parseLatestPost(xml: String): RSSPost? {
        val factory = XmlPullParserFactory.newInstance()
        val parser = factory.newPullParser()
        parser.setInput(StringReader(xml))

        var insideItem = false
        var currentTag = ""
        var title = ""
        var guid = ""
        var link = ""

        while (parser.eventType != XmlPullParser.END_DOCUMENT) {
            when (parser.eventType) {
                XmlPullParser.START_TAG -> {
                    currentTag = parser.name
                    if (currentTag == "item") {
                        insideItem = true
                        title = ""
                        guid = ""
                        link = ""
                    }
                }
                XmlPullParser.TEXT -> {
                    if (insideItem) {
                        when (currentTag) {
                            "title" -> title += parser.text
                            "guid" -> guid += parser.text
                            "link" -> link += parser.text
                        }
                    }
                }
                XmlPullParser.END_TAG -> {
                    if (parser.name == "item" && insideItem) {
                        val trimmedGuid = guid.trim()
                        val trimmedLink = link.trim()
                        val url = normalizedNotificationURL(trimmedLink) ?: normalizedNotificationURL(trimmedGuid)
                        return RSSPost(title.trim(), trimmedGuid, url?.absoluteString)
                    }
                    currentTag = ""
                }
            }
            parser.next()
        }
        return null
    }

    private fun sendNotification(context: Context, title: String, url: String?) {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            if (url != null) {
                putExtra(notificationURLExtra, url)
            }
        }
        val pendingIntent = PendingIntent.getActivity(
            context, 0, intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val notification = NotificationCompat.Builder(context, "new_posts")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("Orthodox Korea")
            .setContentText(title)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .build()

        val notificationManager = NotificationManagerCompat.from(context)
        try {
            notificationManager.notify(System.currentTimeMillis().toInt(), notification)
        } catch (e: SecurityException) {
            // Notification permission not granted
        }
    }
}

@Composable
internal fun SyncSystemBarsWithTheme() {
    val dark = MaterialTheme.colorScheme.background.luminance() < 0.5f

    val transparent = AndroidColor.TRANSPARENT
    val style = if (dark) {
        SystemBarStyle.dark(transparent)
    } else {
        SystemBarStyle.light(transparent, transparent)
    }

    val activity = LocalContext.current as? ComponentActivity
    DisposableEffect(style) {
        activity?.enableEdgeToEdge(
            statusBarStyle = style,
            navigationBarStyle = style
        )
        onDispose { }
    }
}

@Composable
internal fun PresentationRootView(context: ComposeContext) {
    val colorScheme = if (isSystemInDarkTheme()) ColorScheme.dark else ColorScheme.light
    PresentationRoot(defaultColorScheme = colorScheme, context = context) { ctx ->
        SyncSystemBarsWithTheme()
        val contentContext = ctx.content()
        Box(modifier = ctx.modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            AppRootView().Compose(context = contentContext)
        }
    }
}
