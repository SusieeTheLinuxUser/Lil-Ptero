import 'package:flutter/material.dart';

import '../api_client.dart';
import '../credentials.dart';
import '../models.dart';
import 'server_detail_screen.dart';
import 'settings_screen.dart';

class ServerListScreen extends StatefulWidget {
  final Credentials credentials;

  /// Overrides the API client the screen polls, for widget tests (same role
  /// as the console tab's apiClient).
  final PterodactylApiClient? apiClient;
  const ServerListScreen({super.key, required this.credentials, this.apiClient});

  @override
  State<ServerListScreen> createState() => _ServerListScreenState();
}

class _ServerListScreenState extends State<ServerListScreen> {
  late final PterodactylApiClient _client;
  late Future<List<PteroServer>> _future;

  @override
  void initState() {
    super.initState();
    _client = widget.apiClient ?? PterodactylApiClient(widget.credentials);
    _future = _client.listServers();
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  Future<void> _refresh() async {
    // Capture the new request before setState. The closure must be a block:
    // an assignment expression (`() => _future = f`) returns the assigned
    // value, and a Future from setState triggers a framework assertion.
    final future = _client.listServers();
    setState(() {
      _future = future;
    });
    try {
      await future;
    } catch (_) {
      // FutureBuilder already renders the error; don't rethrow into onRefresh.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Servers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => SettingsScreen(credentials: widget.credentials)),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<PteroServer>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              final message =
                  snapshot.error is ApiException ? (snapshot.error as ApiException).message : 'Something went wrong';
              // Always scrollable: a short list can't be dragged on Android,
              // which would make pull to refresh — and the retry — dead.
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 80),
                  Center(child: Text(message)),
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: _refresh,
                      child: const Text('Retry'),
                    ),
                  ),
                ],
              );
            }
            final servers = snapshot.data!;
            if (servers.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [SizedBox(height: 80), Center(child: Text('No servers found'))],
              );
            }
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: servers.length,
              itemBuilder: (context, index) {
                final server = servers[index];
                return ListTile(
                  title: Text(server.name),
                  subtitle: Text(server.identifier),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ServerDetailScreen(credentials: widget.credentials, server: server),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
