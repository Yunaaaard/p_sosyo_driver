package com.example.p_sosyo_driver

import android.Manifest
import android.app.Activity
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.telephony.SmsManager
import android.telephony.SubscriptionManager
import androidx.core.app.ActivityCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicBoolean

class MainActivity: FlutterActivity() {
    private val LOCATION_CHANNEL = "com.example.p_sosyo_driver/location"
    private val PERMISSIONS_CHANNEL = "com.example.p_sosyo_driver/permissions"
    private val SMS_CHANNEL = "com.example.p_sosyo_driver/sms"
    private val BT_PERMISSION_REQUEST_CODE = 1002
    private val SMS_PERMISSION_REQUEST_CODE = 1003
    private var pendingBtPermissionResult: MethodChannel.Result? = null
    private var pendingSmsPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LOCATION_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getCurrentLocation" -> {
                    val loc = fetchBestLastKnownLocation()
                    if (loc != null) {
                        result.success(mapOf(
                            "latitude" to loc.latitude,
                            "longitude" to loc.longitude
                        ))
                    } else {
                        result.success(null)
                    }
                }
                "openMapsDirections" -> {
                    val originLat = call.argument<Number>("originLat")?.toDouble()
                    val originLng = call.argument<Number>("originLng")?.toDouble()
                    val destLat = call.argument<Number>("destLat")?.toDouble()
                    val destLng = call.argument<Number>("destLng")?.toDouble()

                    if (destLat == null || destLng == null) {
                        result.error("INVALID_ARGS", "Destination coordinates required", null)
                        return@setMethodCallHandler
                    }

                    val launched = launchGoogleMapsDirections(originLat, originLng, destLat, destLng)
                    result.success(launched)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PERMISSIONS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestBluetoothPermissions" -> {
                    handleRequestBluetoothPermissions(result)
                }
                "openAppSettings" -> {
                    val opened = openAppDetailsSettings()
                    result.success(opened)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasSmsPermission" -> {
                    result.success(hasSmsPermission())
                }
                "requestSmsPermission" -> {
                    handleRequestSmsPermission(result)
                }
                "sendSms" -> {
                    val number = call.argument<String>("number")?.trim() ?: ""
                    val message = call.argument<String>("message")?.trim() ?: ""
                    if (number.isEmpty() || message.isEmpty()) {
                        result.error("INVALID_ARGS", "Phone number and message are required", null)
                        return@setMethodCallHandler
                    }
                    sendSmsDirect(number, message, result)
                }
                "openSmsComposer" -> {
                    val number = call.argument<String>("number")?.trim() ?: ""
                    val message = call.argument<String>("message")?.trim() ?: ""
                    result.success(openSmsComposer(number, message))
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun requiredBluetoothPermissions(): Array<String> {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            arrayOf(
                Manifest.permission.BLUETOOTH_CONNECT,
                Manifest.permission.BLUETOOTH_SCAN
            )
        } else {
            arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
        }
    }

    private fun hasAllBluetoothPermissions(): Boolean {
        return requiredBluetoothPermissions().all { perm ->
            ActivityCompat.checkSelfPermission(this, perm) == PackageManager.PERMISSION_GRANTED
        }
    }

    private fun handleRequestBluetoothPermissions(result: MethodChannel.Result) {
        if (hasAllBluetoothPermissions()) {
            result.success(true)
            return
        }
        pendingBtPermissionResult?.success(false)
        pendingBtPermissionResult = result
        ActivityCompat.requestPermissions(
            this,
            requiredBluetoothPermissions(),
            BT_PERMISSION_REQUEST_CODE
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == BT_PERMISSION_REQUEST_CODE) {
            val allGranted = grantResults.isNotEmpty() &&
                grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            pendingBtPermissionResult?.success(allGranted || hasAllBluetoothPermissions())
            pendingBtPermissionResult = null
        } else if (requestCode == SMS_PERMISSION_REQUEST_CODE) {
            val granted = grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingSmsPermissionResult?.success(granted || hasSmsPermission())
            pendingSmsPermissionResult = null
        }
    }

    private fun hasSmsPermission(): Boolean {
        return ActivityCompat.checkSelfPermission(
            this,
            Manifest.permission.SEND_SMS
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun handleRequestSmsPermission(result: MethodChannel.Result) {
        if (hasSmsPermission()) {
            result.success(true)
            return
        }
        pendingSmsPermissionResult?.success(false)
        pendingSmsPermissionResult = result
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.SEND_SMS),
            SMS_PERMISSION_REQUEST_CODE
        )
    }

    private fun resolveSmsManager(): SmsManager {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
            val subId = SubscriptionManager.getDefaultSmsSubscriptionId()
            if (subId != SubscriptionManager.INVALID_SUBSCRIPTION_ID && subId >= 0) {
                return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    getSystemService(SmsManager::class.java).createForSubscriptionId(subId)
                } else {
                    @Suppress("DEPRECATION")
                    SmsManager.getSmsManagerForSubscriptionId(subId)
                }
            }
        }
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            getSystemService(SmsManager::class.java)
        } else {
            @Suppress("DEPRECATION")
            SmsManager.getDefault()
        }
    }

    private fun sendSmsDirect(number: String, message: String, result: MethodChannel.Result) {
        if (!hasSmsPermission()) {
            result.error("PERMISSION_DENIED", "SEND_SMS permission is not granted", null)
            return
        }
        try {
            val smsManager = resolveSmsManager()
            val parts = smsManager.divideMessage(message)
            val action = "com.example.p_sosyo_driver.SMS_SENT_${System.currentTimeMillis()}"
            val replied = AtomicBoolean(false)

            val receiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    if (!replied.compareAndSet(false, true)) return
                    try {
                        unregisterReceiver(this)
                    } catch (_: Exception) {}

                    when (resultCode) {
                        Activity.RESULT_OK -> result.success(true)
                        SmsManager.RESULT_ERROR_GENERIC_FAILURE ->
                            result.error("SMS_GENERIC_FAILURE", "Carrier/SIM rejected SMS (check load or default SIM)", null)
                        SmsManager.RESULT_ERROR_NO_SERVICE ->
                            result.error("SMS_NO_SERVICE", "No cellular service available", null)
                        SmsManager.RESULT_ERROR_RADIO_OFF ->
                            result.error("SMS_RADIO_OFF", "Cellular radio is turned off / Airplane mode", null)
                        SmsManager.RESULT_ERROR_NULL_PDU ->
                            result.error("SMS_NULL_PDU", "Invalid SMS PDU", null)
                        32 -> // SmsManager.RESULT_USER_NOT_ALLOWED
                            result.error(
                                "SMS_USER_NOT_ALLOWED",
                                "Device/SIM blocked background SMS (code 32). Check SMS permissions in Settings or send via SMS app.",
                                null
                            )
                        else ->
                            result.error("SMS_FAILED", "SMS send failed (code: $resultCode)", null)
                    }
                }
            }

            val filter = IntentFilter(action)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                registerReceiver(receiver, filter)
            }

            if (parts.size <= 1) {
                val sentIntent = PendingIntent.getBroadcast(
                    this,
                    0,
                    Intent(action).setPackage(packageName),
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                )
                smsManager.sendTextMessage(number, null, message, sentIntent, null)
            } else {
                val sentIntents = ArrayList<PendingIntent>()
                for (i in parts.indices) {
                    val sentIntent = PendingIntent.getBroadcast(
                        this,
                        i,
                        Intent(action).setPackage(packageName),
                        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                    )
                    sentIntents.add(sentIntent)
                }
                smsManager.sendMultipartTextMessage(number, null, parts, sentIntents, null)
            }
        } catch (e: Exception) {
            result.error("SMS_FAILED", e.message ?: "Failed to send SMS", null)
        }
    }

    private fun openSmsComposer(number: String, message: String): Boolean {
        return try {
            val intent = Intent(Intent.ACTION_SENDTO).apply {
                data = Uri.parse("smsto:${Uri.encode(number)}")
                putExtra("sms_body", message)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun openAppDetailsSettings(): Boolean {
        return try {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.fromParts("package", packageName, null)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun launchGoogleMapsDirections(
        originLat: Double?,
        originLng: Double?,
        destLat: Double,
        destLng: Double
    ): Boolean {
        val url = if (originLat != null && originLng != null) {
            "https://www.google.com/maps/dir/?api=1&origin=$originLat,$originLng&destination=$destLat,$destLng&travelmode=driving"
        } else {
            "https://www.google.com/maps/dir/?api=1&destination=$destLat,$destLng&travelmode=driving"
        }
        val uri = Uri.parse(url)

        // 1. Prefer Google Maps app directly
        try {
            val mapsIntent = Intent(Intent.ACTION_VIEW, uri).apply {
                setPackage("com.google.android.apps.maps")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(mapsIntent)
            return true
        } catch (_: Exception) {}

        // 2. Fallback to any installed map app or browser
        return try {
            val fallbackIntent = Intent(Intent.ACTION_VIEW, uri).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(fallbackIntent)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun fetchBestLastKnownLocation(): Location? {
        val fineGranted = ActivityCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        val coarseGranted = ActivityCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
        if (!fineGranted && !coarseGranted) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION),
                1001
            )
            return null
        }

        val locationManager = getSystemService(Context.LOCATION_SERVICE) as? LocationManager ?: return null
        val providers = locationManager.getProviders(true)
        var bestLocation: Location? = null
        for (provider in providers) {
            try {
                val l = locationManager.getLastKnownLocation(provider) ?: continue
                if (bestLocation == null || l.accuracy < bestLocation.accuracy) {
                    bestLocation = l
                }
            } catch (_: SecurityException) {}
        }
        return bestLocation
    }
}
