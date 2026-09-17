import 'dart:async';

import 'package:flutter/material.dart';

import '../api_client.dart';
import '../console_socket.dart';
import '../credentials.dart';
import '../models.dart';

class ConsoleTab extends StatefulWidget {
  final Credentials credentials;
  final PteroServer server;
  final TabController tabController;

  const ConsoleTab({super.key, required this.credentials, required this.server, required this.tabController});

  @override
  State<ConsoleTab> createState() => _ConsoleTabState();
}

class _ConsoleTabState extends State<ConsoleTab> {
  late final PterodactylApiClient _api;
  ConsoleSocket? _socket;
  StreamSubscription<ConsoleEvent>? _subscription;
  final _lines = <String>[];
  final _commandController = TextEditingController();
  final _scrollController = ScrollController();
  bool _connecting = false;
  bool _connected = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _api = PterodactylApiClient(widget.credentials);
    widget.tabController.addListener(_onTabChanged);
    if (widget.tabController.index == 1) _connect();
  }

  @override
  void dispose() {
    widget.tabController.removeListener(_onTabChanged);
    _subscription?.cancel();
    _socket?.dispose();
    _commandController.dispose();
    _scrollController.dispose();
    _api.close();
    super.dispose();
  }

  void _onTabChanged() {
    if (widget.tabController.index == 1 && _socket == null && !_connecting) {
      _connect();
    }
  }

  Future<void> _connect() async {
    setState(() {
      _connecting = true;
      _error = null;
    });
    final socket = ConsoleSocket(_api, widget.server.identifier);
    _subscription = socket.events.listen(_handleEvent);
    try {
      await socket.connect();
      if (!mounted) return;
      setState(() {
        _socket = socket;
        _connecting = false;
        _connected = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _connecting = false;
        _error = 'Could not connect to console';
      });
    }
  }

  void _handleEvent(ConsoleEvent event) {
    if (!mounted) return;
    switch (event) {
      case ConsoleOutput(:final line):
        setState(() {
          _lines.add(line);
          if (_lines.length > 500) _lines.removeAt(0);
        });
        _scrollToBottom();
      case SocketClosed():
        setState(() => _connected = false);
      default:
        break;
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  void _send() {
    final text = _commandController.text.trim();
    if (text.isEmpty || _socket == null) return;
    _socket!.sendCommand(text);
    _commandController.clear();
  }

  void _reconnect() {
    _subscription?.cancel();
    _socket?.dispose();
    _socket = null;
    setState(() => _lines.clear());
    _connect();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_error != null || (!_connected && !_connecting))
          MaterialBanner(
            content: Text(_error ?? 'Console disconnected'),
            actions: [TextButton(onPressed: _reconnect, child: const Text('Reconnect'))],
          ),
        Expanded(
          child: _connecting && _lines.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : Container(
                  color: Colors.black,
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: _lines.length,
                    itemBuilder: (context, index) => Text(
                      _lines[index],
                      style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commandController,
                  decoration: const InputDecoration(hintText: 'Enter command', border: OutlineInputBorder()),
                  enabled: _connected,
                  onSubmitted: (_) => _send(),
                ),
              ),
              IconButton(icon: const Icon(Icons.send), onPressed: _connected ? _send : null),
            ],
          ),
        ),
      ],
    );
  }
}
