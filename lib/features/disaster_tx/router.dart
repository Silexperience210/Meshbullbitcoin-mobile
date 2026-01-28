import 'package:bb_mobile/features/disaster_tx/presentation/cubit/disaster_tx_cubit.dart';
import 'package:bb_mobile/features/disaster_tx/presentation/screens/disaster_tx_screen.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class DisasterTxRoutes {
  static const String base = '/disaster-tx';

  static final routes = [
    GoRoute(
      path: base,
      builder: (context, state) => BlocProvider(
        create: (_) => locator<DisasterTxCubit>(),
        child: const DisasterTxScreen(),
      ),
    ),
  ];
}
