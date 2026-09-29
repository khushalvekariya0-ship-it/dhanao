import 'package:flutter/material.dart';

import 'format.dart';
import 'mock_data.dart';
import 'models.dart';

/// Single in-memory store for the app. Screens read from [AppState.instance]
/// and rebuild with `ListenableBuilder(listenable: app, ...)`.
class AppState extends ChangeNotifier {
  AppState._();

  static final AppState instance = AppState._();

  // ---- Session ------------------------------------------------------------
  final String userName = 'Ravi S.';
  final String userRole = 'Manufacturing Engineer';

  /// Kept separate from the store so theme changes rebuild only MaterialApp.
  final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.light);

  bool notificationsEnabled = true;

  // ---- Data ---------------------------------------------------------------
  final List<Job> jobs = MockData.jobs();
  final List<Partner> partners = MockData.partners();
  final List<MetalStock> metals = MockData.metals();
  final List<GemStock> gems = MockData.gems();
  final List<ActionItem> actions = MockData.actions();
  final List<ActivityItem> activity = MockData.activity();

  JobDraft draft = JobDraft();

  int _seq = 1842;

  // ---- Queries ------------------------------------------------------------
  Job? jobById(String id) {
    for (final j in jobs) {
      if (j.id == id) return j;
    }
    return null;
  }

  /// Falls back to the showcase job (DH-1048) so stage screens always have data,
  /// even after new jobs are inserted at the top of the list.
  Job jobOrDefault(String? id) => (id == null ? null : jobById(id)) ?? jobById('DH-1048') ?? jobs.first;

  List<Job> get activeJobs => jobs.where((j) => !j.isComplete).toList();
  List<Job> get atRiskJobs => activeJobs.where((j) => j.atRisk || j.isOverdue).toList();

  List<Job> jobsInStage(JobStage s) => jobs.where((j) => j.stage == s).toList();
  List<Job> jobsInColumn(BoardColumn c) => jobs.where((j) => c.stages.contains(j.stage)).toList();

  /// Active jobs due within [days] days, most urgent first.
  List<Job> priorityJobs({int days = 2}) {
    final l = activeJobs.where((j) => j.daysUntilDue <= days).toList()..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return l;
  }

  List<ProjectFile> get allFiles => [for (final j in jobs) ...j.files];

  Partner? partnerByName(String name) {
    for (final p in partners) {
      if (p.name == name) return p;
    }
    return null;
  }

  // ---- Mutations ----------------------------------------------------------
  void setStage(Job job, JobStage stage, {String? by, String? note}) {
    if (job.stage == stage) return;
    job.stage = stage;
    job.stageEnteredAt = DateTime.now();
    job.history.add(StageEvent(stage: stage, at: DateTime.now(), by: by ?? userName, note: note));
    job.thread.add(
      ThreadMessage(
        author: 'System',
        kind: MessageKind.stage,
        title: 'Stage Changed: ${stage.label}',
        text: note ?? '${by ?? userName} moved the job to ${stage.label}.',
        time: DateTime.now(),
      ),
    );
    activity.insert(
      0,
      ActivityItem(text: '${stage.label} started', jobId: job.id, time: DateTime.now(), by: by ?? userName),
    );
    notifyListeners();
  }

  /// Moves the job to the next pipeline stage. Returns the new stage.
  JobStage? advance(Job job, {String? by, String? note}) {
    final n = job.stage.next;
    if (n != null) setStage(job, n, by: by, note: note);
    return n;
  }

  /// Saves details of what happened in [stage] (merged into earlier records).
  void recordStage(Job job, JobStage stage, Map<String, String> data) {
    final clean = {
      for (final e in data.entries)
        if (e.value.trim().isNotEmpty) e.key: e.value.trim(),
    };
    if (clean.isEmpty) return;
    (job.stageData[stage] ??= {}).addAll(clean);
    notifyListeners();
  }

  /// Assigns who will hold [stage] (and optionally by when). Assigning the current stage
  /// also updates the job's assignee.
  void assignStage(Job job, JobStage stage, String who, {DateTime? expected}) {
    (job.stageData[stage] ??= {}).addAll({
      'Assigned To': who,
      if (expected != null) 'Expected': Fmt.dateLong(expected),
    });
    if (stage == job.stage) job.assignee = who;
    job.thread.add(
      ThreadMessage(
        author: 'System',
        kind: MessageKind.system,
        title: 'Assigned: ${stage.label}',
        text: '$who will handle ${stage.label}${expected == null ? '' : ' by ${Fmt.dateLong(expected)}'}.',
        time: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  /// Completes the job's current stage: records who/notes, attaches an optional
  /// photo, then moves to the next stage.
  JobStage? completeStage(Job job, {String? by, String? note, String? photoPath}) {
    final stage = job.stage;
    final who = (by == null || by.trim().isEmpty) ? userName : by.trim();
    recordStage(job, stage, {
      'Completed By': who,
      'Completion Note': ?note,
      if (photoPath != null) 'Photo': photoPath.split(RegExp(r'[\\/]')).last,
    });
    if (photoPath != null) addFile(job, _localImage(photoPath));
    return advance(job, by: who, note: (note == null || note.trim().isEmpty) ? null : note.trim());
  }

  void postMessage(Job job, String text) {
    job.thread.add(ThreadMessage(author: userName, text: text, time: DateTime.now(), isMe: true));
    notifyListeners();
  }

  void addEvent(Job job, {required String title, required String text, MessageKind kind = MessageKind.system}) {
    job.thread.add(ThreadMessage(author: 'System', kind: kind, title: title, text: text, time: DateTime.now()));
    notifyListeners();
  }

  void addFile(Job job, ProjectFile file) {
    job.files.insert(0, file);
    job.thread.add(
      ThreadMessage(
        author: userName,
        kind: MessageKind.file,
        title: 'File uploaded',
        text: file.name,
        time: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  void moveToColumn(Job job, BoardColumn column) {
    if (column.stages.contains(job.stage)) return;
    setStage(job, column.entryStage, note: 'Moved on Production Floor to ${column.label}.');
  }

  void assignGem(GemStock gem, String? jobId) {
    gem.assignedJobId = jobId;
    notifyListeners();
  }

  void dismissAction(ActionItem a) {
    actions.remove(a);
    notifyListeners();
  }

  void toggleRisk(Job job) {
    job.atRisk = !job.atRisk;
    notifyListeners();
  }

  // ---- New Job wizard -----------------------------------------------------
  /// Nothing listens to the draft itself, so this deliberately doesn't notify —
  /// that keeps it safe to call from a pushed route's initState.
  void resetDraft() => draft = JobDraft();

  String nextJobId() => 'DH-2026-${(++_seq).toString().padLeft(5, '0')}';

  /// Turns the current [draft] into a real job at the Inquiry stage. With [fullOrder] the draft is
  /// kept on the job as its specification (shown on Job Detail).
  Job createJobFromDraft({String? id, String? title, bool fullOrder = false}) {
    final d = draft;
    final job = Job(
      id: id ?? nextJobId(),
      title: title ?? (d.title.trim().isNotEmpty ? d.title.trim() : '${d.metalLabel} ${d.productCategory}'),
      productType: d.productCategory,
      customer: d.customer,
      stage: JobStage.inquiry,
      dueDate: d.requestedDelivery ?? d.deliveryDate ?? DateTime.now().add(const Duration(days: 35)),
      value: d.targetUnitPrice * d.quantity,
      priority: d.priority,
      metal: d.metalLabel,
      centerStone: d.stoneLabel,
      settingStyle: d.settingStyle,
      weightGrams: d.targetWeight,
      ringSize: d.productCategory.contains('Ring') ? '${d.sizeSystem} ${d.ringSize}' : null,
      quantity: d.quantity,
      notes: d.notes.isEmpty ? null : d.notes,
      order: fullOrder ? d : null,
      stageEnteredAt: DateTime.now(),
      history: [StageEvent(stage: JobStage.inquiry, at: DateTime.now(), by: userName)],
      thread: [
        ThreadMessage(
          author: 'System',
          kind: MessageKind.stage,
          title: 'Job Order Created',
          text: 'Parameters saved. Routing specs to CAD engineering.',
          time: DateTime.now(),
        ),
      ],
      files: [
        for (final p in d.referenceImages) _localImage(p),
        if (d.stonePhoto != null) _localImage(d.stonePhoto!),
        if (d.stoneCertificatePhoto != null) _localImage(d.stoneCertificatePhoto!),
      ],
    );
    job.stageData[JobStage.inquiry] = {
      'Order Type': fullOrder ? 'Full Job Order' : d.jobType,
      'Job Type': d.jobType,
      'Customer': d.customer,
      'Product': d.productCategory,
      'Metal': d.metalLabel,
      if (job.centerStone != '—') 'Center Stone': job.centerStone,
      if (job.ringSize != null) 'Ring Size': job.ringSize!,
      'Quantity': '${d.quantity}',
      'Target Value': Fmt.money(job.value),
      'Requested Delivery': Fmt.dateLong(job.dueDate),
      if (d.referenceImages.isNotEmpty) 'Reference Images': '${d.referenceImages.length}',
      if (d.hasVoiceNote) 'Voice Note': 'Recorded',
      if (d.notes.isNotEmpty) 'Notes': d.notes,
      'Created By': userName,
    };
    jobs.insert(0, job);
    activity.insert(0, ActivityItem(text: 'Job order created', jobId: job.id, time: DateTime.now(), by: userName));
    notifyListeners();
    return job;
  }
}

ProjectFile _localImage(String path) =>
    ProjectFile(name: path.split(RegExp(r'[\\/]')).last, kind: FileKind.image, localPath: path);

/// Short global accessor.
AppState get app => AppState.instance;
