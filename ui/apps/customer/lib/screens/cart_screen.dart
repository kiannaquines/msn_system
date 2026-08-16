import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:mns_design_system/design_system.dart';

import '../data/reverse_geocoder.dart';
import '../models/customer_models.dart';
import '../state/customer_state.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  final _customAddressController = TextEditingController();
  String? _selectedAddressId;
  Position? _gpsPosition;
  bool _useCustomAddress = false;
  bool _locating = false;
  bool _placing = false;

  @override
  void initState() {
    super.initState();
    // Auto-select first address if available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final addresses = ref.read(addressesProvider).valueOrNull;
      if (addresses != null && addresses.isNotEmpty) {
        setState(() {
          _selectedAddressId = addresses.first.id;
        });
      } else {
        setState(() {
          _useCustomAddress = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _customAddressController.dispose();
    super.dispose();
  }

  Future<void> _checkout(CartState cart, List<DeliveryAddress> savedAddresses) async {
    if (cart.lines.isEmpty || cart.store == null) return;

    DeliveryAddress? deliveryAddress;

    if (!_useCustomAddress && _selectedAddressId != null) {
      final match = savedAddresses.where((a) => a.id == _selectedAddressId);
      if (match.isNotEmpty) {
        deliveryAddress = match.first;
      }
    }

    if (deliveryAddress == null) {
      final customText = _customAddressController.text.trim();
      if (customText.isEmpty) {
        MnsSnackBar.show(
          context,
          title: 'Delivery Address Required',
          message: 'Please select a saved address or enter your delivery details.',
          type: MnsSnackBarType.warning,
        );
        return;
      }
      deliveryAddress = DeliveryAddress(
        label: 'Delivery Point',
        address: customText,
        latitude: _gpsPosition?.latitude ?? 7.1086,
        longitude: _gpsPosition?.longitude ?? 124.8235,
      );
    }

    setState(() => _placing = true);
    try {
      final order = await ref.read(ordersProvider.notifier).place(
            cart,
            deliveryAddress,
          );
      if (order != null && mounted) {
        ref.read(cartProvider.notifier).clear();
        context.go('/order', extra: order);
      }
    } catch (e) {
      if (mounted) {
        MnsSnackBar.show(
          context,
          title: 'Checkout Failed',
          message: e.toString().replaceFirst('Exception: ', '').replaceFirst('ApiException: ', ''),
          type: MnsSnackBarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  Future<void> _captureCurrentLocation() async {
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Location services are disabled on your device.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        throw Exception('Location permission is required to detect your GPS pin.');
      }
      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _gpsPosition = position;
        _useCustomAddress = true;
      });
      final resolved = await ReverseGeocoder.getAddress(position.latitude, position.longitude);
      if (!mounted) return;
      if (resolved != null) {
        setState(() => _customAddressController.text = resolved);
        MnsSnackBar.show(
          context,
          title: 'Location Captured',
          message: resolved,
          type: MnsSnackBarType.success,
        );
      } else {
        MnsSnackBar.show(
          context,
          title: 'GPS Pin Detected',
          message: 'GPS coordinates recorded for delivery.',
          type: MnsSnackBarType.info,
        );
      }
    } catch (error) {
      if (mounted) {
        MnsSnackBar.show(
          context,
          title: 'Location Error',
          message: error.toString().replaceFirst('Exception: ', ''),
          type: MnsSnackBarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final addressesAsync = ref.watch(addressesProvider);
    final savedAddresses = addressesAsync.valueOrNull ?? [];

    // If addresses loaded and none selected yet, default to first
    if (_selectedAddressId == null && savedAddresses.isNotEmpty && !_useCustomAddress) {
      _selectedAddressId = savedAddresses.first.id;
    }

    final deliveryFee = 39.0;
    final totalAmount = cart.subtotal + deliveryFee;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Your Basket & Checkout',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFF0F172A), letterSpacing: -0.3),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE2E8F0)),
        ),
        actions: [
          if (cart.lines.isNotEmpty)
            TextButton.icon(
              onPressed: () => _confirmClearCart(),
              icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)),
              label: const Text('Clear', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w800, fontSize: 13)),
            ),
        ],
      ),
      body: cart.lines.isEmpty
          ? _buildEmptyState()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
              children: [
                // ── 1. Restaurant Header Card ─────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: const [
                      BoxShadow(color: Color(0x04000000), blurRadius: 10, offset: Offset(0, 2)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3E8FF),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.storefront_rounded, color: Color(0xFF7C3AED), size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Text(
                                  'ORDERING FROM',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF7C3AED),
                                    letterSpacing: 0.6,
                                  ),
                                ),
                                SizedBox(width: 6),
                                Icon(Icons.verified_rounded, size: 13, color: Color(0xFF10B981)),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              cart.store!.name,
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0F172A)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${cart.count} ${cart.count == 1 ? 'item' : 'items'}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF475569)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── 2. Order Items List ───────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: const [
                      BoxShadow(color: Color(0x04000000), blurRadius: 10, offset: Offset(0, 2)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(18, 16, 18, 8),
                        child: Text(
                          'Selected Dishes',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF0F172A), letterSpacing: -0.2),
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      ...cart.lines.map((line) {
                        final isLast = line == cart.lines.last;
                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: const Icon(Icons.restaurant_rounded, color: Color(0xFF7C3AED), size: 18),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          line.item.name,
                                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A)),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '₱${line.item.price.toStringAsFixed(0)} each',
                                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Quantity pill
                                  Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          iconSize: 16,
                                          padding: const EdgeInsets.all(4),
                                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                          onPressed: () => ref.read(cartProvider.notifier).setQuantity(line.item.id, line.quantity - 1),
                                          icon: Icon(
                                            line.quantity == 1 ? Icons.delete_outline_rounded : Icons.remove_rounded,
                                            color: line.quantity == 1 ? const Color(0xFFEF4444) : const Color(0xFF475569),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 4),
                                          child: Text(
                                            '${line.quantity}',
                                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF0F172A)),
                                          ),
                                        ),
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          iconSize: 16,
                                          padding: const EdgeInsets.all(4),
                                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                          onPressed: () => ref.read(cartProvider.notifier).setQuantity(line.item.id, line.quantity + 1),
                                          icon: const Icon(Icons.add_rounded, color: Color(0xFF7C3AED)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  SizedBox(
                                    width: 60,
                                    child: Text(
                                      '₱${(line.item.price * line.quantity).toStringAsFixed(0)}',
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF0F172A)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!isLast) const Divider(height: 1, color: Color(0xFFF8FAFC)),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── 3. Selectable Delivery Address ─────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Delivery Address',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0F172A), letterSpacing: -0.3),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: () async {
                        await context.push('/addresses/new');
                        ref.read(addressesProvider.notifier).load();
                      },
                      icon: const Icon(Icons.add_location_alt_outlined, size: 16, color: Color(0xFF7C3AED)),
                      label: const Text('+ Add New', style: TextStyle(color: Color(0xFF7C3AED), fontWeight: FontWeight.w800, fontSize: 13)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Saved Addresses Cards
                if (savedAddresses.isNotEmpty) ...[
                  ...savedAddresses.map((addr) {
                    final isSelected = !_useCustomAddress && _selectedAddressId == addr.id;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedAddressId = addr.id;
                          _useCustomAddress = false;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF7C3AED) : const Color(0xFFE2E8F0),
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isSelected ? const Color(0xFF7C3AED).withValues(alpha: 0.08) : const Color(0x04000000),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFFF3E8FF) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                _getAddressIcon(addr.label),
                                color: isSelected ? const Color(0xFF7C3AED) : const Color(0xFF64748B),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        addr.label,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 14,
                                          color: isSelected ? const Color(0xFF7C3AED) : const Color(0xFF0F172A),
                                        ),
                                      ),
                                      if (isSelected) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF7C3AED),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text(
                                            'SELECTED',
                                            style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    addr.address,
                                    style: const TextStyle(color: Color(0xFF475569), fontSize: 12, fontWeight: FontWeight.w500),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                              color: isSelected ? const Color(0xFF7C3AED) : const Color(0xFFCBD5E1),
                              size: 22,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],

                // Custom / Other Address Tile
                GestureDetector(
                  onTap: () => setState(() => _useCustomAddress = true),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _useCustomAddress ? const Color(0xFF7C3AED) : const Color(0xFFE2E8F0),
                        width: _useCustomAddress ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _useCustomAddress ? const Color(0xFFF3E8FF) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.edit_location_alt_rounded,
                                color: _useCustomAddress ? const Color(0xFF7C3AED) : const Color(0xFF64748B),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                savedAddresses.isEmpty ? 'Enter Delivery Location' : 'Or enter other location / use GPS',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: _useCustomAddress ? const Color(0xFF7C3AED) : const Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            Icon(
                              _useCustomAddress ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                              color: _useCustomAddress ? const Color(0xFF7C3AED) : const Color(0xFFCBD5E1),
                              size: 22,
                            ),
                          ],
                        ),
                        if (_useCustomAddress) ...[
                          const SizedBox(height: 14),
                          TextField(
                            controller: _customAddressController,
                            decoration: InputDecoration(
                              labelText: 'Street, Building or Landmark',
                              hintText: 'e.g. Building Name, Unit Number, Landmark',
                              hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                              prefixIcon: const Icon(Icons.place_outlined, color: Color(0xFF7C3AED), size: 20),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.5)),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF0F172A),
                                side: const BorderSide(color: Color(0xFFCBD5E1)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: _locating ? null : _captureCurrentLocation,
                              icon: _locating
                                  ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7C3AED)))
                                  : const Icon(Icons.my_location_rounded, size: 18, color: Color(0xFF7C3AED)),
                              label: Text(
                                _gpsPosition == null ? 'Detect Current GPS Location' : '📍 GPS Captured (${_gpsPosition!.latitude.toStringAsFixed(4)}, ${_gpsPosition!.longitude.toStringAsFixed(4)})',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── 4. Cash On Delivery Guarantee Card ────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1FAE5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.payments_rounded, color: Color(0xFF059669), size: 24),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Payment: Cash on Delivery (COD)',
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF065F46)),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Pay your rider directly upon receiving your warm food.',
                              style: TextStyle(fontSize: 11, color: Color(0xFF047857), fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 20),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── 5. Payment Summary Card ───────────────────────────
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: const [
                      BoxShadow(color: Color(0x04000000), blurRadius: 10, offset: Offset(0, 2)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Payment Summary',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF0F172A), letterSpacing: -0.3),
                      ),
                      const SizedBox(height: 14),
                      _SummaryRow(label: 'Items Subtotal', value: '₱${cart.subtotal.toStringAsFixed(0)}'),
                      const SizedBox(height: 10),
                      const _SummaryRow(label: 'Standard Delivery Fee', value: '₱39'),
                      const SizedBox(height: 10),
                      const _SummaryRow(label: 'Service & Packaging', value: 'FREE', valueColor: Color(0xFF10B981)),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(height: 1, color: Color(0xFFF1F5F9)),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total to Pay',
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0F172A)),
                              ),
                              Text(
                                'Cash on Delivery',
                                style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          Text(
                            '₱${totalAmount.toStringAsFixed(0)}',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: Color(0xFF7C3AED), letterSpacing: -0.5),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

      // ── Floating Sticky Checkout Button ────────────────────────────
      bottomNavigationBar: cart.lines.isEmpty
          ? null
          : Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                boxShadow: [
                  BoxShadow(color: Color(0x0A000000), blurRadius: 16, offset: Offset(0, -4)),
                ],
              ),
              child: SafeArea(
                child: SizedBox(
                  height: 54,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      disabledBackgroundColor: const Color(0xFF7C3AED).withValues(alpha: 0.6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 3,
                      shadowColor: const Color(0xFF7C3AED).withValues(alpha: 0.4),
                    ),
                    onPressed: _placing ? null : () => _checkout(cart, savedAddresses),
                    child: _placing
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)),
                              SizedBox(width: 12),
                              Text('Placing your order...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${cart.count} ${cart.count == 1 ? 'item' : 'items'}',
                                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Text(
                                    'Place COD Order',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.2),
                                  ),
                                ],
                              ),
                              Text(
                                '₱${totalAmount.toStringAsFixed(0)}',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFFF3E8FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shopping_bag_outlined, size: 56, color: Color(0xFF7C3AED)),
            ),
            const SizedBox(height: 20),
            const Text(
              'Your basket is empty',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.5),
            ),
            const SizedBox(height: 8),
            const Text(
              'Explore top-rated restaurants and add your favorite dishes!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B), fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 15),
              ),
              onPressed: () => context.go('/home'),
              icon: const Icon(Icons.storefront_rounded, size: 18),
              label: const Text('Browse Restaurants', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmClearCart() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear Cart?', style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text('Are you sure you want to remove all items from your basket?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(cartProvider.notifier).clear();
            },
            child: const Text('Clear Basket', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  IconData _getAddressIcon(String label) {
    final lower = label.toLowerCase();
    if (lower.contains('home') || lower.contains('house')) return Icons.home_rounded;
    if (lower.contains('work') || lower.contains('office')) return Icons.business_rounded;
    if (lower.contains('campus') || lower.contains('school') || lower.contains('usm')) return Icons.school_rounded;
    return Icons.location_on_rounded;
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: valueColor ?? const Color(0xFF0F172A),
            ),
          ),
        ],
      );
}
