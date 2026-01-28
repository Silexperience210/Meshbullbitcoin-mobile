import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/disaster_tx/domain/entities/meshtastic_device.dart';
import 'package:bb_mobile/features/disaster_tx/presentation/cubit/disaster_tx_cubit.dart';
import 'package:bb_mobile/features/disaster_tx/presentation/cubit/disaster_tx_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

/// Disaster TX screen - Send transactions via LoRa when offline.
///
/// Automatically scans for Meshtastic devices, chunks transactions,
/// and broadcasts them over the mesh network.
class DisasterTxScreen extends StatefulWidget {
  const DisasterTxScreen({
    super.key,
    this.prefilledTxHex,
  });

  final String? prefilledTxHex;

  @override
  State<DisasterTxScreen> createState() => _DisasterTxScreenState();
}

class _DisasterTxScreenState extends State<DisasterTxScreen> {
  final _txController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.prefilledTxHex != null) {
      _txController.text = widget.prefilledTxHex!;
    }

    // Auto-scan on start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DisasterTxCubit>().scanDevices();
    });
  }

  @override
  void dispose() {
    _txController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Disaster TX'),
        actions: [
          BlocBuilder<DisasterTxCubit, DisasterTxState>(
            builder: (context, state) {
              return IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: state.isScanning || state.isSending
                    ? null
                    : () => context.read<DisasterTxCubit>().scanDevices(),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: BlocListener<DisasterTxCubit, DisasterTxState>(
          listener: (context, state) {
            // Error handling
            if (state.errorMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.errorMessage!),
                  backgroundColor: context.appColors.error,
                ),
              );
              context.read<DisasterTxCubit>().clearError();
            }

            // Vibration feedback on completion (Improvement 7)
            if (state.sendProgress >= 1.0 && !state.isSending) {
              HapticFeedback.heavyImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Transaction broadcast complete!'),
                  backgroundColor: context.appColors.success,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: const [
                _InfoCard(),
                Gap(16),
                _StatusCard(),
                Gap(16),
                _DeviceSelector(),
                Gap(16),
                _TransactionInput(),
                Gap(16),
                _ConnectionControls(),
                Gap(16),
                _ProgressCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Info card explaining the feature.
class _InfoCard extends StatelessWidget {
  const _InfoCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.emergency,
              size: 32,
              color: context.appColors.warning,
            ),
            const Gap(12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Offline Broadcasting',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Gap(4),
                  Text(
                    'Send Bitcoin transactions via LoRa mesh network when internet is unavailable.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.appColors.textMuted,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Status indicator card.
class _StatusCard extends StatelessWidget {
  const _StatusCard();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DisasterTxCubit, DisasterTxState>(
      builder: (context, state) {
        final Color statusColor;
        final IconData statusIcon;
        final String statusText;

        if (state.isSending) {
          statusColor = context.appColors.primary;
          statusIcon = Icons.send;
          statusText = 'Broadcasting...';
        } else if (state.isConnected) {
          statusColor = context.appColors.success;
          statusIcon = Icons.check_circle;
          statusText = 'Connected';
        } else if (state.isConnecting) {
          statusColor = context.appColors.primary;
          statusIcon = Icons.sync;
          statusText = 'Connecting...';
        } else if (state.isScanning) {
          statusColor = context.appColors.primary;
          statusIcon = Icons.bluetooth_searching;
          statusText = 'Scanning...';
        } else {
          statusColor = context.appColors.textMuted;
          statusIcon = Icons.bluetooth_disabled;
          statusText = 'Not Connected';
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  statusIcon,
                  size: 48,
                  color: statusColor,
                ),
                const Gap(16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusText,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: statusColor,
                            ),
                      ),
                      if (state.selectedDevice != null) ...[
                        const Gap(4),
                        Text(
                          state.selectedDevice!.name,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Text(
                          'MTU: ${state.selectedDevice!.mtu} • Chunk: ${state.selectedDevice!.effectiveChunkSize}B',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: context.appColors.textMuted,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (state.isConnecting || state.isScanning)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Device selector (auto-selects best signal).
class _DeviceSelector extends StatelessWidget {
  const _DeviceSelector();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DisasterTxCubit, DisasterTxState>(
      builder: (context, state) {
        if (state.isConnected || state.availableDevices.isEmpty) {
          return const SizedBox.shrink();
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Meshtastic Devices',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Gap(8),
                ...state.availableDevices.map((device) {
                  final isSelected = state.selectedDevice == device;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.router,
                      color: _getSignalColor(context, device),
                    ),
                    title: Text(device.name),
                    subtitle: Text('${device.rssi} dBm • ${device.address}'),
                    trailing: isSelected
                        ? Icon(Icons.check, color: context.appColors.primary)
                        : null,
                    selected: isSelected,
                    onTap: () {
                      context.read<DisasterTxCubit>().selectDevice(device);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getSignalColor(BuildContext context, MeshtasticDevice device) {
    switch (device.signalQuality) {
      case SignalQuality.excellent:
      case SignalQuality.good:
        return context.appColors.success;
      case SignalQuality.fair:
        return context.appColors.warning;
      case SignalQuality.poor:
        return context.appColors.error;
    }
  }
}

/// Transaction input field.
class _TransactionInput extends StatefulWidget {
  const _TransactionInput();

  @override
  State<_TransactionInput> createState() => _TransactionInputState();
}

class _TransactionInputState extends State<_TransactionInput> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DisasterTxCubit, DisasterTxState>(
      builder: (context, state) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Transaction',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    // Clipboard button (Improvement 6)
                    TextButton.icon(
                      onPressed: state.isSending
                          ? null
                          : () async {
                              final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
                              if (clipboardData?.text != null) {
                                _controller.text = clipboardData!.text!;
                                setState(() {});
                                HapticFeedback.lightImpact();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text('Transaction pasted from clipboard'),
                                      backgroundColor: context.appColors.success,
                                      duration: const Duration(seconds: 1),
                                    ),
                                  );
                                }
                              }
                            },
                      icon: const Icon(Icons.content_paste, size: 16),
                      label: const Text('Paste'),
                    ),
                  ],
                ),
                const Gap(8),
                TextField(
                  controller: _controller,
                  maxLines: 4,
                  enabled: !state.isSending,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                  decoration: const InputDecoration(
                    hintText: 'Paste signed transaction hex...',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => setState(() {}),
                ),
                if (_controller.text.isNotEmpty) ...[
                  const Gap(8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_controller.text.length} bytes',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: context.appColors.textMuted,
                            ),
                      ),
                      if (state.selectedDevice != null)
                        Text(
                          '${_calculateChunks(state)} chunks',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: context.appColors.primary,
                              ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  int _calculateChunks(DisasterTxState state) {
    if (state.selectedDevice == null || _controller.text.isEmpty) {
      return 0;
    }
    final chunkSize = state.selectedDevice!.effectiveChunkSize;
    return (_controller.text.length / chunkSize).ceil();
  }
}

/// Connection and broadcast controls.
class _ConnectionControls extends StatefulWidget {
  const _ConnectionControls();

  @override
  State<_ConnectionControls> createState() => _ConnectionControlsState();
}

class _ConnectionControlsState extends State<_ConnectionControls> {
  final _txController = TextEditingController();

  @override
  void dispose() {
    _txController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DisasterTxCubit, DisasterTxState>(
      builder: (context, state) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!state.isConnected) ...[
                  ElevatedButton.icon(
                    onPressed: state.selectedDevice != null &&
                            !state.isConnecting &&
                            !state.isSending
                        ? () => context.read<DisasterTxCubit>().connect()
                        : null,
                    icon: const Icon(Icons.link),
                    label: Text(
                      state.isConnecting ? 'Connecting...' : 'Connect',
                    ),
                  ),
                ] else ...[
                  TextField(
                    controller: _txController,
                    maxLines: 4,
                    enabled: !state.isSending,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                        ),
                    decoration: const InputDecoration(
                      hintText: 'Paste signed transaction hex...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const Gap(16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: !state.isSending && _txController.text.isNotEmpty
                              ? () {
                                  context.read<DisasterTxCubit>().sendTransaction(
                                        _txController.text,
                                      );
                                }
                              : null,
                          icon: const Icon(Icons.send),
                          label: Text(state.isSending ? 'Broadcasting...' : 'Broadcast'),
                        ),
                      ),
                      const Gap(8),
                      OutlinedButton.icon(
                        onPressed: state.isSending
                            ? null
                            : () => context.read<DisasterTxCubit>().disconnect(),
                        icon: const Icon(Icons.link_off),
                        label: const Text('Disconnect'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Progress indicator card.
class _ProgressCard extends StatelessWidget {
  const _ProgressCard();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DisasterTxCubit, DisasterTxState>(
      builder: (context, state) {
        if (!state.isSending && state.sendProgress < 1.0) {
          return const SizedBox.shrink();
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      state.isSending ? 'Broadcasting...' : 'Complete',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (state.currentChunk != null)
                      Text(
                        '${state.currentChunk!.chunkNumber}/${state.currentChunk!.totalChunks}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: context.appColors.primary,
                            ),
                      ),
                  ],
                ),
                const Gap(12),
                LinearProgressIndicator(
                  value: state.sendProgress,
                  minHeight: 8,
                ),
                const Gap(8),
                Text(
                  '${(state.sendProgress * 100).toStringAsFixed(0)}% complete',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.appColors.textMuted,
                      ),
                ),
                if (state.sendProgress >= 1.0) ...[
                  const Gap(12),
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: context.appColors.success,
                        size: 20,
                      ),
                      const Gap(8),
                      Text(
                        'Transaction sent to LoRa mesh',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: context.appColors.success,
                            ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
