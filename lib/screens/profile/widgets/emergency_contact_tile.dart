import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/emergency_contact.dart';

class EmergencyContactTile extends StatelessWidget {
  final EmergencyContact contact;
  final VoidCallback onDelete;
  final VoidCallback onSetPrimary;

  const EmergencyContactTile({
    super.key,
    required this.contact,
    required this.onDelete,
    required this.onSetPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: contact.isPrimary
              ? AppColors.primaryLight
              : Colors.grey.shade200,
          width: 1.5,
        ),
      ),
      color: contact.isPrimary
          ? AppColors.primaryLightest
          : AppColors.cardBg,
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: contact.isPrimary
              ? AppColors.primary
              : AppColors.primaryLightest,
          child: Text(
            contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
            style: TextStyle(
              color: contact.isPrimary ? Colors.white : AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                contact.name,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (contact.isPrimary)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'PRIMARY',
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              contact.phone,
              style: TextStyle(
                  fontSize: 13, color: AppColors.textSecondary),
            ),
            if (contact.relation.isNotEmpty)
              Text(
                contact.relation,
                style: TextStyle(
                    fontSize: 11, color: AppColors.textHint),
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded,
              color: AppColors.textSecondary, size: 20),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          onSelected: (v) {
            if (v == 'primary') onSetPrimary();
            if (v == 'delete') onDelete();
          },
          itemBuilder: (_) => [
            if (!contact.isPrimary)
              PopupMenuItem(
                value: 'primary',
                child: Row(children: [
                  const Icon(Icons.star_rounded,
                      size: 16, color: AppColors.warning),
                  const SizedBox(width: 8),
                  Text('Set as Primary',
                      style: TextStyle(fontSize: 13)),
                ]),
              ),
            PopupMenuItem(
              value: 'delete',
              child: Row(children: [
                const Icon(Icons.delete_rounded,
                    size: 16, color: AppColors.emergency),
                const SizedBox(width: 8),
                Text('Delete',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.emergency)),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
