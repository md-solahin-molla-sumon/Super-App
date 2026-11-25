
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class SocialConnectPage extends StatefulWidget {
  const SocialConnectPage({super.key});

  @override
  State<SocialConnectPage> createState() => _SocialConnectPageState();
}

class _SocialConnectPageState extends State<SocialConnectPage> {
  final Map<String, String> _accounts = {};
  bool _loading = true;

  static const String _storageKey = 'nexaura_social_accounts';

  final List<_SocialPlatform> _platforms = [
    _SocialPlatform(
      name: 'Facebook',
      subtitle: 'Connect your Facebook profile',
      icon: Icons.facebook_rounded,
      color: const Color(0xFF1877F2),
      hint: 'Facebook username or profile link',
    ),
    _SocialPlatform(
      name: 'Instagram',
      subtitle: 'Connect your Instagram profile',
      icon: Icons.camera_alt_rounded,
      color: const Color(0xFFE1306C),
      hint: 'Instagram username',
    ),
    _SocialPlatform(
      name: 'X (Twitter)',
      subtitle: 'Connect your X profile',
      icon: Icons.alternate_email_rounded,
      color: Colors.black,
      hint: 'X username',
    ),
    _SocialPlatform(
      name: 'TikTok',
      subtitle: 'Connect your TikTok profile',
      icon: Icons.music_note_rounded,
      color: Colors.black,
      hint: 'TikTok username',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  // LOAD ACCOUNTS

  Future<void> _loadAccounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_storageKey);

      if (saved != null && saved.isNotEmpty) {
        Map<String, String> decodedAccounts = {};

        // New JSON format
        try {
          final decoded = jsonDecode(saved);

          if (decoded is Map) {
            decodedAccounts = decoded.map(
              (key, value) => MapEntry(
                key.toString(),
                value.toString(),
              ),
            );
          }
        } catch (_) {
          // Migration from the previous query-string format
          decodedAccounts = Uri(query: saved).queryParameters;
        }

        if (mounted) {
          setState(() {
            _accounts
              ..clear()
              ..addAll(decodedAccounts);
          });
        }
      }
    } catch (_) {
      // Ignore loading errors.
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  // SAVE ACCOUNTS

  Future<void> _saveAccounts() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _storageKey,
      jsonEncode(_accounts),
    );
  }

  // ADD / EDIT ACCOUNT

  Future<void> _addAccount(_SocialPlatform platform) async {
    final controller = TextEditingController(
      text: _accounts[platform.name] ?? '',
    );

    final username = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          _accounts.containsKey(platform.name)
              ? 'Edit ${platform.name} account'
              : 'Add ${platform.name} account',
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Username or profile link',
            hintText: platform.hint,
            prefixIcon: Icon(
              platform.icon,
              color: platform.color,
            ),
            border: const OutlineInputBorder(),
          ),
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.done,
          onSubmitted: (value) {
            Navigator.pop(dialogContext, value);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              controller.text,
            ),
            child: const Text('Save Account'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (username == null || username.trim().isEmpty) return;

    setState(() {
      _accounts[platform.name] = username.trim();
    });

    await _saveAccounts();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${platform.name} account saved'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // REMOVE ACCOUNT

  Future<void> _removeAccount(_SocialPlatform platform) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove Account?'),
        content: Text(
          'Do you want to remove ${platform.name} from Social Connect?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _accounts.remove(platform.name);
    });

    await _saveAccounts();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${platform.name} account removed'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // PROFILE URL

  String _getProfileUrl(
    _SocialPlatform platform,
    String username,
  ) {
    final value = username.trim();

    if (value.startsWith('https://') ||
        value.startsWith('http://')) {
      return value;
    }

    final cleanUsername = value.replaceAll('@', '');

    switch (platform.name) {
      case 'Facebook':
        return 'https://www.facebook.com/$cleanUsername';

      case 'Instagram':
        return 'https://www.instagram.com/$cleanUsername/';

      case 'X (Twitter)':
        return 'https://x.com/$cleanUsername';

      case 'TikTok':
        return 'https://www.tiktok.com/@$cleanUsername';

      default:
        return value;
    }
  }

  // OPEN APP

  Future<void> _openSocialApp(
    _SocialPlatform platform,
    String username,
  ) async {
    final profileUrl = _getProfileUrl(platform, username);
    final cleanUsername = username.trim().replaceAll('@', '');

    Uri appUri;

    switch (platform.name) {
      case 'Facebook':
        appUri = Uri.parse(
          'fb://facewebmodal/f?href=${Uri.encodeComponent(profileUrl)}',
        );
        break;

      case 'Instagram':
        appUri = Uri.parse(
          'instagram://user?username=$cleanUsername',
        );
        break;

      case 'X (Twitter)':
        appUri = Uri.parse(
          'twitter://user?screen_name=$cleanUsername',
        );
        break;

      case 'TikTok':
        appUri = Uri.parse(profileUrl);
        break;

      default:
        appUri = Uri.parse(profileUrl);
    }

    try {
      final opened = await launchUrl(
        appUri,
        mode: LaunchMode.externalApplication,
      );

      if (opened) return;
    } catch (_) {}

    // If app is unavailable, open profile in browser.
    await _browseSocialProfile(platform, username);
  }

  // BROWSE PROFILE

  Future<void> _browseSocialProfile(
    _SocialPlatform platform,
    String username,
  ) async {
    final uri = Uri.parse(
      _getProfileUrl(platform, username),
    );

    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open this social profile.'),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open this social profile.'),
        ),
      );
    }
  }

  // COPY PROFILE LINK

  Future<void> _copyProfileLink(
    _SocialPlatform platform,
    String username,
  ) async {
    final url = _getProfileUrl(platform, username);

    await Clipboard.setData(
      ClipboardData(text: url),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${platform.name} profile link copied'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // UI

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final connectedCount = _accounts.length;

    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF6514E8),
                  Color(0xFF3700A8),
                  Color(0xFF210078),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.hub_rounded,
                  color: Colors.white,
                  size: 38,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Social Connect',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Manage your social profiles from one place.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),

                // ACCOUNT COUNTER

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.link_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$connectedCount / ${_platforms.length} profiles added',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          Text(
            'Your Social Accounts',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Add your main social media profile.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(
                alpha: 0.65,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // PLATFORM LIST

          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount =
                  constraints.maxWidth >= 900
                      ? 3
                      : constraints.maxWidth >= 600
                            ? 2
                            : 1;

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _platforms.length,
                gridDelegate:
                    SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 14,
                  mainAxisExtent: 280,
                ),
                itemBuilder: (context, index) {
                  final platform = _platforms[index];
                  final username = _accounts[platform.name];
                  final isAdded = username != null;

                  return _SocialCard(
                    platform: platform,
                    username: username,
                    isAdded: isAdded,
                    onAdd: () => _addAccount(platform),
                    onRemove: () => _removeAccount(platform),
                    onOpenApp: isAdded
                        ? () => _openSocialApp(platform, username)
                        : null,
                    onBrowse: isAdded
                        ? () => _browseSocialProfile(platform, username)
                        : null,
                    onCopy: isAdded
                        ? () => _copyProfileLink(platform, username)
                        : null,
                  );
                },
              );
            },
          ),

          const SizedBox(height: 28),

          // SECURITY NOTICE

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(
                  alpha: 0.15,
                ),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.security_rounded,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Account Privacy',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Profile links are saved locally on this device. '
                        'NEXAURA does not store your social passwords.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // LOCAL STORAGE NOTICE

          Row(
            children: [
              Icon(
                Icons.phone_android_rounded,
                size: 16,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Saved on this device',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(
                      alpha: 0.55,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// PLATFORM MODEL

class _SocialPlatform {
  final String name;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String hint;

  const _SocialPlatform({
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.hint,
  });
}

// SOCIAL ACCOUNT CARD

class _SocialCard extends StatelessWidget {
  final _SocialPlatform platform;
  final String? username;
  final bool isAdded;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final VoidCallback? onOpenApp;
  final VoidCallback? onBrowse;
  final VoidCallback? onCopy;

  const _SocialCard({
    required this.platform,
    required this.username,
    required this.isAdded,
    required this.onAdd,
    required this.onRemove,
    required this.onOpenApp,
    required this.onBrowse,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isAdded
              ? Colors.green.withValues(alpha: 0.45)
              : theme.colorScheme.outline.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ICON + STATUS

          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: platform.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  platform.icon,
                  color: platform.color,
                  size: 26,
                ),
              ),
              const Spacer(),
              if (isAdded)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 13,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Added',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Icon(
                  Icons.add_link_rounded,
                  color: theme.colorScheme.onSurface.withValues(
                    alpha: 0.35,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 14),

          // NAME

          Text(
            platform.name,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 5),

          // USERNAME

          if (isAdded)
            Text(
              username!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            Text(
              platform.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(
                  alpha: 0.6,
                ),
              ),
            ),

          const Spacer(),

          // BUTTONS

          if (!isAdded)
            SizedBox(
              width: double.infinity,
              height: 40,
              child: OutlinedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Account'),
              ),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: FilledButton.icon(
                      onPressed: onOpenApp,
                      icon: const Icon(
                        Icons.open_in_new_rounded,
                        size: 16,
                      ),
                      label: const Text('Open App'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: OutlinedButton.icon(
                      onPressed: onBrowse,
                      icon: const Icon(
                        Icons.language_rounded,
                        size: 16,
                      ),
                      label: const Text('Browse'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: onAdd,
                    child: const Text('Edit'),
                  ),
                ),
                IconButton(
                  onPressed: onCopy,
                  tooltip: 'Copy profile link',
                  icon: const Icon(Icons.copy_rounded),
                ),
                IconButton(
                  onPressed: onRemove,
                  tooltip: 'Remove account',
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
