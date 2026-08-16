import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mns_design_system/design_system.dart';

import '../models/customer_models.dart';
import '../screens/add_address_screen.dart';
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
      GoRoute(path: '/add-address', builder: (_, __) => const AddAddressScreen()),
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
        scaffoldBackgroundColor: const Color(0xFFF9F7FD),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7C3AED),
          primary: const Color(0xFF7C3AED),
          surface: Colors.white,
          onSurface: const Color(0xFF0F172A),
        ),
        cardTheme: const CardThemeData(
          elevation: 0,
          color: Colors.white,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(18)),
            side: BorderSide(color: Color(0xFFE5DEEE)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF7C3AED),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5DEEE))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5DEEE))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.5)),
          labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
          floatingLabelStyle: const TextStyle(color: Color(0xFF7C3AED), fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
