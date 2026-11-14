import 'dart:convert';
import 'dart:io';

import 'package:citrine_core/citrine_core.dart';
import 'package:test/test.dart';

void main() {
  group('Planning & Review Process Engine (B-06, B-07, R-01..R-04, Q-02, Y-02)', () {
    test('PlanningPresetCatalog ships canonical and alternative presets for all 6 rituals', () {
      for (final ritual in RitualKind.values) {
        final presets = PlanningPresetCatalog.presetsFor(ritual);
        expect(presets, isNotEmpty, reason: 'Expected presets for $ritual');

        final defaultPreset = PlanningPresetCatalog.defaultPresetFor(ritual);
        expect(defaultPreset.ritualKind, ritual);
        expect(defaultPreset.steps, isNotEmpty);
        expect(
          defaultPreset.steps.where((RitualStepSpec s) => s.includedInMinimal),
          isNotEmpty,
          reason: 'Every default preset must have at least 1 minimal step',
        );
      }

      // Verify specific well-known presets exist
      expect(PlanningPresetCatalog.findById('citrine_daily_morning'), isNotNull);
      expect(PlanningPresetCatalog.findById('ivy_lee_morning'), isNotNull);
      expect(PlanningPresetCatalog.findById('franklin_morning'), isNotNull);
      expect(PlanningPresetCatalog.findById('citrine_daily_shutdown'), isNotNull);
      expect(PlanningPresetCatalog.findById('newport_shutdown'), isNotNull);
      expect(PlanningPresetCatalog.findById('franklin_evening'), isNotNull);
      expect(PlanningPresetCatalog.findById('gtd_weekly_review'), isNotNull);
      expect(PlanningPresetCatalog.findById('adhd_cbt_weekly_reset'), isNotNull);
      expect(PlanningPresetCatalog.findById('bujo_monthly_migration'), isNotNull);
      expect(PlanningPresetCatalog.findById('citrine_quarterly_hybrid'), isNotNull);
      expect(PlanningPresetCatalog.findById('gates_think_week'), isNotNull);
      expect(PlanningPresetCatalog.findById('citrine_yearly_hybrid'), isNotNull);
      expect(PlanningPresetCatalog.findById('ferriss_past_year_review'), isNotNull);
      expect(PlanningPresetCatalog.findById('franklin_virtue_ledger'), isNotNull);
    });

    test('RitualProcessConfig supports Layer 1 Presets, Layer 2 Custom Steps, and Minimal filtering', () {
      final base = RitualProcessConfig.defaultFor(RitualKind.dailyMorningPlan);
      expect(base.executionMode, CadenceExecutionMode.guidedPreset);

      final fullSteps = base.activeSteps(depthOverride: RitualDepthMode.full);
      final minimalSteps = base.activeSteps(depthOverride: RitualDepthMode.minimal);
      expect(fullSteps.length, greaterThan(minimalSteps.length));
      expect(minimalSteps.every((RitualStepSpec s) => s.includedInMinimal), isTrue);

      // Switch to Ivy Lee preset
      final ivyConfig = base.copyWith(selectedPresetId: 'ivy_lee_morning');
      final ivySteps = ivyConfig.activeSteps();
      expect(ivySteps.last.maxFocusItems, 6);

      // Switch to Layer 2 Custom Steps and add a custom reflection prompt
      const customStep = RitualStepSpec(
        id: 'custom_gratitude',
        kind: RitualStepKind.customReflectionPrompt,
        title: 'Morning Gratitude',
        subtitle: 'Write 1 thing you appreciate today.',
        coachWhy: 'Boosts baseline dopamine.',
        coachAvoidTrap: '1 sentence is enough.',
        promptQuestion: 'What am I grateful for this morning?',
      );
      final customConfig = base.copyWith(
        executionMode: CadenceExecutionMode.customSteps,
        customSteps: [...base.customSteps, customStep],
      );
      expect(
        customConfig.activeSteps(depthOverride: RitualDepthMode.full).last.id,
        'custom_gratitude',
      );
    });

    test('RitualSessionOutput formats clean Markdown for Daily, Quarterly, and Yearly logs', () {
      const morningOut = RitualSessionOutput(
        ritualKind: RitualKind.dailyMorningPlan,
        depthMode: RitualDepthMode.full,
        presetName: 'Citrine Hybrid Morning Launch (Default)',
        completedAtIso: '2026-11-11',
        ruleOfOneFloorDay: true,
        periodOutcomes: ['Draft architecture RFC'],
        microFirstStepText: 'Open RFC template and type 3 headings',
        ifThenCueText:
            'When I sit down with coffee at 9am, then I will open the RFC file',
        customPromptResponses: {
          'What good shall I do this day?': 'Unblock the team on API schema.',
        },
      );
      final morningMd = morningOut.toMarkdownLines().join('\n');
      expect(morningMd, contains('## Daily Morning Plan (2026-11-11 · Full Process)'));
      expect(morningMd, contains('Floor Day (Rule of 1 Active)'));
      expect(morningMd, contains('- [ ] Draft architecture RFC'));
      expect(morningMd, contains('Open RFC template and type 3 headings'));
      expect(morningMd, contains('When I sit down with coffee at 9am'));
      expect(morningMd, contains('### What good shall I do this day?'));

      const yearlyOut = RitualSessionOutput(
        ritualKind: RitualKind.yearlyReviewPlan,
        depthMode: RitualDepthMode.full,
        presetName: 'Citrine Yearly Review & Vision',
        completedAtIso: '2026-12-31',
        peakPositiveActivities: 'Pair programming and deep writing',
        notToDoEnergyDrains: 'Late-night status meetings\nUnscoped side projects',
        fiveQuestionAnswers: {
          'What did I accomplish?': 'Shipped Citrine v1',
        },
        focalVirtueOrTheme: 'Order — calm space for every tool and thought',
        avoidAtAllCostsList: 'Building sync before local UX is rock-solid',
        periodOutcomes: ['Ship mobile release'],
        bridgeActionForNextLowerCadence: 'Set up iOS TestFlight build',
      );
      final yearlyMd = yearlyOut.toMarkdownLines().join('\n');
      expect(yearlyMd, contains('### 80/20 Energy Audit (Tim Ferriss Past Year Review)'));
      expect(yearlyMd, contains('Not-To-Do List (- 20% energy drains to eliminate)'));
      expect(yearlyMd, contains('### Five-Question Self-Audit'));
      expect(yearlyMd, contains('Focal Virtue / Theme:'));
      expect(yearlyMd, contains('Buffett 5/25 Avoid-At-All-Costs List:'));
      expect(yearlyMd, contains('- [ ] Ship mobile release'));
      expect(yearlyMd, contains('Set up iOS TestFlight build'));
    });

    test('Portable process config saves to .citrine/process_config.json on disk', () async {
      final tempDir = await Directory.systemTemp.createTemp('citrine_process_test_');
      try {
        final configs = {
          for (final k in RitualKind.values) k: RitualProcessConfig.defaultFor(k),
        };
        configs[RitualKind.weeklyReviewPlan] = configs[RitualKind.weeklyReviewPlan]!
            .copyWith(
              executionMode: CadenceExecutionMode.freeformMarkdown,
              preferredDepth: RitualDepthMode.minimal,
            );

        await PlanningPresetCatalog.savePortableConfigToVault(
          vaultRootPath: tempDir.path,
          configs: configs,
          guidanceEnabled: false,
          learningStage: LearningStage.stage3WeeklyReview,
        );

        final file = File(
          '${tempDir.path}/${PlanningPresetCatalog.portableConfigRelPath}',
        );
        expect(await file.exists(), isTrue);
        final decoded =
            jsonDecode(await file.readAsString()) as Map<String, Object?>;
        expect(decoded['guidanceEnabled'], isFalse);
        expect(decoded['learningStage'], LearningStage.stage3WeeklyReview.id);
      } finally {
        await tempDir.delete(recursive: true);
      }
    });
  });
}
