import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/services/local_data_service.dart';
import '../../../core/utils/currency_format.dart';
import '../../expense/models/expense_model.dart';
import '../../expense/models/recurring_expense_model.dart';
import '../../expense/services/recurring_expense_service.dart';
import '../../auth/services/auth_service.dart';
import '../../expense/services/expense_service.dart';
import '../../income/models/income_model.dart';
import '../../income/services/income_service.dart';

// ─── Unified transaction for display ─────────────────────────────────────────

class _Transaction {
  final String id;
  final String title;
  final double amount;
  final DateTime date;
  final bool isIncome;
  final int typeOrCategory;
  final bool isRecurring;

  _Transaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.isIncome,
    required this.typeOrCategory,
    this.isRecurring = false,
  });
}

// ─── Entry Screen ─────────────────────────────────────────────────────────────

class EntryScreen extends StatefulWidget {
  const EntryScreen({super.key});

  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen>
    with TickerProviderStateMixin {
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDay;

  List<Income> _incomes = [];
  List<Expense> _expenses = [];
  List<RecurringExpense> _recurring = [];
  double _monthlyIncome = 0.0;
  int _salaryDay = 1;
  bool _isLoading = true;

  late AnimationController _bgController;

  // ── Category / type meta ────────────────────────────────────────────────────
  final Map<int, String> _categoryNames = {
    1: 'Yemek', 2: 'Ulaşım', 3: 'Kira', 4: 'Alışveriş',
    5: 'Eğlence', 6: 'Faturalar', 7: 'Eğitim', 8: 'Diğer',
  };
  final Map<int, Color> _categoryColors = {
    1: const Color(0xFFFF9F43), 2: const Color(0xFF54A0FF),
    3: const Color(0xFF00E5A0), 4: const Color(0xFFFF6B9D),
    5: const Color(0xFFA29BFE), 6: const Color(0xFFFFB085),
    7: const Color(0xFF85C9FF), 8: const Color(0xFFB2BEC3),
  };
  final Map<int, IconData> _categoryIcons = {
    1: Icons.restaurant_outlined, 2: Icons.directions_bus_outlined,
    3: Icons.home_outlined, 4: Icons.shopping_bag_outlined,
    5: Icons.movie_outlined, 6: Icons.receipt_outlined,
    7: Icons.school_outlined, 8: Icons.more_horiz,
  };
  final Map<int, String> _incomeTypes = {
    1: 'Maaş', 2: 'Freelance', 3: 'Burs', 4: 'Aile Desteği', 5: 'Diğer',
  };
  final Map<int, IconData> _typeIcons = {
    1: Icons.work_outline, 2: Icons.laptop_outlined,
    3: Icons.school_outlined, 4: Icons.favorite_outline, 5: Icons.more_horiz,
  };

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
    _loadData();
  }

  @override
  void dispose() {
    _bgController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Sync salary/profile from backend
      await AuthService.getProfile();

      final results = await Future.wait([
        IncomeService.getIncomes(),
        ExpenseService.getExpenses(),
        RecurringExpenseService.getRecurringExpenses(),
        LocalDataService.getSalary(),
        LocalDataService.getSalaryDay(),
      ]);
      setState(() {
        _incomes = results[0] as List<Income>;
        _expenses = results[1] as List<Expense>;
        _recurring = results[2] as List<RecurringExpense>;
        _monthlyIncome = results[3] as double;
        _salaryDay = results[4] as int;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  // ── Calendar helpers ────────────────────────────────────────────────────────

  int get _daysInMonth =>
      DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;

  int get _firstWeekday =>
      DateTime(_focusedMonth.year, _focusedMonth.month, 1).weekday; // 1=Mon

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _hasIncome(int day) {
    if (_monthlyIncome > 0 && day == _salaryDay) return true;
    final d = DateTime(_focusedMonth.year, _focusedMonth.month, day);
    return _incomes.any((i) => _isSameDay(i.receivedDate, d));
  }

  bool _hasExpense(int day) {
    final d = DateTime(_focusedMonth.year, _focusedMonth.month, day);
    return _expenses.any((e) => _isSameDay(e.spentAt, d));
  }

  int _scheduledDayInMonth(int dayOfMonth, DateTime month) {
    final maxDay = DateTime(month.year, month.month + 1, 0).day;
    if (dayOfMonth < 1) return 1;
    if (dayOfMonth > maxDay) return maxDay;
    return dayOfMonth;
  }

  bool _hasRecurring(int day) {
    final month = _focusedMonth;
    return _recurring.any((r) =>
        r.isActive && _scheduledDayInMonth(r.dayOfMonth, month) == day);
  }

  List<_Transaction> _transactionsForDay(DateTime day) {
    final result = <_Transaction>[];
    
    // Sabit aylık gelir kontrolü
    if (_monthlyIncome > 0 && day.day == _salaryDay) {
      result.add(_Transaction(
        id: 'salary_fixed',
        title: 'Aylık Gelir (Sabit)',
        amount: _monthlyIncome,
        date: day,
        isIncome: true,
        typeOrCategory: 1, // 1 = Maaş/Gelir
      ));
    }

    for (final i in _incomes) {
      if (_isSameDay(i.receivedDate, day)) {
        result.add(_Transaction(
          id: i.id, title: i.title, amount: i.amount,
          date: i.receivedDate, isIncome: true, typeOrCategory: i.type,
        ));
      }
    }
    for (final e in _expenses) {
      if (_isSameDay(e.spentAt, day)) {
        result.add(_Transaction(
          id: e.id, title: e.title, amount: e.amount,
          date: e.spentAt, isIncome: false, typeOrCategory: e.category,
        ));
      }
    }
    // Recurring expenses for this day of month
    for (final r in _recurring) {
      final scheduledDay = _scheduledDayInMonth(r.dayOfMonth, day);
      if (r.isActive && scheduledDay == day.day) {
        result.add(_Transaction(
          id: 'rec_${r.id}', title: r.title, amount: r.amount,
          date: day, isIncome: false, typeOrCategory: r.category,
          isRecurring: true,
        ));
      }
    }
    result.sort((a, b) => b.date.compareTo(a.date));
    return result;
  }

  // ─── Add transaction sheet ──────────────────────────────────────────────────

  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  bool _addingIncome = false;
  int _addCategory = 6; // Faturalar default for expense
  int _addIncomeType = 1;
  bool _addRecurring = false;
  int _addRecurringDay = 1;

  void _showAddSheet(DateTime forDay) {
    _titleCtrl.clear();
    _amountCtrl.clear();
    _addingIncome = false;
    _addCategory = 6;
    _addIncomeType = 1;
    _addRecurring = false;
    _addRecurringDay = forDay.day;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                DateFormat('d MMMM yyyy', 'tr').format(forDay),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5), fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Kayıt Ekle',
                style: GoogleFonts.inter(
                  color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              // Income / Expense toggle
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    _tabChip('Harcama', !_addingIncome, AppColors.sky,
                        () => setModalState(() => _addingIncome = false)),
                    _tabChip('Gelir', _addingIncome, AppColors.peach,
                        () => setModalState(() => _addingIncome = true)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _inputField(_titleCtrl, 'Başlık', Icons.title),
              const SizedBox(height: 12),
              _inputField(_amountCtrl, 'Tutar (₺)', Icons.payments_outlined,
                  keyboard: TextInputType.number),
              const SizedBox(height: 12),
              if (!_addingIncome) ...[
                DropdownButtonFormField<int>(
                  value: _addCategory,
                  dropdownColor: const Color(0xFF1A2333),
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDeco('Kategori', Icons.category_outlined,
                      AppColors.sky),
                  items: _categoryNames.entries
                      .map((e) => DropdownMenuItem(
                            value: e.key,
                            child: Row(children: [
                              Icon(_categoryIcons[e.key], size: 15,
                                  color: _categoryColors[e.key]),
                              const SizedBox(width: 8),
                              Text(e.value),
                            ]),
                          ))
                      .toList(),
                  onChanged: (v) => setModalState(() {
                    _addCategory = v!;
                  }),
                ),
                // Tekrarlayan toggle — tüm kategorilerde gözüksün
                const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: _addRecurring
                          ? const Color(0xFFA29BFE).withOpacity(0.12)
                          : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _addRecurring
                            ? const Color(0xFFA29BFE).withOpacity(0.4)
                            : Colors.white.withOpacity(0.1),
                      ),
                    ),
                    child: Column(children: [
                      Row(children: [
                        const Icon(Icons.repeat_rounded,
                            color: Color(0xFFA29BFE), size: 17),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Tekrarlayan Gider mi?',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13)),
                              Text('Her ay takvime eklensin',
                                  style: TextStyle(
                                      color: Colors.white.withOpacity(0.4),
                                      fontSize: 10)),
                            ],
                          ),
                        ),
                        Switch(
                          value: _addRecurring,
                          onChanged: (v) =>
                              setModalState(() => _addRecurring = v),
                          activeColor: const Color(0xFFA29BFE),
                          inactiveTrackColor: Colors.white.withOpacity(0.1),
                        ),
                      ]),
                      if (_addRecurring) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(children: [
                            const Icon(Icons.event_repeat_rounded,
                                color: Color(0xFFA29BFE), size: 15),
                            const SizedBox(width: 8),
                            Text(
                              'Her ayın $_addRecurringDay. günü',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () => setModalState(() {
                                if (_addRecurringDay > 1) _addRecurringDay--;
                              }),
                              child: Container(
                                width: 28, height: 28,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                child: const Icon(Icons.remove,
                                    color: Colors.white54, size: 14),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Text('$_addRecurringDay',
                                  style: const TextStyle(
                                      color: Color(0xFFA29BFE),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15)),
                            ),
                            GestureDetector(
                              onTap: () => setModalState(() {
                                if (_addRecurringDay < 31) _addRecurringDay++;
                              }),
                              child: Container(
                                width: 28, height: 28,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                child: const Icon(Icons.add,
                                    color: Colors.white54, size: 14),
                              ),
                            ),
                          ]),
                        ),
                      ],
                    ]),
                  ),
              ] else ...[
                DropdownButtonFormField<int>(
                  value: _addIncomeType,
                  dropdownColor: const Color(0xFF1A2333),
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDeco('Gelir Türü', Icons.category_outlined,
                      AppColors.peach),
                  items: _incomeTypes.entries
                      .map((e) => DropdownMenuItem(
                            value: e.key,
                            child: Row(children: [
                              Icon(_typeIcons[e.key], size: 15,
                                  color: AppColors.peach),
                              const SizedBox(width: 8),
                              Text(e.value),
                            ]),
                          ))
                      .toList(),
                  onChanged: (v) => setModalState(() => _addIncomeType = v!),
                ),
              ],
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => _submitTransaction(forDay),
                child: Container(
                  width: double.infinity,
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: _addingIncome
                        ? AppColors.peachSkyGradient
                        : LinearGradient(colors: [
                            AppColors.sky,
                            AppColors.sky.withOpacity(0.7)
                          ]),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: (_addingIncome ? AppColors.peach : AppColors.sky)
                            .withOpacity(0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      _addingIncome ? 'Gelir Ekle' : 'Harcama Ekle',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitTransaction(DateTime forDay) async {
    if (_titleCtrl.text.isEmpty || _amountCtrl.text.isEmpty) return;
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) return;
    try {
      if (_addingIncome) {
        await IncomeService.addIncome(CreateIncomeRequest(
          title: _titleCtrl.text.trim(),
          amount: amount,
          receivedDate: forDay,
          type: _addIncomeType,
        ));
      } else {
        await ExpenseService.addExpense(CreateExpenseRequest(
          title: _titleCtrl.text.trim(),
          amount: amount,
          spentAt: forDay,
          category: _addCategory,
        ));
        // Tekrarlayan olarak da kaydet
        if (_addRecurring) {
          await RecurringExpenseService.addRecurringExpense(
            CreateRecurringExpenseRequest(
              title: _titleCtrl.text.trim(),
              amount: amount,
              category: _addCategory,
              dayOfMonth: _addRecurringDay,
            ),
          );
        }
      }
      _addRecurring = false;
      if (mounted) Navigator.pop(context);
      _loadData();
    } catch (_) {}
  }

  Widget _tabChip(String label, bool active, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? color.withOpacity(0.25) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: active
                ? Border.all(color: color.withOpacity(0.5))
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: active ? color : Colors.white38,
                fontWeight: active ? FontWeight.w700 : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _inputField(TextEditingController ctrl, String label, IconData icon,
      {TextInputType? keyboard}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: _inputDeco(label, icon, AppColors.peach),
    );
  }

  InputDecoration _inputDeco(String label, IconData icon, Color accent) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 14),
      prefixIcon: Icon(icon, color: Colors.white38, size: 20),
      filled: true,
      fillColor: Colors.white.withOpacity(0.06),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: accent, width: 1.5)),
    );
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _bgController,
      builder: (ctx, child) {
        final t = _bgController.value;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1 + t * 0.4, -1),
              end: Alignment(1 - t * 0.4, 1),
              colors: [
                Color.lerp(const Color(0xFF0D1117), const Color(0xFF0D1A2E), t)!,
                Color.lerp(const Color(0xFF111827), const Color(0xFF1A1225), t)!,
                Color.lerp(const Color(0xFF0D1117), const Color(0xFF0D1A2E), t)!,
              ],
            ),
          ),
          child: child,
        );
      },
      child: Stack(
        children: [
          Positioned(
            top: -80, right: -60,
            child: AnimatedBuilder(
              animation: _bgController,
              builder: (_, __) => Transform.scale(
                scale: 1 + _bgController.value * 0.2,
                child: Container(
                  width: 260, height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      AppColors.sky.withOpacity(0.1), Colors.transparent,
                    ]),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.sky))
                : RefreshIndicator(
                    onRefresh: _loadData,
                    color: AppColors.peach,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 24),
                          _buildHeader(),
                          const SizedBox(height: 20),
                          _buildCalendar(),
                          const SizedBox(height: 16),
                          _buildDayDetail(),
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
          ),
          // FAB
          Positioned(
            bottom: 90,
            right: 20,
            child: GestureDetector(
              onTap: () => _showAddSheet(_selectedDay ?? DateTime.now()),
              child: Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  gradient: AppColors.peachSkyGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.peach.withOpacity(0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 26),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ShaderMask(
              shaderCallback: (b) => AppColors.peachSkyGradient.createShader(b),
              child: Text(
                'Kayıt & Takvim',
                style: GoogleFonts.inter(
                  color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const Spacer(),
            // Month summary chips
            _summaryChip(
              '+${CurrencyFormatter.format(_monthTotal(true))}',
              AppColors.peach,
            ),
            const SizedBox(width: 6),
            _summaryChip(
              '-${CurrencyFormatter.format(_monthTotal(false))}',
              AppColors.sky,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Tüm gelir ve giderlerinizi takvim üzerinde görün.',
          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
        ),
      ],
    );
  }

  double _monthTotal(bool income) {
    if (income) {
      return _incomes
          .where((i) =>
              i.receivedDate.month == _focusedMonth.month &&
              i.receivedDate.year == _focusedMonth.year)
          .fold(0.0, (s, i) => s + i.amount);
    } else {
      return _expenses
          .where((e) =>
              e.spentAt.month == _focusedMonth.month &&
              e.spentAt.year == _focusedMonth.year)
          .fold(0.0, (s, e) => s + e.amount);
    }
  }

  Widget _summaryChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }

  // ─── Calendar ───────────────────────────────────────────────────────────────

  Widget _buildCalendar() {
    return GlassCard(
      child: Column(
        children: [
          // Month navigation
          Row(
            children: [
              GestureDetector(
                onTap: () => setState(() {
                  _focusedMonth = DateTime(
                      _focusedMonth.year, _focusedMonth.month - 1);
                }),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.chevron_left,
                      color: Colors.white54, size: 20),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    DateFormat('MMMM yyyy', 'tr').format(_focusedMonth),
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() {
                  _focusedMonth = DateTime(
                      _focusedMonth.year, _focusedMonth.month + 1);
                }),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.chevron_right,
                      color: Colors.white54, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Weekday headers
          Row(
            children: ['Pt', 'Sa', 'Ça', 'Pe', 'Cu', 'Ct', 'Pa'].map((d) =>
              Expanded(
                child: Center(
                  child: Text(d,
                    style: TextStyle(
                      color: d == 'Ct' || d == 'Pa'
                          ? AppColors.peach.withOpacity(0.6)
                          : Colors.white.withOpacity(0.35),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ).toList(),
          ),
          const SizedBox(height: 8),
          // Day grid
          _buildDayGrid(),
          const SizedBox(height: 8),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legend(AppColors.peach, 'Gelir'),
              const SizedBox(width: 14),
              _legend(AppColors.sky, 'Harcama'),
              const SizedBox(width: 14),
              _legend(const Color(0xFFA29BFE), 'Tekrarlayan'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(
          color: Colors.white.withOpacity(0.4), fontSize: 10,
        )),
      ],
    );
  }

  Widget _buildDayGrid() {
    final cells = <Widget>[];

    // Empty cells before first day
    for (int i = 1; i < _firstWeekday; i++) {
      cells.add(const SizedBox());
    }

    final today = DateTime.now();
    for (int day = 1; day <= _daysInMonth; day++) {
      final date = DateTime(_focusedMonth.year, _focusedMonth.month, day);
      final isToday = _isSameDay(date, today);
      final isSelected = _selectedDay != null && _isSameDay(date, _selectedDay!);
      final hasInc = _hasIncome(day);
      final hasExp = _hasExpense(day);
      final hasRec = _hasRecurring(day);

      cells.add(GestureDetector(
        onTap: () => setState(() => _selectedDay = date),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.peach.withOpacity(0.25)
                : isToday
                    ? Colors.white.withOpacity(0.08)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isSelected
                ? Border.all(color: AppColors.peach.withOpacity(0.6), width: 1.5)
                : isToday
                    ? Border.all(color: Colors.white.withOpacity(0.2))
                    : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$day',
                style: TextStyle(
                  color: isSelected
                      ? AppColors.peach
                      : isToday
                          ? Colors.white
                          : Colors.white.withOpacity(0.7),
                  fontSize: 13,
                  fontWeight: isToday || isSelected
                      ? FontWeight.w700
                      : FontWeight.normal,
                ),
              ),
              if (hasInc || hasExp || hasRec)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (hasInc) _dot(AppColors.peach),
                      if (hasExp) _dot(AppColors.sky),
                      if (hasRec) _dot(const Color(0xFFA29BFE)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ));
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 0.9,
      children: cells,
    );
  }

  Widget _dot(Color color) => Container(
        width: 5, height: 5,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );

  // ─── Day Detail ─────────────────────────────────────────────────────────────

  Widget _buildDayDetail() {
    final day = _selectedDay;
    if (day == null) return const SizedBox();

    final txns = _transactionsForDay(day);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              DateFormat('d MMMM EEEE', 'tr').format(day),
              style: GoogleFonts.inter(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => _showAddSheet(day),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: AppColors.peachSkyGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text('Ekle', style: const TextStyle(
                      color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700,
                    )),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (txns.isEmpty)
          GlassCard(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Bu gün için kayıt yok.',
                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14),
                ),
              ),
            ),
          )
        else
          ...txns.map((t) => _buildTransactionTile(t)),
      ],
    );
  }

  Widget _buildTransactionTile(_Transaction t) {
    final color = t.isRecurring
        ? const Color(0xFFA29BFE)
        : t.isIncome
            ? AppColors.peach
            : (_categoryColors[t.typeOrCategory] ?? Colors.white54);
    final icon = t.isIncome
        ? (_typeIcons[t.typeOrCategory] ?? Icons.attach_money)
        : (_categoryIcons[t.typeOrCategory] ?? Icons.more_horiz);
    final subtitle = t.isIncome
        ? (_incomeTypes[t.typeOrCategory] ?? 'Gelir')
        : (_categoryNames[t.typeOrCategory] ?? 'Harcama');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(t.title,
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w600,
                              fontSize: 14)),
                      if (t.isRecurring) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFA29BFE).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('Tekrarlayan',
                              style: TextStyle(
                                color: Color(0xFFA29BFE), fontSize: 9,
                                fontWeight: FontWeight.w700,
                              )),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.4), fontSize: 11)),
                ],
              ),
            ),
            Text(
              '${t.isIncome ? '+' : '-'}${CurrencyFormatter.format(t.amount)}',
              style: TextStyle(
                color: color, fontWeight: FontWeight.w700, fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
