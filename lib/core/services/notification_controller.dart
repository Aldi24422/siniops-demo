import 'dart:async';
import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_notification_listener/flutter_notification_listener.dart';
import 'package:permission_handler/permission_handler.dart';

// ignore_for_file: avoid_print
// print() is required in background isolate callback where debugPrint is unavailable

/// Top-level Function for Background Isolate
/// MUST be outside any class and annotated with @pragma('vm:entry-point')
/// NOTE: Cannot use debugPrint here - it requires Flutter bindings not available in background isolate
@pragma('vm:entry-point')
void callback(NotificationEvent evt) {
  // Use print() instead of debugPrint() for background isolate compatibility
  print('[NotificationCallback] Received: ${evt.packageName} - ${evt.title}');
  try {
    final SendPort? send = IsolateNameServer.lookupPortByName(
      NotificationController.kPortName,
    );
    if (send == null) {
      print('[NotificationCallback] SendPort is NULL - port not registered!');
    } else {
      print('[NotificationCallback] Sending event to main isolate...');
      send.send(evt);
      print('[NotificationCallback] Event sent successfully');
    }
  } catch (e) {
    // Silently handle errors - port may be closed during cleanup
    print('[NotificationCallback] Error: $e');
  }
}

/// Permission check result for notification listener
enum NotificationPermissionStatus {
  granted,
  postNotificationsDenied,
  listenerAccessDenied,
}

/// Robust Notification Controller with proper lifecycle management.
///
/// Features:
/// - Singleton pattern for global access
/// - Proper ReceivePort lifecycle (no memory leaks)
/// - Race condition prevention with mutex-like guards
/// - Broadcast stream for multiple listeners
/// - Android 13+ runtime permission handling
class NotificationController {
  // Singleton pattern
  static final NotificationController _instance =
      NotificationController._internal();
  static NotificationController get instance => _instance;
  NotificationController._internal();

  static const String kPortName = "notification_send_port";

  // Managed ReceivePort - only one at a time
  ReceivePort? _port;
  StreamSubscription? _portSubscription;

  // Broadcast stream for multiple UI listeners
  final StreamController<NotificationEvent> _streamController =
      StreamController<NotificationEvent>.broadcast();

  /// Public Stream for UI to listen
  Stream<NotificationEvent> get notificationStream => _streamController.stream;

  bool _isListening = false;
  bool get isListening => _isListening;

  // Guard against concurrent startListening calls
  bool _isInitializing = false;

  /// Check and request all required permissions for notification listening.
  /// Returns the permission status.
  Future<NotificationPermissionStatus> checkAndRequestPermissions() async {
    // 1. Request POST_NOTIFICATIONS for Android 13+ (API 33+)
    // This is a runtime permission that can be requested programmatically
    final notificationStatus = await Permission.notification.status;
    if (notificationStatus.isDenied) {
      final result = await Permission.notification.request();
      if (!result.isGranted) {
        debugPrint(
          '[NotificationController] POST_NOTIFICATIONS permission denied',
        );
        return NotificationPermissionStatus.postNotificationsDenied;
      }
    }

    // 2. Check Notification Listener Access (requires Settings page)
    // BIND_NOTIFICATION_LISTENER_SERVICE cannot be requested at runtime
    bool? hasListenerPermission = await NotificationsListener.hasPermission;
    if (hasListenerPermission != true) {
      debugPrint(
        '[NotificationController] Notification Listener access not granted',
      );
      return NotificationPermissionStatus.listenerAccessDenied;
    }

    return NotificationPermissionStatus.granted;
  }

  /// Open system settings for notification listener access.
  void openListenerSettings() {
    NotificationsListener.openPermissionSettings();
  }

  /// Quick permission check without triggering any requests or settings.
  /// Use this to verify permission status after returning from Settings.
  Future<bool> hasValidPermission() async {
    try {
      final notificationStatus = await Permission.notification.status;
      if (!notificationStatus.isGranted) {
        return false;
      }

      final hasListenerPermission = await NotificationsListener.hasPermission;
      return hasListenerPermission == true;
    } catch (e) {
      debugPrint('[NotificationController] Error checking permission: $e');
      return false;
    }
  }

  /// Safe re-initialization after app resumes from Settings or background.
  /// This method checks permission first and only initializes if granted.
  /// Returns true if listener is active after this call.
  Future<bool> reinitializeIfNeeded() async {
    try {
      // If already listening, verify permission is still valid
      if (_isListening) {
        final stillValid = await hasValidPermission();
        if (stillValid) {
          debugPrint(
            '[NotificationController] Still listening, permission valid',
          );
          return true;
        }
        // Permission was revoked, stop listening
        await stopListening();
      }

      // Check if we now have permission (user just granted it)
      final hasPermission = await hasValidPermission();
      if (!hasPermission) {
        debugPrint(
          '[NotificationController] No permission, cannot reinitialize',
        );
        return false;
      }

      // Permission granted, start listening
      return await startListening();
    } catch (e) {
      debugPrint('[NotificationController] Error in reinitializeIfNeeded: $e');
      return false;
    }
  }

  /// Initialize and start listening to notifications.
  /// Safe to call multiple times - will be no-op if already listening.
  /// Returns true if successfully started, false otherwise.
  Future<bool> startListening() async {
    // Guard: already listening or initializing
    if (_isListening || _isInitializing) {
      debugPrint('[NotificationController] Already listening or initializing');
      return _isListening;
    }

    _isInitializing = true;

    try {
      // 1. Check and request permissions
      final permissionStatus = await checkAndRequestPermissions();

      switch (permissionStatus) {
        case NotificationPermissionStatus.postNotificationsDenied:
          debugPrint('[NotificationController] POST_NOTIFICATIONS denied');
          _isInitializing = false;
          return false;

        case NotificationPermissionStatus.listenerAccessDenied:
          debugPrint(
            '[NotificationController] Listener access denied, opening settings',
          );
          openListenerSettings();
          _isInitializing = false;
          return false;

        case NotificationPermissionStatus.granted:
          // Continue with initialization
          break;
      }

      // 2. Cleanup previous port if exists (prevents memory leak)
      await _cleanupPort();

      // 3. Create new ReceivePort and register
      _port = ReceivePort();

      // Remove any stale mapping first
      IsolateNameServer.removePortNameMapping(kPortName);

      // Register the new port
      final registered = IsolateNameServer.registerPortWithName(
        _port!.sendPort,
        kPortName,
      );

      if (!registered) {
        debugPrint('[NotificationController] Failed to register port');
        await _cleanupPort();
        _isInitializing = false;
        return false;
      }

      // 4. Listen to port and forward to stream
      _portSubscription = _port!.listen(
        (message) {
          debugPrint(
            '[NotificationController] Port received message: ${message.runtimeType}',
          );
          if (message is NotificationEvent) {
            debugPrint(
              '[NotificationController] Forwarding NotificationEvent to stream: ${message.packageName}',
            );
            if (!_streamController.isClosed) {
              _streamController.add(message);
              debugPrint(
                '[NotificationController] Event added to stream successfully',
              );
            } else {
              debugPrint(
                '[NotificationController] StreamController is CLOSED!',
              );
            }
          } else {
            debugPrint(
              '[NotificationController] Message is NOT NotificationEvent: ${message.runtimeType}',
            );
          }
        },
        onError: (error) {
          debugPrint('[NotificationController] Port error: $error');
        },
      );

      // 5. Initialize Background Service
      await NotificationsListener.initialize(callbackHandle: callback);
      _isListening = true;
      debugPrint('[NotificationController] Successfully started listening');
      return true;
    } catch (e, stack) {
      debugPrint('[NotificationController] Error initializing: $e');
      debugPrint('$stack');
      await _cleanupPort();
      _isListening = false;
      return false;
    } finally {
      _isInitializing = false;
    }
  }

  /// Stop listening to notifications.
  /// Call this when the feature is no longer needed.
  /// Now properly async to ensure cleanup completes.
  Future<void> stopListening() async {
    debugPrint('[NotificationController] Stopping listener');
    await _cleanupPort();
    _isListening = false;
  }

  /// Cleanup port resources properly to prevent memory leaks.
  Future<void> _cleanupPort() async {
    // Cancel subscription first
    await _portSubscription?.cancel();
    _portSubscription = null;

    // Remove from IsolateNameServer
    IsolateNameServer.removePortNameMapping(kPortName);

    // Close the port
    _port?.close();
    _port = null;
  }

  /// Dispose the controller completely.
  /// Call this only when app is shutting down.
  Future<void> dispose() async {
    await stopListening();
    await _streamController.close();
  }
}
