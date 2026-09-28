import 'package:flutter/material.dart';
import '../../state/studio_controller.dart';

class StudioToolbar extends StatefulWidget {
  final StudioController controller;

  const StudioToolbar({super.key, required this.controller});

  @override
  State<StudioToolbar> createState() => _StudioToolbarState();
}

class _StudioToolbarState extends State<StudioToolbar> {
  bool _isEditingName = false;
  late final TextEditingController _nameController;
  final FocusNode _nameFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.controller.machineName);
    _nameFocusNode.addListener(() {
      if (!_nameFocusNode.hasFocus && _isEditingName) {
        _finishEditingName();
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  void _finishEditingName() {
    if (mounted) {
      final text = _nameController.text.trim();
      if (text.isNotEmpty) {
        widget.controller.setMachineName(text);
      }
      setState(() {
        _isEditingName = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final isDfa = widget.controller.automaton.isDfa;
        final hasEpsilon = widget.controller.automaton.hasEpsilonTransitions;
        final isSidebarOpen =
            widget.controller.activeSidebarTab != SidebarTab.none;

        return Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14.0),
          decoration: const BoxDecoration(
            color: Color(0xFF11141D),
            border: Border(
              bottom: BorderSide(color: Color(0xFF1E2333), width: 1.2),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left Group: Subdued lowercase brandmark, machine title pill, and type badge
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Minimalist glyph & subtle uncapitalized title
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: const Color(0xFF313B54), width: 1),
                      color: const Color(0xFF161B28),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      '∞',
                      style: TextStyle(
                        color: Color(0xFF818CF8),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        height: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'infinite state',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                      fontFamily: 'monospace',
                    ),
                  ),

                  Container(
                    width: 1,
                    height: 16,
                    margin: const EdgeInsets.symmetric(horizontal: 14),
                    color: const Color(0xFF262C3E),
                  ),

                  // Editable Machine Title Pill
                  _buildMachineTitlePill(context),

                  const SizedBox(width: 10),

                  // Classification Badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: isDfa
                          ? const Color(0xFF064E3B)
                          : const Color(0xFF312E81),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: isDfa
                            ? const Color(0xFF10B981)
                            : const Color(0xFF818CF8),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      isDfa ? 'DFA' : (hasEpsilon ? 'ε-NFA' : 'NFA'),
                      style: TextStyle(
                        color: isDfa
                            ? const Color(0xFF6EE7B7)
                            : const Color(0xFFA5B4FC),
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              // Right Group: Undo, Clear All, and Sidebar Toggle
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Undo Button
                  IconButton(
                    icon: const Icon(Icons.undo, size: 18),
                    tooltip: 'Undo (Ctrl+Z)',
                    color: widget.controller.canUndo
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF475569),
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(),
                    onPressed: widget.controller.canUndo ? widget.controller.undo : null,
                  ),

                  const SizedBox(width: 4),

                  // Redo Button
                  IconButton(
                    icon: const Icon(Icons.redo, size: 18),
                    tooltip: 'Redo (Ctrl+Shift+Z)',
                    color: widget.controller.canRedo
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF475569),
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(),
                    onPressed: widget.controller.canRedo ? widget.controller.redo : null,
                  ),

                  const SizedBox(width: 8),

                  // Clear All Button with Anchored Dropdown Menu
                  PopupMenuButton<String>(
                    tooltip: 'Clear All States',
                    icon: const Icon(Icons.delete_sweep,
                        size: 19, color: Color(0xFFF87171)),
                    color: const Color(0xFF1E222D),
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: Color(0xFF334155)),
                    ),
                    onSelected: (val) {
                      if (val == 'clear') {
                        widget.controller.clearAutomaton();
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        enabled: false,
                        height: 36,
                        child: Text(
                          'Clear all states & transitions?\n(You can undo anytime)',
                          style:
                              TextStyle(color: Colors.grey.shade400, fontSize: 11),
                        ),
                      ),
                      const PopupMenuDivider(height: 1),
                      const PopupMenuItem(
                        value: 'clear',
                        height: 36,
                        child: Row(
                          children: [
                            Icon(Icons.delete_forever,
                                size: 18, color: Color(0xFFEF4444)),
                            SizedBox(width: 8),
                            Text(
                              'Clear Canvas',
                              style: TextStyle(
                                color: Color(0xFFEF4444),
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(width: 8),

                  Container(
                    width: 1,
                    height: 16,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    color: const Color(0xFF262C3E),
                  ),

                  const SizedBox(width: 4),

                  // Right Sidebar Toggle Button
                  IconButton(
                    icon: Icon(
                      isSidebarOpen
                          ? Icons.view_sidebar
                          : Icons.view_sidebar_outlined,
                      size: 18,
                    ),
                    tooltip: isSidebarOpen ? 'Collapse Panels' : 'Expand Panels',
                    color: isSidebarOpen
                        ? const Color(0xFF00E5FF)
                        : const Color(0xFF94A3B8),
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      if (isSidebarOpen) {
                        widget.controller.setSidebarTab(SidebarTab.none);
                      } else {
                        widget.controller.setSidebarTab(SidebarTab.inspector);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMachineTitlePill(BuildContext context) {
    if (_isEditingName) {
      return Container(
        width: 170,
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2333),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF00E5FF), width: 1.5),
        ),
        alignment: Alignment.centerLeft,
        child: TextField(
          controller: _nameController,
          focusNode: _nameFocusNode,
          autofocus: true,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.zero,
            border: InputBorder.none,
          ),
          onSubmitted: (_) => _finishEditingName(),
        ),
      );
    }

    return InkWell(
      onTap: () {
        _nameController.text = widget.controller.machineName;
        setState(() => _isEditingName = true);
        _nameFocusNode.requestFocus();
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2333),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF2E374D)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.controller.machineName,
              style: const TextStyle(
                color: Color(0xFFE2E8F0),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.edit, size: 12, color: Color(0xFF64748B)),
          ],
        ),
      ),
    );
  }
}
