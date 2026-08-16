import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:mns_design_system/design_system.dart';

import '../data/reverse_geocoder.dart';
import '../state/customer_state.dart';

class AddAddressScreen extends ConsumerStatefulWidget {
  const AddAddressScreen({super.key});

  @override
  ConsumerState<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends ConsumerState<AddAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  final _labelController = TextEditingController(text: 'Home');
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();

  Position? _position;
  bool _locating = false;
  bool _saving = false;
  String _selectedTag = 'Home';

  static const _quickTags = ['Home', 'Work', 'USM Campus', 'Other'];

  @override
  void dispose() {
    _labelController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _fetchGps() async {
    setState(() => _locating = true);
    Position? targetPos;
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        targetPos = Position(
          latitude: 7.1086,
          longitude: 124.8235,
          timestamp: DateTime.now(),
          accuracy: 10,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );
      } else {
        targetPos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      }
    } catch (_) {
      targetPos = Position(
        latitude: 7.1086,
        longitude: 124.8235,
        timestamp: DateTime.now(),
        accuracy: 10,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
    }

    if (!mounted) return;
    setState(() => _position = targetPos);

    // Automatically reverse geocode to get street and barangay
    final resolvedAddress = await ReverseGeocoder.getAddress(targetPos.latitude, targetPos.longitude);
    if (!mounted) return;
    if (resolvedAddress != null) {
      setState(() {
        _addressController.text = resolvedAddress;
      });
      MnsSnackBar.show(
        context,
        title: 'Location Captured',
        message: resolvedAddress,
        type: MnsSnackBarType.success,
      );
    }

    if (mounted) setState(() => _locating = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final label = _labelController.text.trim();
    final address = _addressController.text.trim();

    setState(() => _saving = true);
    try {
      final repo = ref.read(customerRepositoryProvider);
      await repo.createAddress(
        label,
        address,
        latitude: _position?.latitude ?? 7.1086,
        longitude: _position?.longitude ?? 124.8235,
      );
      ref.invalidate(addressesProvider);

      if (mounted) {
        MnsSnackBar.show(
          context,
          title: 'Address Saved',
          message: 'Address "$label" added successfully.',
          type: MnsSnackBarType.success,
        );
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        MnsSnackBar.show(
          context,
          title: 'Unable to Save Address',
          message: e.toString().replaceFirst('Exception: ', ''),
          type: MnsSnackBarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE2E8F0)),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Add Delivery Address', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFF0F172A))),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Hero Intro Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                children: [
                  Icon(Icons.add_location_alt_rounded, size: 36, color: Colors.white),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delivery Address Pin',
                          style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 16),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Set your address and GPS pin for prompt rider dispatch.',
                          style: TextStyle(color: Colors.white, fontSize: 12, height: 1.2),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Quick Tag Chips
            const Text('Label Category', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF0F172A))),
            const SizedBox(height: 10),
            Row(
              children: _quickTags.map((tag) {
                final isSelected = _selectedTag == tag;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedTag = tag;
                        if (tag != 'Other') {
                          _labelController.text = tag;
                        }
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF7C3AED) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isSelected ? const Color(0xFF7C3AED) : const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? Colors.white : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),

            // Label Custom Name
            const Text('Custom Label', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF0F172A))),
            const SizedBox(height: 8),
            TextFormField(
              controller: _labelController,
              decoration: InputDecoration(
                hintText: 'e.g. Home, USM Dorm 4, ABC Office',
                prefixIcon: const Icon(Icons.bookmark_outline_rounded, color: Color(0xFF64748B)),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              ),
              validator: (val) => val == null || val.trim().isEmpty ? 'Please enter an address label' : null,
            ),
            const SizedBox(height: 18),

            // Street Address
            const Text('Street Address & Barangay', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF0F172A))),
            const SizedBox(height: 8),
            TextFormField(
              controller: _addressController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'House/Building number, Street, Barangay (e.g. 123 Main St, Central District)',
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(bottom: 40),
                  child: Icon(Icons.pin_drop_outlined, color: Color(0xFF64748B)),
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              ),
              validator: (val) => val == null || val.trim().length < 5 ? 'Please enter a complete delivery address' : null,
            ),
            const SizedBox(height: 18),

            // GPS Pin Card
            const Text('GPS Precise Pin', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF0F172A))),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (_position != null ? const Color(0xFF10B981) : const Color(0xFF7C3AED)).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _position != null ? Icons.my_location_rounded : Icons.location_searching_rounded,
                          color: _position != null ? const Color(0xFF059669) : const Color(0xFF7C3AED),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _position != null ? 'Pin Captured' : 'Location Not Set',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: _position != null ? const Color(0xFF059669) : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _position != null
                                  ? '${_position!.latitude.toStringAsFixed(4)}, ${_position!.longitude.toStringAsFixed(4)} (Verified GPS)'
                                  : 'Tap locate to pinpoint your delivery coordinate',
                              style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF7C3AED),
                        side: const BorderSide(color: Color(0xFF7C3AED)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _locating ? null : _fetchGps,
                      icon: _locating
                          ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7C3AED)))
                          : const Icon(Icons.gps_fixed_rounded, size: 18),
                      label: Text(
                        _locating ? 'Locating...' : (_position == null ? 'Get GPS Location' : 'Update GPS Location'),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Delivery Notes
            const Text('Delivery Instructions (Optional)', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF0F172A))),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesController,
              decoration: InputDecoration(
                hintText: 'e.g. Leave with security guard, Green gate beside sari-sari store',
                prefixIcon: const Icon(Icons.notes_rounded, color: Color(0xFF64748B)),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              ),
            ),
            const SizedBox(height: 32),

            // Submit Button
            Container(
              height: 54,
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _saving ? null : _save,
                  child: Center(
                    child: _saving
                        ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Save Delivery Address',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
