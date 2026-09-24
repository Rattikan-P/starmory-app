import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../pages/profile_tab.dart';
import '../providers/providers.dart';

/// Interactive Top Right Actions Bar showing Streak Pill, Shield Pill, and Profile Avatar
class TopHeaderActions extends ConsumerWidget {
  final VoidCallback? onProfileTap;

  const TopHeaderActions({
    super.key,
    this.onProfileTap,
  });

  void _openProfile(BuildContext context) {
    if (onProfileTap != null) {
      onProfileTap!();
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const ProfileTab(),
        ),
      );
    }
  }

  int _calculateMultiplier(int streak) {
    if (streak >= 30) return 3;
    if (streak >= 14) return 2;
    if (streak >= 7) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userState = ref.watch(userStateProvider);
    final streakData = ref.watch(streakProvider);

    final user = userState.user;
    final displayName = user?.displayName ?? user?.email ?? 'Guest';
    final avatarLetter =
        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'G';
    final photoUrl = user?.photoUrl;

    final streakDays = streakData?.currentStreak ?? 0;
    final multiplier = _calculateMultiplier(streakDays);
    final shields = streakData?.shieldsAvailable ?? 0;

    return SizedBox(
      height: 42,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Streak [ 🔥 7 (2x) ] (clean, borderless, non-card)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => showStreakInfoDialog(context, streakDays, multiplier),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.local_fire_department_rounded,
                      color: Color(0xFFFF5722),
                      size: 20,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '$streakDays',
                      style: GoogleFonts.lexend(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF221F33),
                      ),
                    ),
                    if (multiplier > 1) ...[
                      const SizedBox(width: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF5722),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${multiplier}x',
                          style: GoogleFonts.lexend(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 1),

          // 2. Shield [ 🛡️ 2 ] (clean, borderless, non-card)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => showShieldInfoDialog(context, shields),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.shield_rounded,
                      size: 18,
                      color: Color(0xFFFF7A51),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '$shields',
                      style: GoogleFonts.lexend(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF221F33),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 4),

        // 3. User Avatar ( 👤 )
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _openProfile(context),
            customBorder: const CircleBorder(),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF4EEFF),
                border: Border.all(color: const Color(0xFFE2DBFD), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C5CFC).withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipOval(
                child: photoUrl != null && photoUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: photoUrl,
                        fit: BoxFit.cover,
                        width: 42,
                        height: 42,
                        placeholder: (context, url) => Center(
                          child: Text(
                            avatarLetter,
                            style: GoogleFonts.lexend(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF7C5CFC),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Center(
                          child: Text(
                            avatarLetter,
                            style: GoogleFonts.lexend(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF7C5CFC),
                            ),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          avatarLetter,
                          style: GoogleFonts.lexend(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF7C5CFC),
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
}

/// Helper function to show Streak Info Dialog
void showStreakInfoDialog(BuildContext context, int streakDays, int multiplier) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF5722).withValues(alpha: 0.15),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFFB088), Color(0xFFFF5722)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF5722).withValues(alpha: 0.3),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.local_fire_department_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '$streakDays Day Streak!',
                style: GoogleFonts.lexend(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF221F33),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                multiplier > 1
                    ? 'You are on a roll with a ${multiplier}x Streak Multiplier!'
                    : 'Practice vocabulary daily to increase your streak & earn rewards.',
                style: GoogleFonts.lexend(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF655D80),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7F2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFFFE6D8),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    _buildInfoItem(
                      icon: Icons.auto_awesome_rounded,
                      iconColor: const Color(0xFFFF5722),
                      bgColor: const Color(0xFFFFECE0),
                      title: 'Daily Habit',
                      description: 'Take photos or review word cards every day',
                    ),
                    const SizedBox(height: 10),
                    _buildInfoItem(
                      icon: Icons.military_tech_rounded,
                      iconColor: const Color(0xFFFF5722),
                      bgColor: const Color(0xFFFFECE0),
                      title: 'Bonus Multiplier',
                      description: 'Reach 7+ days for 2x, and 30+ days for 3x boost',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5722),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Keep Learning!',
                    style: GoogleFonts.lexend(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Helper function to show Shield Info Dialog
void showShieldInfoDialog(BuildContext context, int shields) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C5CFC).withValues(alpha: 0.15),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFFB088), Color(0xFFFF5722)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF5722).withValues(alpha: 0.3),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.shield_rounded,
                  color: Colors.white,
                  size: 38,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Streak Shields ($shields)',
                style: GoogleFonts.lexend(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF221F33),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Don\'t let a missed day break your streak!',
                style: GoogleFonts.lexend(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF655D80),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4EEFF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFE2DBFD),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    _buildInfoItem(
                      icon: Icons.shield_rounded,
                      iconColor: const Color(0xFF7C5CFC),
                      bgColor: const Color(0xFFF4EEFF),
                      title: 'Shield Protection',
                      description:
                          'Each shield protects your streak for 1 missed day',
                    ),
                    const SizedBox(height: 10),
                    _buildInfoItem(
                      icon: Icons.star_rounded,
                      iconColor: const Color(0xFF7C5CFC),
                      bgColor: const Color(0xFFF4EEFF),
                      title: 'Earn Shields',
                      description:
                          'Keep learning for 7 days to earn a new shield',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C5CFC),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Got it!',
                    style: GoogleFonts.lexend(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _buildInfoItem({
  required IconData icon,
  required Color iconColor,
  required Color bgColor,
  required String title,
  required String description,
}) {
  return Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: const Color(0xFFEBE6FC),
        width: 1,
      ),
    ),
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.lexend(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF221F33),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: GoogleFonts.lexend(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF655D80),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
