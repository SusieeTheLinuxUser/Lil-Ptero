import 'package:flutter/material.dart';

import '../credentials.dart';
import '../models.dart';
import 'console_tab.dart';
import 'overview_tab.dart';

class ServerDetailScreen extends StatefulWidget {
  final Credentials credentials;
  final PteroServer server;
  const ServerDetailScreen({super.key, required this.credentials, required this.server});

  @override
  State<ServerDetailScreen> createState() => _ServerDetailScreenState();
}

class _ServerDetailScreenState extends State<ServerDetailScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.server.name),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Overview'), Tab(text: 'Console')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          OverviewTab(credentials: widget.credentials, server: widget.server),
          ConsoleTab(credentials: widget.credentials, server: widget.server, tabController: _tabController),
        ],
      ),
    );
  }
}
