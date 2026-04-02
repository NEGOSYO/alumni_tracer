import 'package:flutter/material.dart';

import 'tracer_form_page.dart';

class BSITTracerPage extends StatelessWidget {
  const BSITTracerPage({super.key, required this.userId});

  final int userId;

  @override
  Widget build(BuildContext context) {
    return TracerFormPage(userId: userId, programCode: 'BSIT');
  }
}
