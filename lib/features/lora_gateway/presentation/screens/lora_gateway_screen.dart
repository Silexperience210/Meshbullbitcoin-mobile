import 'package:bb_mobile/core/lora_gateway/domain/entities/gateway_status.dart';
import 'package:bb_mobile/core/lora_gateway/domain/entities/transaction_log_entry.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/lora_gateway/presentation/bloc/lora_gateway_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

/// Main screen for the LoRa Gateway feature.
class LoraGatewayScreen extends StatelessWidget {
  const LoraGatewayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LoRa Gateway'),
        actions: [
          BlocBuilder<LoraGatewayCubit, LoraGatewayState>(
            builder: (context, state) {
              return IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: state.isScanning
                    ? null
                    : () => context.read<LoraGatewayCubit>().scanDevices(),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _StatusCard(),
              const Gap(16),
              const _DeviceSelector(),
              const Gap(16),
              const _ConnectionControls(),
              const Gap(16),
              const _NetworkToggle(),
              const Gap(16),
              const _StatsCard(),
              const Gap(16),
              const _TransactionLog(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Displays the current gateway status.
class _StatusCard extends StatelessWidget {
  const _StatusCard();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LoraGatewayCubit, LoraGatewayState>(
      builder: (context, state) {
        final Color statusColor;
        final IconData statusIcon;

        switch (state.connectionState) {
          case GatewayConnectionState.disconnected:
            statusColor = context.appColors.textMuted;
            statusIcon = Icons.cell_tower_outlined;
          case GatewayConnectionState.connecting:
            statusColor = context.appColors.primary;
            statusIcon = Icons.sync;
          case GatewayConnectionState.connected:
            statusColor = state.isGatewayActive
                ? context.appColors.success
                : context.appColors.primary;
            statusIcon = state.isGatewayActive
                ? Icons.cell_tower
                : Icons.cell_tower_outlined;
          case GatewayConnectionState.error:
            statusColor = context.appColors.error;
            statusIcon = Icons.error_outline;
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
                        state.statusText,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: statusColor,
                            ),
                      ),
                      if (state.connectedDeviceName != null)
                        Text(
                          state.connectedDeviceName!,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      if (state.error != null)
                        Text(
                          state.error!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: context.appColors.error,
                              ),
                        ),
                    ],
                  ),
                ),
                if (state.isConnecting)
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

/// Device selector dropdown.
class _DeviceSelector extends StatelessWidget {
  const _DeviceSelector();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LoraGatewayCubit, LoraGatewayState>(
      builder: (context, state) {
        if (state.isConnected) {
          return const SizedBox.shrink();
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Meshtastic Device',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Gap(8),
                if (state.isScanning)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (state.availableDevices.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: Text(
                        'No USB devices found.\nConnect a Meshtastic device and tap refresh.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: context.appColors.textMuted,
                            ),
                      ),
                    ),
                  )
                else
                  ...state.availableDevices.map((device) {
                    final isSelected = state.selectedDevice == device;
                    return ListTile(
                      leading: Icon(
                        device.isMeshtasticCompatible
                            ? Icons.usb
                            : Icons.usb_off,
                        color: device.isMeshtasticCompatible
                            ? context.appColors.success
                            : context.appColors.textMuted,
                      ),
                      title: Text(device.displayName),
                      subtitle: device.manufacturerName != null
                          ? Text(device.manufacturerName!)
                          : null,
                      trailing: isSelected
                          ? Icon(Icons.check, color: context.appColors.primary)
                          : null,
                      selected: isSelected,
                      onTap: () {
                        context.read<LoraGatewayCubit>().selectDevice(device);
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
}

/// Connection and gateway control buttons.
class _ConnectionControls extends StatelessWidget {
  const _ConnectionControls();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LoraGatewayCubit, LoraGatewayState>(
      builder: (context, state) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!state.isConnected) ...[
                  ElevatedButton.icon(
                    onPressed: state.selectedDevice != null && !state.isConnecting
                        ? () => context.read<LoraGatewayCubit>().connect()
                        : null,
                    icon: const Icon(Icons.link),
                    label: Text(
                      state.isConnecting ? 'Connecting...' : 'Connect',
                    ),
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            context.read<LoraGatewayCubit>().toggleGateway();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: state.isGatewayActive
                                ? context.appColors.error
                                : context.appColors.success,
                          ),
                          icon: Icon(
                            state.isGatewayActive
                                ? Icons.stop
                                : Icons.play_arrow,
                          ),
                          label: Text(
                            state.isGatewayActive
                                ? 'Stop Gateway'
                                : 'Start Gateway',
                          ),
                        ),
                      ),
                      const Gap(8),
                      OutlinedButton.icon(
                        onPressed: () {
                          context.read<LoraGatewayCubit>().disconnect();
                        },
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

/// Network toggle (mainnet/testnet).
class _NetworkToggle extends StatelessWidget {
  const _NetworkToggle();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LoraGatewayCubit, LoraGatewayState>(
      builder: (context, state) {
        return Card(
          child: SwitchListTile(
            title: const Text('Use Testnet'),
            subtitle: Text(
              state.isTestnet
                  ? 'Broadcasting to Bitcoin Testnet'
                  : 'Broadcasting to Bitcoin Mainnet',
            ),
            value: state.isTestnet,
            onChanged: (value) {
              context.read<LoraGatewayCubit>().setTestnet(value);
            },
          ),
        );
      },
    );
  }
}

/// Statistics card showing TX counts.
class _StatsCard extends StatelessWidget {
  const _StatsCard();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LoraGatewayCubit, LoraGatewayState>(
      builder: (context, state) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(
                  label: 'Received',
                  value: state.txReceived.toString(),
                  color: context.appColors.primary,
                ),
                _StatItem(
                  label: 'Broadcasted',
                  value: state.txBroadcasted.toString(),
                  color: context.appColors.success,
                ),
                _StatItem(
                  label: 'Failed',
                  value: state.txFailed.toString(),
                  color: context.appColors.error,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// Transaction log display.
class _TransactionLog extends StatelessWidget {
  const _TransactionLog();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LoraGatewayCubit, LoraGatewayState>(
      builder: (context, state) {
        return Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Transaction Log',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (state.transactionLog.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          context.read<LoraGatewayCubit>().clearLog();
                        },
                        child: const Text('Clear'),
                      ),
                  ],
                ),
              ),
              if (state.transactionLog.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      'No transactions yet.\nStart the gateway to begin receiving.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: context.appColors.textMuted,
                          ),
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: state.transactionLog.length.clamp(0, 20),
                  itemBuilder: (context, index) {
                    final entry = state.transactionLog[index];
                    return _TransactionLogItem(entry: entry);
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class _TransactionLogItem extends StatelessWidget {
  const _TransactionLogItem({required this.entry});

  final TransactionLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final Color statusColor;
    final IconData statusIcon;

    switch (entry.status) {
      case TransactionLogStatus.receiving:
        statusColor = context.appColors.primary;
        statusIcon = Icons.download;
      case TransactionLogStatus.received:
        statusColor = context.appColors.primary;
        statusIcon = Icons.check_circle_outline;
      case TransactionLogStatus.broadcasting:
        statusColor = context.appColors.primary;
        statusIcon = Icons.upload;
      case TransactionLogStatus.broadcasted:
        statusColor = context.appColors.success;
        statusIcon = Icons.check_circle;
      case TransactionLogStatus.failed:
        statusColor = context.appColors.error;
        statusIcon = Icons.error;
    }

    return ListTile(
      leading: Icon(statusIcon, color: statusColor),
      title: Text(
        entry.txid ?? entry.id,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
            ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${_formatTime(entry.timestamp)} • ${entry.sender}',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.appColors.textMuted,
            ),
      ),
      trailing: entry.status == TransactionLogStatus.receiving
          ? Text(
              '${entry.chunksReceived}/${entry.chunksTotal}',
              style: Theme.of(context).textTheme.bodySmall,
            )
          : null,
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}';
  }
}
