import 'package:flutter/material.dart';
import '../../state/studio_controller.dart';

class SimulationBar extends StatefulWidget {
  final StudioController controller;

  const SimulationBar({super.key, required this.controller});

  @override
  State<SimulationBar> createState() => _SimulationBarState();
}

class _SimulationBarState extends State<SimulationBar> {
  late TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.controller.inputTape);
    widget.controller.addListener(_onControllerChange);
  }

  void _onControllerChange() {
    if (widget.controller.inputTape != _textController.text) {
      _textController.text = widget.controller.inputTape;
    }
  }

  @override
  void didUpdateWidget(covariant SimulationBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChange);
      widget.controller.addListener(_onControllerChange);
    }
    if (widget.controller.inputTape != _textController.text) {
      _textController.text = widget.controller.inputTape;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final sim = widget.controller.simulator;
        final currentStep = sim?.currentStep;
        final isFinished = sim?.isAtEnd ?? false;
        final isAccepted = sim?.isStringAccepted ?? false;
        final isStuck = currentStep?.isStuck ?? false;

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF161922),
            border: const Border(
              top: BorderSide(color: Color(0xFF282D3D), width: 1.5),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Tape Visualization Strip
              Row(
                children: [
                  const Text(
                    'TAPE:',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _buildTapeCells(currentStep?.tapeIndex ?? 0),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Result Badge
                  if (isFinished)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isAccepted
                            ? const Color(0xFF052E16)
                            : const Color(0xFF450A0A),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isAccepted
                              ? const Color(0xFF22C55E)
                              : const Color(0xFFEF4444),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isAccepted ? Icons.check_circle : Icons.cancel,
                            size: 16,
                            color: isAccepted
                                ? const Color(0xFF4ADE80)
                                : const Color(0xFFF87171),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isAccepted ? 'ACCEPTED' : (isStuck ? 'STUCK' : 'REJECTED'),
                            style: TextStyle(
                              color: isAccepted
                                  ? const Color(0xFF4ADE80)
                                  : const Color(0xFFF87171),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 10),

              // 2. Control Bar (Input, Buttons, Timeline)
              Row(
                children: [
                  // Tape Input field with auto-set
                  SizedBox(
                    width: 170,
                    height: 36,
                    child: TextField(
                      controller: _textController,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontFamily: 'monospace',
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        hintText: 'Type input tape...',
                        hintStyle:
                            const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                        filled: true,
                        fillColor: const Color(0xFF1E222D),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(color: Color(0xFF334155)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(color: Color(0xFF6366F1)),
                        ),
                      ),
                      onChanged: (val) => widget.controller.setInputTape(val),
                      onSubmitted: (val) => widget.controller.setInputTape(val),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Live Mode Keystroke Toggle Button
                  InkWell(
                    onTap: widget.controller.toggleLiveMode,
                    borderRadius: BorderRadius.circular(6),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: widget.controller.liveMode
                            ? const Color(0xFF0E7490).withValues(alpha: 0.35)
                            : const Color(0xFF1E222D),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: widget.controller.liveMode
                              ? const Color(0xFF00E5FF)
                              : const Color(0xFF334155),
                          width: 1.2,
                        ),
                        boxShadow: widget.controller.liveMode
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF00E5FF)
                                      .withValues(alpha: 0.2),
                                  blurRadius: 6,
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.bolt,
                            size: 16,
                            color: widget.controller.liveMode
                                ? const Color(0xFF00E5FF)
                                : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Live',
                            style: TextStyle(
                              color: widget.controller.liveMode
                                  ? const Color(0xFF00E5FF)
                                  : const Color(0xFF94A3B8),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Stepper Buttons
                  IconButton(
                    icon: const Icon(Icons.replay, size: 20),
                    tooltip: 'Reset to Start',
                    color: const Color(0xFF94A3B8),
                    onPressed: widget.controller.resetSimulation,
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_previous, size: 22),
                    tooltip: 'Step Back',
                    color: (sim?.canStepBackward ?? false)
                        ? Colors.white
                        : const Color(0xFF475569),
                    onPressed: (sim?.canStepBackward ?? false)
                        ? widget.controller.stepBackward
                        : null,
                  ),
                  IconButton(
                    icon: Icon(
                      widget.controller.isPlaying
                          ? Icons.pause
                          : Icons.play_arrow,
                      size: 24,
                    ),
                    tooltip: widget.controller.isPlaying ? 'Pause' : 'Play',
                    color: const Color(0xFF6366F1),
                    onPressed: widget.controller.togglePlayPause,
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next, size: 22),
                    tooltip: 'Step Forward',
                    color: (sim?.canStepForward ?? false)
                        ? Colors.white
                        : const Color(0xFF475569),
                    onPressed: (sim?.canStepForward ?? false)
                        ? widget.controller.stepForward
                        : null,
                  ),

                  const SizedBox(width: 16),

                  // Timeline Scrubber Slider
                  if ((sim?.totalSteps ?? 0) > 1) ...[
                    Text(
                      'Step ${sim!.currentStepIndex + 1} / ${sim.totalSteps}',
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: const Color(0xFF6366F1),
                          inactiveTrackColor: const Color(0xFF334155),
                          thumbColor: const Color(0xFF818CF8),
                          trackHeight: 3.0,
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6.0),
                        ),
                        child: Slider(
                          value: sim.currentStepIndex.toDouble(),
                          min: 0,
                          max: (sim.totalSteps - 1).toDouble(),
                          divisions: sim.totalSteps - 1,
                          onChanged: (val) =>
                              widget.controller.jumpToStep(val.toInt()),
                        ),
                      ),
                    ),
                  ],

                  // Step description message
                  Expanded(
                    child: Text(
                      currentStep?.message ?? '',
                      style: TextStyle(
                        color: isStuck
                            ? const Color(0xFFF87171)
                            : const Color(0xFFCBD5E1),
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildTapeCells(int currentTapeIdx) {
    final tape = widget.controller.inputTape;
    if (tape.isEmpty) {
      return [
        const Text(
          '(empty string ε)',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
        ),
      ];
    }

    final cells = <Widget>[];
    for (int i = 0; i < tape.length; i++) {
      final isCurrent = i == currentTapeIdx;
      final isConsumed = i < currentTapeIdx;

      cells.add(
        Container(
          margin: const EdgeInsets.only(right: 4.0),
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: isCurrent
                ? const Color(0xFF4338CA)
                : (isConsumed
                    ? const Color(0xFF1E293B)
                    : const Color(0xFF0F172A)),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isCurrent
                  ? const Color(0xFF818CF8)
                  : const Color(0xFF334155),
              width: isCurrent ? 1.8 : 1.0,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            tape[i],
            style: TextStyle(
              color: isCurrent
                  ? Colors.white
                  : (isConsumed
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFFE2E8F0)),
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              fontFamily: 'monospace',
              fontSize: 13,
            ),
          ),
        ),
      );
    }
    return cells;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChange);
    _textController.dispose();
    super.dispose();
  }
}
