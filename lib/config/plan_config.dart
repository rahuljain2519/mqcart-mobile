/// The free seller plan expires for everyone on this fixed calendar date,
/// not N days after each seller's own activation - every free-plan seller
/// hits the same cutoff together. After it, only paid plans are selectable
/// (see ActivateShopScreen) and any seller still on free gets hidden (not
/// deleted) by the enforcePlanExpiry Cloud Function until they pick a
/// paid plan (see functions/planExpiry.js - mirrored here since there is
/// no shared module between the Flutter app and the Cloud Functions repo).
final DateTime freePlanCutoff = DateTime(2027, 3, 31);

bool get isFreePlanWindowClosed => DateTime.now().isAfter(freePlanCutoff);

String formatPlanDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}
