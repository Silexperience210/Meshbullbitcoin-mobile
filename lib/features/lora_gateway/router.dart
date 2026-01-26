import 'package:bb_mobile/features/lora_gateway/presentation/bloc/lora_gateway_cubit.dart';
import 'package:bb_mobile/features/lora_gateway/presentation/screens/lora_gateway_screen.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Routes for the LoRa Gateway feature.
enum LoraGatewayRoute {
  loraGatewayHome('/lora-gateway');

  const LoraGatewayRoute(this.path);

  final String path;
}

/// Router configuration for the LoRa Gateway feature.
class LoraGatewayRouter {
  static final route = GoRoute(
    name: LoraGatewayRoute.loraGatewayHome.name,
    path: LoraGatewayRoute.loraGatewayHome.path,
    builder: (context, state) => BlocProvider(
      create: (_) => locator<LoraGatewayCubit>(),
      child: const LoraGatewayScreen(),
    ),
  );
}
