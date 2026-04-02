import 'package:flutter/material.dart';

import 'tracer_form_page.dart';

class BSSWTracerPage extends StatelessWidget {
  const BSSWTracerPage({super.key, required this.userId});

  final int userId;

  @override
  Widget build(BuildContext context) {
    return TracerFormPage(userId: userId, programCode: 'BSSW');
  }
}
