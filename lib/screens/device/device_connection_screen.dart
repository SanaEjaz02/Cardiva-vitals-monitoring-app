import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/vital_provider.dart';
import '../../router/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class DeviceConnectionScreen extends ConsumerStatefulWidget {
  const DeviceConnectionScreen({super.key});

  @override
  ConsumerState<DeviceConnectionScreen> createState() =>
      _DeviceConnectionScreenState();
}

class _DeviceConnectionScreenState
    extends ConsumerState<DeviceConnectionScreen> {
  final List<ScanResult> _results = [];
  BluetoothDevice? _connectedDevice;
  String? _connectedName;
  BluetoothDevice? _connecting;
  bool _isScanning = false;
  bool _btOn = false;

  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothAdapterState>? _adapterSub;
  StreamSubscription<BluetoothConnectionState>? _connSub;

  @override
  void initState() {
    super.initState();
    _loadSaved();
    _adapterSub = FlutterBluePlus.adapterState.listen((state) {
      final on = state == BluetoothAdapterState.on;
      if (mounted) setState(() => _btOn = on);
      if (on && _results.isEmpty && !_isScanning) _startScan();
    });
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _adapterSub?.cancel();
    _connSub?.cancel();
    if (_isScanning) FlutterBluePlus.stopScan();
    super.dispose();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final id   = prefs.getString('ble_device_id');
    final name = prefs.getString('ble_device_name');
    if (id != null && name != null && mounted) {
      setState(() => _connectedName = name);
    }
  }

  Future<void> _startScan() async {
    final state = await FlutterBluePlus.adapterState.first;
    if (state != BluetoothAdapterState.on) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please turn on Bluetooth to scan for devices.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    setState(() {
      _results.clear();
      _isScanning = true;
    });

    _scanSub?.cancel();
    _scanSub = FlutterBluePlus.onScanResults.listen((results) {
      if (!mounted) return;
      setState(() {
        for (final r in results) {
          final i = _results
              .indexWhere((e) => e.device.remoteId == r.device.remoteId);
          if (i >= 0) {
            _results[i] = r;
          } else {
            _results.add(r);
          }
        }
        _results.sort((a, b) => b.rssi.compareTo(a.rssi));
      });
    });

    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 12),
      androidUsesFineLocation: false,
    );

    if (mounted) setState(() => _isScanning = false);
  }

  Future<void> _connect(BluetoothDevice device) async {
    if (_connecting != null) return;
    setState(() => _connecting = device);

    try {
      await device.connect(timeout: const Duration(seconds: 12));

      _connSub?.cancel();
      _connSub = device.connectionState.listen((s) {
        if (!mounted) return;
        if (s == BluetoothConnectionState.disconnected) {
          ref.read(bleConnectedProvider.notifier).state = false;
          setState(() => _connectedDevice = null);
        }
      });

      final name = device.platformName.isNotEmpty
          ? device.platformName
          : 'Device (${device.remoteId.toString().substring(0, 8)})';

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ble_device_id', device.remoteId.toString());
      await prefs.setString('ble_device_name', name);

      // Attach to BleService so readingStream becomes active
      await ref.read(bleServiceProvider).attachDevice(device);
      ref.read(bleConnectedProvider.notifier).state = true;

      if (mounted) {
        setState(() {
          _connectedDevice = device;
          _connectedName = name;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connected to $name'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connection failed. Please try again.'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _connecting = null);
    }
  }

  Future<void> _disconnect() async {
    try {
      await _connectedDevice?.disconnect();
      await ref.read(bleServiceProvider).detach();
      ref.read(bleConnectedProvider.notifier).state = false;

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('ble_device_id');
      await prefs.remove('ble_device_name');
      if (mounted) {
        setState(() {
          _connectedDevice = null;
          _connectedName = null;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final bleConnected = ref.watch(bleConnectedProvider);

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        backgroundColor: AppColors.bgLight,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              size: 20, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Connect Device', style: AppTextStyles.h1),
        centerTitle: true,
        actions: [
          if (!_isScanning)
            IconButton(
              icon: const Icon(Icons.refresh_rounded,
                  color: AppColors.primary, size: 22),
              onPressed: _startScan,
              tooltip: 'Scan again',
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Connected device banner ─────────────────────────────────
          if (_connectedDevice != null || _connectedName != null)
            _ConnectedBanner(
              name: _connectedName ?? 'Connected Device',
              onDisconnect: _disconnect,
              onViewLive: bleConnected
                  ? () => Navigator.pushNamed(context, AppRouter.liveMonitor)
                  : null,
            ),

          // ── Scan status bar ─────────────────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            color: _isScanning
                ? AppColors.primary.withValues(alpha: 0.06)
                : Colors.transparent,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                if (_isScanning) ...[
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary),
                  ),
                  const SizedBox(width: 10),
                  Text('Scanning for devices…',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.primary)),
                ] else ...[
                  Icon(
                    _btOn
                        ? Icons.bluetooth_searching_rounded
                        : Icons.bluetooth_disabled_rounded,
                    size: 16,
                    color: _btOn
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _btOn
                        ? '${_results.length} device${_results.length == 1 ? '' : 's'} found  ·  Tap to connect'
                        : 'Bluetooth is off',
                    style: AppTextStyles.caption,
                  ),
                ],
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.divider),

          // ── Device list ─────────────────────────────────────────────
          Expanded(
            child: _results.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    itemCount: _results.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final r = _results[i];
                      final isConnecting =
                          _connecting?.remoteId == r.device.remoteId;
                      final isConnected =
                          _connectedDevice?.remoteId == r.device.remoteId;
                      return _DeviceTile(
                        result: r,
                        isConnecting: isConnecting,
                        isConnected: isConnected,
                        onTap: isConnected
                            ? _disconnect
                            : () => _connect(r.device),
                      );
                    },
                  ),
          ),

          // ── Bottom hint ─────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Text(
                'Make sure your wearable band is powered on and in pairing mode.',
                style: AppTextStyles.caption,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: AppColors.primaryBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.bluetooth_searching_rounded,
                color: AppColors.primary, size: 36),
          ),
          const SizedBox(height: 16),
          Text(
            _isScanning ? 'Looking for devices…' : 'No devices found',
            style: AppTextStyles.h2,
          ),
          const SizedBox(height: 8),
          Text(
            _isScanning
                ? 'Keep your band close and in pairing mode.'
                : 'Turn on your band and tap the refresh button.',
            style: AppTextStyles.caption,
            textAlign: TextAlign.center,
          ),
          if (!_isScanning) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _startScan,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Scan Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Connected banner ──────────────────────────────────────────────────────────

class _ConnectedBanner extends StatelessWidget {
  final String name;
  final VoidCallback onDisconnect;
  final VoidCallback? onViewLive;

  const _ConnectedBanner({
    required this.name,
    required this.onDisconnect,
    this.onViewLive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.successBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.watch_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: AppTextStyles.body
                            .copyWith(fontWeight: FontWeight.w600)),
                    Text('Connected',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.success)),
                  ],
                ),
              ),
              TextButton(
                onPressed: onDisconnect,
                style: TextButton.styleFrom(
                    foregroundColor: AppColors.danger),
                child: const Text('Disconnect'),
              ),
            ],
          ),
          if (onViewLive != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onViewLive,
                icon: const Icon(Icons.monitor_heart_rounded, size: 18),
                label: const Text('View Live Data'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Device list tile ──────────────────────────────────────────────────────────

class _DeviceTile extends StatelessWidget {
  final ScanResult result;
  final bool isConnecting;
  final bool isConnected;
  final VoidCallback onTap;

  const _DeviceTile({
    required this.result,
    required this.isConnecting,
    required this.isConnected,
    required this.onTap,
  });

  String get _name {
    final n = result.device.platformName;
    return n.isNotEmpty
        ? n
        : 'Unknown Device (${result.device.remoteId.toString().substring(0, 8)})';
  }

  int get _bars {
    final rssi = result.rssi;
    if (rssi >= -60) return 4;
    if (rssi >= -70) return 3;
    if (rssi >= -80) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isConnected ? AppColors.successBg : AppColors.bgWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isConnected
              ? AppColors.success.withValues(alpha: 0.4)
              : AppColors.divider,
        ),
        boxShadow: const [
          BoxShadow(
              color: AppColors.shadowSm,
              blurRadius: 8,
              offset: Offset(0, 2))
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: isConnected
                ? AppColors.success.withValues(alpha: 0.15)
                : AppColors.primaryBg,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.watch_rounded,
            color: isConnected ? AppColors.success : AppColors.primary,
            size: 20,
          ),
        ),
        title: Text(_name,
            style:
                AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Row(
          children: [
            _SignalBars(bars: _bars),
            const SizedBox(width: 6),
            Text('${result.rssi} dBm', style: AppTextStyles.caption),
          ],
        ),
        trailing: isConnecting
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.primary),
              )
            : isConnected
                ? const Icon(Icons.check_circle_rounded,
                    color: AppColors.success, size: 22)
                : ElevatedButton(
                    onPressed: onTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Connect',
                        style: TextStyle(fontSize: 12)),
                  ),
        onTap: isConnected ? onTap : null,
      ),
    );
  }
}

// ── Signal bars widget ────────────────────────────────────────────────────────

class _SignalBars extends StatelessWidget {
  final int bars;

  const _SignalBars({required this.bars});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(4, (i) {
        final active = i < bars;
        final heights = [6.0, 9.0, 12.0, 15.0];
        return Container(
          width: 3,
          height: heights[i],
          margin: const EdgeInsets.only(right: 2),
          decoration: BoxDecoration(
            color: active ? AppColors.primary : AppColors.divider,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}
