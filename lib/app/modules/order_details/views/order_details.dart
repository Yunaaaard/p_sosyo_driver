import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:p_sosyo_driver/app/core/themes/theme_colors.dart';
import 'package:p_sosyo_driver/app/core/utils/app_logger.dart';
import 'package:p_sosyo_driver/app/core/utils/paqner_qr_codec.dart';
import 'package:p_sosyo_driver/app/core/utils/peso_formatter.dart';
import 'package:p_sosyo_driver/app/data/models/order_item.dart';
import 'package:p_sosyo_driver/app/modules/home/controller/home_controller.dart';
import 'package:p_sosyo_driver/app/modules/order_details/controller/order_details_controller.dart';
import 'package:p_sosyo_driver/app/routes/app_routes.dart';
import 'package:p_sosyo_driver/app/widgets/custom_appBar.dart';
import 'package:p_sosyo_driver/app/widgets/custom_button.dart';
import 'package:p_sosyo_driver/app/widgets/delivery_attempt_dialog.dart';
import 'package:p_sosyo_driver/app/widgets/status_badge.dart';
import 'package:p_sosyo_driver/app/widgets/store_image_widget.dart';

class OrderDetailsPage extends GetView<OrderDetailsController> {
  const OrderDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: const CustomAppBar(
        title: 'Order Details',
        showBackButton: true,
      ),
      body: Obx(() {
        return CustomScrollView(
          slivers: [
            // ── Rounded Stop Manifest Summary Card ──────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              sliver: SliverToBoxAdapter(
                child: _buildMainDetailsCard(context),
              ),
            ),

            // ── Section Header: Ordered Items ───────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              sliver: SliverToBoxAdapter(
                child: SectionHeader(
                  title: 'Ordered Items',
                  count: controller.items.length,
                  trailingText: controller.items.isNotEmpty
                      ? '${controller.totalSku} ${controller.totalSku == 1 ? 'line item' : 'line items'}'
                      : null,
                ),
              ),
            ),

            // ── Rounded Item Cards / Loading / Empty ────────────────
            if (controller.isLoading.value)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Loading order items...',
                        style: AppTypography.body.copyWith(
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (controller.items.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyStateView(
                  icon: Icons.inventory_2_outlined,
                  title: 'No Items Found',
                  subtitle:
                      'Items for this order have not been loaded or synced yet.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.xxl,
                ),
                sliver: SliverList.separated(
                  itemCount: controller.items.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm + 2),
                  itemBuilder: (context, index) =>
                      _buildItemCard(controller.items[index], index + 1),
                ),
              ),
          ],
        );
      }),
    );
  }

  /// Rounded padded stop manifest card with store profile, metrics containers,
  /// and secondary QR generation action.
  Widget _buildMainDetailsCard(BuildContext context) {
    final order = controller.order;
    final statusStr = controller.orderStatus.value.trim();
    final statusLower = statusStr.toLowerCase();
    final isDelivered = statusLower == 'delivered';
    final isCancelled =
        statusLower == 'cancelled' || statusLower == 'canceled';
    final refNo = order?.id ?? order?.transactionId ?? controller.orderId;

    return SurfaceCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      borderRadius: AppRadii.xl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              StatusPill(
                label: isDelivered
                    ? 'Delivered'
                    : isCancelled
                        ? 'Cancelled'
                        : 'Out for Delivery',
                isPositive: isDelivered,
                isDanger: isCancelled,
                icon: isDelivered
                    ? Icons.check_circle_outline_rounded
                    : isCancelled
                        ? Icons.cancel_outlined
                        : null,
              ),
              if (refNo.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.canvas,
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.receipt_long_outlined,
                        size: 13,
                        color: AppColors.inkMuted,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Ref #$refNo',
                        style: AppTypography.monoRef.copyWith(
                          fontSize: 15,
                          color: AppColors.inkPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StoreImageWidget(
                imageUrl: controller.storePhoto,
                custCode: controller.custCode,
                width: 58,
                height: 58,
                borderRadius: BorderRadius.circular(AppRadii.md),
                enablePreview: true,
                fallback: _buildDefaultStoreImage(),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      controller.storeName,
                      style: AppTypography.heading.copyWith(fontSize: 22),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: AppColors.inkMuted,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            controller.address.isNotEmpty
                                ? controller.address
                                : 'No address specified',
                            style: AppTypography.body.copyWith(
                              fontSize: 17.5,
                              color: AppColors.inkSecondary,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (order != null) ...[
                      const SizedBox(height: 8),
                      Material(
                        color: AppColors.primaryTint,
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                        child: InkWell(
                          onTap: controller.openStoreNavigation,
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              borderRadius:
                                  BorderRadius.circular(AppRadii.pill),
                              border: Border.all(
                                color: AppColors.primaryBorder,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.directions_rounded,
                                  size: 13,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    order.formattedDistanceAway.isNotEmpty
                                        ? '${order.formattedDistanceAway}  ·  Open Google Maps'
                                        : 'Open Google Maps Directions',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.monoRef.copyWith(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Rounded Dual Stat Wells
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.canvas,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TOTAL SKUS',
                        style: AppTypography.eyebrow.copyWith(fontSize: 12.5),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${controller.totalSku} ${controller.totalSku == 1 ? 'Item' : 'Items'}',
                        style: AppTypography.metric.copyWith(fontSize: 21),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm + 2),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryTint,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    border: Border.all(color: AppColors.primaryBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AMOUNT DUE',
                        style: AppTypography.eyebrow.copyWith(
                          fontSize: 12.5,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text.rich(
                          PesoFormatter.buildPesoTextSpan(
                            amount: controller.formattedTotalAmount,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _buildCustomerContactBox(context),
          if (!isDelivered && !isCancelled) ...[
            const SizedBox(height: AppSpacing.md),
            if (controller.isLocked.value) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.warningTint,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  border: Border.all(color: AppColors.warningBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.lock_clock_outlined,
                          size: 18,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            controller.scheduledDeliveryDate.value.isNotEmpty
                                ? 'Locked · Queued for ${HomeController.formatDateLabel(controller.scheduledDeliveryDate.value)}'
                                : 'Locked · Queued for Redelivery',
                            style: AppTypography.label.copyWith(
                              fontSize: 15.5,
                              color: AppColors.warning,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final tomorrow =
                                  DateTime.now().add(const Duration(days: 1));
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: DateTime.tryParse(controller
                                        .scheduledDeliveryDate.value) ??
                                    tomorrow,
                                firstDate: tomorrow,
                                lastDate: DateTime.now()
                                    .add(const Duration(days: 60)),
                              );
                              if (picked != null) {
                                final iso =
                                    '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                                await controller.rescheduleOrder(iso);
                              }
                            },
                            icon: const Icon(Icons.calendar_today_outlined,
                                size: 16),
                            label: const Text('Change Date'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              backgroundColor: AppColors.surface,
                              side: const BorderSide(
                                  color: AppColors.primaryBorder),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: controller.unlockOrder,
                            icon: const Icon(Icons.lock_open_rounded, size: 16),
                            label: const Text('Unlock Order'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.warning,
                              foregroundColor: Colors.white,
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ] else ...[
              CustomButton(
                label: 'Generate QR for Payment',
                icon: Icons.qr_code_2_rounded,
                height: 48,
                onPressed: () => _showPaymentReceiptDialog(context),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final input = await showDeliveryAttemptDialog(
                      context,
                      storeName: controller.storeName,
                      orderId: refNo,
                      currentAttemptCount: controller.attemptCount.value,
                    );
                    if (input != null) {
                      await controller.recordAttempt(
                        reason: input.reason,
                        remarks: input.remarks,
                        lockAndQueue: input.lockAndQueue,
                        scheduledDateIso: input.scheduledDateIso,
                      );
                    }
                  },
                  icon: const Icon(Icons.assignment_late_outlined, size: 18),
                  label: Text(
                    'Log Delivery Attempt (#${controller.attemptCount.value + 1})',
                    style: AppTypography.label.copyWith(
                      fontSize: 16.5,
                      color: AppColors.warning,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.warning,
                    backgroundColor: AppColors.warningTint,
                    side: const BorderSide(color: AppColors.warningBorder),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.md),
                    ),
                  ),
                ),
              ),
            ],
          ],
          if (controller.attempts.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _buildAttemptsHistoryBox(),
          ],
        ],
      ),
    );
  }

  Widget _buildCustomerContactBox(BuildContext context) {
    final phone = controller.customerPhone.value.trim();
    final remarks = controller.orderRemarks.trim();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.phone_outlined,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  phone.isNotEmpty ? phone : 'No customer phone number',
                  style: AppTypography.body.copyWith(
                    fontSize: 16.5,
                    fontWeight:
                        phone.isNotEmpty ? FontWeight.w600 : FontWeight.w400,
                    color: phone.isNotEmpty
                        ? AppColors.inkPrimary
                        : AppColors.inkMuted,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => _showEditPhoneDialog(context, phone),
                icon: Icon(
                  phone.isNotEmpty ? Icons.edit_outlined : Icons.add_rounded,
                  size: 15,
                  color: AppColors.primary,
                ),
                label: Text(
                  phone.isNotEmpty ? 'Edit' : 'Add Phone',
                  style: AppTypography.caption.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 6),
              Material(
                color: AppColors.primaryTint,
                borderRadius: BorderRadius.circular(AppRadii.sm),
                child: InkWell(
                  onTap: controller.isSendingSms.value
                      ? null
                      : controller.sendOutForDeliverySms,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                      border: Border.all(color: AppColors.primaryBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.sms_outlined,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          controller.isSendingSms.value
                              ? 'Sending...'
                              : 'Notify SMS',
                          style: AppTypography.caption.copyWith(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (remarks.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.notes_rounded,
                    size: 15,
                    color: AppColors.inkMuted,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Remarks: $remarks',
                    style: AppTypography.caption.copyWith(
                      fontSize: 14.5,
                      color: AppColors.inkSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showEditPhoneDialog(
    BuildContext context,
    String initialPhone,
  ) async {
    final textController = TextEditingController(text: initialPhone);
    String? errorText;

    final saved = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.lg),
              ),
              title: Text(
                'Customer Phone Number',
                style: AppTypography.title.copyWith(fontSize: 19),
              ),
              content: TextField(
                controller: textController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: 'e.g. 09171234567',
                  errorText: errorText,
                  filled: true,
                  fillColor: AppColors.canvas,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(null),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final value = textController.text.trim();
                    if (value.isEmpty ||
                        value.replaceAll(RegExp(r'[^0-9]'), '').length < 10) {
                      setState(() {
                        errorText = 'Enter a valid mobile number';
                      });
                      return;
                    }
                    Navigator.of(dialogContext).pop(value);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved != null) {
      await controller.saveCustomerPhone(saved);
    }
  }

  Widget _buildAttemptsHistoryBox() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warningTint.withOpacity(0.55),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.warningBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.history_rounded,
                size: 16,
                color: AppColors.warning,
              ),
              const SizedBox(width: 6),
              Text(
                'DELIVERY ATTEMPTS (${controller.attempts.length})',
                style: AppTypography.eyebrow.copyWith(
                  fontSize: 12.5,
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...controller.attempts.map((attempt) {
            final baseDetails = attempt.remarks.isNotEmpty
                ? '${attempt.reason} — ${attempt.remarks}'
                : attempt.reason;
            final details = attempt.rescheduledDate != null &&
                    attempt.rescheduledDate!.isNotEmpty
                ? '$baseDetails (Queued: ${HomeController.formatDateLabel(attempt.rescheduledDate!)})'
                : baseDetails;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                      border: Border.all(color: AppColors.warningBorder),
                    ),
                    child: Text(
                      '#${attempt.attemptNumber}',
                      style: AppTypography.monoRef.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      details,
                      style: AppTypography.caption.copyWith(
                        fontSize: 14,
                        color: AppColors.inkPrimary,
                      ),
                    ),
                  ),
                  if (attempt.smsSent)
                    const Icon(
                      Icons.sms_outlined,
                      size: 14,
                      color: AppColors.success,
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDefaultStoreImage() {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Image.asset(
          'assets/images/shop_thumbnail.png',
          width: 58,
          height: 58,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => const Icon(
            Icons.storefront_outlined,
            color: AppColors.primary,
            size: 26,
          ),
        ),
      ),
    );
  }

  /// Receipt-shaped Payment QR Dialog encoding the RavaMate Paqner Trade Terms v1 payload.
  Future<void> _showPaymentReceiptDialog(BuildContext context) async {
    final receiptAmount =
        controller.formattedTotalAmount.replaceAll('₱', '').trim();
    final refNo =
        controller.order?.id ?? controller.order?.transactionId ?? 'R92611051';
    final qrPayload = await controller.buildPaqnerPayPayload();
    final plainJson = jsonEncode(qrPayload);
    final paymentPayload = PaqnerQrCodec.encode(qrPayload);

    logImportant(
      'Paqner Pay QR JSON (${plainJson.length} chars): $plainJson',
      tag: 'QR',
    );
    logImportant(
      'Paqner Pay QR Base64(GZIP) (${paymentPayload.length} chars): $paymentPayload',
      tag: 'QR',
    );

    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl,
          vertical: AppSpacing.xl,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: SingleChildScrollView(
            child: CustomPaint(
              painter: const _ReceiptShadowPainter(),
              child: ClipPath(
                clipper: const _ReceiptPaperClipper(),
                child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Dark Plum Receipt Stub Header (Zero outer white border)
                  Container(
                    color: AppColors.surfaceDark,
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      AppSpacing.xl + 4,
                      AppSpacing.md,
                      AppSpacing.lg,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceDarkElevated,
                                borderRadius:
                                    BorderRadius.circular(AppRadii.sm),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.qr_code_2_rounded,
                                    color: AppColors.mint,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'PAYMENT QR',
                                    style: AppTypography.eyebrow.copyWith(
                                      fontSize: 13.5,
                                      color: AppColors.mint,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => Get.back(),
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          controller.storeName,
                          style: AppTypography.title.copyWith(
                            color: Colors.white,
                            fontSize: 21,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Ref #$refNo',
                          style: AppTypography.monoRef.copyWith(
                            fontSize: 15,
                            color: Colors.white.withOpacity(0.75),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Crisp White Paper Receipt Body
                  Container(
                    color: AppColors.surface,
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      AppSpacing.xl,
                      AppSpacing.xl,
                      AppSpacing.xxl,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _showMaximizedQrDialog(
                              context,
                              paymentPayload: paymentPayload,
                              refNo: refNo,
                              receiptAmount: receiptAmount,
                            ),
                            borderRadius: BorderRadius.circular(AppRadii.md),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                QrImageView(
                                  data: paymentPayload,
                                  version: QrVersions.auto,
                                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                                  size: 196.0,
                                  backgroundColor: Colors.white,
                                  errorStateBuilder: (cxt, err) {
                                    return const Center(
                                      child: Text(
                                        'QR Generation Error',
                                        textAlign: TextAlign.center,
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryTint,
                                    borderRadius:
                                        BorderRadius.circular(AppRadii.pill),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.open_in_full_rounded,
                                        size: 12,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        'Tap QR to maximize',
                                        style: AppTypography.caption.copyWith(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // Printed dashed receipt tear rule
                        const _ReceiptDashedRule(),
                        const SizedBox(height: AppSpacing.lg),

                        Text(
                          'AMOUNT TO COLLECT',
                          style: AppTypography.eyebrow.copyWith(fontSize: 13.5),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text.rich(
                            PesoFormatter.buildPesoTextSpan(
                              amount: receiptAmount,
                              fontSize: 38,
                              fontWeight: FontWeight.w700,
                              color: AppColors.inkPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),

                        const _ReceiptDashedRule(),
                        const SizedBox(height: AppSpacing.md),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'CHANNEL',
                              style: AppTypography.eyebrow.copyWith(
                                fontSize: 12.5,
                              ),
                            ),
                            Text(
                              'PAQNER TRADE TERMS',
                              style: AppTypography.monoRef.copyWith(
                                fontSize: 14.5,
                                color: AppColors.inkPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),

                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.canvas,
                            borderRadius: BorderRadius.circular(AppRadii.sm),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                size: 14,
                                color: AppColors.inkMuted,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Present this QR to the customer to scan and pay',
                                  textAlign: TextAlign.center,
                                  style: AppTypography.caption.copyWith(
                                    fontSize: 15.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        CustomButton(
                          label: 'Scan Customer Receipt',
                          icon: Icons.qr_code_scanner_rounded,
                          height: 48,
                          onPressed: () {
                            Get.back();
                            Get.toNamed(
                              AppRoutes.receiptDetails,
                              arguments: {
                                'order': controller.order,
                                'expectedReferenceId':
                                    controller.generatedReferenceId,
                                'expectedAmount': controller.totalAmount,
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        ),
      ),
      barrierDismissible: true,
    );
  }

  /// Full-screen maximized QR view for easy scanning of dense Paqner payloads.
  void _showMaximizedQrDialog(
    BuildContext context, {
    required String paymentPayload,
    required String refNo,
    required String receiptAmount,
  }) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final qrBoxSize = (screenWidth - 48).clamp(240.0, 360.0);

    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.lg,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 400),
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadii.xl),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.28),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                controller.storeName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style:
                                    AppTypography.title.copyWith(fontSize: 19),
                              ),
                              Text(
                                'Ref #$refNo',
                                style: AppTypography.monoRef.copyWith(
                                  fontSize: 14,
                                  color: AppColors.inkMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Get.back(),
                          icon: const Icon(
                            Icons.close_fullscreen_rounded,
                            color: AppColors.inkPrimary,
                            size: 22,
                          ),
                          tooltip: 'Minimize QR',
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    InteractiveViewer(
                      minScale: 1.0,
                      maxScale: 2.5,
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppRadii.md),
                        ),
                        child: QrImageView(
                          data: paymentPayload,
                          version: QrVersions.auto,
                          errorCorrectionLevel: QrErrorCorrectLevel.M,
                          size: qrBoxSize,
                          backgroundColor: Colors.white,
                          errorStateBuilder: (cxt, err) {
                            return const Center(
                              child: Text(
                                'QR Generation Error',
                                textAlign: TextAlign.center,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text.rich(
                        PesoFormatter.buildPesoTextSpan(
                          amount: receiptAmount,
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pinch to zoom · Tap close to return to receipt',
                      textAlign: TextAlign.center,
                      style: AppTypography.caption.copyWith(
                        fontSize: 14.5,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      barrierColor: AppColors.surfaceDark.withOpacity(0.88),
    );
  }

  /// Rounded, padded item card for each ordered SKU.
  Widget _buildItemCard(OrderItem item, int lineNumber) {
    return SurfaceCard(
      padding: const EdgeInsets.all(AppSpacing.md + 2),
      borderRadius: AppRadii.lg,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.primaryTint,
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            alignment: Alignment.center,
            child: Text(
              lineNumber.toString().padLeft(2, '0'),
              style: AppTypography.monoRef.copyWith(
                fontSize: 14.5,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: AppTypography.label.copyWith(fontSize: 18.5),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.canvas,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.displayQty,
                        style: AppTypography.monoRef.copyWith(
                          fontSize: 14.5,
                          color: AppColors.inkPrimary,
                        ),
                      ),
                    ),
                    Text(
                      '×',
                      style: AppTypography.caption.copyWith(fontSize: 15),
                    ),
                    Text.rich(
                      TextSpan(
                        children: [
                          PesoFormatter.buildPesoTextSpan(
                            amount: item.formattedPrice,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.inkSecondary,
                          ),
                          TextSpan(
                            text: ' / ${item.uom.isNotEmpty ? item.uom : 'PC'}',
                            style:
                                AppTypography.caption.copyWith(fontSize: 14.5),
                          ),
                        ],
                      ),
                    ),
                    if (item.stockCode.isNotEmpty)
                      Text(
                        '#${item.stockCode}',
                        style: AppTypography.monoRef.copyWith(
                          fontSize: 14,
                          color: AppColors.inkMuted,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text.rich(
            PesoFormatter.buildPesoTextSpan(
              amount: item.formattedTotalAmount,
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: AppColors.inkPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

Path _buildReceiptPath(Size size) {
  const double toothHeight = 7.0;
  final int toothCount = (size.width / 15.0).round().clamp(14, 28);
  final double toothWidth = size.width / toothCount;

  final path = Path()..moveTo(0, toothHeight);

  // Top serrated paper edge
  for (int i = 0; i < toothCount; i++) {
    final double xMid = (i + 0.5) * toothWidth;
    final double xEnd = (i + 1) * toothWidth;
    path.lineTo(xMid, 0);
    path.lineTo(xEnd, toothHeight);
  }

  // Right edge down to bottom teeth
  path.lineTo(size.width, size.height - toothHeight);

  // Bottom serrated paper edge (right to left)
  for (int i = toothCount - 1; i >= 0; i--) {
    final double xMid = (i + 0.5) * toothWidth;
    final double xStart = i * toothWidth;
    path.lineTo(xMid, size.height);
    path.lineTo(xStart, size.height - toothHeight);
  }

  path.close();
  return path;
}

class _ReceiptPaperClipper extends CustomClipper<Path> {
  const _ReceiptPaperClipper();

  @override
  Path getClip(Size size) => _buildReceiptPath(size);

  @override
  bool shouldReclip(covariant _ReceiptPaperClipper oldClipper) => false;
}

class _ReceiptShadowPainter extends CustomPainter {
  const _ReceiptShadowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildReceiptPath(size);
    canvas.drawShadow(path, Colors.black.withOpacity(0.32), 18.0, false);
  }

  @override
  bool shouldRepaint(covariant _ReceiptShadowPainter oldDelegate) => false;
}

class _ReceiptDashedRule extends StatelessWidget {
  const _ReceiptDashedRule();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const dashWidth = 6.0;
        const dashSpace = 5.0;
        final count = (constraints.maxWidth / (dashWidth + dashSpace))
            .floor()
            .clamp(4, 60);
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            count,
            (_) => const SizedBox(
              width: dashWidth,
              height: 1.2,
              child: DecoratedBox(
                decoration: BoxDecoration(color: AppColors.borderStrong),
              ),
            ),
          ),
        );
      },
    );
  }
}
