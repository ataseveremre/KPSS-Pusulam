import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'data.dart'; // Veri dosyamızı unutmuyoruz
import 'progress_manager.dart';
import 'subscription_manager.dart';
import 'dart:math';
import 'ad_manager.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

void main() async {
  // AdMob ve diğer servislerin düzgün başlaması için şarttır
  WidgetsFlutterBinding.ensureInitialized(); 
  
  // AdMob'u başlatıyoruz
  await AdManager.initialize(); 
  
  runApp(const KPSSApp());
}
class KPSSApp extends StatelessWidget {
  const KPSSApp({super.key});

  @override
  Widget build(BuildContext context) {
    const Color primaryNavy = Color(0xFF0D1B2A);
    const Color backgroundCream = Color(0xFFF7F2E9);

    // Provider'ı burada, MaterialApp'in en tepesine koyuyoruz.
    return ChangeNotifierProvider(
      create: (_) => SubscriptionManager()..initialize(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'KPSS Rehberim',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: primaryNavy,
            primary: primaryNavy,
            background: backgroundCream,
          ),
          scaffoldBackgroundColor: backgroundCream,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: false,
            surfaceTintColor: Colors.transparent,
            foregroundColor: primaryNavy,
          ),
        ),
        // Artık buradaki ChangeNotifierProvider'ı silebilirsin, sadece AppEntryPage kalsın
        home: const AppEntryPage(),
      ),
    );
  }
}

class AppEntryPage extends StatefulWidget {
  const AppEntryPage({super.key});

  @override
  State<AppEntryPage> createState() => _AppEntryPageState();
}

class _AppEntryPageState extends State<AppEntryPage> {
  late Future<String?> _userNameFuture;

  @override
  void initState() {
    super.initState();
    _userNameFuture = ProgressManager.getUserName();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _userNameFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final name = (snapshot.data ?? '').trim();
        if (name.isEmpty) {
          return const WelcomePage();
        }
        return DashboardPage(userName: name);
      },
    );
  }
}

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final TextEditingController _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    await ProgressManager.saveUserName(name);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => DashboardPage(userName: name),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.school_rounded, size: 64, color: theme.colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    'KPSS Rehberim\'e Hoş Geldin',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sana nasıl hitap etmemi istersin?',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _nameController,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _continue(),
                    decoration: InputDecoration(
                      labelText: 'İsmin',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _continue,
                    child: const Text('Başla'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class Lesson {
  final String name;
  final IconData icon;
  final Color color;

  Lesson({
    required this.name,
    required this.icon,
    required this.color,
  });
}

/// Ders adından ProgressManager'daki konu id önekine eşleme
String _topicIdPrefixForLesson(String lessonName) {
  switch (lessonName) {
    case 'Tarih':
      return 'tarih_';
    case 'Coğrafya':
      return 'cografya_';
    case 'Vatandaşlık':
      return 'vatandaslik_';
    default:
      return '';
  }
}

// --- ANA SAYFA ---
class DashboardPage extends StatefulWidget {
  final String userName;

  const DashboardPage({super.key, required this.userName});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  /// Ders adı -> tamamlanan konu sayısı (ProgressManager'dan)
  Map<String, int> _completedCountByLesson = {};
  late final String _motivationMessage;

  List<Lesson> get lessons => [
        Lesson(
          name: 'Tarih',
          icon: PhosphorIconsBold.scroll,
          color: const Color(0xFF1B4D9B),
        ),
        Lesson(
          name: 'Coğrafya',
          icon: PhosphorIconsBold.globeHemisphereWest,
          color: const Color(0xFF2A9D8F),
        ),
        Lesson(
          name: 'Vatandaşlık',
          icon: PhosphorIconsBold.scales,
          color: const Color(0xFFE76F51),
        ),
      ];

  @override
  void initState() {
    super.initState();
    _motivationMessage = _pickMotivationMessage();
    loadProgress();

    if (!context.read<SubscriptionManager>().isPro) {
    AdManager.loadInterstitialAd();
  }
  }

  String _pickMotivationMessage() {
    const messages = [
      'Küçük adımların toplamı büyük başarıyı getirir.',
      'Disiplin, motivasyon bittiğinde de devam etmektir.',
      'Bugün öğrenilen her satır, yarının gücüne dönüşür.',
      'Süreklilik, KPSS yolculuğunun en güclü stratejisidir.',
      'Her tekrar, seni hedef puanına biraz daha yaklastırır.',
      'Bugün çözdüğün her soru, yarınki memuriyet hayatına atılmış bir adımdır.',
      'Pes etmek yok! Hayallerindeki o kadro seni bekliyor.',
      'Zorlanıyorsan gelişiyorsun demektir. Masadan kalkma!',
      'Ertelediğin her gün, hedefine giden yolu uzatır. Şimdi başla!',
      'Atanma sevincini yaşayacağın o anı düşün ve tekrar kaleme sarıl.',
      'Rakiplerin çalışırken sen dinlenemezsin. Başarı, fedakarlık ister.',
      'Bugünün yorgunluğu, yarının gururu olacak.',
      'Fazladan yapacağın bir net, binlerce kişiyi geride bırakmanı sağlar.',
      'KPSS bir maratondur; hızlı koşan değil, pes etmeyen kazanır.',
      'Bahane yok, sadece hedefler var. O sınav geçilecek!',
      'İnanmak başarmanın yarısıdır, diğer yarısı ise o masada döktüğün terdir.',
      'Sınav zor olabilir ama senin azmin ondan daha güçlü.',
      'Kendi hikayenin kahramanı olma vakti geldi. Çalışmaya devam!',
      'Bugün kendine yapacağın en büyük yatırım, o konu testini bitirmektir.',
      'Başarı tesadüf değildir. Emeklerinin karşılığını alacağın o gün çok yakın.',
    ];
    return messages[Random().nextInt(messages.length)];
  }

  /// ProgressManager'dan tamamlanan konu ID'lerini çekip ders bazında sayar; state güncellenir.
  Future<void> loadProgress() async {
    final completedIds = await ProgressManager.getCompletedTopics();
    final Map<String, int> byLesson = {};
    for (final lesson in lessons) {
      final prefix = _topicIdPrefixForLesson(lesson.name);
      byLesson[lesson.name] = completedIds.where((id) => id.startsWith(prefix)).length;
    }
    if (!mounted) return;
    setState(() {
      _completedCountByLesson = byLesson;
    });
  }

  String _formattedToday() {
    final now = DateTime.now();
    const months = [
      'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
    ];
    final day = now.day.toString().padLeft(2, '0');
    final monthName = months[now.month - 1];
    final year = now.year.toString();
    return '$day $monthName $year';
  }

  Widget _buildPaywallBenefit({
    required IconData icon,
    required String text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: const Color(0xFF2E7D32),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showProfileBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF7F2E9),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        final theme = Theme.of(context);
        return Consumer<SubscriptionManager>(
          builder: (context, subscriptionManager, _) {
            final isPro = subscriptionManager.isPro;
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (isPro) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Üyelik Durumu: Pro Sürüm',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Icon(
                            PhosphorIconsFill.trophy,
                            color: const Color(0xFFFFB300),
                            size: 24,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Tüm içeriklerin kilidi açık. Başarılar dileriz!',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.black87,
                          height: 1.35,
                        ),
                      ),
                    ] else ...[
                      Center(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFFD700).withOpacity(0.45),
                                    blurRadius: 26,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFFFFD46A),
                                  width: 1.2,
                                ),
                              ),
                              child: Icon(
                                PhosphorIconsFill.crownSimple,
                                color: const Color(0xFFFFB300),
                                size: 34,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: Text(
                          "KPSS Rehberim Pro'ya Hoş Geldin",
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildPaywallBenefit(
                        icon: PhosphorIconsRegular.checkCircle,
                        text: "20'den Fazla Kilitli Konu Anlatımı",
                      ),
                      _buildPaywallBenefit(
                        icon: PhosphorIconsRegular.checkCircle,
                        text: 'Tamamen Reklamsız Deneyim',
                      ),
                      _buildPaywallBenefit(
                        icon: PhosphorIconsRegular.checkCircle,
                        text: 'Ömür Boyu Tek Seferlik Ödeme',
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7D6),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFFFFDA85),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFE5A6),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                'Kısa Süreliğine Tanıtım Fiyatı',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
  'Sadece ${subscriptionManager.proPrice}',
  style: theme.textTheme.headlineSmall?.copyWith(
    fontWeight: FontWeight.w800,
  ),
),
                            
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const _PaywallCtaButton(),
                    ],  
                      if (kDebugMode) ...[
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () {
                            context.read<SubscriptionManager>().toggleProForTest();
                          },
                          child: Text(isPro ? 'Test: Pro Yapma' : 'Test: Pro Yap'),
                        ),
                      ),
                    ],  //debug modda pro mod açma     
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const Color primaryNavy = Color(0xFF0D1B2A);
    final bool isPro = context.watch<SubscriptionManager>().isPro;

    return Scaffold(
      backgroundColor: isPro ? const Color(0xFFFDF5E6) : null,
      appBar: AppBar(
        title: const Text('KPSS Pusulam', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            onPressed: _showProfileBottomSheet,
            icon: const CircleAvatar(
              radius: 18,
              backgroundColor: Color(0xFF0D1B2A),
              child: Icon(Icons.person, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(theme, primaryNavy, isPro),
              const SizedBox(height: 16),
              Text(
                'Derslerin',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: primaryNavy,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: lessons.length,
                  itemBuilder: (context, index) {
                    final lesson = lessons[index];
                    final total = AppData.getTopicsForLesson(lesson.name).length;
                    final completed = _completedCountByLesson[lesson.name] ?? 0;
                    final percent = total > 0
                        ? (completed / total * 100).toInt().clamp(0, 100)
                        : 0;
                    return _StaggeredListItem(
                      index: index,
                      child: _LessonCard(
                        lesson: lesson,
                        completionPercent: percent,
                        isPro: isPro,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => LessonDetailPage(lesson: lesson),
                            ),
                          ).then((_) => loadProgress());
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await ProgressManager.clearAllProgress();
                    await loadProgress();
                  },
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('İlerlememi Sıfırla'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isPro ? const Color(0xFF8A6A00) : null,
                    backgroundColor:
                        isPro ? const Color(0xFFFFF8DC).withOpacity(0.85) : null,
                    side: BorderSide(
                      color: isPro ? const Color(0xFFD4AF37) : theme.colorScheme.outline,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const BottomBannerAd(),
    );
  }

  Widget _buildHeader(ThemeData theme, Color primaryNavy, bool isPro) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF15273A),
            Color(0xFF1C3247),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: primaryNavy.withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 6)),
        ],
        border: isPro
            ? Border.all(color: const Color(0xFFFFD700).withOpacity(0.85), width: 1)
            : null,
      ),
      child: Stack(
        children: [
          if (isPro) const Positioned.fill(child: _HeaderShimmer()),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Merhaba, ${widget.userName}!',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        if (isPro) ...[
                          Icon(
                            PhosphorIconsFill.crownSimple,
                            size: 16,
                            color: const Color(0xFFFFD700),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD4AF37).withOpacity(0.95),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'PRO',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Text(
                    _formattedToday(),
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _motivationMessage,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white.withOpacity(0.92),
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderShimmer extends StatefulWidget {
  const _HeaderShimmer();

  @override
  State<_HeaderShimmer> createState() => _HeaderShimmerState();
}

class _HeaderShimmerState extends State<_HeaderShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final x = (_controller.value * 2) - 1;
          return Transform.translate(
            offset: Offset(220 * x, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.white.withOpacity(0.0),
                      Colors.white.withOpacity(0.08),
                      Colors.white.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LessonCard extends StatelessWidget {
  final Lesson lesson;
  final int completionPercent;
  final bool isPro;
  final VoidCallback onTap;

  const _LessonCard({
    required this.lesson,
    required this.completionPercent,
    required this.isPro,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final double progressValue = completionPercent.clamp(0, 100) / 100.0;

    final card = Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 1.5,
      color: const Color(0xCCFFFFFF),
      shadowColor: Colors.black.withOpacity(0.08),
      surfaceTintColor: colorScheme.surfaceTint.withOpacity(0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: Colors.white.withOpacity(0.65),
          width: 0.8,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Hero(
                tag: 'lesson_icon_${lesson.name}',
                child: Material(
                  color: Colors.transparent,
                  child: CircleAvatar(
                    radius: 26,
                    backgroundColor: lesson.color.withOpacity(0.15),
                    child: Icon(lesson.icon, color: lesson.color, size: 26),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lesson.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Tamamlanan: %$completionPercent', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[700])),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 48,
                width: 48,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progressValue,
                      strokeWidth: 3,
                      strokeCap: StrokeCap.round,
                      backgroundColor: isPro
                          ? const Color(0xFFD4AF37).withOpacity(0.24)
                          : lesson.color.withOpacity(0.16),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color.alphaBlend(Colors.black.withOpacity(0.06), lesson.color),
                      ),
                    ),
                    Text('%$completionPercent', style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!isPro) return card;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.09),
            blurRadius: 26,
            spreadRadius: 1.2,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: card,
    );
  }
}

class _StaggeredListItem extends StatefulWidget {
  final int index;
  final Widget child;

  const _StaggeredListItem({
    required this.index,
    required this.child,
  });

  @override
  State<_StaggeredListItem> createState() => _StaggeredListItemState();
}

class _StaggeredListItemState extends State<_StaggeredListItem> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 70 * widget.index), () {
      if (!mounted) return;
      setState(() {
        _visible = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      offset: _visible ? Offset.zero : const Offset(0, 0.10),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        opacity: _visible ? 1 : 0,
        child: widget.child,
      ),
    );
  }
}

class _PaywallCtaButton extends StatefulWidget {
  const _PaywallCtaButton();

  @override
  State<_PaywallCtaButton> createState() => _PaywallCtaButtonState();
}

class _PaywallCtaButtonState extends State<_PaywallCtaButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapCancel: () => setState(() => _isPressed = false),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTap: () async {
        // Kullanıcı butona bastığında RevenueCat satın alma penceresi açılır
        bool success = await context.read<SubscriptionManager>().purchaseProVersion();
        
        if (success) {
          if (!mounted) return;
          Navigator.pop(context); // Satın alma başarılıysa BottomSheet'i kapat
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Pro sürüme hoş geldin! Tüm içeriklerin kilidi açıldı.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          if (!mounted) return;
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Satın alma işlemi tamamlanamadı veya iptal edildi.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      },
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1,
        duration: const Duration(milliseconds: 120),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFA500).withOpacity(0.36),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: const Center(
            child: Text(
              'Pro Sürüm Satın Al',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- KONU LİSTESİ SAYFASI ---
class LessonDetailPage extends StatefulWidget {
  final Lesson lesson;

  const LessonDetailPage({super.key, required this.lesson});

  @override
  State<LessonDetailPage> createState() => _LessonDetailPageState();
}

class _LessonDetailPageState extends State<LessonDetailPage> {
  Set<String> _completedTopics = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCompletedTopics();
  }

  // Hafızadan tamamlanan konuları çeken fonksiyon
  Future<void> _loadCompletedTopics() async {
    final completedIds = await ProgressManager.getCompletedTopics();
    if (!mounted) return;
    setState(() {
      _completedTopics = completedIds.toSet();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<TopicContent> currentTopics = AppData.getTopicsForLesson(widget.lesson.name);
    final bool isPro = context.watch<SubscriptionManager>().isPro;

    return Scaffold(
      backgroundColor: isPro ? const Color(0xFFFDF5E6) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: isPro ? const Color(0xFF15273A) : widget.lesson.color,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: isPro
            ? const Border(
                bottom: BorderSide(
                  color: Color(0xFFFFD700),
                  width: 1.5,
                ),
              )
            : null,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Hero(
              tag: 'lesson_icon_${widget.lesson.name}',
              child: Material(
                color: Colors.transparent,
                child: CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.white.withOpacity(0.22),
                  child: Icon(widget.lesson.icon, color: Colors.white, size: 16),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(widget.lesson.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            if (isPro) ...[
              const SizedBox(width: 8),
              const Icon(
                PhosphorIconsFill.crownSimple,
                size: 16,
                color: Color(0xFFFFD700),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37).withOpacity(0.95),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'PRO',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: widget.lesson.color))
          : currentTopics.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.library_books_outlined, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('Bu ders için henüz içerik eklenmedi.', style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: currentTopics.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  physics: const BouncingScrollPhysics(),
                  itemBuilder: (context, index) {
                    final topic = currentTopics[index];
                    final bool isLocked = !isPro && index > 5;
                    
                    // --- MÜHENDİSLİK DOKUNUŞU: Bu konu bitti mi? ---
                    final bool isCompleted = _completedTopics.contains(topic.id);

                    return _StaggeredListItem(
                      index: index,
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 14),
                        elevation: 1.5,
                        color: Colors.white,
                        shadowColor: widget.lesson.color.withOpacity(0.15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                          side: BorderSide(
                            color: isCompleted ? Colors.green.withOpacity(0.4) : widget.lesson.color.withOpacity(0.12), // Biten konunun çerçevesi hafif yeşil olur
                            width: isCompleted ? 1.5 : 1,
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () {
                            if (isLocked) {
                              showModalBottomSheet(
                                context: context,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                                ),
                                builder: (context) {
                                  return Padding(
                                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 36,
                                          height: 4,
                                          decoration: BoxDecoration(
                                            color: Colors.grey[300],
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        const Icon(Icons.workspace_premium, size: 36, color: Colors.amber),
                                        const SizedBox(height: 10),
                                        const Text(
                                          'Pro Üyelik Gerekli',
                                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Bu konuya erişmek için Pro üyeliğe geçmelisin.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(color: Colors.grey[700]),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                              return;
                            }

                            Navigator.push(
                              context,
                              PageRouteBuilder(
                                transitionDuration: const Duration(milliseconds: 400),
                                reverseTransitionDuration: const Duration(milliseconds: 300),
                                pageBuilder: (context, animation, secondaryAnimation) => 
                                    TopicStudyPage(topic: topic, lessonColor: widget.lesson.color),
                                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                  const begin = Offset(0.05, 0.0);
                                  const end = Offset.zero;
                                  const curve = Curves.easeOutCubic;
                                  var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                                  var offsetAnimation = animation.drive(tween);
                                  return FadeTransition(
                                    opacity: animation,
                                    child: SlideTransition(position: offsetAnimation, child: child),
                                  );
                                },
                              ),
                            ).then((_) => _loadCompletedTopics()); // KULLANICI GERİ DÖNDÜĞÜNDE LİSTEYİ GÜNCELLER!
                          },
                          child: Opacity(
                            opacity: isLocked ? 0.65 : 1.0,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              child: Row(
                                children: [
                                  // Sol: Numaralandırma çemberi
                                  Container(
                                    width: 44,
                                    height: 44,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: isCompleted ? Colors.green.withOpacity(0.1) : widget.lesson.color.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: isCompleted 
                                      ? const Icon(Icons.check_rounded, color: Colors.green, size: 24) // Biten konuda numara yerine tik çıksın
                                      : Text(
                                          "${index + 1}",
                                          style: TextStyle(
                                            color: widget.lesson.color,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 16,
                                          ),
                                        ),
                                  ),
                                  const SizedBox(width: 16),
                                  
                                  // Orta: Konu Başlığı
                                  Expanded(
                                    child: Text(
                                      topic.title,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        color: isCompleted ? Colors.green.shade800 : const Color(0xFF1E293B), // Biten konu yazısı yeşilimsi siyah
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  
                                  // Sağ: Tamamlandı Tiki, Kilit veya Ok İşareti
                                  if (isCompleted)
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        const Icon(Icons.check_circle_rounded, size: 20, color: Color(0xFF4CAF50)),
                                        const SizedBox(height: 2),
                                        Text(
                                          "Tamamlandı",
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.green.shade600,
                                          ),
                                        ),
                                      ],
                                    )
                                  else if (isLocked)
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        const Icon(
                                          PhosphorIconsFill.lockKey,
                                          size: 18,
                                          color: Color(0xFFD4AF37),
                                        ),
                                        const SizedBox(height: 4),
                                        const Text(
                                          "Pro'ya Özel",
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFFD4AF37),
                                          ),
                                        ),
                                      ],
                                    )
                                  else
                                    Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 16,
                                      color: widget.lesson.color.withOpacity(0.4),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
      bottomNavigationBar: const BottomBannerAd(), // BANNER REKLAMI KORUNDU
    );
  }
}
// --- DERS ÇALIŞMA VE TEST SAYFASI ---
// --- DERS ÇALIŞMA VE TEST SAYFASI (RENKLENDİRİLMİŞ VERSİYON) ---
class TopicStudyPage extends StatefulWidget {
  final TopicContent topic;
  final Color lessonColor;

  const TopicStudyPage({super.key, required this.topic, required this.lessonColor});

  @override
  State<TopicStudyPage> createState() => _TopicStudyPageState();
}

class _TopicStudyPageState extends State<TopicStudyPage> {
  // Quiz Değişkenleri
  int currentQuestionIndex = 0;
  Map<int, int> userAnswers = {};
  bool isQuizFinished = false;

  // Konu tamamlama durumu
  bool _isTopicCompleted = false;
  bool _isCompletionLoading = true;

  int get score {
    int s = 0;
    for (final entry in userAnswers.entries) {
      final qIndex = entry.key;
      final answerIndex = entry.value;
      if (qIndex >= 0 &&
          qIndex < widget.topic.questions.length &&
          answerIndex == widget.topic.questions[qIndex].correctIndex) {
        s++;
      }
    }
    return s;
  }

  bool get isAnswered => userAnswers.containsKey(currentQuestionIndex);

  int? get selectedOptionIndex => userAnswers[currentQuestionIndex];

  @override
  void initState() {
    super.initState();
    _loadCompletionState();
  }

  Future<void> _loadCompletionState() async {
    final completed = await ProgressManager.isCompleted(widget.topic.id);
    if (!mounted) return;
    setState(() {
      _isTopicCompleted = completed;
      _isCompletionLoading = false;
    });
  }

  Future<void> _markTopicCompleted() async {
    if (_isTopicCompleted) return;
    await ProgressManager.saveTopic(widget.topic.id);
    if (!mounted) return;
    setState(() {
      _isTopicCompleted = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Harika! Bir konuyu daha devirdin.'),
      ),
    );
    if (!context.read<SubscriptionManager>().isPro) {
      AdManager.showInterstitialAd();
    }
  }

  void _answerQuestion(int index) {
    setState(() {
      userAnswers[currentQuestionIndex] = index;
    });
  }

  void _previousQuestion() {
    if (currentQuestionIndex <= 0) return;
    setState(() {
      currentQuestionIndex--;
    });
  }

  void _nextQuestion() {
    if (currentQuestionIndex < widget.topic.questions.length - 1) {
      setState(() {
        currentQuestionIndex++;
      });
    } else {
      setState(() {
        isQuizFinished = true;
      });
      
      // TEST BİTTİĞİNDE REKLAMI GÖSTER (Sadece Pro değilse)
      // Bu kısım tam olarak quiz bittiği anda tetiklenir
      if (!context.read<SubscriptionManager>().isPro) {
        AdManager.showInterstitialAd();
      }
    }
  }

  void _resetQuiz() {
    setState(() {
      currentQuestionIndex = 0;
      userAnswers = {};
      isQuizFinished = false;
    });
  }
// --- SİHİRLİ METİN AYRIŞTIRICI (PARSER) ---
  List<Widget> _buildRichContent(String rawText, ThemeData theme) {
    List<Widget> widgets = [];
    List<String> lines = rawText.split('\n');

    // YENİ: Cümle içindeki **kalın** kelimeleri algılayan küçük motor
    List<TextSpan> parseBoldText(String text, TextStyle baseStyle) {
      List<TextSpan> spans = [];
      List<String> parts = text.split('**');
      for (int i = 0; i < parts.length; i++) {
        if (i % 2 == 0) {
          spans.add(TextSpan(text: parts[i], style: baseStyle)); // Normal yazı
        } else {
          // Çift yıldız (**) arasındaki metni ekstra siyah ve kalın yap
          spans.add(TextSpan(
            text: parts[i],
            style: baseStyle.copyWith(fontWeight: FontWeight.w900, color: Colors.black),
          ));
        }
      }
      return spans;
    }

    for (String line in lines) {
      String trimmedLine = line.trim();

      if (trimmedLine.isEmpty) {
        widgets.add(const SizedBox(height: 12));
      } 
  // 1. KURAL: ANA BAŞLIKLAR (1., 2.)
      else if (RegExp(r'^\d+\.').hasMatch(trimmedLine)) {
        widgets.add(
          Container(
            margin: const EdgeInsets.only(top: 24.0, bottom: 12.0),
            padding: const EdgeInsets.only(left: 14.0, top: 4, bottom: 4),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: widget.lessonColor, width: 4)), // Modern sol çizgi vurgusu
              color: widget.lessonColor.withOpacity(0.05), // Çok hafif zemin rengi
            ),
            child: Text(
              trimmedLine,
              style: TextStyle(
                fontSize: 20, 
                fontWeight: FontWeight.w900,
                color: const Color(0xFF0F172A), // Gece mavisine çalan koyu siyah
                letterSpacing: 0.3,
              ),
            ),
          ),
        );
      }
      // 2. KURAL: ŞIKLAR (A), B))
      else if (RegExp(r'^[A-Z]\)').hasMatch(trimmedLine)) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Text(
              trimmedLine,
              style: TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.bold, // Kalın
                color: Colors.red.shade700,
              ),
            ),
          ),
        );
      }
      // 3. KURAL: ALT BAŞLIKLAR (##)
      else if (trimmedLine.startsWith('##')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.label_important, color: Colors.deepPurple, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: Text(
                      trimmedLine.substring(2).trim(),
                      style: const TextStyle(
                        fontSize: 19, 
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
      // 4. KURAL: YILDIZLI MADDELER (*)
      else if (trimmedLine.startsWith('*')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.star_rounded, color: Colors.redAccent, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  // Burada Text yerine Text.rich kullanarak kalın kelimeleri ekliyoruz
                  child: Text.rich(
                    TextSpan(
                      children: parseBoldText(
                        trimmedLine.substring(1).trim(),
                        const TextStyle(fontSize: 17, height: 1.5, color: Colors.black87),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
      // 5. KURAL: KISA MADDELER (-)
      else if (trimmedLine.startsWith('-')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.arrow_right, color: widget.lessonColor, size: 24),
                const SizedBox(width: 4),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: Text.rich(
                      TextSpan(
                        children: parseBoldText(
                          trimmedLine.substring(1).trim(),
                          const TextStyle(fontSize: 17, color: Colors.black87),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
      // 6. KURAL: PİN (📌)
      else if (trimmedLine.startsWith('📌')) {
        widgets.add(
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('📌', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: parseBoldText(
                        trimmedLine.replaceFirst('📌', '').trim(),
                        TextStyle(fontSize: 16, color: Colors.brown.shade800), // Pin kutusu için kahverengi yazı
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
      // 7. KURAL: GÖRSEL (🖼️)
      else if (trimmedLine.startsWith('🖼️')) {
        String imageFileName = trimmedLine.replaceFirst('🖼️', '').trim();
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/images/$imageFileName',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    padding: const EdgeInsets.all(20),
                    color: Colors.grey[200],
                    child: const Text("Görsel yüklenemedi.", textAlign: TextAlign.center),
                  );
                },
              ),
            ),
          ),
        );
      }

      // 9. KURAL: ÖRNEKLER (Örnek:)
      else if (trimmedLine.startsWith('Örnek:')) {
        widgets.add(
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blueGrey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border(
                left: BorderSide(color: Colors.blue.shade300, width: 5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb_outline, size: 20, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Text(
                      "ÖRNEK",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Colors.blue.shade800,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text.rich(
                  TextSpan(
                    children: parseBoldText(
                      trimmedLine.replaceFirst('Örnek:', '').trim(),
                      const TextStyle(
                        fontSize: 16, 
                        height: 1.5, 
                        color: Colors.black87,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
      // 8. KURAL: NORMAL METİN
      else {
        widgets.add(
          Text.rich(
            TextSpan(
              children: parseBoldText(
                trimmedLine,
                const TextStyle(fontSize: 17, height: 1.6, color: Colors.black87),
              ),
            ),
          ),
        );
      }
    }
    return widgets;
  }

 @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isPro = context.watch<SubscriptionManager>().isPro; // Pro temasını buraya da taşıyalım
    final bgColor = isPro ? const Color(0xFFFDF5E6) : const Color(0xFFF8F9FA);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: bgColor, // Saf beyazdan kurtulduk, daha göz yormayan bir zemin
        appBar: AppBar(
          title: Text(widget.topic.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          backgroundColor: isPro ? const Color(0xFF15273A) : widget.lessonColor, // Pro laciverti
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(25),
              ),
              child: TabBar(
                // İŞTE MODERN HAP (PILL) TASARIMI
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  color: isPro ? const Color(0xFFFFD700) : Colors.white, // Pro'da altın, normalde beyaz hap
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2)),
                  ],
                ),
                labelColor: isPro ? const Color(0xFF15273A) : widget.lessonColor, // Seçili sekme yazısı rengi
                unselectedLabelColor: Colors.white70,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                tabs: const [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [Icon(Icons.menu_book, size: 18), SizedBox(width: 6), Text("Konu")],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [Icon(Icons.quiz, size: 18), SizedBox(width: 6), Text("Hızlı Test")],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        
        // --- İŞTE DEĞİŞEN KISIM BURASI ---
        body: Column(
          children: [
            // TabBarView sayfanın kalan tüm alanını kaplaması için Expanded içine alındı
            Expanded(
              child: TabBarView(
                children: [
                  // --- KONU ANLATIMI EKRANI ---
                  Container(
                    color: bgColor,
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Ana Başlık
                          Text(
                            widget.topic.title,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1E293B), // Siyah yerine koyu slate (Çok daha asil)
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Başlık altı dekoratif çizgi
                          Container(
                            width: 60, 
                            height: 4, 
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [widget.lessonColor, widget.lessonColor.withOpacity(0.3)]), 
                              borderRadius: BorderRadius.circular(4)
                            )
                          ),
                          const SizedBox(height: 32),
                          
                          // İçerik Parser'ı
                          ..._buildRichContent(widget.topic.lectureNote, theme),
                          
                          const SizedBox(height: 40),

                          if (_isCompletionLoading)
                            const Center(child: CircularProgressIndicator())
                          else
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _isTopicCompleted ? null : _markTopicCompleted,
                                icon: Icon(_isTopicCompleted ? Icons.check_circle : Icons.flag),
                                style: FilledButton.styleFrom(
                                  backgroundColor: isPro ? const Color(0xFFFFD700) : widget.lessonColor,
                                  foregroundColor: isPro ? const Color(0xFF15273A) : Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 18),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  elevation: 0,
                                ),
                                label: Text(
                                  _isTopicCompleted ? 'Bu Konuyu Bitirdin ✅' : 'Konuyu Bitirdim',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),

                  // SEKMESİ 2: QUIZ
                  widget.topic.questions.isEmpty
                      ? const Center(child: Text("Bu konu için henüz test eklenmedi."))
                      : Padding(
                          padding: const EdgeInsets.all(20),
                          child: isQuizFinished ? _buildResultScreen() : _buildQuizScreen(),
                        ),
                ],
              ),
            ),
            
            // --- REKLAM VİDEOSU/BANNER'I BURAYA SABİTLENDİ ---
            const BottomBannerAd(),
          ],
        ),
      ),   
    );
  }

  Widget _buildQuizScreen() {
    final question = widget.topic.questions[currentQuestionIndex];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. KISIM: Soru ve şıkları kaydırılabilir alana alıyoruz
        Expanded(
          child: SingleChildScrollView(
            // BouncingScrollPhysics ekleyerek daha yumuşak bir kaydırma hissi verebilirsin
            physics: const BouncingScrollPhysics(), 
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "Soru ${currentQuestionIndex + 1}/${widget.topic.questions.length}",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                  ),
                  child: question.text.trim().startsWith('🖼️')
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.asset(
                                'assets/images/${question.text.replaceFirst('🖼️', '').trim()}',
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    padding: const EdgeInsets.all(20),
                                    color: Colors.grey[200],
                                    child: const Text("Soru görseli yüklenemedi.", textAlign: TextAlign.center),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "Yukarıdaki görsele göre soruyu cevaplayınız.",
                              style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey[600], fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        )
                      : Text(
                          question.text,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                ),
                const SizedBox(height: 20),
                ...List.generate(question.options.length, (index) {
                  Color btnColor = Colors.white;
                  Color textColor = Colors.black87;

                  if (isAnswered) {
                    if (index == question.correctIndex) {
                      btnColor = Colors.green.shade100;
                      textColor = Colors.green.shade900;
                    } else if (index == selectedOptionIndex) {
                      btnColor = Colors.red.shade100;
                      textColor = Colors.red.shade900;
                    }
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: btnColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _answerQuestion(index),
                      child: Text(question.options[index], style: TextStyle(color: textColor, fontSize: 16)),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        
        // 2. KISIM: Önceki + İleri/Bitir
        Padding(
          padding: const EdgeInsets.only(top: 12.0),
          child: Row(
            children: [
              if (currentQuestionIndex > 0)
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: widget.lessonColor,
                    side: BorderSide(color: widget.lessonColor),
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _previousQuestion,
                  child: const Text('Önceki'),
                ),
              if (currentQuestionIndex > 0) const SizedBox(width: 12),
              if (isAnswered)
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.lessonColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _nextQuestion,
                    child: Text(
                      currentQuestionIndex == widget.topic.questions.length - 1
                          ? "Testi Bitir"
                          : "Sonraki Soru",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResultScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.emoji_events, size: 80, color: Colors.amber),
          const SizedBox(height: 24),
          const Text("Test Tamamlandı!", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text("Skorunuz: $score / ${widget.topic.questions.length}", style: const TextStyle(fontSize: 20, color: Colors.grey)),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh, color: Colors.white),
            label: const Text("Tekrar Çöz", style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.lessonColor,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
            onPressed: _resetQuiz,
          ),
        ],
      ),
    );
  }
}
class BottomBannerAd extends StatefulWidget {
  const BottomBannerAd({super.key});

  @override
  State<BottomBannerAd> createState() => _BottomBannerAdState();
}

class _BottomBannerAdState extends State<BottomBannerAd> {
  BannerAd? _bannerAd;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    _bannerAd = BannerAd(
      adUnitId: AdManager.bannerAdUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() {}),
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
          debugPrint('Banner reklam yüklenemedi: $err');
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Kullanıcı Pro ise reklam alanını tamamen gizle
    final isPro = context.watch<SubscriptionManager>().isPro;
    if (isPro || _bannerAd == null) return const SizedBox.shrink();

    return Container(
      alignment: Alignment.center,
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}