package io.dartastic.made_with_flutter

import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.os.Build
import java.io.ByteArrayOutputStream
import java.io.InputStream
import java.util.zip.ZipFile

/**
 * Finds installed apps built with Flutter and extracts build details from
 * their native libraries. The channel protocol is mirrored in
 * lib/src/scanner.dart — keep the two in sync.
 *
 * Detection: an APK (base or split) containing lib/<abi>/libflutter.so is a
 * Flutter app. Deep inspection string-scans libflutter.so for the embedded
 * Dart VM version and libapp.so (the AOT snapshot) for `package:` URIs; the
 * snapshot version hash is the 32-hex string the two libraries share.
 */
class FlutterAppInspector(private val context: Context) {

    private val pm: PackageManager = context.packageManager

    fun listFlutterApps(): List<Map<String, Any?>> {
        val apps = mutableListOf<Map<String, Any?>>()
        for (info in installedApplications()) {
            if (apkPathsOf(info).none { hasFlutterLib(it) }) continue
            apps.add(
                mapOf(
                    "appId" to info.packageName,
                    "name" to pm.getApplicationLabel(info).toString(),
                    "storeVersion" to versionNameOf(info.packageName),
                    "isSystemApp" to
                        ((info.flags and ApplicationInfo.FLAG_SYSTEM) != 0),
                )
            )
        }
        return apps.sortedBy { (it["name"] as String).lowercase() }
    }

    fun inspectApp(packageName: String): Map<String, Any?> {
        val apkPaths = apkPathsOf(applicationInfo(packageName))
        val engineScan = LibraryScan(wantDartVersion = true)
        val appScan = LibraryScan(wantPackages = true)
        bestLibEntry(apkPaths, "libflutter.so")?.let { (apk, entry) ->
            scanZipEntry(apk, entry, engineScan)
        }
        val appEntry = bestLibEntry(apkPaths, "libapp.so")
        appEntry?.let { (apk, entry) -> scanZipEntry(apk, entry, appScan) }

        val raw = engineScan.dartVersionRaw
        val shared = engineScan.hexStrings intersect appScan.hexStrings
        return mapOf(
            "dartVersionRaw" to raw,
            "dartVersion" to raw?.substringBefore(' '),
            "dartChannel" to engineScan.dartChannel,
            "snapshotHash" to (shared.singleOrNull()),
            "hasAotSnapshot" to (appEntry != null),
            "packages" to appScan.packages.toList(),
        )
    }

    fun appIcon(packageName: String): ByteArray? {
        val drawable = try {
            pm.getApplicationIcon(packageName)
        } catch (e: PackageManager.NameNotFoundException) {
            return null
        }
        val bitmap = if (drawable is BitmapDrawable) {
            drawable.bitmap
        } else {
            val width = drawable.intrinsicWidth.takeIf { it > 0 } ?: ICON_SIZE
            val height = drawable.intrinsicHeight.takeIf { it > 0 } ?: ICON_SIZE
            Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888).also {
                val canvas = Canvas(it)
                drawable.setBounds(0, 0, canvas.width, canvas.height)
                drawable.draw(canvas)
            }
        }
        val out = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
        return out.toByteArray()
    }

    private fun installedApplications(): List<ApplicationInfo> =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            pm.getInstalledApplications(
                PackageManager.ApplicationInfoFlags.of(0)
            )
        } else {
            @Suppress("DEPRECATION")
            pm.getInstalledApplications(0)
        }

    private fun applicationInfo(packageName: String): ApplicationInfo =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            pm.getApplicationInfo(
                packageName,
                PackageManager.ApplicationInfoFlags.of(0),
            )
        } else {
            @Suppress("DEPRECATION")
            pm.getApplicationInfo(packageName, 0)
        }

    private fun versionNameOf(packageName: String): String? = try {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            pm.getPackageInfo(
                packageName,
                PackageManager.PackageInfoFlags.of(0),
            ).versionName
        } else {
            @Suppress("DEPRECATION")
            pm.getPackageInfo(packageName, 0).versionName
        }
    } catch (e: PackageManager.NameNotFoundException) {
        null
    }

    private fun apkPathsOf(info: ApplicationInfo): List<String> =
        (listOf(info.sourceDir) + (info.splitSourceDirs?.toList() ?: emptyList()))
            .filterNotNull()

    private fun hasFlutterLib(apkPath: String): Boolean = try {
        ZipFile(apkPath).use { zip ->
            zip.entries().asSequence().any {
                it.name.startsWith("lib/") && it.name.endsWith("/libflutter.so")
            }
        }
    } catch (e: Exception) {
        false
    }

    /** The (apkPath, entryName) for [libName] in the most relevant ABI. */
    private fun bestLibEntry(
        apkPaths: List<String>,
        libName: String,
    ): Pair<String, String>? {
        var best: Pair<String, String>? = null
        var bestRank = Int.MAX_VALUE
        for (apkPath in apkPaths) {
            try {
                ZipFile(apkPath).use { zip ->
                    for (entry in zip.entries()) {
                        val name = entry.name
                        if (!name.startsWith("lib/") || !name.endsWith("/$libName")) {
                            continue
                        }
                        val abi = name.removePrefix("lib/").substringBefore('/')
                        val rank = ABI_PREFERENCE.indexOf(abi)
                            .takeIf { it >= 0 } ?: ABI_PREFERENCE.size
                        if (rank < bestRank) {
                            bestRank = rank
                            best = apkPath to name
                        }
                    }
                }
            } catch (e: Exception) {
                // Unreadable APK; try the next one.
            }
        }
        return best
    }

    private fun scanZipEntry(
        apkPath: String,
        entryName: String,
        scan: LibraryScan,
    ) {
        ZipFile(apkPath).use { zip ->
            val entry = zip.getEntry(entryName) ?: return
            zip.getInputStream(entry).use { scan.consume(it) }
        }
    }

    private companion object {
        val ABI_PREFERENCE = listOf("arm64-v8a", "armeabi-v7a", "x86_64", "x86")
        const val ICON_SIZE = 108
    }
}

/**
 * Single-pass streaming string scanner. Chunks are decoded as ISO-8859-1
 * (1 byte == 1 char) with a carried-over tail so matches straddling chunk
 * boundaries are still found; sets absorb the duplicates the overlap causes.
 */
private class LibraryScan(
    val wantDartVersion: Boolean = false,
    val wantPackages: Boolean = false,
) {
    var dartVersionRaw: String? = null
    var dartChannel: String? = null
    val hexStrings = mutableSetOf<String>()
    val packages = sortedSetOf<String>()

    fun consume(stream: InputStream) {
        val buffer = ByteArray(CHUNK_SIZE)
        var carry = ""
        while (true) {
            val read = stream.read(buffer)
            if (read <= 0) break
            val text = carry + String(buffer, 0, read, Charsets.ISO_8859_1)
            if (wantDartVersion && dartVersionRaw == null) {
                DART_VERSION.find(text)?.let {
                    dartVersionRaw = it.value
                    dartChannel = it.groupValues[1]
                }
            }
            if (hexStrings.size < MAX_HEX) {
                for (match in HEX32.findAll(text)) {
                    hexStrings.add(match.value)
                    if (hexStrings.size >= MAX_HEX) break
                }
            }
            if (wantPackages && packages.size < MAX_PACKAGES) {
                for (match in PACKAGE_URI.findAll(text)) {
                    packages.add(match.groupValues[1])
                    if (packages.size >= MAX_PACKAGES) break
                }
            }
            carry = if (text.length > OVERLAP) {
                text.substring(text.length - OVERLAP)
            } else {
                text
            }
        }
    }

    private companion object {
        const val CHUNK_SIZE = 1 shl 20
        const val OVERLAP = 512
        const val MAX_HEX = 2000
        const val MAX_PACKAGES = 2000

        /**
         * The Dart VM version string libflutter.so embeds, e.g.
         * `3.12.2 (stable) (Tue Jul 15 2026 +0000) on "android_arm64"`.
         */
        val DART_VERSION = Regex(
            """\d+\.\d+\.\d+[0-9A-Za-z.\-]* \((stable|beta|dev|main|be)\) """ +
                """\([^)]{1,80}\) on "android_[a-z0-9_]+""""
        )

        /** Exactly-32-char lowercase hex runs (snapshot hash candidates). */
        val HEX32 = Regex("""(?<![0-9a-f])[0-9a-f]{32}(?![0-9a-f])""")

        val PACKAGE_URI = Regex("""package:([a-zA-Z0-9_]+)/""")
    }
}
