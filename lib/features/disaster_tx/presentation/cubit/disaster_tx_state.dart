import 'package:bb_mobile/features/disaster_tx/domain/entities/meshtastic_device.dart';
import 'package:bb_mobile/features/disaster_tx/domain/entities/tx_chunk.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'disaster_tx_state.freezed.dart';

@freezed
abstract class DisasterTxState with _$DisasterTxState {
  const factory DisasterTxState({
    @Default([]) List<MeshtasticDevice> availableDevices,
    MeshtasticDevice? selectedDevice,
    @Default(false) bool isScanning,
    @Default(false) bool isConnecting,
    @Default(false) bool isConnected,
    @Default(false) bool isSending,
    @Default(0.0) double sendProgress,
    TxChunk? currentChunk,
    String? errorMessage,
  }) = _DisasterTxState;

  const DisasterTxState._();
}
