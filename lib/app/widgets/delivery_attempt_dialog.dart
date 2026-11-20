import 'package:flutter/material.dart';
import 'package:p_sosyo_driver/app/core/themes/theme_colors.dart';
import 'package:p_sosyo_driver/app/modules/home/controller/home_controller.dart';

class DeliveryAttemptInput {
  final String reason;
  final String remarks;
  final bool lockAndQueue;
  final String? scheduledDateIso;

  const DeliveryAttemptInput({
    required this.reason,
    required this.remarks,
    this.lockAndQueue = false,
    this.scheduledDateIso,
  });
}

String _toIsoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

/// Shows a dialog to log a delivery attempt with a reason and optional
/// deferral/reschedule date setter (locks card & queues at bottom of list).
Future<DeliveryAttemptInput?> showDeliveryAttemptDialog(
  BuildContext context, {
  required String storeName,
  required String orderId,
  required int currentAttemptCount,
  bool initialLockAndQueue = false,
}) {
  final nextAttempt = currentAttemptCount + 1;

  const deferReasons = <String>{
    'Store closed',
    'No one can claim delivery',
    'Order deferred by customer',
    'Deliver tomorrow / reschedule',
  };

  final presetReasons = <String>[
    'Store closed',
    'No one can claim delivery',
    'Order deferred by customer',
    'Deliver tomorrow / reschedule',
    'No response after call',
    'Customer on errands / unavailable',
    'Others',
  ];

  String selectedReason =
      initialLockAndQueue ? 'Store closed' : 'No response after call';
  bool lockAndQueue =
      initialLockAndQueue || deferReasons.contains(selectedReason);
  DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
  final customController = TextEditingController();
  String? errorText;

  return showDialog<DeliveryAttemptInput>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          final isOthers = selectedReason == 'Others';
          final tomorrow = DateTime.now().add(const Duration(days: 1));
          final isTomorrow = _toIsoDate(selectedDate) == _toIsoDate(tomorrow);
          final scheduledIso = _toIsoDate(selectedDate);
          final scheduledLabel = HomeController.formatDateLabel(scheduledIso);

          return Dialog(
            backgroundColor: AppColors.surface,
            elevation: 0,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.xxl,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.xl),
              side: const BorderSide(color: AppColors.border),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.warningTint,
                          borderRadius: BorderRadius.circular(AppRadii.md),
                          border: Border.all(color: AppColors.warningBorder),
                        ),
                        child: Icon(
                          lockAndQueue
                              ? Icons.lock_clock_outlined
                              : Icons.local_shipping_outlined,
                          size: 20,
                          color: AppColors.warning,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              initialLockAndQueue
                                  ? 'Lock & Queue Delivery'
                                  : 'Delivery Attempt #$nextAttempt',
                              style: AppTypography.title.copyWith(fontSize: 20),
                            ),
                            Text(
                              '$storeName · Ref #$orderId',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.monoRef.copyWith(
                                fontSize: 13.5,
                                color: AppColors.inkMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Select a reason (customer will be notified via SMS):',
                    style: AppTypography.caption.copyWith(
                      fontSize: 15,
                      color: AppColors.inkSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: presetReasons.map((reason) {
                      final selected = selectedReason == reason;
                      return ChoiceChip(
                        label: Text(
                          reason,
                          style: AppTypography.caption.copyWith(
                            fontSize: 14,
                            fontWeight:
                                selected ? FontWeight.w600 : FontWeight.w500,
                            color: selected
                                ? AppColors.warning
                                : AppColors.inkSecondary,
                          ),
                        ),
                        selected: selected,
                        selectedColor: AppColors.warningTint,
                        backgroundColor: AppColors.canvas,
                        side: BorderSide(
                          color: selected
                              ? AppColors.warningBorder
                              : AppColors.border,
                        ),
                        onSelected: (_) {
                          setState(() {
                            selectedReason = reason;
                            lockAndQueue =
                                initialLockAndQueue || deferReasons.contains(reason);
                            errorText = null;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: lockAndQueue
                          ? AppColors.warningTint.withOpacity(0.55)
                          : AppColors.canvas,
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      border: Border.all(
                        color: lockAndQueue
                            ? AppColors.warningBorder
                            : AppColors.border,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Lock card & queue for redelivery',
                                style: AppTypography.label.copyWith(
                                  fontSize: 15,
                                  color: AppColors.inkPrimary,
                                ),
                              ),
                            ),
                            Switch.adaptive(
                              value: lockAndQueue,
                              activeColor: AppColors.warning,
                              onChanged: (val) {
                                setState(() => lockAndQueue = val);
                              },
                            ),
                          ],
                        ),
                        if (lockAndQueue) ...[
                          Text(
                            'Set agreed delivery date (sent to customer via SMS):',
                            style: AppTypography.caption.copyWith(
                              fontSize: 13.5,
                              color: AppColors.inkSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ChoiceChip(
                                label: Text(
                                  'Tomorrow (${HomeController.formatDateLabel(_toIsoDate(tomorrow))})',
                                  style: AppTypography.caption.copyWith(
                                    fontSize: 13.5,
                                    fontWeight: isTomorrow
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: isTomorrow
                                        ? AppColors.primary
                                        : AppColors.inkSecondary,
                                  ),
                                ),
                                selected: isTomorrow,
                                selectedColor: AppColors.primaryTint,
                                backgroundColor: AppColors.surface,
                                side: BorderSide(
                                  color: isTomorrow
                                      ? AppColors.primaryBorder
                                      : AppColors.border,
                                ),
                                onSelected: (_) {
                                  setState(() => selectedDate = tomorrow);
                                },
                              ),
                              ActionChip(
                                avatar: const Icon(
                                  Icons.calendar_today_outlined,
                                  size: 15,
                                  color: AppColors.primary,
                                ),
                                label: Text(
                                  isTomorrow
                                      ? 'Pick Date...'
                                      : scheduledLabel,
                                  style: AppTypography.caption.copyWith(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                                backgroundColor: AppColors.surface,
                                side: const BorderSide(
                                  color: AppColors.primaryBorder,
                                ),
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: selectedDate,
                                    firstDate: tomorrow,
                                    lastDate: DateTime.now()
                                        .add(const Duration(days: 60)),
                                  );
                                  if (picked != null) {
                                    setState(() => selectedDate = picked);
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: customController,
                    maxLines: 2,
                    textInputAction: TextInputAction.done,
                    onChanged: (_) {
                      if (errorText != null) {
                        setState(() => errorText = null);
                      }
                    },
                    decoration: InputDecoration(
                      hintText: isOthers
                          ? 'Enter attempt remarks (required)...'
                          : 'Optional remarks (e.g. store opens at 9AM)...',
                      errorText: errorText,
                      filled: true,
                      fillColor: AppColors.canvas,
                      contentPadding: const EdgeInsets.all(AppSpacing.md),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadii.md),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadii.md),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadii.md),
                        borderSide: const BorderSide(color: AppColors.warning),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(dialogContext).pop(null),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.inkSecondary,
                            side: const BorderSide(color: AppColors.border),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadii.md),
                            ),
                          ),
                          child: Text(
                            'Back',
                            style: AppTypography.label.copyWith(
                              fontSize: 17,
                              color: AppColors.inkSecondary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            final remarks = customController.text.trim();
                            if (isOthers && remarks.isEmpty) {
                              setState(() {
                                errorText = 'Please enter attempt remarks';
                              });
                              return;
                            }
                            Navigator.of(dialogContext).pop(
                              DeliveryAttemptInput(
                                reason: selectedReason,
                                remarks: remarks,
                                lockAndQueue: lockAndQueue,
                                scheduledDateIso:
                                    lockAndQueue ? scheduledIso : null,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.warning,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadii.md),
                            ),
                          ),
                          child: Text(
                            lockAndQueue
                                ? 'Lock & Queue'
                                : 'Log Attempt #$nextAttempt',
                            style: AppTypography.label.copyWith(
                              fontSize: 16.5,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
