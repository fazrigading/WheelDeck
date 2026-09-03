# Workflow preferences

- Prefers implementation plans tracked as GitHub issues, one issue per phase. Confidence: 0.8
- Uses the awesome-copilot skill family (create-implementation-plan, create-github-issues-feature-from-implementation-plan) for spec-to-plan-to-issues workflows. Confidence: 0.7

- Prefers plan mode for exploration before executing multi-step tasks (explores codebase, then asks clarifying questions, then writes a plan). Confidence: 0.7

- Comfortable scaling back multi-phase tasks when they feel heavy; delegates judgment on how much to trim ("do first 2 phases if you think it's too heavy"). Confidence: 0.7

- Drives work by referencing explicit task IDs (e.g. "Continue implement TASK-010") and expects the agent to pick up and implement that task autonomously. Confidence: 0.8

- Prefers correcting known issues early while refactoring is still cheap (e.g. before empty scaffolds accumulate dependents). Confidence: 0.6

- Uses todo checklists to track sub-steps of a task, marking each in_progress and then completed as work proceeds. Confidence: 0.7

- Reads existing type/enum definitions before writing code that depends on them, to stay consistent with current shapes and naming. Confidence: 0.7
- Works on Linux; previously expected OS-specific tasks to be skipped when not applicable to the current platform, but now implements them anyway (e.g. TASK-013 Windows ViGEmBus on Linux), compile-verifying and flagging that runtime testing requires the target OS. Confidence: 0.8
- When implementation tasks complete, update the plan's task table "Completed" and "Date" columns to reflect done work, then commit that plan update as a chore. Confidence: 0.9
