import 'dart:async';
import 'package:bb_mobile/features/disaster_tx/data/datasources/meshtastic_ble_datasource.dart';
import 'package:bb_mobile/features/disaster_tx/data/services/broadcast_notification_service.dart';
import 'package:bb_mobile/features/disaster_tx/domain/entities/meshtastic_device.dart';
import 'package:bb_mobile/features/disaster_tx/domain/usecases/broadcast_via_lora_usecase.dart';
import 'package:bb_mobile/features/disaster_tx/presentation/cubit/disaster_tx_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DisasterTxCubit extends Cubit<DisasterTxState> {
  DisasterTxCubit({
    required MeshtasticBleDatasource bleDatasource,
    required BroadcastViaLoraUsecase broadcastViaLoraUsecase,
  })  : _bleDatasource = bleDatasource,
        _broadcastViaLoraUsecase = broadcastViaLoraUsecase,
        super(const DisasterTxState());

  final MeshtasticBleDatasource _bleDatasource;
  final BroadcastViaLoraUsecase _broadcastViaLoraUsecase;

  static const _lastDeviceAddressKey = 'disaster_tx_last_device_address';
  Timer? _scanTimeout;

  /// Start scanning for Meshtastic devices with auto-connect.
  Future<void> scanDevices() async {
    emit(state.copyWith(
      isScanning: true,
      availableDevices: [],
      errorMessage: null,
    ));

    try {
      final devices = <MeshtasticDevice>[];
      String? lastDeviceAddress = await _getLastDeviceAddress();
      MeshtasticDevice? bestDevice;

      // Set timeout
      _scanTimeout = Timer(const Duration(seconds: 15), () {
        if (devices.isEmpty) {
          emit(state.copyWith(
            isScanning: false,
            errorMessage: 'No Meshtastic devices found nearby.\n'
                'Make sure your T-Beam is powered on and in Bluetooth range.',
          ));
        }
      });

      await for (final device in _bleDatasource.scanDevices()) {
        devices.add(device);

        // Auto-select best device (prioritize last used, then best signal)
        if (lastDeviceAddress != null && device.address == lastDeviceAddress) {
          bestDevice = device;
        } else if (bestDevice == null || device.rssi > bestDevice.rssi) {
          if (lastDeviceAddress == null) {
            bestDevice = device;
          }
        }

        emit(state.copyWith(
          availableDevices: List.from(devices),
          selectedDevice: bestDevice,
        ));
      }

      _scanTimeout?.cancel();
      emit(state.copyWith(isScanning: false));

      // Auto-connect to best device if found
      if (bestDevice != null && !state.isConnected) {
        await connect();
      }
    } catch (e) {
      _scanTimeout?.cancel();
      emit(state.copyWith(
        isScanning: false,
        errorMessage: 'Scan failed: ${e.toString()}',
      ));
    }
  }

  /// Select a device from the list.
  void selectDevice(MeshtasticDevice device) {
    emit(state.copyWith(selectedDevice: device));
  }

  /// Connect to the selected device.
  Future<void> connect() async {
    if (state.selectedDevice == null) {
      emit(state.copyWith(errorMessage: 'No device selected'));
      return;
    }

    emit(state.copyWith(isConnecting: true, errorMessage: null));

    try {
      await _bleDatasource.connect(state.selectedDevice!);

      // Update device with negotiated MTU
      final updatedDevice = state.selectedDevice!.copyWith(
        mtu: _bleDatasource.currentMtu,
      );

      // Save as last used device
      await _saveLastDeviceAddress(updatedDevice.address);

      emit(state.copyWith(
        isConnecting: false,
        isConnected: true,
        selectedDevice: updatedDevice,
      ));
    } catch (e) {
      emit(state.copyWith(
        isConnecting: false,
        isConnected: false,
        errorMessage: 'Connection failed: ${e.toString()}\n'
            'Make sure the device is in range and not connected to another app.',
      ));
    }
  }

  /// Disconnect from the current device.
  Future<void> disconnect() async {
    await _broadcastViaLoraUsecase.disconnect();
    emit(state.copyWith(
      isConnected: false,
      selectedDevice: null,
    ));
  }

  /// Send a transaction via LoRa.
  Future<void> sendTransaction(String txHex) async {
    if (!state.isConnected || state.selectedDevice == null) {
      emit(state.copyWith(
        errorMessage: 'Not connected to any device.\nPlease connect first.',
      ));
      return;
    }

    if (txHex.isEmpty) {
      emit(state.copyWith(errorMessage: 'Transaction hex is empty'));
      return;
    }

    emit(state.copyWith(
      isSending: true,
      sendProgress: 0.0,
      currentChunk: null,
      errorMessage: null,
    ));

    try {
      // Show persistent notification (Improvement 8)
      await BroadcastNotificationService.showBroadcastStarted(
        deviceName: state.selectedDevice!.name,
      );

      await _broadcastViaLoraUsecase.execute(
        txHex: txHex,
        device: state.selectedDevice!,
        onProgress: (progress, chunk) {
          emit(state.copyWith(
            sendProgress: progress,
            currentChunk: chunk,
          ));

          // Update notification progress
          BroadcastNotificationService.updateProgress(
            progress: progress,
            currentChunk: chunk.chunkNumber,
            totalChunks: chunk.totalChunks,
          );
        },
      );

      emit(state.copyWith(
        isSending: false,
        sendProgress: 1.0,
      ));

      // Show completion notification
      await BroadcastNotificationService.showBroadcastComplete();
    } catch (e) {
      // Show error notification
      await BroadcastNotificationService.showBroadcastError(
        'Failed: ${e.toString()}',
      );

      emit(state.copyWith(
        isSending: false,
        errorMessage: 'Broadcast failed: ${e.toString()}\n'
            'The transaction may not have been sent completely.',
      ));
    }
  }

  /// Clear error message.
  void clearError() {
    emit(state.copyWith(errorMessage: null));
  }

  /// Get last used device address from storage.
  Future<String?> _getLastDeviceAddress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_lastDeviceAddressKey);
    } catch (e) {
      return null;
    }
  }

  /// Save last used device address to storage.
  Future<void> _saveLastDeviceAddress(String address) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastDeviceAddressKey, address);
    } catch (e) {
      // Ignore save errors
    }
  }

  @override
  Future<void> close() {
    _scanTimeout?.cancel();
    return super.close();
  }
}
