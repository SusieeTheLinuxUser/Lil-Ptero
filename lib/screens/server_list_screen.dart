import 'package:flutter/material.dart';

import '../api_client.dart';
import '../credentials.dart';
import '../models.dart';
import 'server_detail_screen.dart';
import 'settings_screen.dart';

class ServerListScreen extends StatefulWidget {
  final Credentials credentials;
  const ServerListScreen({super.key, required this.credentials});

  @override
  State<ServerListScreen> createState() => _ServerListScreenState();
}

class _ServerListScreenState extends State<ServerListScreen> {
  late final PterodactylApiClient _client;
  late Future<List<PteroServer>> _future;

  @override
  void initState() {
    super.initState();
    _client = PterodactylApiClient(widget.credentials);
    _future = _client.listServers();
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _future = _client.listServers());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Servers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
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
              return ListView(
                children: [const SizedBox(height: 80), Center(child: Text(message))],
              );
            }
            final servers = snapshot.data!;
            if (servers.isEmpty) {
              return ListView(
                children: const [SizedBox(height: 80), Center(child: Text('No servers found'))],
              );
            }
            return ListView.builder(
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
