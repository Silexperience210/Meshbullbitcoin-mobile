import 'dart:async';

import 'package:bb_mobile/core/lora_gateway/domain/entities/gateway_status.dart';
import 'package:bb_mobile/core/lora_gateway/domain/entities/usb_device_info.dart';
import 'package:bb_mobile/core/lora_gateway/domain/repositories/lora_gateway_repository.dart';
import 'package:bb_mobile/core/lora_gateway/domain/usecases/broadcast_received_tx_usecase.dart';
import 'package:bb_mobile/core/lora_gateway/domain/usecases/connect_meshtastic_usecase.dart';
import 'package:bb_mobile/core/lora_gateway/domain/usecases/disconnect_meshtastic_usecase.dart';
import 'package:bb_mobile/core/lora_gateway/domain/usecases/scan_usb_devices_usecase.dart';
import 'package:bb_mobile/core/lora_gateway/domain/usecases/start_gateway_usecase.dart';
import 'package:bb_mobile/core/lora_gateway/domain/usecases/stop_gateway_usecase.dart';
import 'package:bb_mobile/features/lora_gateway/presentation/bloc/lora_gateway_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Cubit for managing the LoRa Gateway feature.
class LoraGatewayCubit extends Cubit<LoraGatewayState> {
  LoraGatewayCubit({
    required LoraGatewayRepository repository,
    required ScanUsbDevicesUsecase scanDevicesUsecase,
    required ConnectMeshtasticUsecase connectUsecase,
    required DisconnectMeshtasticUsecase disconnectUsecase,
    required StartGatewayUsecase startGatewayUsecase,
    required StopGatewayUsecase stopGatewayUsecase,
    required BroadcastReceivedTxUsecase broadcastTxUsecase,
  })  : _repository = repository,
        _scanDevicesUsecase = scanDevicesUsecase,
        _connectUsecase = connectUsecase,
        _disconnectUsecase = disconnectUsecase,
        _startGatewayUsecase = startGatewayUsecase,
        _stopGatewayUsecase = stopGatewayUsecase,
        _broadcastTxUsecase = broadcastTxUsecase,
        super(const LoraGatewayState()) {
    _init();
  }

  final LoraGatewayRepository _repository;
  final ScanUsbDevicesUsecase _scanDevicesUsecase;
  final ConnectMeshtasticUsecase _connectUsecase;
  final DisconnectMeshtasticUsecase _disconnectUsecase;
  final StartGatewayUsecase _startGatewayUsecase;
  final StopGatewayUsecase _stopGatewayUsecase;
  final BroadcastReceivedTxUsecase _broadcastTxUsecase;

  StreamSubscription<GatewayStatus>? _statusSubscription;
  StreamSubscription<(String, String, String)>? _txSubscription;

  void _init() {
    // Listen to status changes
    _statusSubscription = _repository.statusStream.listen(_onStatusChanged);

    // Listen for complete transactions to broadcast
    _txSubscription = _repository.completeTxStream.listen(_onCompleteTx);

    // Initial device scan
    scanDevices();
  }

  void _onStatusChanged(GatewayStatus status) {
    emit(state.copyWith(
      connectionState: status.connectionState,
      isGatewayActive: status.isGatewayActive,
      txReceived: status.txReceived,
      txBroadcasted: status.txBroadcasted,
      txFailed: status.txFailed,
      connectedDeviceName: status.deviceName,
      error: status.lastError,
      isTestnet: status.isTestnet,
      transactionLog: _repository.getTransactionLog(),
    ));
  }

  Future<void> _onCompleteTx((String, String, String) txData) async {
    final (txHex, _, logEntryId) = txData;

    try {
      await _broadcastTxUsecase.execute(
        txHex: txHex,
        logEntryId: logEntryId,
      );
    } catch (e) {
      // Error already reported by usecase
    }

    // Update transaction log in state
    emit(state.copyWith(
      transactionLog: _repository.getTransactionLog(),
    ));
  }

  /// Scans for available USB devices.
  Future<void> scanDevices() async {
    emit(state.copyWith(isScanning: true, error: null));

    try {
      final devices = await _scanDevicesUsecase.execute();
      emit(state.copyWith(
        availableDevices: devices,
        isScanning: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        isScanning: false,
        error: e.toString(),
      ));
    }
  }

  /// Selects a device to connect to.
  void selectDevice(UsbDeviceInfo device) {
    emit(state.copyWith(selectedDevice: device));
  }

  /// Connects to the selected device.
  Future<void> connect() async {
    final device = state.selectedDevice;
    if (device == null) return;

    emit(state.copyWith(
      connectionState: GatewayConnectionState.connecting,
      error: null,
    ));

    try {
      await _connectUsecase.execute(device);
    } catch (e) {
      emit(state.copyWith(
        connectionState: GatewayConnectionState.error,
        error: e.toString(),
      ));
    }
  }

  /// Disconnects from the current device.
  Future<void> disconnect() async {
    try {
      await _disconnectUsecase.execute();
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  /// Starts the gateway.
  void startGateway() {
    _startGatewayUsecase.execute();
  }

  /// Stops the gateway.
  void stopGateway() {
    _stopGatewayUsecase.execute();
  }

  /// Toggles the gateway on/off.
  void toggleGateway() {
    if (state.isGatewayActive) {
      stopGateway();
    } else {
      startGateway();
    }
  }

  /// Sets whether to use testnet.
  void setTestnet(bool isTestnet) {
    _repository.setTestnet(isTestnet);
    emit(state.copyWith(isTestnet: isTestnet));
  }

  /// Clears the transaction log.
  void clearLog() {
    _repository.clearTransactionLog();
    emit(state.copyWith(transactionLog: []));
  }

  @override
  Future<void> close() async {
    await _statusSubscription?.cancel();
    await _txSubscription?.cancel();
    return super.close();
  }
}
