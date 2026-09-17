import 'dart:async';

import 'package:flutter/material.dart';

import '../api_client.dart';
import '../credentials.dart';
import '../format.dart';
import '../models.dart';
import '../widgets/resource_gauge.dart';

class OverviewTab extends StatefulWidget {
  final Credentials credentials;
  final PteroServer server;
  const OverviewTab({super.key, required this.credentials, required this.server});

  @override
  State<OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<OverviewTab> {
  late final PterodactylApiClient _api;
  Timer? _timer;
  ServerResources? _resources;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _api = PterodactylApiClient(widget.credentials);
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _api.close();
    super.dispose();
  }

  Future<void> _poll() async {
    try {
      final resources = await _api.getResources(widget.server.identifier);
      if (mounted) {
        setState(() {
          _resources = resources;
          _error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  String _label(String signal) => signal[0].toUpperCase() + signal.substring(1);

  Future<void> _power(String signal) async {
    if (signal == 'stop' || signal == 'restart' || signal == 'kill') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('${_label(signal)} server?'),
          content: Text('Are you sure you want to $signal this server?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: Text(_label(signal))),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    setState(() => _busy = true);
    try {
      await _api.sendPower(widget.server.identifier, signal);
      await _poll();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final resources = _resources;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        if (resources == null)
          const Center(child: CircularProgressIndicator())
        else ...[
          Chip(label: Text(resources.currentState.name.toUpperCase())),
          const SizedBox(height: 16),
          ResourceGauge(
            label: 'CPU',
            value: resources.cpuAbsolute / 100,
            valueLabel: '${resources.cpuAbsolute.toStringAsFixed(1)}%',
          ),
          ResourceGauge(
            label: 'Memory',
            value: widget.server.memoryLimitMb == 0
                ? 0
                : resources.memoryBytes / (widget.server.memoryLimitMb * 1024 * 1024),
            valueLabel: formatBytes(resources.memoryBytes),
          ),
          ResourceGauge(
            label: 'Disk',
            value:
                widget.server.diskLimitMb == 0 ? 0 : resources.diskBytes / (widget.server.diskLimitMb * 1024 * 1024),
            valueLabel: formatBytes(resources.diskBytes),
          ),
          const SizedBox(height: 8),
          Text('Uptime: ${formatUptime(Duration(milliseconds: resources.uptimeMs))}'),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            children: [
              FilledButton(onPressed: _busy ? null : () => _power('start'), child: const Text('Start')),
              OutlinedButton(onPressed: _busy ? null : () => _power('restart'), child: const Text('Restart')),
              OutlinedButton(onPressed: _busy ? null : () => _power('stop'), child: const Text('Stop')),
              TextButton(
                onPressed: _busy ? null : () => _power('kill'),
                style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                child: const Text('Kill'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
