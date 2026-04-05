// lib/features/students/presentation/students_screen.dart
// Student list with filters, search, bulk actions, shimmer loading
// Dev: rahulpr2000 | RAHUL PR | Marrty LLC

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../data/student_repository.dart';
import '../domain/student_models.dart';
import 'add_student_sheet.dart';
import 'student_detail_screen.dart';

// ── Providers ────────────────────────────────────────
final _filterBatch    = StateProvider<String?>((ref) => null);
final _filterSemester = StateProvider<String?>((ref) => null);
final _filterStatus   = StateProvider<String>((ref) => 'active');
final _searchQuery    = StateProvider<String>((ref) => '');

final studentsListProvider = FutureProvider.autoDispose<List<Student>>((ref) {
  final batch = ref.watch(_filterBatch);
  final sem   = ref.watch(_filterSemester);
  final status= ref.watch(_filterStatus);
  final query = ref.watch(_searchQuery);
  return StudentRepository().list(
    batchYear: batch,
    semester: sem,
    status: status.isEmpty ? null : status,
    search: query.isEmpty ? null : query,
  );
});

class StudentsScreen extends ConsumerStatefulWidget {
  const StudentsScreen({super.key});
  @override ConsumerState<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends ConsumerState<StudentsScreen> {
  final _searchCtrl = TextEditingController();
  final Set<String> _selected = {};
  bool _selectMode = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_selected.contains(id)) _selected.remove(id);
      else _selected.add(id);
      _selectMode = _selected.isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(studentsListProvider);
    final batch    = ref.watch(_filterBatch);
    final semester = ref.watch(_filterSemester);
    final status   = ref.watch(_filterStatus);

    return Scaffold(
      appBar: AppBar(
        title: _selectMode
            ? Text('${_selected.length} selected')
            : const Text('Students'),
        actions: _selectMode
            ? [
                IconButton(icon: const Icon(Icons.arrow_upward), tooltip: 'Promote',
                  onPressed: () => _bulkAction('promote')),
                IconButton(icon: const Icon(Icons.arrow_downward), tooltip: 'Demote',
                  onPressed: () => _bulkAction('demote')),
                IconButton(icon: const Icon(Icons.school), tooltip: 'Mark Passout',
                  onPressed: () => _bulkAction('passout')),
                IconButton(icon: const Icon(Icons.close),
                  onPressed: () => setState(() { _selected.clear(); _selectMode = false; })),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => _showSearch(),
                ),
              ],
      ),
      body: Column(
        children: [
          // ── Filters ──────────────────────────────────
          _FiltersRow(
            batch: batch,
            semester: semester,
            status: status,
            onBatch:    (v) => ref.read(_filterBatch.notifier).state = v,
            onSemester: (v) => ref.read(_filterSemester.notifier).state = v,
            onStatus:   (v) => ref.read(_filterStatus.notifier).state = v,
          ),

          // ── Students list ─────────────────────────────
          Expanded(
            child: studentsAsync.when(
              loading: () => _ShimmerList(),
              error:   (e, _) => Center(child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.wifi_off, size: 48, color: AppColors.textSecLight),
                  const SizedBox(height: 8),
                  Text('$e'),
                  TextButton(
                    onPressed: () => ref.invalidate(studentsListProvider),
                    child: const Text('Retry'),
                  ),
                ],
              )),
              data: (students) {
                if (students.isEmpty) {
                  return const Center(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.people_outline, size: 64, color: AppColors.textSecLight),
                      SizedBox(height: 12),
                      Text('No students found'),
                    ]),
                  );
                }
                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async => ref.invalidate(studentsListProvider),
                  child: ListView.builder(
                    itemCount: students.length,
                    itemBuilder: (ctx, i) {
                      final s = students[i];
                      final isSelected = _selected.contains(s.studentId);
                      return _StudentTile(
                        student: s,
                        isSelected: isSelected,
                        selectMode: _selectMode,
                        onTap: () {
                          if (_selectMode) {
                            _toggleSelect(s.studentId);
                          } else {
                            Navigator.push(ctx, MaterialPageRoute(
                              builder: (_) => StudentDetailScreen(student: s),
                            ));
                          }
                        },
                        onLongPress: () => _toggleSelect(s.studentId),
                      ).animate().fadeIn(delay: (i * 30).ms);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () async {
          final created = await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            builder: (_) => const AddStudentSheet(),
          );
          if (created == true) ref.invalidate(studentsListProvider);
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showSearch() {
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Search Students'),
      content: TextField(
        controller: _searchCtrl,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Name, Roll No, PNR...'),
        onChanged: (v) => ref.read(_searchQuery.notifier).state = v,
      ),
      actions: [
        TextButton(onPressed: () {
          _searchCtrl.clear();
          ref.read(_searchQuery.notifier).state = '';
          Navigator.pop(context);
        }, child: const Text('Clear')),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
      ],
    ));
  }

  void _bulkAction(String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$action for ${_selected.length} students — coming soon')),
    );
  }
}

// ── Student tile ─────────────────────────────────────
class _StudentTile extends StatelessWidget {
  final Student   student;
  final bool      isSelected;
  final bool      selectMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _StudentTile({
    required this.student,
    required this.isSelected,
    required this.selectMode,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: ListTile(
        onTap: onTap,
        onLongPress: onLongPress,
        leading: CircleAvatar(
          backgroundColor: isSelected
              ? AppColors.primary
              : AppColors.primary.withValues(alpha: 0.15),
          child: isSelected
              ? const Icon(Icons.check, color: Colors.white, size: 18)
              : Text(student.name[0],
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
        ),
        title: Row(children: [
          Expanded(child: Text(student.name,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
          if (student.streak > 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.streak.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('🔥${student.streak}',
                style: const TextStyle(fontSize: 11, color: AppColors.streak, fontWeight: FontWeight.w700)),
            ),
        ]),
        subtitle: Text('${student.rollNo} · ${student.batchYear} · ${student.semester}',
            style: const TextStyle(fontSize: 12)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(
            student.faceEnrolled ? Icons.face : Icons.face_retouching_off,
            color: student.faceEnrolled ? AppColors.primary : AppColors.textSecLight,
            size: 18,
          ),
          const SizedBox(width: 6),
          CircleAvatar(
            radius: 4,
            backgroundColor: student.status == 'active' ? AppColors.present : AppColors.textSecLight,
          ),
        ]),
      ),
    );
  }
}

// ── Filters row ──────────────────────────────────────
class _FiltersRow extends StatelessWidget {
  final String? batch;
  final String? semester;
  final String  status;
  final ValueChanged<String?> onBatch;
  final ValueChanged<String?> onSemester;
  final ValueChanged<String>  onStatus;

  const _FiltersRow({
    required this.batch,
    required this.semester,
    required this.status,
    required this.onBatch,
    required this.onSemester,
    required this.onStatus,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          _DropChip(
            label: batch ?? 'Batch',
            items: AppConstants.batchYears,
            value: batch,
            onSelected: onBatch,
          ),
          const SizedBox(width: 8),
          _DropChip(
            label: semester ?? 'Semester',
            items: AppConstants.semesters,
            value: semester,
            onSelected: onSemester,
          ),
          const SizedBox(width: 8),
          for (final s in ['active', 'inactive', 'passout'])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(s[0].toUpperCase() + s.substring(1)),
                selected: status == s,
                onSelected: (_) => onStatus(s),
                selectedColor: AppColors.surfaceVarLight,
                checkmarkColor: AppColors.primary,
              ),
            ),
        ],
      ),
    );
  }
}

class _DropChip extends StatelessWidget {
  final String label;
  final List<String> items;
  final String? value;
  final ValueChanged<String?> onSelected;
  const _DropChip({required this.label, required this.items, required this.value, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String>(
      value: value,
      hint: Text(label, style: const TextStyle(fontSize: 13)),
      underline: const SizedBox.shrink(),
      items: [
        DropdownMenuItem(value: null, child: Text('All $label')),
        ...items.map((i) => DropdownMenuItem(value: i, child: Text(i))),
      ],
      onChanged: onSelected,
      isDense: true,
    );
  }
}

// ── Shimmer list ─────────────────────────────────────
class _ShimmerList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 8,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          child: const ListTile(
            leading: CircleAvatar(),
            title: SizedBox(height: 12, width: 120, child: ColoredBox(color: Colors.white)),
            subtitle: SizedBox(height: 10, width: 80, child: ColoredBox(color: Colors.white)),
          ),
        ),
      ),
    );
  }
}
