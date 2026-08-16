import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mns_design_system/design_system.dart';

import '../models/customer_models.dart';
import '../screens/auth_screen.dart';
import '../screens/addresses_screen.dart';
import '../screens/cart_screen.dart';
import '../screens/home_screen.dart';
import '../screens/order_detail_screen.dart';
import '../screens/store_screen.dart';

class CustomerApp extends StatelessWidget {
  const CustomerApp({super.key});

  static final router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const AuthScreen()),
      GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
      GoRoute(
        path: '/store',
        builder: (_, state) => StoreScreen(store: state.extra! as Store),
      ),
      GoRoute(path: '/cart', builder: (_, __) => const CartScreen()),
      GoRoute(path: '/addresses', builder: (_, __) => const AddressesScreen()),
      GoRoute(
        path: '/order',
        builder: (_, state) => OrderDetailScreen(order: state.extra! as CustomerOrder),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'M&S Delivery',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: MnsTheme.light().copyWith(
        cardTheme: const CardThemeData(elevation: 0, color: Colors.white, margin: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20)))),
      ),
    );
  }
}
