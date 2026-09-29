import 'package:flutter/material.dart';

/// The full manufacturing pipeline, in order.
enum JobStage {
  inquiry('Inquiry', 'Inquiry', Icons.edit_note),
  cad('CAD Design', 'CAD', Icons.view_in_ar),
  approval('Design Approval', 'Approval', Icons.fact_check_outlined),
  pricing('Pricing', 'Pricing', Icons.request_quote_outlined),
  finalApproval('Final Approval', 'Final App', Icons.verified_outlined),
  wax('Wax / 3D Print', 'Wax', Icons.print_outlined),
  casting('Casting', 'Casting', Icons.local_fire_department_outlined),
  assembly('Assembly', 'Assembly', Icons.build_outlined),
  setting('Stone Setting', 'Setting', Icons.diamond_outlined),
  polishing('Polishing', 'Polishing', Icons.auto_awesome_outlined),
  qc('Quality Control', 'QC', Icons.rule_outlined),
  certification('Certification', 'Cert', Icons.workspace_premium_outlined),
  dispatch('Dispatch', 'Dispatch', Icons.local_shipping_outlined),
  delivered('Delivered', 'Delivered', Icons.inventory_2_outlined);

  const JobStage(this.label, this.short, this.icon);

  final String label;
  final String short;
  final IconData icon;

  bool isBefore(JobStage other) => index < other.index;
  bool isAfter(JobStage other) => index > other.index;

  JobStage? get next => index + 1 < JobStage.values.length ? JobStage.values[index + 1] : null;

  /// Status color family from the design system:
  /// Inquiry = slate, CAD = sky, Approval = emerald, Production = amber.
  Color get color {
    switch (this) {
      case JobStage.inquiry:
        return const Color(0xFF94A3B8);
      case JobStage.cad:
        return const Color(0xFF0EA5E9);
      case JobStage.approval:
      case JobStage.pricing:
      case JobStage.finalApproval:
        return const Color(0xFF10B981);
      case JobStage.wax:
      case JobStage.casting:
      case JobStage.assembly:
      case JobStage.setting:
      case JobStage.polishing:
        return const Color(0xFFF59E0B);
      case JobStage.qc:
      case JobStage.certification:
        return const Color(0xFF6366F1);
      case JobStage.dispatch:
      case JobStage.delivered:
        return const Color(0xFF64748B);
    }
  }
}

/// Columns on the Production Floor kanban board.
enum BoardColumn {
  approved('Approved', [JobStage.inquiry, JobStage.cad, JobStage.approval, JobStage.pricing, JobStage.finalApproval]),
  wax('Wax/Print', [JobStage.wax]),
  casting('Casting', [JobStage.casting]),
  assembly('Assembly', [JobStage.assembly]),
  setting('Setting', [JobStage.setting]),
  finishing('Polish & QC', [JobStage.polishing, JobStage.qc, JobStage.certification]),
  dispatch('Dispatch', [JobStage.dispatch, JobStage.delivered]);

  const BoardColumn(this.label, this.stages);

  final String label;
  final List<JobStage> stages;

  /// The stage a job is moved to when dropped onto this column.
  JobStage get entryStage => this == BoardColumn.approved ? JobStage.finalApproval : stages.first;

  static BoardColumn of(JobStage s) => BoardColumn.values.firstWhere((c) => c.stages.contains(s));
}

enum Priority {
  standard('Standard'),
  high('High Priority'),
  rush('Rush'),
  critical('Critical');

  const Priority(this.label);
  final String label;
}

enum MessageKind { message, system, file, stage }

class ThreadMessage {
  ThreadMessage({
    required this.author,
    required this.text,
    required this.time,
    this.kind = MessageKind.message,
    this.title,
    this.isMe = false,
    this.avatar,
  });

  final String author;
  final String text;
  final DateTime time;
  final MessageKind kind;

  /// Bold heading for system/file/stage events ("CAD revision uploaded").
  final String? title;
  final bool isMe;

  /// Optional asset path for the author avatar.
  final String? avatar;
}

enum FileKind { image, cad, pdf, sheet, audio }

class ProjectFile {
  ProjectFile({
    required this.name,
    required this.kind,
    this.asset,
    this.localPath,
    this.jobId,
    this.uploadedBy = 'Ravi S.',
    DateTime? date,
    this.sizeLabel = '—',
  }) : date = date ?? DateTime.now();

  final String name;
  final FileKind kind;

  /// Bundled image under assets/images (for mock files).
  final String? asset;

  /// Path of a file the user picked/captured on the device.
  final String? localPath;
  final String? jobId;
  final String uploadedBy;
  final DateTime date;
  final String sizeLabel;

  IconData get icon {
    switch (kind) {
      case FileKind.image:
        return Icons.image_outlined;
      case FileKind.cad:
        return Icons.view_in_ar_outlined;
      case FileKind.pdf:
        return Icons.picture_as_pdf_outlined;
      case FileKind.sheet:
        return Icons.table_chart_outlined;
      case FileKind.audio:
        return Icons.graphic_eq;
    }
  }
}

class Partner {
  const Partner({
    required this.name,
    required this.role,
    this.avatar,
    this.company,
    this.location,
    this.phone,
    this.activeJobs = 0,
    this.rating = 4.8,
  });

  final String name;

  /// e.g. "Lead Designer", "Casting", "Retailer", "Stone Provider".
  final String role;
  final String? avatar;
  final String? company;
  final String? location;
  final String? phone;
  final int activeJobs;
  final double rating;

  String get initials {
    final parts = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
}

class StageEvent {
  StageEvent({required this.stage, required this.at, required this.by, this.note});

  final JobStage stage;
  final DateTime at;
  final String by;
  final String? note;
}

class Job {
  Job({
    required this.id,
    required this.title,
    required this.customer,
    required this.stage,
    required this.dueDate,
    required this.value,
    this.productType = 'Ring',
    this.manufacturer = 'AuraForge India',
    this.priority = Priority.standard,
    this.image,
    this.metal = '18K Yellow Gold',
    this.centerStone = '—',
    this.settingStyle = '—',
    this.weightGrams,
    this.ringSize,
    this.assignee,
    this.stageEnteredAt,
    this.atRisk = false,
    this.quantity = 1,
    this.notes,
    this.order,
    List<ThreadMessage>? thread,
    List<ProjectFile>? files,
    List<StageEvent>? history,
    Map<JobStage, Map<String, String>>? stageData,
  }) : thread = thread ?? [],
       files = files ?? [],
       history = history ?? [],
       stageData = stageData ?? {};

  final String id;
  String title;
  String customer;
  JobStage stage;
  DateTime dueDate;
  double value;
  String productType;
  String manufacturer;
  Priority priority;

  /// Asset path for the hero/thumbnail image.
  String? image;
  String metal;
  String centerStone;
  String settingStyle;
  double? weightGrams;
  String? ringSize;

  /// Who currently holds the job (vendor / bench / designer).
  String? assignee;
  DateTime? stageEnteredAt;
  bool atRisk;
  int quantity;
  String? notes;

  /// Full specification captured by the Full Job Order wizard (null for quick jobs,
  /// inquiries and seed data).
  final JobDraft? order;

  final List<ThreadMessage> thread;
  final List<ProjectFile> files;
  final List<StageEvent> history;

  /// What was recorded in each stage (e.g. pricing → quote lines, dispatch → courier + waybill).
  /// Shown on the Process Detail screen.
  final Map<JobStage, Map<String, String>> stageData;

  /// 0..1 progress through the pipeline.
  double get progress => stage.index / (JobStage.values.length - 1);

  int get daysInStage => stageEnteredAt == null ? 0 : DateTime.now().difference(stageEnteredAt!).inDays;

  int get daysUntilDue {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return due.difference(today).inDays;
  }

  bool get isOverdue => daysUntilDue < 0 && stage != JobStage.delivered;
  bool get isComplete => stage == JobStage.delivered;
}

class MetalStock {
  MetalStock({
    required this.code,
    required this.name,
    required this.grams,
    required this.capacityGrams,
    required this.color,
  });

  final String code;
  final String name;
  double grams;
  final double capacityGrams;
  final Color color;
}

class GemStock {
  GemStock({
    required this.id,
    required this.name,
    required this.tag,
    required this.carat,
    required this.specs,
    required this.location,
    this.image,
    this.assignedJobId,
  });

  final String id;
  final String name;

  /// e.g. "GIA Cert", "Unheated".
  final String tag;
  final double carat;

  /// Ordered spec pairs, e.g. {'COLOR': 'F', 'CLARITY': 'VVS2'}.
  final Map<String, String> specs;
  final String location;
  final String? image;
  String? assignedJobId;
}

enum ActionKind { cadReview, pricing, delay, missing, certification }

class ActionItem {
  ActionItem({required this.kind, required this.title, required this.subtitle, required this.jobId, required this.cta});

  final ActionKind kind;
  final String title;
  final String subtitle;
  final String jobId;
  final String cta;
}

class ActivityItem {
  ActivityItem({required this.text, required this.jobId, required this.time, required this.by});

  final String text;
  final String jobId;
  final DateTime time;
  final String by;
}

class MeleeParcel {
  MeleeParcel({
    this.type = 'Diamond',
    this.shape = 'Round',
    this.sizeRange = '1.0 - 1.5mm',
    this.totalCarat = 0.25,
    this.colorClarity = 'G-H / VS',
    this.supplied = false,
    this.notes,
  });

  String type;
  String shape;
  String sizeRange;
  double totalCarat;
  String colorClarity;

  /// true = in stock / supplied, false = needs sourcing.
  bool supplied;
  String? notes;

  String get summary => '$sizeRange • ${totalCarat.toStringAsFixed(2)} ctw • $colorClarity';
}

class CostLine {
  CostLine(this.label, this.amount, {this.group = 'Manufacturing', this.suppliedBy, this.note});

  String label;
  double amount;
  String group;
  String? suppliedBy;
  String? note;
}

/// Everything captured by the New Job wizard. One instance lives in
/// [AppState.draft] and is reset when a job is created or cancelled.
class JobDraft {
  /// Name of the piece ("Gold Signet Ring"); used as the job title when set.
  String title = '';

  // Job type / flow
  String jobType = 'New Custom Design';
  String productCategory = 'Ring';
  String customer = 'ABC Jewelers';
  int quantity = 1;
  String notes = '';

  // Reference media
  final List<String> referenceImages = [];
  bool hasVoiceNote = false;
  Duration voiceNoteLength = Duration.zero;

  // Quick specs
  String quickBaseMetal = 'Y.GOLD';
  String quickPurity = '18K';
  bool quickGemstone = true;
  double? budget;
  DateTime? deliveryDate;

  // Design specs
  String sizeSystem = 'US';
  String ringSize = '6.5';
  double bandWidthMm = 2.0;
  String settingStyle = 'Prong';
  String metalFinish = 'High Polish';
  String bandProfile = 'Round';
  String sideStoneSetting = 'None';
  final Set<String> priorities = {'Match Exactly'};

  // Metal
  String baseMetal = 'Gold';
  String purity = '18K';
  String metalColor = 'Yellow';
  double? targetWeight = 4.2;
  double? weightTolerance = 0.2;
  bool customerSuppliedMetal = false;
  bool hallmark = true;
  String alloyNotes = '';

  // Center stone
  bool stoneSupplied = false;
  String stoneType = 'Diamond';
  String stoneOrigin = 'Natural';
  String stoneShape = 'Round';
  double? stoneCarat = 1.5;
  String stoneDims = '';
  String stoneColor = 'G-H';
  String stoneClarity = 'VS1';
  String stoneCut = 'Ex';
  String certificate = 'GIA';
  String? stonePhoto;
  String? stoneCertificatePhoto;
  String stoneNotes = '';
  final List<MeleeParcel> melee = [MeleeParcel()];

  // Commercial
  String pricingBasis = 'Fixed Quote';
  final List<CostLine> costs = [
    CostLine('CAD Design', 250),
    CostLine('Setting (Micro-pave)', 450),
    CostLine('Finishing & Polish', 120),
    CostLine('Certification (GIA)', 150),
  ];
  double metalMarketRate = 2050;
  double declaredStoneValue = 12500;
  double targetUnitPrice = 3450;
  double maxApprovedPrice = 3800;

  // Delivery
  DateTime? requestedDelivery;
  bool hardDeadline = false;
  bool partialDelivery = false;
  Priority priority = Priority.standard;

  // Quality acceptance
  final Set<String> qualityChecks = {'Match CAD / Reference', 'High-Polish Surface Finish'};
  String qualityCertification = 'GIA';
  String customerRequirements = '';
  String qualityAuthority = 'Internal QC';

  String get metalLabel {
    if (baseMetal == 'Platinum') return 'Platinum 950';
    if (baseMetal == 'Silver') return '925 Silver';
    return '$purity $metalColor $baseMetal';
  }

  String get stoneLabel {
    final ct = stoneCarat == null ? '' : '${stoneCarat!.toStringAsFixed(2)}ct ';
    return '$ct$stoneShape $stoneType';
  }

  double get manufacturingTotal => costs.fold(0, (s, l) => s + l.amount);
}
