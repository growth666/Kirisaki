import 'package:flutter/material.dart';

import '../../../../core/source/source_service.dart';
import 'source_manage_page.dart';

class CustomSourcesPage extends StatelessWidget {
  const CustomSourcesPage({super.key, this.service});
  final SourceService? service;
  @override
  Widget build(BuildContext context) =>
      SourceManagePage(service: service, customOnly: true);
}
