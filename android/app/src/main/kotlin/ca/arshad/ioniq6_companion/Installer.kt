package ca.arshad.ioniq6_companion

import android.content.Context
import android.content.Intent
import androidx.core.content.FileProvider
import java.io.File

/** Hands a downloaded update APK to Android's package installer. */
object Installer {
    fun install(context: Context, path: String) {
        val uri = FileProvider.getUriForFile(context, "${context.packageName}.updates", File(path))
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(intent)
    }
}
