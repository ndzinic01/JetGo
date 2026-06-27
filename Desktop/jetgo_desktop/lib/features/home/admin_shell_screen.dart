import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../auth/auth_controller.dart';
import '../flights_routes/flights_routes_section.dart';
import '../payments/payments_section.dart';
import '../reference_data/reference_data_section.dart';
import '../reservations/reservations_section.dart';
import '../support/support_section.dart';
import '../users/users_section.dart';

enum AdminSection {
  overview,
  referenceData,
  network,
  reservations,
  users,
  support,
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

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            Container(
              width: 280,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  right: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.admin_panel_settings_rounded,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'JetGo Admin',
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _AdminProfileCard(
                    fullName: user.fullName,
                    username: user.username,
                    email: user.email,
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView(
                      children: [
                        _NavButton(
                          icon: Icons.space_dashboard_rounded,
                          label: 'Overview',
                          isSelected:
                              _selectedSection == AdminSection.overview,
                          onTap: () =>
                              _selectSection(AdminSection.overview),
                        ),
                        _NavButton(
                          icon: Icons.public_rounded,
                          label: 'Reference Data',
                          isSelected:
                              _selectedSection == AdminSection.referenceData,
                          onTap: () =>
                              _selectSection(AdminSection.referenceData),
                        ),
                        _NavButton(
                          icon: Icons.alt_route_rounded,
                          label: 'Flights & Routes',
                          isSelected: _selectedSection == AdminSection.network,
                          onTap: () => _selectSection(AdminSection.network),
                        ),
                        _NavButton(
                          icon: Icons.confirmation_num_rounded,
                          label: 'Reservations',
                          isSelected:
                              _selectedSection == AdminSection.reservations,
                          onTap: () =>
                              _selectSection(AdminSection.reservations),
                        ),
                        _NavButton(
                          icon: Icons.group_rounded,
                          label: 'Users',
                          isSelected: _selectedSection == AdminSection.users,
                          onTap: () => _selectSection(AdminSection.users),
                        ),
                        _NavButton(
                          icon: Icons.support_agent_rounded,
                          label: 'Support',
                          isSelected: _selectedSection == AdminSection.support,
                          onTap: () => _selectSection(AdminSection.support),
                        ),
                        _NavButton(
                          icon: Icons.receipt_long_rounded,
                          label: 'Reports',
                          isSelected: _selectedSection == AdminSection.reports,
                          onTap: () => _selectSection(AdminSection.reports),
                        ),
                        _NavButton(
                          icon: Icons.payments_rounded,
                          label: 'Payments',
                          isSelected: _selectedSection == AdminSection.payments,
                          onTap: () => _selectSection(AdminSection.payments),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: widget.authController.logout,
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Odjava'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TopBar(
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
        return _OverviewSection(
          fullName: fullName,
          roles: roles,
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
      case AdminSection.reports:
        return const _SectionPlaceholder(
          title: 'Reports',
          description:
              'Reports modul ce koristiti postojece PDF backend endpoint-e za preuzimanje izvjestaja.',
          bullets: [
            'Reservations PDF',
            'Payments PDF',
            'Filter po datumu i statusu',
          ],
        );
      case AdminSection.payments:
        return PaymentsSection(
          token: widget.authController.session!.accessToken,
        );
    }
  }

  String _sectionTitle(AdminSection section) {
    switch (section) {
      case AdminSection.overview:
        return 'Overview';
      case AdminSection.referenceData:
        return 'Reference Data';
      case AdminSection.network:
        return 'Flights & Routes';
      case AdminSection.reservations:
        return 'Reservations';
      case AdminSection.users:
        return 'Users';
      case AdminSection.support:
        return 'Support';
      case AdminSection.reports:
        return 'Reports';
      case AdminSection.payments:
        return 'Payments';
    }
  }

  String _sectionSubtitle(AdminSection section) {
    switch (section) {
      case AdminSection.overview:
        return 'Prvi desktop skeleton za admin radni prostor.';
      case AdminSection.referenceData:
        return 'Referentni podaci su prvi konkretni CRUD korak.';
      case AdminSection.network:
        return 'Letovi i destinacije dolaze odmah iza reference data modula.';
      case AdminSection.reservations:
        return 'Operativni pregled rezervacija za desktop korisnika.';
      case AdminSection.users:
        return 'Upravljanje korisnicima i pristupima.';
      case AdminSection.support:
        return 'Desktop support inbox za odgovore i pregled upita.';
      case AdminSection.reports:
        return 'Preuzimanje i kontrola PDF izvjestaja.';
      case AdminSection.payments:
        return 'Pregled payment workflow-a i refund stanja.';
    }
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
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
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.secondaryContainer
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverviewSection extends StatelessWidget {
  const _OverviewSection({
    required this.fullName,
    required this.roles,
  });

  final String fullName;
  final List<String> roles;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          childAspectRatio: 1.5,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _OverviewCard(
              title: 'Administrator',
              value: fullName,
              caption: 'Aktivna desktop sesija',
              icon: Icons.admin_panel_settings_rounded,
            ),
            _OverviewCard(
              title: 'Role',
              value: roles.join(', '),
              caption: 'Preuzete iz JWT sesije',
              icon: Icons.verified_user_rounded,
            ),
            const _OverviewCard(
              title: 'Ready',
              value: 'Desktop shell',
              caption: 'Spreman za CRUD module',
              icon: Icons.desktop_windows_rounded,
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sta je spremno sada',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Ovaj skeleton zatvara desktop login, admin-only ulaz i sidebar navigaciju. Sljedeci commit mozemo odmah puniti stvarnim tabelama i formama za prvi CRUD modul.',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.title,
    required this.value,
    required this.caption,
    required this.icon,
  });

  final String title;
  final String value;
  final String caption;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const Spacer(),
            Text(
              title,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              caption,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionPlaceholder extends StatelessWidget {
  const _SectionPlaceholder({
    required this.title,
    required this.description,
    required this.bullets,
  });

  final String title;
  final String description;
  final List<String> bullets;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Text(description),
            const SizedBox(height: 20),
            ...bullets.map(
              (bullet) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Icon(Icons.chevron_right_rounded, size: 18),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(bullet)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
