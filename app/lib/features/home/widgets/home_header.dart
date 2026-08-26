import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:readytech/core/theme/app_spacing.dart';
import 'package:readytech/core/theme/app_theme.dart';
import 'package:readytech/data/models/profile.dart';
import 'package:readytech/features/auth/bloc/auth_bloc.dart';
import 'package:readytech/features/auth/bloc/auth_event.dart';

/// Greeting plus account menu, shared by all three role landings.
class HomeHeader extends StatelessWidget {
  const HomeHeader({required this.profile, super.key, this.subtitle});

  final Profile profile;

  /// Overrides the default role line - used by the technician dashboard to
  /// show availability instead.
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome back, ${profile.firstName}',
                style: theme.textTheme.titleLarge,
                overflow: TextOverflow.ellipsis,
              ),
              VGap.xxs,
              Text(
                subtitle ?? profile.role.label,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        HGap.md,
        _AccountMenu(profile: profile),
      ],
    );
  }
}

class _AccountMenu extends StatelessWidget {
  const _AccountMenu({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_AccountAction>(
      tooltip: 'Account',
      position: PopupMenuPosition.under,
      onSelected: (action) {
        switch (action) {
          case _AccountAction.signOut:
            context.read<AuthBloc>().add(const AuthSignOutRequested());
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.fullName,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(profile.email, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: _AccountAction.signOut,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.logout_rounded, size: 20),
            title: Text('Sign out'),
          ),
        ),
      ],
      child: _Avatar(profile: profile),
    );
  }
}

enum _AccountAction { signOut }

class _Avatar extends StatelessWidget {
  const _Avatar({required this.profile});

  final Profile profile;

  static const _size = 44.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final avatarUrl = profile.avatarUrl;

    return Container(
      height: _size,
      width: _size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        shape: BoxShape.circle,
        border: Border.all(color: context.semanticColors.hairline),
      ),
      child: avatarUrl == null || avatarUrl.isEmpty
          ? _Initials(profile: profile)
          : CachedNetworkImage(
              imageUrl: avatarUrl,
              fit: BoxFit.cover,
              // Falls back to initials rather than a broken-image glyph, which
              // would read as an error the user cannot act on.
              errorWidget: (_, _, _) => _Initials(profile: profile),
              placeholder: (_, _) => _Initials(profile: profile),
            ),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Text(
        profile.initials,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(color: scheme.onPrimaryContainer),
      ),
    );
  }
}
