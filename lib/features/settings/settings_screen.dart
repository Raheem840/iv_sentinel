import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/bed_config.dart';
import '../../core/theme/app_colors.dart';
import 'bed_config_notifier.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditBedSheet(context, ref, null),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Beds section ───────────────────────────────────────────
          Text('Monitored Beds', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),

          if (settings.beds.isEmpty)
            _EmptyBedsCard()
          else
            ...settings.beds.map(
              (bed) => _BedListTile(
                bed: bed,
                onEdit: () => _showAddEditBedSheet(context, ref, bed),
                onDelete: () => notifier.removeBed(bed.id),
              ),
            ),

          const SizedBox(height: 32),

          // ── Global settings section ─────────────────────────────────
          Text('Monitoring', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          _SettingsCard(
            children: [
              _LabeledRow(
                label: 'Poll interval',
                sublabel: '${settings.pollIntervalSeconds}s',
                child: Slider(
                  value: settings.pollIntervalSeconds.toDouble(),
                  min: 1,
                  max: 60,
                  divisions: 59,
                  label: '${settings.pollIntervalSeconds}s',
                  onChanged: (v) => notifier.setPollInterval(v.round()),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          Text('Alerts', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          _SettingsCard(
            children: [
              _SwitchRow(
                label: 'Vibration',
                sublabel: 'Vibrate on LOW and CRITICAL transitions',
                value: settings.vibrationEnabled,
                onChanged: notifier.setVibration,
              ),
              Divider(height: 1, color: theme.dividerColor),
              _SwitchRow(
                label: 'Notifications',
                sublabel: 'Show alert when bed goes CRITICAL',
                value: settings.notificationsEnabled,
                onChanged: notifier.setNotifications,
              ),
            ],
          ),

          const SizedBox(height: 16),
          Text('Display', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          _SettingsCard(
            children: [
              _SwitchRow(
                label: 'Dark mode',
                sublabel: 'Easier on eyes during night shift',
                value: settings.darkMode,
                onChanged: notifier.setDarkMode,
              ),
            ],
          ),
          const SizedBox(height: 80), // space above FAB
        ],
      ),
    );
  }

  void _showAddEditBedSheet(BuildContext context, WidgetRef ref, BedConfig? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddEditBedSheet(existing: existing, ref: ref),
    );
  }
}

// ── Empty state ─────────────────────────────────────────────────────────────

class _EmptyBedsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderDark.withAlpha(80)),
      ),
      child: Column(
        children: [
          Icon(Icons.bed_outlined, size: 48, color: kTextSecondaryDark),
          const SizedBox(height: 16),
          Text(
            'No beds added yet',
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the + button to add your first bed and start monitoring.',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Bed list tile ────────────────────────────────────────────────────────────

class _BedListTile extends StatelessWidget {
  final BedConfig bed;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _BedListTile({
    required this.bed,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dismissible(
      key: Key(bed.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: kStatusRed.withAlpha(30),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: kStatusRed),
      ),
      onDismissed: (_) => onDelete(),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            backgroundColor: kStatusGreen.withAlpha(30),
            child: const Icon(Icons.bed, color: kStatusGreen, size: 20),
          ),
          title: Text(bed.name, style: theme.textTheme.titleMedium),
          subtitle: Text(
            'Channel ${bed.channelId} · Low ${bed.lowThreshold.toInt()}% · Crit ${bed.critThreshold.toInt()}%',
            style: theme.textTheme.bodySmall,
          ),
          trailing: IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: onEdit,
          ),
        ),
      ),
    );
  }
}

// ── Add / Edit bottom sheet ──────────────────────────────────────────────────

class _AddEditBedSheet extends StatefulWidget {
  final BedConfig? existing;
  final WidgetRef ref;

  const _AddEditBedSheet({this.existing, required this.ref});

  @override
  State<_AddEditBedSheet> createState() => _AddEditBedSheetState();
}

class _AddEditBedSheetState extends State<_AddEditBedSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _channelCtrl;
  late final TextEditingController _keyCtrl;
  late double _lowThreshold;
  late double _critThreshold;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _channelCtrl = TextEditingController(text: e?.channelId ?? '');
    _keyCtrl = TextEditingController(text: e?.apiKey ?? '');
    _lowThreshold = e?.lowThreshold ?? 30.0;
    _critThreshold = e?.critThreshold ?? 15.0;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _channelCtrl.dispose();
    _keyCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final notifier = widget.ref.read(appSettingsProvider.notifier);
    final bed = BedConfig(
      id: widget.existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameCtrl.text.trim(),
      channelId: _channelCtrl.text.trim(),
      apiKey: _keyCtrl.text.trim(),
      lowThreshold: _lowThreshold,
      critThreshold: _critThreshold,
    );
    if (widget.existing == null) {
      notifier.addBed(bed);
    } else {
      notifier.updateBed(bed);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: kBorderDark,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.existing == null ? 'Add Bed' : 'Edit Bed',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Bed name / number'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _channelCtrl,
              decoration: const InputDecoration(labelText: 'ThingSpeak Channel ID'),
              keyboardType: TextInputType.number,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _keyCtrl,
              decoration: const InputDecoration(labelText: 'Read API Key'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 20),
            Text('LOW threshold: ${_lowThreshold.toInt()}%', style: theme.textTheme.bodyMedium),
            Slider(
              value: _lowThreshold,
              min: 5,
              max: 50,
              divisions: 9,
              label: '${_lowThreshold.toInt()}%',
              onChanged: (v) => setState(() => _lowThreshold = v),
            ),
            Text('CRITICAL threshold: ${_critThreshold.toInt()}%', style: theme.textTheme.bodyMedium),
            Slider(
              value: _critThreshold,
              min: 5,
              max: 30,
              divisions: 5,
              label: '${_critThreshold.toInt()}%',
              onChanged: (v) => setState(() => _critThreshold = v),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  backgroundColor: kStatusGreen,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  widget.existing == null ? 'Add Bed' : 'Save Changes',
                  style: theme.textTheme.titleMedium?.copyWith(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Reusable layout helpers ──────────────────────────────────────────────────

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(children: children),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String label;
  final String sublabel;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.label,
    required this.sublabel,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodyMedium),
                Text(sublabel, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _LabeledRow extends StatelessWidget {
  final String label;
  final String sublabel;
  final Widget child;

  const _LabeledRow({
    required this.label,
    required this.sublabel,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Text(sublabel, style: theme.textTheme.bodySmall),
          child,
        ],
      ),
    );
  }
}
