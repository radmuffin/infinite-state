import 'package:flutter/material.dart';
import '../../state/studio_controller.dart';
import 'batch_test_dialog.dart';
import 'inspector_panel.dart';
import 'regex_panel.dart';
import 'save_load_dialog.dart';

class RightSidebar extends StatelessWidget {
  final StudioController controller;

  const RightSidebar({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final activeTab = controller.activeSidebarTab;
        final isOpen = activeTab != SidebarTab.none;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Slide-out panel content
            if (isOpen)
              SizedBox(
                width: 350,
                child: _buildPanelContent(activeTab),
              ),

            // Persistent vertical activity rail on the right edge
            Container(
              width: 44,
              decoration: const BoxDecoration(
                color: Color(0xFF0F1118),
                border: Border(
                  left: BorderSide(color: Color(0xFF1E2333), width: 1.2),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 8),

                  // 1. Inspector & Matrix Tab
                  _buildRailTab(
                    icon: Icons.tune,
                    tooltip: 'Inspector & Matrix',
                    isActive: activeTab == SidebarTab.inspector,
                    onTap: () => controller.toggleSidebarTab(SidebarTab.inspector),
                  ),

                  const SizedBox(height: 4),

                  // 2. Regex Studio Tab
                  _buildRailTab(
                    icon: Icons.code,
                    tooltip: 'Regex & Language L(M)',
                    isActive: activeTab == SidebarTab.regex,
                    onTap: () => controller.toggleSidebarTab(SidebarTab.regex),
                  ),

                  const SizedBox(height: 4),

                  // 3. Batch Tests Tab
                  _buildRailTab(
                    icon: Icons.playlist_add_check,
                    tooltip: 'Batch Testing Suite',
                    isActive: activeTab == SidebarTab.batchTests,
                    onTap: () => controller.toggleSidebarTab(SidebarTab.batchTests),
                  ),

                  const SizedBox(height: 4),

                  // 4. Library & Presets Tab
                  _buildRailTab(
                    icon: Icons.folder_special,
                    tooltip: 'Library & Presets',
                    isActive: activeTab == SidebarTab.library,
                    onTap: () => controller.toggleSidebarTab(SidebarTab.library),
                  ),

                  const Spacer(),

                  // Bottom collapse/expand quick toggle
                  Tooltip(
                    message: isOpen ? 'Collapse Panel' : 'Expand Panel',
                    child: InkWell(
                      onTap: () {
                        if (isOpen) {
                          controller.setSidebarTab(SidebarTab.none);
                        } else {
                          controller.setSidebarTab(SidebarTab.inspector);
                        }
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        width: 34,
                        height: 34,
                        margin: const EdgeInsets.only(bottom: 8),
                        alignment: Alignment.center,
                        child: Icon(
                          isOpen ? Icons.chevron_right : Icons.chevron_left,
                          size: 18,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRailTab({
    required IconData icon,
    required String tooltip,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF1E2538) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: isActive
                ? Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.5), width: 1)
                : null,
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 18,
            color: isActive ? const Color(0xFF00E5FF) : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildPanelContent(SidebarTab tab) {
    switch (tab) {
      case SidebarTab.inspector:
        return InspectorPanel(
          controller: controller,
          onClose: () => controller.setSidebarTab(SidebarTab.none),
        );
      case SidebarTab.regex:
        return RegexPanel(
          controller: controller,
          onClose: () => controller.setSidebarTab(SidebarTab.none),
        );
      case SidebarTab.batchTests:
        return BatchTestView(
          controller: controller,
          onClose: () => controller.setSidebarTab(SidebarTab.none),
        );
      case SidebarTab.library:
        return SaveLoadView(
          controller: controller,
          onClose: () => controller.setSidebarTab(SidebarTab.none),
        );
      case SidebarTab.none:
        return const SizedBox.shrink();
    }
  }
}
