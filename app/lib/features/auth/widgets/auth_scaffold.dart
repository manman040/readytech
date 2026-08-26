import 'package:flutter/material.dart';
import 'package:readytech/core/theme/app_spacing.dart';

/// Shared layout for the auth screens.
///
/// Keeps a consistent measure on large screens - a form stretched across a
/// tablet is unpleasant to read and to fill in - and handles the keyboard by
/// scrolling rather than by letting the content overflow.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    required this.title,
    required this.children,
    super.key,
    this.subtitle,
    this.showBackButton = true,
    this.footer,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final bool showBackButton;

  /// Pinned below the scrollable content, for the "already have an account"
  /// style link that should always be reachable.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: showBackButton,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  Gap.page,
                  Gap.sm,
                  Gap.page,
                  Gap.xxl,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(title, style: theme.textTheme.headlineMedium),
                        if (subtitle != null) ...[
                          VGap.sm,
                          Text(subtitle!, style: theme.textTheme.bodyMedium),
                        ],
                        VGap.xxxl,
                        ...children,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (footer != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Gap.page,
                  Gap.sm,
                  Gap.page,
                  Gap.lg,
                ),
                child: footer,
              ),
          ],
        ),
      ),
    );
  }
}

/// An inline error banner for a failure that concerns the whole form rather
/// than one field - a rejected password, a rate limit, a dropped connection.
class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(Gap.md),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: Radii.borderMd,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 18,
              color: scheme.onErrorContainer,
            ),
            HGap.md,
            Expanded(
              child: Text(
                message,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
