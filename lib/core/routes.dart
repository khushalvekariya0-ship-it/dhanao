import 'package:flutter/material.dart';

import '../screens/inquiry/new_inquiry_screen.dart';
import '../screens/jobs/job_detail_screen.dart';
import '../screens/jobs/stage_detail_screen.dart';
import '../screens/more/files_screen.dart';
import '../screens/more/partners_screen.dart';
import '../screens/more/settings_screen.dart';
import '../screens/new_job/capture_details_screen.dart';
import '../screens/new_job/commercial_requirements_screen.dart';
import '../screens/new_job/confirm_order_screen.dart';
import '../screens/new_job/delivery_requirements_screen.dart';
import '../screens/new_job/design_specs_screen.dart';
import '../screens/new_job/job_order_created_screen.dart';
import '../screens/new_job/metal_materials_screen.dart';
import '../screens/new_job/product_selection_screen.dart';
import '../screens/new_job/quality_acceptance_screen.dart';
import '../screens/new_job/quick_specs_screen.dart';
import '../screens/new_job/review_job_order_screen.dart';
import '../screens/new_job/start_new_job_screen.dart';
import '../screens/new_job/stone_requirements_screen.dart';
import '../screens/shell/home_shell.dart';
import '../screens/stages/cad_review_screen.dart';
import '../screens/stages/caster_dashboard_screen.dart';
import '../screens/stages/certification_screen.dart';
import '../screens/stages/order_details_screen.dart';
import '../screens/stages/pricing_approval_screen.dart';
import '../screens/stages/quality_control_screen.dart';
import '../screens/stages/shipping_screen.dart';
import '../screens/stages/workflow_tracker_screen.dart';
import 'models.dart';
import 'stage_info.dart';

/// Named routes. Job-scoped routes take the job id (String) as `arguments`.
///
///   Navigator.pushNamed(context, Routes.cadReview, arguments: job.id);
class Routes {
  Routes._();

  static const home = '/';

  // Job + stage screens (arguments: String jobId)
  static const job = '/job';
  static const cadReview = '/job/cad-review';
  static const pricing = '/job/pricing';
  static const casting = '/job/casting';
  static const qc = '/job/qc';
  static const certification = '/job/certification';
  static const shipping = '/job/shipping';
  static const tracker = '/job/tracker';
  static const orderDetails = '/job/order';

  /// Process Detail for one stage of a job. arguments: StageRef(jobId, stage).
  static const stage = '/job/stage';

  static const inquiry = '/inquiry';
  static const partners = '/partners';
  static const files = '/files';
  static const settings = '/settings';

  // New Job wizard — quick flow
  static const newJob = '/new';
  static const capture = '/new/capture';
  static const quickSpecs = '/new/quick-specs';
  static const confirmOrder = '/new/confirm';

  // New Job wizard — full job order flow
  static const product = '/new/product';
  static const designSpecs = '/new/design-specs';
  static const metal = '/new/metal';
  static const stones = '/new/stones';
  static const commercial = '/new/commercial';
  static const delivery = '/new/delivery';
  static const quality = '/new/quality';
  static const review = '/new/review';

  /// arguments: String jobId of the created job.
  static const created = '/new/created';

  /// The most relevant stage screen for a job currently in [s].
  static String forStage(JobStage s) {
    switch (s) {
      case JobStage.inquiry:
        return orderDetails;
      case JobStage.cad:
      case JobStage.approval:
        return cadReview;
      case JobStage.pricing:
      case JobStage.finalApproval:
        return pricing;
      case JobStage.wax:
      case JobStage.casting:
        return casting;
      case JobStage.assembly:
      case JobStage.setting:
      case JobStage.polishing:
        return tracker;
      case JobStage.qc:
        return qc;
      case JobStage.certification:
        return certification;
      case JobStage.dispatch:
      case JobStage.delivered:
        return shipping;
    }
  }

  static Route<dynamic>? generate(RouteSettings s) {
    final id = s.arguments is String ? s.arguments as String : null;
    Widget page;
    switch (s.name) {
      case home:
        page = const HomeShell();
      case job:
        page = JobDetailScreen(jobId: id ?? 'DH-1048');
      case stage:
        final ref = s.arguments is StageRef ? s.arguments as StageRef : const StageRef('DH-1048', JobStage.inquiry);
        page = StageDetailScreen(jobId: ref.jobId, initialStage: ref.stage);
      case cadReview:
        page = CadReviewScreen(jobId: id);
      case pricing:
        page = PricingApprovalScreen(jobId: id);
      case casting:
        page = CasterDashboardScreen(jobId: id);
      case qc:
        page = QualityControlScreen(jobId: id);
      case certification:
        page = CertificationScreen(jobId: id);
      case shipping:
        page = ShippingScreen(jobId: id);
      case tracker:
        page = WorkflowTrackerScreen(jobId: id);
      case orderDetails:
        page = OrderDetailsScreen(jobId: id);
      case inquiry:
        page = const NewInquiryScreen();
      case partners:
        page = const PartnersScreen();
      case files:
        page = const FilesScreen();
      case settings:
        page = const SettingsScreen();
      case newJob:
        page = const StartNewJobScreen();
      case capture:
        page = const CaptureDetailsScreen();
      case quickSpecs:
        page = const QuickSpecsScreen();
      case confirmOrder:
        page = const ConfirmOrderScreen();
      case product:
        page = const ProductSelectionScreen();
      case designSpecs:
        page = const DesignSpecsScreen();
      case metal:
        page = const MetalMaterialsScreen();
      case stones:
        page = const StoneRequirementsScreen();
      case commercial:
        page = const CommercialRequirementsScreen();
      case delivery:
        page = const DeliveryRequirementsScreen();
      case quality:
        page = const QualityAcceptanceScreen();
      case review:
        page = const ReviewJobOrderScreen();
      case created:
        page = JobOrderCreatedScreen(jobId: id ?? '');
      default:
        return null;
    }
    return MaterialPageRoute(builder: (_) => page, settings: s);
  }
}
