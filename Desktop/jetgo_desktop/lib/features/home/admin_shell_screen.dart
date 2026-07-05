import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../auth/auth_controller.dart';
import '../flights_routes/flights_routes_section.dart';
import '../overview/overview_section.dart';
import '../payments/payments_section.dart';
import '../news/news_section.dart';
import '../profile/profile_section.dart';
import '../reference_data/reference_data_section.dart';
import '../reports/reports_section.dart';
import '../reservations/reservations_section.dart';
import '../support/support_section.dart';
import '../users/users_section.dart';

enum AdminSection {
  overview,
  profile,
  referenceData,
  network,
  reservations,
  users,
  support,
  news,
  reports,
  payments,
}

class AdminShellScreen extends StatefulWidget {
  const AdminShellScreen({required this.authController, super.key});

  final AuthController authController;

  @override
  State<AdminShellScreen> createState() => _AdminShellScreenState();
}

class _AdminShellScreenState extends State<AdminShellScreen> {
  AdminSection _selectedSection = AdminSection.overview;

  @override
  Widget build(BuildContext context) {
    final session = widget.authController.session!;
    final user = session.user;
    final theme = Theme.of(context);
    final palette = theme.extension<DesktopPalette>()!;

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            Container(
              width: 250,
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
              decoration: BoxDecoration(
                color: palette.sidebar,
                border: Border(
                  right: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(28, 26, 20, 20),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.insert_chart_outlined_rounded,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'JetGo Admin',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontSize: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _AdminProfileCard(
                    fullName: user.fullName,
                    username: user.username,
                    email: user.email,
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 0),
                      children: [
                        _NavButton(
                          icon: Icons.space_dashboard_rounded,
                          label: 'Kontrolna tabla',
                          isSelected:
                              _selectedSection == AdminSection.overview,
                          onTap: () =>
                              _selectSection(AdminSection.overview),
                        ),
                        _NavButton(
                          icon: Icons.person_rounded,
                          label: 'Moj profil',
                          isSelected:
                              _selectedSection == AdminSection.profile,
                          onTap: () => _selectSection(AdminSection.profile),
                        ),
                        _NavButton(
                          icon: Icons.public_rounded,
                          label: 'Osnovni podaci',
                          isSelected:
                              _selectedSection == AdminSection.referenceData,
                          onTap: () =>
                              _selectSection(AdminSection.referenceData),
                        ),
                        _NavButton(
                          icon: Icons.alt_route_rounded,
                          label: 'Rute i letovi',
                          isSelected: _selectedSection == AdminSection.network,
                          onTap: () => _selectSection(AdminSection.network),
                        ),
                        _NavButton(
                          icon: Icons.confirmation_num_rounded,
                          label: 'Rezervacije',
                          isSelected:
                              _selectedSection == AdminSection.reservations,
                          onTap: () =>
                              _selectSection(AdminSection.reservations),
                        ),
                        _NavButton(
                          icon: Icons.group_rounded,
                          label: 'Korisnici',
                          isSelected: _selectedSection == AdminSection.users,
                          onTap: () => _selectSection(AdminSection.users),
                        ),
                        _NavButton(
                          icon: Icons.support_agent_rounded,
                          label: 'Podrska',
                          isSelected: _selectedSection == AdminSection.support,
                          onTap: () => _selectSection(AdminSection.support),
                        ),
                        _NavButton(
                          icon: Icons.article_rounded,
                          label: 'Novosti',
                          isSelected: _selectedSection == AdminSection.news,
                          onTap: () => _selectSection(AdminSection.news),
                        ),
                        _NavButton(
                          icon: Icons.receipt_long_rounded,
                          label: 'Izvjestaji',
                          isSelected: _selectedSection == AdminSection.reports,
                          onTap: () => _selectSection(AdminSection.reports),
                        ),
                        _NavButton(
                          icon: Icons.payments_rounded,
                          label: 'Placanja',
                          isSelected: _selectedSection == AdminSection.payments,
                          onTap: () => _selectSection(AdminSection.payments),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: OutlinedButton.icon(
                      onPressed: widget.authController.logout,
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Odjava'),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TopBar(
                      icon: _sectionIcon(_selectedSection),
                      title: _sectionTitle(_selectedSection),
                      subtitle: _sectionSubtitle(_selectedSection),
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: _buildSectionContent(
                        context,
                        user.fullName,
                        user.roles,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'API endpoint: ${AppConfig.apiBaseUrl}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectSection(AdminSection section) {
    setState(() {
      _selectedSection = section;
    });
  }

  Widget _buildSectionContent(
    BuildContext context,
    String fullName,
    List<String> roles,
  ) {
    switch (_selectedSection) {
      case AdminSection.overview:
        return OverviewSection(
          token: widget.authController.session!.accessToken,
          currentUserFullName: fullName,
          currentUserRoles: roles,
        );
      case AdminSection.profile:
        return ProfileSection(
          token: widget.authController.session!.accessToken,
          authController: widget.authController,
        );
      case AdminSection.referenceData:
        return ReferenceDataSection(
          token: widget.authController.session!.accessToken,
        );
      case AdminSection.network:
        return FlightsRoutesSection(
          token: widget.authController.session!.accessToken,
        );
      case AdminSection.reservations:
        return ReservationsSection(
          token: widget.authController.session!.accessToken,
        );
      case AdminSection.users:
        return UsersSection(
          token: widget.authController.session!.accessToken,
          currentUserId: widget.authController.session!.user.userId,
        );
      case AdminSection.support:
        return SupportSection(
          token: widget.authController.session!.accessToken,
        );
      case AdminSection.news:
        return NewsSection(
          token: widget.authController.session!.accessToken,
        );
      case AdminSection.reports:
        return ReportsSection(
          token: widget.authController.session!.accessToken,
        );
      case AdminSection.payments:
        return PaymentsSection(
          token: widget.authController.session!.accessToken,
        );
    }
  }

  IconData _sectionIcon(AdminSection section) {
    switch (section) {
      case AdminSection.overview:
        return Icons.insert_chart_outlined_rounded;
      case AdminSection.profile:
        return Icons.person_outline_rounded;
      case AdminSection.referenceData:
        return Icons.public_rounded;
      case AdminSection.network:
        return Icons.flight_takeoff_rounded;
      case AdminSection.reservations:
        return Icons.calendar_month_rounded;
      case AdminSection.users:
        return Icons.group_rounded;
      case AdminSection.support:
        return Icons.support_agent_rounded;
      case AdminSection.news:
        return Icons.campaign_rounded;
      case AdminSection.reports:
        return Icons.description_outlined;
      case AdminSection.payments:
        return Icons.payments_outlined;
    }
  }

  String _sectionTitle(AdminSection section) {
    switch (section) {
      case AdminSection.overview:
        return 'Kontrolna tabla';
      case AdminSection.profile:
        return 'Moj profil';
      case AdminSection.referenceData:
        return 'Osnovni podaci';
      case AdminSection.network:
        return 'Rute i letovi';
      case AdminSection.reservations:
        return 'Rezervacije';
      case AdminSection.users:
        return 'Upravljanje korisnicima';
      case AdminSection.support:
        return 'Podrska';
      case AdminSection.news:
        return 'Novosti';
      case AdminSection.reports:
        return 'Izvjestaji';
      case AdminSection.payments:
        return 'Placanja';
    }
  }

  String _sectionSubtitle(AdminSection section) {
    switch (section) {
      case AdminSection.overview:
        return 'Kratak pregled najvaznijih operativnih pokazatelja.';
      case AdminSection.profile:
        return 'Pregled i uredjivanje licnih podataka prijavljenog administratora.';
      case AdminSection.referenceData:
        return 'Drzave, gradovi, aerodromi i aviokompanije koje koriste ostali moduli.';
      case AdminSection.network:
        return 'Rute predstavljaju vezu izmedju dva aerodroma, a letovi su konkretni termini na tim rutama.';
      case AdminSection.reservations:
        return 'Operativni pregled rezervacija za desktop korisnika.';
      case AdminSection.users:
        return 'Upravljanje korisnicima i pristupima.';
      case AdminSection.support:
        return 'Desktop support inbox za odgovore i pregled upita.';
      case AdminSection.news:
        return 'Kreiranje i uredjivanje novosti koje korisnici vide u mobile aplikaciji.';
      case AdminSection.reports:
        return 'Preuzimanje i kontrola PDF izvjestaja.';
      case AdminSection.payments:
        return 'Pregled payment workflow-a i refund stanja.';
    }
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Icon(icon, color: theme.colorScheme.primary, size: 28),
              const SizedBox(width: 12),
              Text(title, style: theme.textTheme.headlineMedium),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class _AdminProfileCard extends StatelessWidget {
  const _AdminProfileCard({
    required this.fullName,
    required this.username,
    required this.email,
  });

  final String fullName;
  final String username;
  final String email;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: Colors.white,
            child: Text(
              fullName.isNotEmpty ? fullName.trim()[0].toUpperCase() : 'A',
            ),
          ),
          const SizedBox(height: 12),
          Text(fullName, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('@$username'),
          const SizedBox(height: 4),
          Text(
            email,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.white.withValues(alpha: 0.52)
                  : Colors.transparent,
              border: Border(
                top: BorderSide(color: theme.colorScheme.outlineVariant),
                bottom: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: const Color(0xFF2F5F97),
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
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
}
