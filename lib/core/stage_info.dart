import 'models.dart';

/// Static description of what happens in each pipeline stage.
class StageInfo {
  const StageInfo({required this.summary, required this.owner, required this.checklist, required this.workspace});

  final String summary;

  /// Who normally handles the stage.
  final String owner;

  /// What must be true before the stage can be completed.
  final List<String> checklist;

  /// Label of the dedicated stage screen (opened via Routes.forStage).
  final String workspace;

  static const Map<JobStage, StageInfo> all = {
    JobStage.inquiry: StageInfo(
      summary: 'Customer request is captured: product, metal, stones, references, budget and delivery date.',
      owner: 'Manufacturing Engineer',
      checklist: [
        'Product & design specs captured',
        'Reference images / voice brief attached',
        'Budget and delivery date agreed',
      ],
      workspace: 'Order Details',
    ),
    JobStage.cad: StageInfo(
      summary: 'CAD designer builds the 3D model from the brief and uploads versions for review.',
      owner: 'CAD Designer',
      checklist: [
        '3D model uploaded (STL / STEP)',
        'Stone sizes and proportions match specs',
        'Renders shared for review',
      ],
      workspace: 'CAD Review',
    ),
    JobStage.approval: StageInfo(
      summary: 'The design is reviewed; revisions are requested or the version is approved and locked.',
      owner: 'Manufacturing Engineer / Customer',
      checklist: ['Latest version compared with previous', 'Revision feedback resolved', 'Design version locked'],
      workspace: 'CAD Review',
    ),
    JobStage.pricing: StageInfo(
      summary: 'Bill of materials is costed: metal, gemstones, labour, setting and certification.',
      owner: 'Manufacturing Engineer',
      checklist: ['Metal weight and rate confirmed', 'Stone costs confirmed', 'Itemised quote prepared'],
      workspace: 'Pricing Approval',
    ),
    JobStage.finalApproval: StageInfo(
      summary: 'Customer approves the final design and price; the job is released to manufacturing.',
      owner: 'Customer',
      checklist: ['Quote approved', 'Design approved', 'Released to production'],
      workspace: 'Pricing Approval',
    ),
    JobStage.wax: StageInfo(
      summary: 'The approved CAD is 3D printed in castable wax/resin and inspected.',
      owner: '3D Print Bureau',
      checklist: ['Wax model printed', 'Wax inspected for defects', 'Wax sent to caster'],
      workspace: 'Casting Dashboard',
    ),
    JobStage.casting: StageInfo(
      summary: 'The wax is invested, burnt out and cast in the chosen alloy.',
      owner: 'Casting House',
      checklist: ['Complete burnout before casting', 'Casting photo uploaded', 'No porosity or incomplete fill'],
      workspace: 'Casting Dashboard',
    ),
    JobStage.assembly: StageInfo(
      summary: 'Sprues are removed, parts cleaned up, pre-polished and assembled at the bench.',
      owner: 'Bench Jeweler',
      checklist: ['Sprues removed', 'Components assembled / soldered', 'Pre-polish done'],
      workspace: 'Workflow Tracker',
    ),
    JobStage.setting: StageInfo(
      summary: 'Center and accent stones are set and secured.',
      owner: 'Stone Setter',
      checklist: ['Center stone set', 'Melee / accent stones set', 'Prongs checked for security'],
      workspace: 'Workflow Tracker',
    ),
    JobStage.polishing: StageInfo(
      summary: 'Final polishing and finishing (high polish, matte, texture) as specified.',
      owner: 'Polisher',
      checklist: ['Finish matches spec', 'No tool marks or scratches', 'Cleaned ultrasonically'],
      workspace: 'Workflow Tracker',
    ),
    JobStage.qc: StageInfo(
      summary: 'Final inspection against the approved CAD, dimensions, weight, stone security and finish.',
      owner: 'QC Specialist',
      checklist: [
        'Design matches approved CAD',
        'Dimensions and weight in tolerance',
        'Stones secure, finish approved',
      ],
      workspace: 'Quality Control',
    ),
    JobStage.certification: StageInfo(
      summary: 'Stones / piece are sent to a gem lab (IGI, GIA, HRD) and the certificate is logged.',
      owner: 'Gem Lab',
      checklist: ['Package sent to lab', 'Certificate received', 'Certificate number logged'],
      workspace: 'Certification',
    ),
    JobStage.dispatch: StageInfo(
      summary: 'Secure packing, insurance and courier manifest; the piece is shipped.',
      owner: 'Logistics',
      checklist: ['Tamper-evident seal applied', 'Insurance value declared', 'Waybill generated'],
      workspace: 'Shipping',
    ),
    JobStage.delivered: StageInfo(
      summary: 'The piece is received by the jeweler or customer.',
      owner: 'Customer / Jeweler',
      checklist: ['Delivery confirmed', 'Documents handed over'],
      workspace: 'Shipping',
    ),
  };

  static StageInfo of(JobStage s) => all[s]!;
}

enum StageStatus {
  done('Completed'),
  current('In Progress'),
  upcoming('Upcoming'),
  skipped('Skipped');

  const StageStatus(this.label);
  final String label;
}

/// Everything known about one stage of one job, derived from history, thread and files.
class StageRecord {
  StageRecord({
    required this.stage,
    required this.status,
    required this.data,
    required this.activity,
    required this.files,
    this.start,
    this.end,
    this.by,
    this.note,
  });

  final JobStage stage;
  final StageStatus status;
  final DateTime? start;
  final DateTime? end;
  final String? by;
  final String? note;
  final Map<String, String> data;
  final List<ThreadMessage> activity;
  final List<ProjectFile> files;

  /// Time spent in the stage (until now for the current stage).
  Duration? get duration {
    if (start == null) return null;
    final until = end ?? (status == StageStatus.current ? DateTime.now() : null);
    return until?.difference(start!);
  }

  static StageRecord of(Job job, JobStage s) {
    // History is appended in order. The entry is the latest time the job entered [s]
    // (a stage can be revisited); the exit is the next transition after it. A transition
    // event's `by`/`note` describe who finished the stage being left, so they belong to
    // the stage that was exited, not the one entered.
    var entryIdx = -1;
    for (var i = 0; i < job.history.length; i++) {
      if (job.history[i].stage == s) entryIdx = i;
    }
    final entry = entryIdx < 0 ? null : job.history[entryIdx];
    final exit = (entryIdx >= 0 && s.index < job.stage.index && entryIdx + 1 < job.history.length)
        ? job.history[entryIdx + 1]
        : null;
    final end = exit?.at;
    final data = job.stageData[s] ?? const {};
    final StageStatus status;
    if (s == job.stage) {
      status = StageStatus.current;
    } else if (s.index > job.stage.index) {
      status = StageStatus.upcoming;
    } else {
      status = (entry != null || data.isNotEmpty) ? StageStatus.done : StageStatus.skipped;
    }
    bool inWindow(DateTime t) {
      if (entry == null || status == StageStatus.upcoming) return false;
      if (t.isBefore(entry.at)) return false;
      return end == null || t.isBefore(end);
    }

    final String? by;
    String? note;
    if (status == StageStatus.current) {
      by = job.assignee ?? StageInfo.of(s).owner;
    } else {
      by = data['Completed By'] ?? exit?.by ?? entry?.by;
      if (!data.containsKey('Completion Note')) note = exit?.note;
    }

    return StageRecord(
      stage: s,
      status: status,
      start: status == StageStatus.upcoming ? null : entry?.at,
      end: end,
      by: status == StageStatus.upcoming ? null : by,
      note: note,
      data: data,
      activity: [
        for (final m in job.thread)
          if (inWindow(m.time)) m,
      ],
      files: [
        for (final f in job.files)
          if (inWindow(f.date)) f,
      ],
    );
  }
}

/// "2d 4h", "3h 20m", "12m"
String formatDuration(Duration d) {
  if (d.inDays > 0) return '${d.inDays}d ${d.inHours.remainder(24)}h';
  if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
  return '${d.inMinutes.clamp(0, 59)}m';
}
