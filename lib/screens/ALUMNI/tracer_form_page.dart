import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:signature/signature.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/api_service.dart';
import '../../services/activity_service.dart';

Map<String, dynamic> _parseJsonResponse(http.Response response) {
  try {
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return {
      'success': false,
      'message': 'Unexpected response format from server.',
    };
  } catch (_) {
    final snippet = response.body.replaceAll(RegExp(r'\s+'), ' ').trim();
    return {
      'success': false,
      'message': response.statusCode >= 500
          ? 'Server error while saving the tracer form.'
          : 'Server returned an invalid response: ${snippet.length > 160 ? snippet.substring(0, 160) : snippet}',
    };
  }
}

String _stringOrEmpty(dynamic value) {
  if (value == null) return '';
  final text = value.toString().trim();
  return text.toLowerCase() == 'null' ? '' : text;
}

enum _FieldType { text, multiline, dropdown, checkboxGroup, rating, decade }

class _QuestionDef {
  const _QuestionDef({
    required this.key,
    required this.label,
    required this.type,
    this.options = const [],
    this.numberLabel,
    this.required = false,
    this.min = 1,
    this.max = 5,
  });

  final String key;
  final String label;
  final _FieldType type;
  final List<String> options;
  final String? numberLabel;
  final bool required;
  final double min;
  final double max;
}

class _ProgramConfig {
  const _ProgramConfig({
    required this.programCode,
    required this.programTitle,
    required this.programSubtitle,
    required this.currentJobRelatedLabel,
    required this.studyTypeOptions,
    required this.licensureLabel,
    required this.licensureTypeLabel,
    required this.licensureResultLabel,
    required this.skillsOptions,
    required this.peoStatements,
    required this.curriculumSatisfactionLabel,
    required this.recommendationLabel,
    required this.reputationLabel,
    required this.feedbackCompetenciesLabel,
  });

  final String programCode;
  final String programTitle;
  final String programSubtitle;
  final String currentJobRelatedLabel;
  final List<String> studyTypeOptions;
  final String licensureLabel;
  final String licensureTypeLabel;
  final String licensureResultLabel;
  final List<String> skillsOptions;
  final List<String> peoStatements;
  final String curriculumSatisfactionLabel;
  final String recommendationLabel;
  final String reputationLabel;
  final String feedbackCompetenciesLabel;
}

class _CareerTimelineEntry {
  _CareerTimelineEntry({
    String? position,
    String? employer,
    String? employmentType,
    String? sector,
    String? location,
    String? startDate,
    String? endDate,
    String? salaryRange,
    String? relatedToDegree,
    String? notes,
    this.isCurrent = false,
  }) : positionController = TextEditingController(text: position ?? ''),
       employerController = TextEditingController(text: employer ?? ''),
       employmentTypeController = TextEditingController(
         text: employmentType ?? '',
       ),
       sectorController = TextEditingController(text: sector ?? ''),
       locationController = TextEditingController(text: location ?? ''),
       startDateController = TextEditingController(text: startDate ?? ''),
       endDateController = TextEditingController(text: endDate ?? ''),
       salaryRangeController = TextEditingController(text: salaryRange ?? ''),
       relatedToDegreeController = TextEditingController(
         text: relatedToDegree ?? '',
       ),
       notesController = TextEditingController(text: notes ?? '');

  final TextEditingController positionController;
  final TextEditingController employerController;
  final TextEditingController employmentTypeController;
  final TextEditingController sectorController;
  final TextEditingController locationController;
  final TextEditingController startDateController;
  final TextEditingController endDateController;
  final TextEditingController salaryRangeController;
  final TextEditingController relatedToDegreeController;
  final TextEditingController notesController;
  bool isCurrent;

  factory _CareerTimelineEntry.fromMap(Map<String, dynamic> map) {
    return _CareerTimelineEntry(
      position: _stringOrEmpty(map['position'] ?? map['job_title']),
      employer: _stringOrEmpty(
        map['employer'] ?? map['company'] ?? map['company_name'],
      ),
      employmentType: _stringOrEmpty(map['employment_type'] ?? map['job_type']),
      sector: _stringOrEmpty(map['sector'] ?? map['industry']),
      location: _stringOrEmpty(map['location'] ?? map['country']),
      startDate: _stringOrEmpty(map['start_date']),
      endDate: _stringOrEmpty(map['end_date']),
      salaryRange: _stringOrEmpty(
        map['salary_range'] ?? map['monthly_income'] ?? map['income_range'],
      ),
      relatedToDegree: _stringOrEmpty(
        map['related_to_degree'] ?? map['related_job'] ?? map['job_related'],
      ),
      notes: _stringOrEmpty(map['notes'] ?? map['employment_status']),
      isCurrent: map['is_current'] == true || map['is_current'] == 'true',
    );
  }

  Map<String, dynamic> toMap() {
    final position = positionController.text.trim();
    final employer = employerController.text.trim();
    final employmentType = employmentTypeController.text.trim();
    final sector = sectorController.text.trim();
    final location = locationController.text.trim();
    final startDate = startDateController.text.trim();
    final endDate = isCurrent ? '' : endDateController.text.trim();
    final salaryRange = salaryRangeController.text.trim();
    final relatedToDegree = relatedToDegreeController.text.trim();
    final notes = notesController.text.trim();

    return {
      'position': position,
      'job_title': position,
      'employer': employer,
      'company': employer,
      'company_name': employer,
      'employment_type': employmentType,
      'job_type': employmentType,
      'sector': sector,
      'industry': sector,
      'location': location,
      'country': location,
      'start_date': startDate,
      'end_date': endDate,
      'salary_range': salaryRange,
      'monthly_income': salaryRange,
      'income_range': salaryRange,
      'related_to_degree': relatedToDegree,
      'related_job': relatedToDegree,
      'job_related': relatedToDegree,
      'notes': notes,
      'employment_status': notes,
      'is_current': isCurrent,
    };
  }

  bool get hasMeaningfulValue =>
      positionController.text.trim().isNotEmpty ||
      employerController.text.trim().isNotEmpty ||
      startDateController.text.trim().isNotEmpty;

  void dispose() {
    positionController.dispose();
    employerController.dispose();
    employmentTypeController.dispose();
    sectorController.dispose();
    locationController.dispose();
    startDateController.dispose();
    endDateController.dispose();
    salaryRangeController.dispose();
    relatedToDegreeController.dispose();
    notesController.dispose();
  }
}

class TracerFormPage extends StatefulWidget {
  const TracerFormPage({
    super.key,
    required this.userId,
    required this.programCode,
  });

  final int userId;
  final String programCode;

  @override
  State<TracerFormPage> createState() => _TracerFormPageState();
}

class _TracerFormPageState extends State<TracerFormPage> {
  static const Color _maroon = Color(0xFF4A152C);
  static const Color _rose = Color(0xFF8C3A57);
  static const Color _cream = Color(0xFFF8F3F1);
  static const Color _ink = Color(0xFF1F2937);
  static const String _agreementVersion = 'JMC-TRACER-2026.1';
  static const String _agreementText =
      'Privacy and Data Use Agreement\n\n'
      'By signing and submitting this tracer form, I confirm that the information I provided is true, complete, and voluntarily given. I understand that JMC may collect, process, store, and review my tracer responses for alumni engagement, institutional quality assurance, program review, accreditation, graduate outcome reporting, and related academic or administrative purposes.\n\n'
      'I understand that my submission may include personal data, employment history, educational information, and my digital signature. I agree that these records may be retained as an official tracer submission record together with the exact agreement text shown at the time of signing, a submission timestamp, and a unique submission reference number.\n\n'
      'I understand that this signed submission may be converted into a PDF record and securely stored by the institution. I also understand that my information will be handled in accordance with the Data Privacy Act of 2012 and institutional data governance procedures. By checking the agreement box and providing my digital signature, I confirm my consent to this processing and record retention.';

  final _formKey = GlobalKey<FormState>();
  final SignatureController _signature = SignatureController(
    penStrokeWidth: 2.8,
    penColor: Colors.black,
    exportPenColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasExistingSubmission = false;
  bool _hasDraftSaved = false;
  bool _isReadOnly = false;
  bool _isCareerUpdateMode = false;
  bool _agreeToConsent = false;
  String _submissionDateIso = '';
  String? _existingSignatureBase64;
  Uint8List? _existingSignatureBytes;
  String? _latestReferenceId;
  String? _latestPdfDownloadUrl;
  String? _latestAgreementVersion;
  int _signedSubmissionCount = 0;

  late final _ProgramConfig _config;
  late final Map<String, TextEditingController> _textControllers;
  late final TextEditingController _submissionDateController;
  final Map<String, String?> _dropdownValues = {};
  final Map<String, double> _ratingValues = {};
  final Map<String, List<String>> _multiSelectValues = {};
  final List<_CareerTimelineEntry> _careerTimeline = [];

  final List<_QuestionDef> _graduateProfileQuestions = const [
    _QuestionDef(
      key: 'name',
      label: 'Name',
      numberLabel: '1',
      type: _FieldType.text,
    ),
    _QuestionDef(
      key: 'tracer_batch',
      label: 'Tracer Batch',
      type: _FieldType.dropdown,
      options: ['1 Year After Graduation', '3 Years', '5 Years'],
      required: true,
    ),
    _QuestionDef(
      key: 'sex',
      label: '2. Sex',
      type: _FieldType.dropdown,
      options: ['Male', 'Female', 'Prefer not to say'],
      required: true,
    ),
    _QuestionDef(
      key: 'age',
      label: '3. Age',
      type: _FieldType.text,
      required: true,
    ),
    _QuestionDef(
      key: 'civil_status',
      label: '4. Civil Status',
      type: _FieldType.dropdown,
      options: ['Single', 'Married', 'Widowed', 'Separated'],
      required: true,
    ),
    _QuestionDef(
      key: 'address',
      label: '5. Permanent Address',
      type: _FieldType.multiline,
      required: true,
    ),
    _QuestionDef(
      key: 'contact',
      label: '6. Contact Number / Email',
      type: _FieldType.text,
      required: true,
    ),
    _QuestionDef(
      key: 'year_graduated',
      label: '7. Year Graduated',
      type: _FieldType.text,
      required: true,
    ),
    _QuestionDef(
      key: 'honors_awards',
      label: '8. Honors or Awards (if any)',
      type: _FieldType.text,
    ),
    _QuestionDef(
      key: 'pre_grad_exp',
      label: '9. Pre-graduation Employment Experience',
      type: _FieldType.dropdown,
      options: ['None', 'Internship', 'Part-time', 'Full-time'],
      required: true,
    ),
    _QuestionDef(
      key: 'study_mode',
      label: '10. Type of Study Mode',
      type: _FieldType.dropdown,
      options: ['Regular', 'Distance/Online', 'Mixed'],
      required: true,
    ),
  ];

  List<_QuestionDef> get _employmentQuestions => [
    const _QuestionDef(
      key: 'employment_status',
      label: '11. Current Employment Status',
      type: _FieldType.dropdown,
      options: [
        'Employed',
        'Self-Employed',
        'Employer',
        'Unemployed',
        'Studying Full-Time',
      ],
      required: true,
    ),
    const _QuestionDef(
      key: 'unemployed_reason',
      label: '12. If unemployed, reason',
      type: _FieldType.dropdown,
      options: [
        'Further study',
        'Family/health reasons',
        'Lack of job opportunities',
        'Relocation',
        'Others',
      ],
    ),
    const _QuestionDef(
      key: 'unemployed_reason_other',
      label: 'Other reason',
      numberLabel: '12a',
      type: _FieldType.text,
    ),
    const _QuestionDef(
      key: 'time_to_first_job',
      label: '13. Time to first employment after graduation',
      type: _FieldType.dropdown,
      options: [
        '<1 month',
        '1-3 months',
        '4-6 months',
        '7-12 months',
        '>1 year',
      ],
    ),
    const _QuestionDef(
      key: 'first_job_related',
      label: '14. First job related to degree?',
      type: _FieldType.dropdown,
      options: ['Yes', 'Partly', 'No'],
    ),
    const _QuestionDef(
      key: 'job_type',
      label: '15. Present Employment Type',
      type: _FieldType.dropdown,
      options: ['Full-time', 'Part-time', 'Project-based', 'Freelance'],
    ),
    const _QuestionDef(
      key: 'job_title',
      label: '16. Job Title / Position',
      type: _FieldType.text,
    ),
    const _QuestionDef(
      key: 'employer',
      label: '17. Employer / Agency / Organization',
      type: _FieldType.text,
    ),
    const _QuestionDef(
      key: 'sector',
      label: '18. Sector',
      type: _FieldType.dropdown,
      options: ['Government', 'Private', 'NGO', 'Academic', 'Overseas'],
    ),
    const _QuestionDef(
      key: 'country',
      label: '19. Country of Work',
      type: _FieldType.dropdown,
      options: ['Philippines', 'Other'],
    ),
    const _QuestionDef(
      key: 'country_other',
      label: 'Specify country',
      numberLabel: '19a',
      type: _FieldType.text,
    ),
    const _QuestionDef(
      key: 'monthly_income',
      label: '20. Monthly Income',
      type: _FieldType.dropdown,
      options: ['<15k', '15-25k', '25-35k', '35-50k', '50-75k', '>75k'],
    ),
    _QuestionDef(
      key: 'related_job',
      label: _config.currentJobRelatedLabel,
      type: _FieldType.dropdown,
      options: ['Yes', 'Somewhat', 'No'],
    ),
    const _QuestionDef(
      key: 'underutilized_reason',
      label: '22. If not related, main reason',
      type: _FieldType.dropdown,
      options: [
        'No jobs in field',
        'Better pay elsewhere',
        'Lack of experience',
        'Location limits',
        'Job satisfaction in another field',
      ],
    ),
    const _QuestionDef(
      key: 'employment_duration',
      label: '23. How long have you been in your current position?',
      type: _FieldType.dropdown,
      options: ['<6 months', '6-12 months', '1-2 years', '3+ years'],
    ),
    const _QuestionDef(
      key: 'promoted',
      label: '24. Have you been promoted since your first job?',
      type: _FieldType.dropdown,
      options: ['Yes', 'No'],
    ),
    const _QuestionDef(
      key: 'want_more_hours',
      label: '25. Would you like to work more hours than you currently do?',
      type: _FieldType.dropdown,
      options: ['Yes', 'No'],
    ),
    const _QuestionDef(
      key: 'more_hours_reason',
      label: 'If yes, why?',
      numberLabel: '25a',
      type: _FieldType.dropdown,
      options: [
        'No available hours',
        'Studying',
        'Family obligations',
        'Lack of local opportunities',
      ],
    ),
    const _QuestionDef(
      key: 'job_satisfaction',
      label: '26. Rate your overall job satisfaction',
      type: _FieldType.rating,
      min: 1,
      max: 5,
      required: true,
    ),
  ];

  final List<_QuestionDef> _skillsQuestions = const [
    _QuestionDef(
      key: 'skills_utilization',
      label:
          '27. How much do you use your college-acquired skills in your current job?',
      type: _FieldType.rating,
      min: 1,
      max: 5,
      required: true,
    ),
    _QuestionDef(
      key: 'overqualified_level',
      label:
          '28. Do you consider yourself overqualified or underutilized for your current position?',
      type: _FieldType.dropdown,
      options: ['No', 'Slightly', 'Somewhat', 'Much', 'Very much'],
      required: true,
    ),
    _QuestionDef(
      key: 'skills',
      label: '29. Top competencies you use at work',
      type: _FieldType.checkboxGroup,
      required: true,
    ),
    _QuestionDef(
      key: 'skills_not_used_reason',
      label: '30. Main reason your skills might not be fully used',
      type: _FieldType.dropdown,
      options: [
        'Job mismatch',
        'No suitable jobs',
        'Limited experience',
        'Satisfied in current work',
        'Financial reasons',
      ],
      required: true,
    ),
    _QuestionDef(
      key: 'employment_classification',
      label: '31. Employment classification',
      type: _FieldType.dropdown,
      options: ['Rank-and-file', 'Supervisory', 'Managerial', 'Executive'],
    ),
  ];
  List<_QuestionDef> get _satisfactionQuestions => [
    _QuestionDef(
      key: 'satisfaction_curriculum',
      label: _config.curriculumSatisfactionLabel,
      numberLabel: '48',
      type: _FieldType.rating,
      min: 1,
      max: 5,
      required: true,
    ),
    const _QuestionDef(
      key: 'satisfaction_faculty',
      label: 'Quality of faculty instruction and mentorship',
      numberLabel: '49',
      type: _FieldType.rating,
      min: 1,
      max: 5,
      required: true,
    ),
    const _QuestionDef(
      key: 'satisfaction_practicum',
      label: 'Field instruction / practicum supervision',
      numberLabel: '50',
      type: _FieldType.rating,
      min: 1,
      max: 5,
      required: true,
    ),
    const _QuestionDef(
      key: 'satisfaction_resources',
      label: 'Library, Wi-Fi, and research resources',
      numberLabel: '51',
      type: _FieldType.rating,
      min: 1,
      max: 5,
      required: true,
    ),
    const _QuestionDef(
      key: 'satisfaction_guidance',
      label: 'Guidance, counseling, and student support services',
      numberLabel: '52',
      type: _FieldType.rating,
      min: 1,
      max: 5,
      required: true,
    ),
    const _QuestionDef(
      key: 'satisfaction_career',
      label: 'Career placement and alumni services',
      numberLabel: '53',
      type: _FieldType.rating,
      min: 1,
      max: 5,
      required: true,
    ),
    const _QuestionDef(
      key: 'satisfaction_admin',
      label: 'Administrative services and transactions',
      numberLabel: '54',
      type: _FieldType.rating,
      min: 1,
      max: 5,
      required: true,
    ),
    const _QuestionDef(
      key: 'satisfaction_overall',
      label: 'Overall satisfaction with JMCFI’s academic environment',
      numberLabel: '55',
      type: _FieldType.rating,
      min: 1,
      max: 5,
      required: true,
    ),
  ];
  List<_QuestionDef> get _engagementQuestions => [
    _QuestionDef(
      key: 'recommendation',
      label: _config.recommendationLabel,
      type: _FieldType.decade,
      min: 0,
      max: 10,
      required: true,
    ),
    _QuestionDef(
      key: 'reputation',
      label: _config.reputationLabel,
      type: _FieldType.dropdown,
      options: [
        'Very negative',
        'Negative',
        'Neutral',
        'Positive',
        'Very positive',
      ],
      required: true,
    ),
    _QuestionDef(
      key: 'alumni_participation',
      label:
          '58. Would you participate in alumni mentoring, outreach, or seminars?',
      type: _FieldType.dropdown,
      options: ['Yes', 'No'],
      required: true,
    ),
  ];
  List<_QuestionDef> get _feedbackQuestions => [
    _QuestionDef(
      key: 'feedback_1',
      label: _config.feedbackCompetenciesLabel,
      type: _FieldType.multiline,
      required: true,
    ),
    const _QuestionDef(
      key: 'feedback_2',
      label: '60. What aspects of field instruction need improvement?',
      type: _FieldType.multiline,
      required: true,
    ),
    const _QuestionDef(
      key: 'feedback_3',
      label:
          '61. How can JMCFI support alumni in career advancement and lifelong learning?',
      type: _FieldType.multiline,
      required: true,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _config = _programConfig(widget.programCode);
    _textControllers = {
      for (final key in _textFieldKeys) key: TextEditingController(),
    };
    _submissionDateController = TextEditingController();
    _seedDefaultValues();
    _loadExistingSubmission();
  }

  List<String> get _textFieldKeys => const [
    'name',
    'age',
    'address',
    'contact',
    'year_graduated',
    'honors_awards',
    'unemployed_reason_other',
    'job_title',
    'employer',
    'country_other',
    'study_program',
    'study_institution',
    'licensure_type',
    'feedback_1',
    'feedback_2',
    'feedback_3',
  ];

  void _seedDefaultValues() {
    _submissionDateIso = DateTime.now().toIso8601String();
    _syncSubmissionDateController();
    _ratingValues.addAll({
      'job_satisfaction': 3,
      'skills_utilization': 3,
      'recommendation': 8,
      'satisfaction_curriculum': 4,
      'satisfaction_faculty': 4,
      'satisfaction_practicum': 4,
      'satisfaction_resources': 4,
      'satisfaction_guidance': 4,
      'satisfaction_career': 4,
      'satisfaction_admin': 4,
      'satisfaction_overall': 4,
    });
    for (var i = 0; i < _config.peoStatements.length; i++) {
      _ratingValues['peo_${i + 1}'] = 4;
    }
    _multiSelectValues['skills'] = [];
    if (_careerTimeline.isEmpty) {
      _careerTimeline.add(_CareerTimelineEntry(isCurrent: true));
    }
  }

  void _syncSubmissionDateController() {
    if (_submissionDateIso.isEmpty) {
      _submissionDateController.text = 'Recorded automatically when submitted';
      return;
    }
    _submissionDateController.text = _formatDate(_submissionDateIso);
  }

  Future<void> _pickDateForController(
    TextEditingController controller, {
    required bool enabled,
    DateTime? initialDate,
    ValueChanged<DateTime>? onDateSelected,
  }) async {
    if (!enabled) return;

    DateTime startDate = initialDate ?? DateTime.now();
    if (controller.text.trim().isNotEmpty) {
      try {
        startDate = DateTime.parse(controller.text.trim());
      } catch (_) {}
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: startDate,
      firstDate: DateTime(1980),
      lastDate: DateTime(2100),
    );

    if (picked == null) return;

    setState(() {
      final iso = picked.toIso8601String();
      controller.text = iso.split('T').first;
      onDateSelected?.call(picked);
    });
  }

  String? _requiredFieldValidator(String? value, String label) {
    if ((value ?? '').trim().isEmpty) {
      return 'Please fill in $label.';
    }
    return null;
  }

  bool _timelineEntryNeedsValidation(_CareerTimelineEntry entry) {
    return _isCurrentlyEmployed ||
        entry.hasMeaningfulValue ||
        _careerTimeline.length == 1;
  }

  _ProgramConfig _programConfig(String programCode) {
    if (programCode == 'BSSW') {
      return const _ProgramConfig(
        programCode: 'BSSW',
        programTitle: 'BS Social Work Graduate Tracer Study Questionnaire',
        programSubtitle:
            'Aligned with CHED QA Indicators, AUN-QA, ISO 9001:2015, and QILT GOS-L Benchmarks',
        currentJobRelatedLabel:
            '21. Is your current job related to social work?',
        studyTypeOptions: ['Certificate', 'MA/MSW', 'PhD', 'Others'],
        licensureLabel: '35. Did you take the Social Work Licensure Exam?',
        licensureTypeLabel: 'Licensure exam type',
        licensureResultLabel: 'If yes, result',
        skillsOptions: [
          'Casework and counseling skills',
          'Community organizing and development',
          'Social policy analysis',
          'Advocacy and networking',
          'Research and evaluation',
          'Ethical decision-making',
          'Documentation and report writing',
          'Supervision and mentoring',
          'Use of ICT tools for social work',
        ],
        peoStatements: [
          'Demonstrate knowledge, skills, and attitudes in generalist helping processes and planned change for therapeutic, protective, preventive, and transformative purposes.',
          'Analyze critically the origin, development, and purposes of social work in the Philippines.',
          'Critique the impacts of global and national socio-structural inadequacies, discrimination, and oppression on quality of life.',
          'Apply knowledge of human behavior and social environment emphasizing person-in-situation dynamics in assessment and intervention.',
          'Critique social welfare policies, programs, and services in terms of relevance, responsiveness, accessibility, and availability.',
          'Engage in advocacy work to promote socio-economic and cultural rights and well-being.',
          'Generate resources for networking and partnership development.',
          'Identify with the social work profession and conduct oneself in accordance with social work values and ethics.',
          'Engage in social work practices that promote diversity and inclusion among client systems.',
          'Use supervision to develop critical self-reflective practice for professional growth.',
          'Produce and maintain portfolios, recordings, and case documentation reflecting quality practice.',
        ],
        curriculumSatisfactionLabel:
            'Curriculum relevance to social work practice',
        recommendationLabel:
            '56. How likely are you to recommend JMCFI’s Social Work program to others?',
        reputationLabel:
            '57. How would you describe JMCFI’s reputation in the social work community?',
        feedbackCompetenciesLabel:
            '59. What specific competencies should be strengthened in the BSSW curriculum?',
      );
    }

    return const _ProgramConfig(
      programCode: 'BSIT',
      programTitle:
          'BS Information Technology Graduate Tracer Study Questionnaire',
      programSubtitle:
          'Aligned with CHED QA Indicators, AUN-QA, ISO 9001:2015, and QILT GOS-L Benchmarks',
      currentJobRelatedLabel: '21. Is your current job related to IT?',
      studyTypeOptions: ['Certificate', 'MIT/MIS', 'PhD/DIT/DBMIS', 'Others'],
      licensureLabel: '35. Did you take any board or licensure exam?',
      licensureTypeLabel: 'If yes, what is the type of licensure exam?',
      licensureResultLabel: 'If yes, result',
      skillsOptions: [
        'Programming and Software Development',
        'Database Management',
        'Networking and Cybersecurity',
        'Systems Analysis and Design',
        'Cloud Computing and DevOps',
        'Problem-Solving and Critical Thinking',
        'Debugging and Troubleshooting',
        'Communication Skills',
        'Teamwork and Collaboration',
        'Time Management and Work Ethics',
        'Adaptability and Continuous Learning',
        'UI/UX Design',
        'Version Control (e.g., Git)',
        'AI / Data Analytics Awareness',
      ],
      peoStatements: [
        'Demonstrate a strong foundation in IT principles and practices, enabling them to effectively create and implement solutions to real-world problems.',
        'Demonstrate leadership and innovation, taking initiative to lead projects, drive technological advancements, and contribute to organizational success.',
        'Engage in continuous learning and professional development to adapt to the evolving field of information technology.',
      ],
      curriculumSatisfactionLabel: 'Curriculum relevance to IT practice',
      recommendationLabel:
          '56. How likely are you to recommend JMCFI’s BSIT program to others?',
      reputationLabel:
          '57. How would you describe JMCFI’s reputation in the IT community?',
      feedbackCompetenciesLabel:
          '59. What specific competencies should be strengthened in the BSIT curriculum?',
    );
  }

  List<_QuestionDef> get _developmentQuestions => [
    const _QuestionDef(
      key: 'further_study',
      label: '32. Are you enrolled in further studies?',
      type: _FieldType.dropdown,
      options: ['Yes', 'No'],
      required: true,
    ),
    const _QuestionDef(
      key: 'study_program',
      label: 'Program',
      numberLabel: '32a',
      type: _FieldType.text,
    ),
    const _QuestionDef(
      key: 'study_institution',
      label: 'Institution',
      numberLabel: '32b',
      type: _FieldType.text,
    ),
    _QuestionDef(
      key: 'study_type',
      label: '33. Type',
      type: _FieldType.dropdown,
      options: _config.studyTypeOptions,
    ),
    _QuestionDef(
      key: 'study_related',
      label: _config.programCode == 'BSIT'
          ? '34. Are these studies related to IT?'
          : '34. Are these studies related to Social Work?',
      type: _FieldType.dropdown,
      options: const ['Yes', 'No'],
    ),
    _QuestionDef(
      key: 'licensure_taken',
      label: _config.licensureLabel,
      type: _FieldType.dropdown,
      options: const ['Yes', 'No'],
      required: true,
    ),
    if (_config.programCode == 'BSIT')
      _QuestionDef(
        key: 'licensure_type',
        label: _config.licensureTypeLabel,
        numberLabel: '35a',
        type: _FieldType.text,
      ),
    _QuestionDef(
      key: 'licensure_result',
      label: _config.licensureResultLabel,
      numberLabel: _config.programCode == 'BSIT' ? '35b' : '35a',
      type: _FieldType.dropdown,
      options: const ['Passed', 'Did not pass', 'Pending'],
    ),
    const _QuestionDef(
      key: 'cpd',
      label:
          '36. Have you attended CPD seminars or workshops after graduation?',
      type: _FieldType.dropdown,
      options: ['Yes', 'No'],
      required: true,
    ),
  ];

  Future<void> _loadExistingSubmission() async {
    try {
      if (widget.userId <= 0) {
        setState(() => _isLoading = false);
        return;
      }

      final response = await http.get(
        ApiService.uri(
          'check_tracer.php',
          queryParameters: {'alumni_id': '${widget.userId}'},
        ),
        headers: ApiService.authHeaders(),
      );

      final body = response.body.trim();
      if (response.statusCode != 200 || body.isEmpty || body.startsWith('<')) {
        setState(() => _isLoading = false);
        return;
      }

      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        setState(() => _isLoading = false);
        return;
      }

      final submitted =
          decoded['submitted'] == true ||
          decoded['status'] == 'submitted' ||
          decoded['is_submitted'] == true;
      final draftSaved =
          decoded['draft_saved'] == true ||
          decoded['status'] == 'draft' ||
          decoded['is_draft'] == true;

      final payload = _extractSubmissionPayload(decoded);

      if (submitted) {
        _hasExistingSubmission = true;
        _hasDraftSaved = false;
        _isReadOnly = true;
        _applyExistingData(payload);
      } else if (draftSaved) {
        _hasExistingSubmission = false;
        _hasDraftSaved = true;
        _isReadOnly = false;
        _applyExistingData(payload);
        _submissionDateIso = '';
        _syncSubmissionDateController();
      }

      _applySignedSubmissionMeta(
        _extractSignedSubmissionPayload(decoded),
        signedSubmissionCount: decoded['signed_submission_count'],
      );

      setState(() => _isLoading = false);
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _extractSubmissionPayload(Map<String, dynamic> source) {
    final candidateKeys = ['data', 'submission', 'tracer', 'record', 'details'];
    for (final key in candidateKeys) {
      final value = source[key];
      if (value is Map<String, dynamic>) return value;
      if (value is String && value.trim().startsWith('{')) {
        final decoded = jsonDecode(value);
        if (decoded is Map<String, dynamic>) return decoded;
      }
    }
    return source;
  }

  Map<String, dynamic>? _extractSignedSubmissionPayload(
    Map<String, dynamic> source,
  ) {
    const candidateKeys = [
      'latest_signed_submission',
      'signed_submission',
      'latest_signed_record',
    ];
    for (final key in candidateKeys) {
      final value = source[key];
      if (value is Map<String, dynamic>) return value;
      if (value is Map) return Map<String, dynamic>.from(value);
      if (value is String && value.trim().startsWith('{')) {
        final decoded = jsonDecode(value);
        if (decoded is Map<String, dynamic>) return decoded;
      }
    }
    return null;
  }

  void _applyExistingData(Map<String, dynamic> data) {
    for (final entry in _textControllers.entries) {
      final value = data[entry.key];
      if (value != null && value.toString() != 'null') {
        entry.value.text = value.toString();
      }
    }

    const dropdownKeys = [
      'tracer_batch',
      'sex',
      'civil_status',
      'pre_grad_exp',
      'study_mode',
      'employment_status',
      'unemployed_reason',
      'time_to_first_job',
      'first_job_related',
      'job_type',
      'sector',
      'country',
      'monthly_income',
      'related_job',
      'underutilized_reason',
      'employment_duration',
      'promoted',
      'want_more_hours',
      'more_hours_reason',
      'overqualified_level',
      'skills_not_used_reason',
      'employment_classification',
      'further_study',
      'study_type',
      'study_related',
      'licensure_taken',
      'licensure_result',
      'cpd',
      'reputation',
      'alumni_participation',
    ];

    for (final key in dropdownKeys) {
      final value = data[key];
      if (value != null && value.toString().isNotEmpty && value != 'null') {
        _dropdownValues[key] = value.toString();
      }
    }

    final ratingKeys = [
      'job_satisfaction',
      'skills_utilization',
      'recommendation',
      'satisfaction_curriculum',
      'satisfaction_faculty',
      'satisfaction_practicum',
      'satisfaction_resources',
      'satisfaction_guidance',
      'satisfaction_career',
      'satisfaction_admin',
      'satisfaction_overall',
      ...List.generate(_config.peoStatements.length, (i) => 'peo_${i + 1}'),
    ];

    for (final key in ratingKeys) {
      final value = double.tryParse('${data[key] ?? ''}');
      if (value != null) _ratingValues[key] = value;
    }

    final skills = _decodeList(data['skills']);
    if (skills.isNotEmpty) {
      _multiSelectValues['skills'] = skills;
    }

    final timeline = _decodeTimeline(data['career_timeline']);
    if (timeline.isNotEmpty) {
      for (final item in _careerTimeline) {
        item.dispose();
      }
      _careerTimeline
        ..clear()
        ..addAll(timeline.map(_CareerTimelineEntry.fromMap));
    } else if ((data['job_title'] ?? '').toString().isNotEmpty ||
        (data['employer'] ?? '').toString().isNotEmpty) {
      for (final item in _careerTimeline) {
        item.dispose();
      }
      _careerTimeline
        ..clear()
        ..add(
          _CareerTimelineEntry(
            position: data['job_title']?.toString(),
            employer: data['employer']?.toString(),
            employmentType: data['job_type']?.toString(),
            sector: data['sector']?.toString(),
            location: _countryLabelFromData(data),
            salaryRange: data['monthly_income']?.toString(),
            relatedToDegree: data['related_job']?.toString(),
            notes: data['employment_status']?.toString(),
            isCurrent: true,
          ),
        );
    }

    _agreeToConsent = _normalizeConsent(data['is_agreed']);
    _submissionDateIso = (data['date_submitted'] ?? data['submitted_at'] ?? '')
        .toString();
    _syncSubmissionDateController();
    _existingSignatureBase64 = data['signature']?.toString();
    if (_existingSignatureBase64 != null &&
        _existingSignatureBase64!.trim().isNotEmpty) {
      try {
        _existingSignatureBytes = base64Decode(_existingSignatureBase64!);
      } catch (_) {
        _existingSignatureBytes = null;
      }
    }
  }

  void _applySignedSubmissionMeta(
    Map<String, dynamic>? data, {
    dynamic signedSubmissionCount,
  }) {
    _signedSubmissionCount = int.tryParse('${signedSubmissionCount ?? 0}') ?? 0;
    if (data == null || data.isEmpty) {
      return;
    }

    _latestReferenceId = data['reference_id']?.toString();
    _latestPdfDownloadUrl =
        data['pdf_download_url']?.toString() ??
        data['signed_pdf_url']?.toString();
    _latestAgreementVersion = data['agreement_version']?.toString();
    final signedTimestamp =
        (data['submission_timestamp'] ?? data['signed_at'] ?? '').toString();
    if (signedTimestamp.isNotEmpty) {
      _submissionDateIso = signedTimestamp;
      _syncSubmissionDateController();
    }
  }

  List<String> _decodeList(dynamic raw) {
    if (raw is List) return raw.map((e) => '$e').toList();
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return [];
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is List) return decoded.map((e) => '$e').toList();
      } catch (_) {
        return trimmed
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
    }
    return [];
  }

  List<Map<String, dynamic>> _decodeTimeline(dynamic raw) {
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      } catch (_) {}
    }
    return [];
  }

  bool _normalizeConsent(dynamic value) {
    final normalized = '${value ?? ''}'.toLowerCase();
    return normalized == '1' || normalized == 'yes' || normalized == 'true';
  }

  bool get _isCurrentlyEmployed {
    final status = _dropdownValues['employment_status'];
    return status == 'Employed' ||
        status == 'Self-Employed' ||
        status == 'Employer';
  }

  String _countryLabelFromData(Map<String, dynamic> data) {
    final country = data['country']?.toString() ?? '';
    final otherCountry = data['country_other']?.toString() ?? '';
    if (country == 'Other' && otherCountry.isNotEmpty) return otherCountry;
    return country;
  }

  void _startCareerUpdate() {
    setState(() {
      _isReadOnly = false;
      _isCareerUpdateMode = true;
      _careerTimeline.add(_CareerTimelineEntry(isCurrent: true));
    });
  }

  void _addTimelineEntry() {
    setState(() {
      _careerTimeline.add(_CareerTimelineEntry(isCurrent: false));
    });
  }

  Map<String, dynamic> _buildTracerPayload({
    required bool saveAsDraft,
    required List<Map<String, dynamic>> timeline,
    required String signatureBase64,
    required String isoDate,
  }) {
    final latestCareer = timeline.isNotEmpty
        ? timeline.last
        : <String, dynamic>{};

    return {
      'user_id': widget.userId,
      'program': _config.programCode,
      'name': _text('name'),
      'tracer_batch': _dropdownValues['tracer_batch'] ?? '',
      'sex': _dropdownValues['sex'] ?? '',
      'age': _text('age'),
      'civil_status': _dropdownValues['civil_status'] ?? '',
      'address': _text('address'),
      'contact': _text('contact'),
      'year_graduated': _text('year_graduated'),
      'honors_awards': _text('honors_awards'),
      'pre_grad_exp': _dropdownValues['pre_grad_exp'] ?? '',
      'study_mode': _dropdownValues['study_mode'] ?? '',
      'employment_status': _dropdownValues['employment_status'] ?? '',
      'unemployed_reason': _dropdownValues['unemployed_reason'] == 'Others'
          ? _text('unemployed_reason_other')
          : (_dropdownValues['unemployed_reason'] ?? ''),
      'time_to_first_job': _dropdownValues['time_to_first_job'] ?? '',
      'first_job_related': _dropdownValues['first_job_related'] ?? '',
      'job_type':
          _dropdownValues['job_type'] ?? latestCareer['employment_type'] ?? '',
      'job_title': _text('job_title').isNotEmpty
          ? _text('job_title')
          : (latestCareer['position'] ?? ''),
      'employer': _text('employer').isNotEmpty
          ? _text('employer')
          : (latestCareer['employer'] ?? ''),
      'sector': _dropdownValues['sector'] ?? latestCareer['sector'] ?? '',
      'country': _dropdownValues['country'] == 'Other'
          ? _text('country_other')
          : (_dropdownValues['country'] ?? latestCareer['location'] ?? ''),
      'country_other': _text('country_other'),
      'monthly_income':
          _dropdownValues['monthly_income'] ??
          latestCareer['salary_range'] ??
          '',
      'related_job':
          _dropdownValues['related_job'] ??
          latestCareer['related_to_degree'] ??
          '',
      'underutilized_reason': _dropdownValues['underutilized_reason'] ?? '',
      'employment_duration': _dropdownValues['employment_duration'] ?? '',
      'employment_classification':
          _dropdownValues['employment_classification'] ?? '',
      'promoted': _dropdownValues['promoted'] ?? '',
      'want_more_hours': _dropdownValues['want_more_hours'] ?? '',
      'more_hours_reason': _dropdownValues['more_hours_reason'] ?? '',
      'job_satisfaction': _ratingValues['job_satisfaction']?.round() ?? 0,
      'skills_utilization': _ratingValues['skills_utilization']?.round() ?? 0,
      'overqualified_level': _dropdownValues['overqualified_level'] ?? '',
      'skills': _multiSelectValues['skills'],
      'skills_not_used_reason': _dropdownValues['skills_not_used_reason'] ?? '',
      'further_study': _dropdownValues['further_study'] ?? '',
      'study_program': _text('study_program'),
      'study_institution': _text('study_institution'),
      'study_type': _dropdownValues['study_type'] ?? '',
      'study_related': _dropdownValues['study_related'] ?? '',
      'licensure_taken': _dropdownValues['licensure_taken'] ?? '',
      'licensure_type': _text('licensure_type'),
      'licensure_result': _dropdownValues['licensure_result'] ?? '',
      'cpd': _dropdownValues['cpd'] ?? '',
      'recommendation': _ratingValues['recommendation']?.round() ?? 0,
      'reputation': _dropdownValues['reputation'] ?? '',
      'alumni_participation': _dropdownValues['alumni_participation'] ?? '',
      'feedback_1': _text('feedback_1'),
      'feedback_2': _text('feedback_2'),
      'feedback_3': _text('feedback_3'),
      'is_agreed': _agreeToConsent ? 'Yes' : 'No',
      'agreement_version': _agreementVersion,
      'agreement_text': _agreementText,
      'date_submitted': isoDate,
      'signature': signatureBase64,
      'career_timeline': timeline,
      'is_update': _hasExistingSubmission,
      'updated_career_timeline': _isCareerUpdateMode,
      'save_as_draft': saveAsDraft,
      for (var i = 0; i < _config.peoStatements.length; i++)
        'peo_${i + 1}': _ratingValues['peo_${i + 1}']?.round() ?? 0,
      'satisfaction_curriculum':
          _ratingValues['satisfaction_curriculum']?.round() ?? 0,
      'satisfaction_faculty':
          _ratingValues['satisfaction_faculty']?.round() ?? 0,
      'satisfaction_practicum':
          _ratingValues['satisfaction_practicum']?.round() ?? 0,
      'satisfaction_resources':
          _ratingValues['satisfaction_resources']?.round() ?? 0,
      'satisfaction_guidance':
          _ratingValues['satisfaction_guidance']?.round() ?? 0,
      'satisfaction_career': _ratingValues['satisfaction_career']?.round() ?? 0,
      'satisfaction_admin': _ratingValues['satisfaction_admin']?.round() ?? 0,
      'satisfaction_overall':
          _ratingValues['satisfaction_overall']?.round() ?? 0,
    };
  }

  Future<void> _saveDraft() async {
    if (_isReadOnly) return;

    final timeline = _careerTimeline
        .where((entry) => entry.hasMeaningfulValue)
        .map((entry) => entry.toMap())
        .toList();

    String signatureBase64 = _existingSignatureBase64 ?? '';
    if (_signature.isNotEmpty) {
      final sign = await _signature.toPngBytes();
      if (sign != null) signatureBase64 = base64Encode(sign);
    }

    final data = _buildTracerPayload(
      saveAsDraft: true,
      timeline: timeline,
      signatureBase64: signatureBase64,
      isoDate: DateTime.now().toIso8601String(),
    );

    setState(() => _isSaving = true);
    try {
      final response = await http.post(
        ApiService.uri('submit_tracer.php'),
        headers: ApiService.jsonHeaders(),
        body: jsonEncode(data),
      );
      final result = _parseJsonResponse(response);
      if (result['success'] == true) {
        setState(() {
          _hasDraftSaved = true;
          _hasExistingSubmission = false;
          _isReadOnly = false;
          _isCareerUpdateMode = false;
          _submissionDateIso = '';
          _syncSubmissionDateController();
          if (signatureBase64.isNotEmpty) {
            _existingSignatureBase64 = signatureBase64;
            _existingSignatureBytes = base64Decode(signatureBase64);
          }
        });
        _showSnack('Tracer draft saved successfully.');
      } else {
        _showSnack(result['message']?.toString() ?? 'Draft save failed.');
      }
    } catch (e) {
      _showSnack('Unable to save tracer draft: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _submit() async {
    if (_isReadOnly) return;
    if (!_formKey.currentState!.validate()) {
      _showSnack('Please fill in the required fields before submitting.');
      return;
    }
    if (!_agreeToConsent) {
      _showSnack('Please confirm the data privacy consent.');
      return;
    }
    if (_multiSelectValues['skills']!.isEmpty) {
      _showSnack('Please select at least one competency you use at work.');
      return;
    }

    final timeline = _careerTimeline
        .where((entry) => entry.hasMeaningfulValue)
        .map((entry) => entry.toMap())
        .toList();

    if (_isCurrentlyEmployed && timeline.isEmpty) {
      _showSnack('Please add at least one career timeline entry.');
      return;
    }

    String signatureBase64 = _existingSignatureBase64 ?? '';
    if (_signature.isNotEmpty) {
      final sign = await _signature.toPngBytes();
      if (sign != null) signatureBase64 = base64Encode(sign);
    }
    if (signatureBase64.isNotEmpty == false) {
      _showSnack('Signature is required before saving the tracer form.');
      return;
    }

    final isoDate = _submissionDateIso.isEmpty
        ? DateTime.now().toIso8601String()
        : _submissionDateIso;
    final data = _buildTracerPayload(
      saveAsDraft: false,
      timeline: timeline,
      signatureBase64: signatureBase64,
      isoDate: isoDate,
    );

    setState(() => _isSaving = true);
    try {
      final response = await http.post(
        ApiService.uri('submit_tracer.php'),
        headers: ApiService.jsonHeaders(),
        body: jsonEncode(data),
      );
      final result = _parseJsonResponse(response);
      if (result['success'] == true) {
        final isUpdate = _hasExistingSubmission;
        setState(() {
          _submissionDateIso = (result['submission_timestamp'] ?? isoDate)
              .toString();
          _syncSubmissionDateController();
          _hasExistingSubmission = true;
          _hasDraftSaved = false;
          _isReadOnly = true;
          _isCareerUpdateMode = false;
          _existingSignatureBase64 = signatureBase64;
          _existingSignatureBytes = base64Decode(signatureBase64);
          _signature.clear();
          _latestReferenceId = result['reference_id']?.toString();
          _latestPdfDownloadUrl = result['pdf_download_url']?.toString();
          _latestAgreementVersion =
              result['agreement_version']?.toString() ?? _agreementVersion;
          _signedSubmissionCount = (_signedSubmissionCount <= 0)
              ? 1
              : _signedSubmissionCount + 1;
        });
        await ActivityService.logImportantFlow(
          action: isUpdate ? 'tracer_update' : 'tracer_submit',
          title:
              '${data['name'].toString().trim().isEmpty ? 'An alumni' : data['name']} ${isUpdate ? 'updated' : 'submitted'} a tracer form',
          type: 'Tracer',
          userId: widget.userId,
          userName: data['name']?.toString(),
          role: 'alumni',
          targetId: result['reference_id']?.toString(),
          targetType: 'tracer_submission',
          metadata: {
            'program': _config.programCode,
            'employment_status': data['employment_status'],
            'submission_timestamp': result['submission_timestamp'] ?? isoDate,
            'reference_id': result['reference_id'],
            'agreement_version':
                result['agreement_version']?.toString() ?? _agreementVersion,
          },
        );
        _showSnack('Tracer form saved successfully.');
      } else {
        _showSnack(result['message']?.toString() ?? 'Submission failed.');
      }
    } catch (e) {
      _showSnack('Unable to save the tracer form: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _text(String key) => _textControllers[key]?.text.trim() ?? '';

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openSignedPdf() async {
    final url = _latestPdfDownloadUrl;
    if (url == null || url.trim().isEmpty) {
      _showSnack('No signed PDF is available yet.');
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri == null) {
      _showSnack('The signed PDF link is invalid.');
      return;
    }

    final launched = await launchUrl(
      uri,
      mode: LaunchMode.platformDefault,
      webOnlyWindowName: '_blank',
    );
    if (!launched) {
      _showSnack('Unable to open the signed PDF download.');
    }
  }

  @override
  void dispose() {
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    _submissionDateController.dispose();
    for (final item in _careerTimeline) {
      item.dispose();
    }
    _signature.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth >= 1280
        ? 32.0
        : screenWidth >= 900
        ? 24.0
        : 16.0;
    return Scaffold(
      backgroundColor: const Color(0xFFF6F1EE),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _maroon))
          : Form(
              key: _formKey,
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      20,
                      horizontalPadding,
                      32,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1280),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildHero(),
                              const SizedBox(height: 20),
                              _buildStatusPanel(),
                              const SizedBox(height: 20),
                              _buildSection(
                                title: 'Graduate Profile',
                                subtitle:
                                    'Basic alumni background and study details.',
                                icon: Icons.badge_outlined,
                                child: _buildQuestionGrid(
                                  _graduateProfileQuestions,
                                ),
                              ),
                              const SizedBox(height: 20),
                              _buildSection(
                                title: 'Employment Status and Career Path',
                                subtitle:
                                    'Current employment snapshot plus the new career timeline for employment updates.',
                                icon: Icons.work_history_outlined,
                                child: Column(
                                  children: [
                                    _buildQuestionGrid(_employmentQuestions),
                                    const SizedBox(height: 20),
                                    _buildCareerTimelineSection(),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              _buildSection(
                                title:
                                    'Professional Skills and Competency Utilization',
                                subtitle:
                                    'How alumni use program outcomes in real work.',
                                icon: Icons.psychology_alt_outlined,
                                child: _buildQuestionGrid(_skillsQuestions),
                              ),
                              const SizedBox(height: 20),
                              _buildSection(
                                title:
                                    'Further Studies, Licensure, and Continuing Development',
                                subtitle:
                                    'Post-graduation growth, exams, and seminars.',
                                icon: Icons.school_outlined,
                                child: _buildQuestionGrid(
                                  _developmentQuestions,
                                ),
                              ),
                              const SizedBox(height: 20),
                              _buildSection(
                                title:
                                    'Attainment of Program Educational Objectives',
                                subtitle:
                                    '1 means strongly disagree, 5 means strongly agree.',
                                icon: Icons.track_changes_outlined,
                                child: _buildPeoSection(),
                              ),
                              const SizedBox(height: 20),
                              _buildSection(
                                title:
                                    'Satisfaction with Academic Preparation and Services',
                                subtitle: 'Rate each area from 1 to 5.',
                                icon: Icons.favorite_border,
                                child: _buildQuestionGrid(
                                  _satisfactionQuestions,
                                ),
                              ),
                              const SizedBox(height: 20),
                              _buildSection(
                                title:
                                    'Institutional Image and Alumni Engagement',
                                subtitle:
                                    'Recommendation, reputation, and alumni participation.',
                                icon: Icons.groups_2_outlined,
                                child: _buildQuestionGrid(_engagementQuestions),
                              ),
                              const SizedBox(height: 20),
                              _buildSection(
                                title: 'Feedback and Continuous Improvement',
                                subtitle:
                                    'Open-ended responses for curriculum and alumni support.',
                                icon: Icons.forum_outlined,
                                child: _buildQuestionGrid(_feedbackQuestions),
                              ),
                              const SizedBox(height: 20),
                              _buildSection(
                                title: 'Consent and Signature',
                                subtitle:
                                    'Submission date is generated automatically based on the exact day you save the form.',
                                icon: Icons.draw_outlined,
                                child: _buildConsentSection(),
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_maroon, _rose],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _maroon.withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 860;
            final titleBlock = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.16),
                    ),
                  ),
                  child: const Text(
                    'Graduate Tracer Survey Form',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  _config.programTitle,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isCompact ? 25 : 31,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _config.programSubtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 14,
                    height: 1.55,
                  ),
                ),
              ],
            );

            final metaCard = Container(
              width: isCompact ? double.infinity : 290,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Form Overview',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildHeroMetaRow('Institution', 'Jose Maria College'),
                  const SizedBox(height: 10),
                  _buildHeroMetaRow('Program', _config.programCode),
                  const SizedBox(height: 10),
                  _buildHeroMetaRow(
                    'Mode',
                    _hasExistingSubmission && _isReadOnly
                        ? 'View only'
                        : 'Editable form',
                  ),
                ],
              ),
            );

            if (isCompact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [titleBlock, const SizedBox(height: 20), metaCard],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: titleBlock),
                const SizedBox(width: 24),
                metaCard,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeroMetaRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.70),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusPanel() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE9DDD7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Submission Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Review form state, signed records, and submission tools before making updates.',
            style: TextStyle(color: Colors.grey.shade700, height: 1.45),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildInfoChip(
                icon: _hasExistingSubmission
                    ? Icons.verified_outlined
                    : (_hasDraftSaved
                          ? Icons.save_outlined
                          : Icons.pending_actions_outlined),
                label: _hasExistingSubmission
                    ? 'Form Submitted'
                    : (_hasDraftSaved ? 'Draft Saved' : 'Draft / New Form'),
                color: _hasExistingSubmission
                    ? Colors.green
                    : (_hasDraftSaved ? Colors.orange : Colors.orange),
              ),
              _buildInfoChip(
                icon: Icons.calendar_today_outlined,
                label: _submissionDateIso.isEmpty
                    ? (_hasDraftSaved
                          ? 'Awaiting final submission'
                          : 'No submission date yet')
                    : 'Submitted ${_formatDate(_submissionDateIso)}',
                color: _maroon,
              ),
              _buildInfoChip(
                icon: Icons.remove_red_eye_outlined,
                label: _isReadOnly ? 'View-only mode' : 'Editing enabled',
                color: _isReadOnly ? Colors.blueGrey : Colors.blue,
              ),
              if ((_latestReferenceId ?? '').isNotEmpty)
                _buildInfoChip(
                  icon: Icons.badge_outlined,
                  label: 'Reference ${_latestReferenceId!}',
                  color: _rose,
                ),
              if ((_latestAgreementVersion ?? '').isNotEmpty)
                _buildInfoChip(
                  icon: Icons.privacy_tip_outlined,
                  label: 'Agreement ${_latestAgreementVersion!}',
                  color: Colors.deepPurple,
                ),
              if (_signedSubmissionCount > 0)
                _buildInfoChip(
                  icon: Icons.history_outlined,
                  label: 'Signed Records $_signedSubmissionCount',
                  color: Colors.teal,
                ),
              if ((_latestPdfDownloadUrl ?? '').isNotEmpty)
                OutlinedButton.icon(
                  onPressed: _openSignedPdf,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _maroon,
                    side: const BorderSide(color: _maroon),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Download Signed PDF'),
                ),
              if (_hasExistingSubmission && _isReadOnly)
                ElevatedButton.icon(
                  onPressed: _startCareerUpdate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _maroon,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.add_business_outlined),
                  label: const Text('Add Career Employment Update'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEADFD8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 520;
              return Flex(
                direction: isCompact ? Axis.vertical : Axis.horizontal,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _cream,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, color: _maroon),
                  ),
                  if (isCompact)
                    const SizedBox(height: 14)
                  else
                    const SizedBox(width: 14),
                  if (isCompact)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: _ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
                    )
                  else
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: _ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildQuestionGrid(List<_QuestionDef> questions) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final visibleQuestions = questions.where(_shouldShowQuestion).toList();
        const spacing = 18.0;
        final columns = maxWidth >= 1180
            ? 3
            : maxWidth >= 760
            ? 2
            : 1;
        final unitWidth = columns == 1
            ? maxWidth
            : (maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: visibleQuestions
              .map(
                (question) => SizedBox(
                  width: _questionCardWidth(
                    question,
                    maxWidth,
                    unitWidth,
                    visibleQuestions.length,
                  ),
                  child: _buildQuestionField(question),
                ),
              )
              .toList(),
        );
      },
    );
  }

  double _questionCardWidth(
    _QuestionDef question,
    double maxWidth,
    double unitWidth,
    int visibleCount,
  ) {
    if (maxWidth < 760) return maxWidth;

    if (visibleCount == 1) {
      return maxWidth >= 980 ? 540 : maxWidth;
    }

    if (question.type == _FieldType.multiline ||
        question.type == _FieldType.checkboxGroup) {
      return maxWidth;
    }

    if (question.type == _FieldType.rating ||
        question.type == _FieldType.decade) {
      return maxWidth >= 900 ? (maxWidth - 18) / 2 : maxWidth;
    }

    return unitWidth;
  }

  bool _shouldShowQuestion(_QuestionDef question) {
    switch (question.key) {
      case 'unemployed_reason':
      case 'unemployed_reason_other':
        return _dropdownValues['employment_status'] == 'Unemployed';
      case 'time_to_first_job':
      case 'first_job_related':
      case 'job_type':
      case 'job_title':
      case 'employer':
      case 'sector':
      case 'country':
      case 'country_other':
      case 'monthly_income':
      case 'related_job':
      case 'underutilized_reason':
      case 'employment_duration':
      case 'promoted':
      case 'want_more_hours':
      case 'more_hours_reason':
      case 'job_satisfaction':
        if (!_isCurrentlyEmployed) return false;
        if (question.key == 'country_other') {
          return _dropdownValues['country'] == 'Other';
        }
        if (question.key == 'underutilized_reason') {
          return _dropdownValues['related_job'] == 'No';
        }
        if (question.key == 'more_hours_reason') {
          return _dropdownValues['want_more_hours'] == 'Yes';
        }
        return true;
      case 'study_program':
      case 'study_institution':
      case 'study_type':
      case 'study_related':
        return _dropdownValues['further_study'] == 'Yes';
      case 'licensure_type':
      case 'licensure_result':
        return _dropdownValues['licensure_taken'] == 'Yes';
      default:
        return true;
    }
  }

  Widget _buildQuestionField(_QuestionDef question) {
    final label = _displayQuestionLabel(question);
    switch (question.type) {
      case _FieldType.text:
      case _FieldType.multiline:
        final controller = _textControllers[question.key]!;
        return _buildQuestionCard(
          label: label,
          minHeight: question.type == _FieldType.multiline ? 194 : 146,
          child: TextFormField(
            controller: controller,
            readOnly: _isReadOnly,
            maxLines: question.type == _FieldType.multiline ? 4 : 1,
            minLines: question.type == _FieldType.multiline ? 4 : 1,
            validator: question.required
                ? (value) => _requiredFieldValidator(value, question.label)
                : null,
            decoration: _inputDecoration(
              question.type == _FieldType.multiline
                  ? 'Type your answer here'
                  : 'Enter your answer',
            ),
          ),
        );
      case _FieldType.dropdown:
        return _buildQuestionCard(
          label: label,
          minHeight: 146,
          child: DropdownButtonFormField<String>(
            initialValue: _dropdownValues[question.key],
            isExpanded: true,
            items: question.options
                .map(
                  (option) =>
                      DropdownMenuItem(value: option, child: Text(option)),
                )
                .toList(),
            onChanged: _isReadOnly
                ? null
                : (value) {
                    setState(() {
                      _dropdownValues[question.key] = value;
                      if (question.key == 'employment_status' &&
                          value != 'Employed' &&
                          value != 'Self-Employed' &&
                          value != 'Employer') {
                        for (final item in _careerTimeline) {
                          item.dispose();
                        }
                        _careerTimeline
                          ..clear()
                          ..add(_CareerTimelineEntry(isCurrent: false));
                      }
                    });
                  },
            validator: question.required
                ? (value) => _requiredFieldValidator(value, question.label)
                : null,
            decoration: _inputDecoration('Select an option'),
          ),
        );
      case _FieldType.checkboxGroup:
        final selected = _multiSelectValues[question.key]!;
        return _buildQuestionCard(
          label: label,
          minHeight: 176,
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _config.skillsOptions.map((option) {
              final isSelected = selected.contains(option);
              return FilterChip(
                label: Text(option),
                selected: isSelected,
                onSelected: _isReadOnly
                    ? null
                    : (checked) {
                        setState(() {
                          if (checked) {
                            selected.add(option);
                          } else {
                            selected.remove(option);
                          }
                        });
                      },
                backgroundColor: Colors.white,
                selectedColor: _maroon.withValues(alpha: 0.12),
                checkmarkColor: _maroon,
                labelStyle: TextStyle(
                  color: isSelected ? _maroon : _ink,
                  fontWeight: FontWeight.w600,
                ),
              );
            }).toList(),
          ),
        );
      case _FieldType.rating:
      case _FieldType.decade:
        final value = _ratingValues[question.key] ?? question.min;
        return _buildQuestionCard(
          label: label,
          minHeight: 148,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 440;
              final scoreChip = Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _cream,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  value.round().toString(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _maroon,
                  ),
                ),
              );
              final slider = SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: _maroon,
                  inactiveTrackColor: _maroon.withValues(alpha: 0.15),
                  thumbColor: _rose,
                  overlayColor: _rose.withValues(alpha: 0.15),
                ),
                child: Slider(
                  min: question.min,
                  max: question.max,
                  divisions: (question.max - question.min).round(),
                  value: value.clamp(question.min, question.max),
                  onChanged: _isReadOnly
                      ? null
                      : (next) => setState(() {
                          _ratingValues[question.key] = next;
                        }),
                ),
              );

              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [scoreChip, const SizedBox(height: 12), slider],
                );
              }

              return Row(
                children: [
                  scoreChip,
                  const SizedBox(width: 12),
                  Expanded(child: slider),
                ],
              );
            },
          ),
        );
    }
  }

  int? _questionNumber(_QuestionDef question) {
    if (!_isNumberedQuestion(question)) {
      return null;
    }

    final graduateVisible = _graduateProfileQuestions
        .where(_shouldShowQuestion)
        .where(_isNumberedQuestion)
        .toList();
    final employmentVisible = _employmentQuestions
        .where(_shouldShowQuestion)
        .where(_isNumberedQuestion)
        .toList();
    final skillsVisible = _skillsQuestions.where(_shouldShowQuestion).toList();
    final developmentVisible = _developmentQuestions
        .where(_shouldShowQuestion)
        .where(_isNumberedQuestion)
        .toList();
    final satisfactionVisible = _satisfactionQuestions
        .where(_shouldShowQuestion)
        .where(_isNumberedQuestion)
        .toList();
    final engagementVisible = _engagementQuestions
        .where(_shouldShowQuestion)
        .where(_isNumberedQuestion)
        .toList();
    final feedbackVisible = _feedbackQuestions
        .where(_shouldShowQuestion)
        .where(_isNumberedQuestion)
        .toList();

    final graduateIndex = graduateVisible.indexWhere(
      (q) => q.key == question.key,
    );
    if (graduateIndex >= 0) {
      return graduateIndex + 1;
    }

    final employmentIndex = employmentVisible.indexWhere(
      (q) => q.key == question.key,
    );
    if (employmentIndex >= 0) {
      return graduateVisible.length + employmentIndex + 1;
    }

    final skillsIndex = skillsVisible.indexWhere((q) => q.key == question.key);
    if (skillsIndex >= 0) {
      return graduateVisible.length +
          employmentVisible.length +
          skillsIndex +
          1;
    }

    final developmentIndex = developmentVisible.indexWhere(
      (q) => q.key == question.key,
    );
    if (developmentIndex >= 0) {
      return graduateVisible.length +
          employmentVisible.length +
          skillsVisible.length +
          developmentIndex +
          1;
    }

    final satisfactionIndex = satisfactionVisible.indexWhere(
      (q) => q.key == question.key,
    );
    if (satisfactionIndex >= 0) {
      return graduateVisible.length +
          employmentVisible.length +
          skillsVisible.length +
          developmentVisible.length +
          _config.peoStatements.length +
          satisfactionIndex +
          1;
    }

    final engagementIndex = engagementVisible.indexWhere(
      (q) => q.key == question.key,
    );
    if (engagementIndex >= 0) {
      return graduateVisible.length +
          employmentVisible.length +
          skillsVisible.length +
          developmentVisible.length +
          _config.peoStatements.length +
          satisfactionVisible.length +
          engagementIndex +
          1;
    }

    final feedbackIndex = feedbackVisible.indexWhere(
      (q) => q.key == question.key,
    );
    if (feedbackIndex >= 0) {
      return graduateVisible.length +
          employmentVisible.length +
          skillsVisible.length +
          developmentVisible.length +
          _config.peoStatements.length +
          satisfactionVisible.length +
          engagementVisible.length +
          feedbackIndex +
          1;
    }

    return null;
  }

  bool _isNumberedQuestion(_QuestionDef question) {
    return question.key != 'tracer_batch';
  }

  int _countNumberedVisible(List<_QuestionDef> questions) {
    return questions.where(_shouldShowQuestion).where(_isNumberedQuestion).length;
  }

  int get _peoStartNumber =>
      _countNumberedVisible(_graduateProfileQuestions) +
      _countNumberedVisible(_employmentQuestions) +
      _countNumberedVisible(_skillsQuestions) +
      _countNumberedVisible(_developmentQuestions) +
      1;

  String _displayQuestionLabel(_QuestionDef question) {
    final stripped = question.label.replaceFirst(
      RegExp(r'^\s*\d+[A-Za-z]?\.\s*'),
      '',
    );
    final number = question.numberLabel ?? _questionNumber(question)?.toString();
    return number == null ? stripped : '$number. $stripped';
  }

  Widget _buildQuestionCard({
    required String label,
    required Widget child,
    double minHeight = 146,
  }) {
    final match = RegExp(r'^(\d+)\.\s*(.*)$').firstMatch(label);
    final number = match?.group(1);
    final text = match?.group(2) ?? label;
    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE7D9D2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (number != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _maroon.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    number,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: _maroon,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _ink,
                    fontSize: 14.5,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      floatingLabelBehavior: FloatingLabelBehavior.never,
      filled: true,
      fillColor: _isReadOnly ? const Color(0xFFF7F4F3) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFE5D7D0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFE5D7D0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _maroon, width: 1.2),
      ),
    );
  }

  Widget _buildCareerTimelineSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF9F3EF), Color(0xFFF5ECE7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Career Timeline',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
              if (!_isReadOnly)
                OutlinedButton.icon(
                  onPressed: _addTimelineEntry,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _maroon,
                    side: const BorderSide(color: _maroon),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Job Entry'),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Alumni can add new employment records here. If the tracer form was already submitted, use this section to update the form with new career progress.',
            style: TextStyle(color: Colors.grey.shade700, height: 1.45),
          ),
          const SizedBox(height: 16),
          ...List.generate(_careerTimeline.length, (index) {
            final entry = _careerTimeline[index];
            return Padding(
              padding: EdgeInsets.only(
                bottom: index == _careerTimeline.length - 1 ? 0 : 14,
              ),
              child: _buildTimelineCard(entry, index),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTimelineCard(_CareerTimelineEntry entry, int index) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final isCompact = availableWidth < 680;
        final isWide = availableWidth >= 1080;
        final twoColumnWidth = isCompact
            ? availableWidth
            : (availableWidth - 12) / 2;
        final threeColumnWidth = isCompact
            ? availableWidth
            : isWide
            ? (availableWidth - 24) / 3
            : twoColumnWidth;
        final fourColumnWidth = isCompact
            ? availableWidth
            : availableWidth < 980
            ? twoColumnWidth
            : (availableWidth - 36) / 4;

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE8DBD4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.025),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: _maroon,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Text(
                    'Employment Record',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  if (!_isReadOnly && _careerTimeline.length > 1)
                    IconButton(
                      onPressed: () {
                        setState(() {
                          final item = _careerTimeline.removeAt(index);
                          item.dispose();
                        });
                      },
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: threeColumnWidth,
                    child: TextFormField(
                      controller: entry.positionController,
                      readOnly: _isReadOnly,
                      validator: (value) => _timelineEntryNeedsValidation(entry)
                          ? _requiredFieldValidator(
                              value,
                              'job title / position',
                            )
                          : null,
                      decoration: _inputDecoration('Job Title / Position'),
                    ),
                  ),
                  SizedBox(
                    width: threeColumnWidth,
                    child: TextFormField(
                      controller: entry.employerController,
                      readOnly: _isReadOnly,
                      validator: (value) => _timelineEntryNeedsValidation(entry)
                          ? _requiredFieldValidator(
                              value,
                              'employer / organization',
                            )
                          : null,
                      decoration: _inputDecoration('Employer / Organization'),
                    ),
                  ),
                  SizedBox(
                    width: threeColumnWidth,
                    child: TextFormField(
                      controller: entry.employmentTypeController,
                      readOnly: _isReadOnly,
                      validator: (value) => _timelineEntryNeedsValidation(entry)
                          ? _requiredFieldValidator(value, 'employment type')
                          : null,
                      decoration: _inputDecoration('Employment Type'),
                    ),
                  ),
                  SizedBox(
                    width: fourColumnWidth,
                    child: TextFormField(
                      controller: entry.sectorController,
                      readOnly: _isReadOnly,
                      validator: (value) => _timelineEntryNeedsValidation(entry)
                          ? _requiredFieldValidator(value, 'sector')
                          : null,
                      decoration: _inputDecoration('Sector'),
                    ),
                  ),
                  SizedBox(
                    width: fourColumnWidth,
                    child: TextFormField(
                      controller: entry.locationController,
                      readOnly: _isReadOnly,
                      validator: (value) => _timelineEntryNeedsValidation(entry)
                          ? _requiredFieldValidator(value, 'country / location')
                          : null,
                      decoration: _inputDecoration('Country / Location'),
                    ),
                  ),
                  SizedBox(
                    width: fourColumnWidth,
                    child: TextFormField(
                      controller: entry.startDateController,
                      readOnly: true,
                      onTap: () => _pickDateForController(
                        entry.startDateController,
                        enabled: !_isReadOnly,
                      ),
                      validator: (value) => _timelineEntryNeedsValidation(entry)
                          ? _requiredFieldValidator(value, 'start date')
                          : null,
                      decoration: _inputDecoration('Start Date').copyWith(
                        suffixIcon: const Icon(Icons.calendar_today_outlined),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: fourColumnWidth,
                    child: TextFormField(
                      controller: entry.endDateController,
                      readOnly: true,
                      onTap: () => _pickDateForController(
                        entry.endDateController,
                        enabled: !_isReadOnly && !entry.isCurrent,
                      ),
                      validator: (value) =>
                          _timelineEntryNeedsValidation(entry) &&
                              !entry.isCurrent
                          ? _requiredFieldValidator(value, 'end date')
                          : null,
                      decoration: _inputDecoration('End Date').copyWith(
                        suffixIcon: Icon(
                          Icons.calendar_today_outlined,
                          color: entry.isCurrent ? Colors.grey.shade400 : null,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: twoColumnWidth,
                    child: TextFormField(
                      controller: entry.salaryRangeController,
                      readOnly: _isReadOnly,
                      validator: (value) => _timelineEntryNeedsValidation(entry)
                          ? _requiredFieldValidator(value, 'salary range')
                          : null,
                      decoration: _inputDecoration('Salary Range'),
                    ),
                  ),
                  SizedBox(
                    width: twoColumnWidth,
                    child: TextFormField(
                      controller: entry.relatedToDegreeController,
                      readOnly: _isReadOnly,
                      validator: (value) => _timelineEntryNeedsValidation(entry)
                          ? _requiredFieldValidator(value, 'related to degree')
                          : null,
                      decoration: _inputDecoration('Related to Degree'),
                    ),
                  ),
                  SizedBox(
                    width: availableWidth,
                    child: TextFormField(
                      controller: entry.notesController,
                      readOnly: _isReadOnly,
                      maxLines: 3,
                      decoration: _inputDecoration('Notes / Milestones'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9F3EF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'This is my current job',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  value: entry.isCurrent,
                  onChanged: _isReadOnly
                      ? null
                      : (value) => setState(() {
                          entry.isCurrent = value;
                          if (value) entry.endDateController.clear();
                        }),
                  activeThumbColor: _maroon,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPeoSection() {
    return Column(
      children: List.generate(_config.peoStatements.length, (index) {
        final key = 'peo_${index + 1}';
        final value = _ratingValues[key] ?? 4;
        final questionNumber = _peoStartNumber + index;
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _cream,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _maroon.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$questionNumber',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: _maroon,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _config.peoStatements[index],
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 440;
                  final scoreChip = Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      value.round().toString(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _maroon,
                      ),
                    ),
                  );
                  final slider = Slider(
                    min: 1,
                    max: 5,
                    divisions: 4,
                    activeColor: _maroon,
                    value: value,
                    onChanged: _isReadOnly
                        ? null
                        : (next) => setState(() {
                            _ratingValues[key] = next;
                          }),
                  );

                  if (isCompact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        scoreChip,
                        const SizedBox(height: 12),
                        SizedBox(width: constraints.maxWidth, child: slider),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      scoreChip,
                      const SizedBox(width: 12),
                      Expanded(child: slider),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildConsentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBF9),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE5D7D0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _maroon.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Agreement Version $_agreementVersion',
                      style: const TextStyle(
                        color: _maroon,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Text(
                    'Review this agreement before you sign and submit.',
                    style: TextStyle(fontWeight: FontWeight.w600, color: _ink),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                _agreementText,
                style: TextStyle(color: Colors.grey.shade800, height: 1.55),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cream,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: _agreeToConsent,
                onChanged: _isReadOnly
                    ? null
                    : (value) => setState(() {
                        _agreeToConsent = value ?? false;
                      }),
                activeColor: _maroon,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'I have reviewed the agreement above and I consent to the processing, retention, and signed recording of my tracer submission under the stated agreement version.',
                  style: TextStyle(height: 1.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 640;
            final dateField = TextFormField(
              controller: _submissionDateController,
              readOnly: true,
              decoration: _inputDecoration('Submission Date').copyWith(
                helperText:
                    'The server records the final submission date and time automatically.',
                suffixIcon: const Icon(Icons.schedule_outlined),
              ),
            );
            final signatureField = TextFormField(
              initialValue: _hasExistingSubmission
                  ? 'Saved signature on file'
                  : (_existingSignatureBytes != null
                        ? 'Draft signature on file'
                        : ''),
              readOnly: true,
              decoration: _inputDecoration('Signature Status'),
            );

            if (isCompact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  dateField,
                  const SizedBox(height: 16),
                  signatureField,
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: dateField),
                const SizedBox(width: 16),
                Expanded(child: signatureField),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        Container(
          height: 170,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE5D7D0)),
          ),
          child: _isReadOnly
              ? (_existingSignatureBytes == null
                    ? const Center(
                        child: Text('No stored signature preview available.'),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.memory(
                          _existingSignatureBytes!,
                          fit: BoxFit.contain,
                        ),
                      ))
              : ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Signature(
                    controller: _signature,
                    backgroundColor: Colors.white,
                  ),
                ),
        ),
        if (!_isReadOnly) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              TextButton.icon(
                onPressed: () => _signature.clear(),
                icon: const Icon(Icons.clear),
                label: const Text('Clear Signature'),
              ),
              if (_existingSignatureBytes != null)
                Text(
                  'Leave the pad blank if you want to keep the previous signature.',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
            ],
          ),
        ],
        const SizedBox(height: 20),
        if (!_isReadOnly)
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 640;
              final draftButton = OutlinedButton.icon(
                onPressed: _isSaving ? null : _saveDraft,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _maroon,
                  side: const BorderSide(color: _maroon),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                icon: const Icon(Icons.save_as_outlined),
                label: Text(
                  _hasDraftSaved ? 'Update Draft' : 'Save Draft',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              );

              final submitButton = ElevatedButton.icon(
                onPressed: _isSaving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _maroon,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(
                  _hasExistingSubmission
                      ? 'Update Tracer Form'
                      : 'Submit Tracer Form',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              );

              if (isCompact) {
                return Column(
                  children: [
                    SizedBox(width: double.infinity, child: draftButton),
                    const SizedBox(height: 12),
                    SizedBox(width: double.infinity, child: submitButton),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: draftButton),
                  const SizedBox(width: 16),
                  Expanded(child: submitButton),
                ],
              );
            },
          ),
      ],
    );
  }

  String _formatDate(String iso) {
    try {
      final parsed = DateTime.parse(iso).toLocal();
      const months = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];
      return '${months[parsed.month - 1]} ${parsed.day}, ${parsed.year}';
    } catch (_) {
      return iso;
    }
  }
}
