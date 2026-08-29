import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../routes.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../theme.dart';

class _SlideData {
  final IconData icon;
  final String title;
  final String description;

  const _SlideData({
    required this.icon,
    required this.title,
    required this.description,
  });
}

const _slides = [
  _SlideData(
    icon: Icons.calendar_month_outlined,
    title: 'Plan your day',
    description:
        'Add tasks with reminders and keep your day organised in one place.',
  ),
  _SlideData(
    icon: Icons.favorite_outline,
    title: 'Track your wellbeing',
    description:
        'Log water, sleep, mood and activity in just a few taps.',
  ),
  _SlideData(
    icon: Icons.lightbulb_outline,
    title: 'Get smart suggestions',
    description:
        'LifeSync AI reads your habits, the weather, and the time of day '
        'to suggest what to do next.',
  ),
];

/// 3-slide intro + a request for location/notification permission on the
/// last slide, then hands off to Login.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();

  int _currentPage = 0;
  bool _requestingPermissions = false;

  bool get _isLastPage => _currentPage == _slides.length - 1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToLogin() {
    Navigator.of(context).pushReplacementNamed(AppRoutes.login);
  }

  Future<void> _getStarted() async {
    setState(() => _requestingPermissions = true);

    // Ask for both permissions up front so the rest of the app (weather,
    // task reminders) can just use them later without extra prompts.
    final locationService = context.read<LocationService>();
    final notificationService = context.read<NotificationService>();
    await locationService.requestPermission();
    await notificationService.requestPermission();

    if (!mounted) return;
    setState(() => _requestingPermissions = false);
    _goToLogin();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _requestingPermissions
                    ? null
                    : () => _pageController.jumpToPage(_slides.length - 1),
                child: const Text('Skip'),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  return _SlideView(slide: slide);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _slides.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: index == _currentPage ? 20 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: index == _currentPage
                          ? AppColors.primary
                          : AppColors.primary.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _requestingPermissions
                      ? null
                      : () {
                          if (_isLastPage) {
                            _getStarted();
                          } else {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOut,
                            );
                          }
                        },
                  child: _requestingPermissions
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(_isLastPage ? 'Get Started' : 'Next'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});

  final _SlideData slide;

  @override
  Widget build(BuildContext context) {
    final isLastSlide = slide == _slides.last;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(slide.icon, size: 64, color: AppColors.primary),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            slide.title,
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            slide.description,
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          if (isLastSlide) ...[
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: context.surfaceColor,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 18, color: context.textSecondaryColor),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Location: used for local weather-based suggestions.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Icon(Icons.notifications_outlined,
                          size: 18, color: context.textSecondaryColor),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Notifications: used for task reminders only.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
