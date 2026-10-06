import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../pages/profile_tab.dart';
import '../providers/providers.dart';
import 'streak_info_dialogs.dart';

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
              onTap: () => showStreakInfoDialog(context, streakDays),
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
                    const FaIcon(
                      FontAwesomeIcons.shieldHalved,
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
                  border:
                      Border.all(color: const Color(0xFFE2DBFD), width: 1.5),
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
