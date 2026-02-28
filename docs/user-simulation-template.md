Unified_Simulated_User_Testing_Template.md
56.33 KB •1,224 lines
•
Formatting may be inconsistent from source

# Unified Simulated User Testing â€” Claude Code Implementation Template

> **Author:** Albert (AKD SOLUTIONS)  
> **Derived from:** Two complementary testing methodologies â€” a persona-driven app testing system (Playwright + 0â€“5 star app store reviews) and a triangulated archetype system (Arena Duel origin â€” Heart/Body/Mind weighted decision engine with cross-profile priority merging).  
> **Purpose:** Drop this single document into any Claude Code project to build a complete simulated user testing system that plays/uses the application like three different humans, produces structured reviews with star ratings, and generates a triangulated priority fix list. Works for games, web apps, mobile apps, and any interactive product.

---

## FOR CLAUDE CODE: READ THIS FIRST

You are building a **simulated user testing system** â€” not unit tests, not E2E tests, not a test harness. This is a psychological simulation layer where three distinct human archetypes independently use the application and then write structured reviews from their unique perspective.

**What this means for you:**

1. **Profiles are config, not code.** One decision engine reads profile weights to produce behavior. Three personality configs, zero code duplication. Adding a 4th profile is just a new JSON file with no engine changes.

2. **The observer is separate from the player.** The app state observer captures snapshots at every step regardless of who's driving. This means the same observer works for simulated profiles AND could record real human sessions later.

3. **Reviews are JSON first, markdown second.** JSON enables machine comparison across versions. Markdown summaries are auto-generated for human reading. Never sacrifice machine-readability for prose.

4. **"Not measurable" is a feature, not a gap.** When a profile cares about something the app doesn't have yet (sound, multiplayer, persistence), score it `null` with a reason string. These accumulate into an organic feature roadmap with every test run.

5. **Triangulation is the point.** Three profiles testing independently, then a cross-profile merge that surfaces issues flagged by multiple perspectives. An issue all three profiles flag is higher priority than one only a single profile catches.

6. **Star ratings are the deliverable.** Every run produces per-persona 0â€“5 star app store reviews AND a cross-profile PRIORITY_FIXES document. These are the artifacts that drive iteration.

---

## PART 1: THEORETICAL FOUNDATION

### Why Three Profiles

This system adapts Laugh's Theory of the Three Types of Fighting Game Players into a general UX testing framework. The theory identifies three orthogonal human strengths that map cleanly to application evaluation dimensions:

| Archetype | Core Strength | Tests For | Application Question |
|-----------|--------------|-----------|---------------------|
| **Heart** (Feel) | Emotional response, social dynamics, aesthetics | UI/UX polish, feedback loops, flow, onboarding, first impressions | "Is this app **enjoyable** to use?" |
| **Body** (Execution) | Precision, speed, optimal performance, efficiency | Core logic depth, responsiveness, error handling, competitive integrity | "Is this app **well-built** under the hood?" |
| **Mind** (Knowledge) | Analysis, system mastery, pattern recognition, depth | Data transparency, configuration depth, domain accuracy, coherence | "Is this app **coherent and deep**?" |

Three profiles create a stable triangulation â€” each vertex stress-tests a different quality dimension while overlap zones between pairs provide cross-validation. Fewer profiles leave blind spots. More profiles create redundancy without proportional coverage gain.

### The Triangulation Map

```
                 Heart Profile
                /  UI/UX & Feel  \
               /   Social/Collab   \
              /    Feedback Loops    \
             /                        \
      CORE APP â€”â€”â€”â€”â€”â€”â€”â€”â€”â€”â€”â€”â€”â€”â€”â€”â€”â€”â€”â€”â€”â€”â€”â€”â€”â€”â€”â€”
             \                        /
              \  Depth & Coherence   /
               \  Data & Config    /
                \ Narrative        /
                 Mind Profile ------- Body Profile
                                     Core Logic
                                     Precision & Speed
                                     Competitive Depth
```

Where two profiles overlap (e.g., Heart + Body both care about responsiveness; Mind + Body both care about data accuracy), issues get flagged by both â€” creating natural priority ranking. The center of the triangle is what ALL three care about â€” that's your core product quality.

### Mapping Archetypes to Personas

The three archetypes map directly to conventional UX persona segments:

| Archetype | Persona Label | User Segment | Typical % |
|-----------|--------------|--------------|-----------|
| Heart | Casual / Majority User | Low patience, high aesthetic standards, surface-level domain knowledge | 55â€“65% |
| Body | Power / Engaged User | Knows the domain, compares to competitors, wants depth and reliability | 20â€“30% |
| Mind | Expert / Professional | Most demanding, evaluates against professional standards, outsized influence | 10â€“20% |

**Adjust percentages per project.** A developer tool might be 20/40/40. A social app might be 70/20/10. The percentages create natural triage priority â€” fix what hurts the largest segment first.

---

## PART 2: ARCHITECTURE

```
{PROJECT_ROOT}/tests/simulation/
â”œâ”€â”€ sim-user-profiles.md          # This spec (reference, not consumed by code)
â”œâ”€â”€ profiles/
â”‚   â”œâ”€â”€ heart.js                  # Heart archetype config (Casual persona)
â”‚   â”œâ”€â”€ body.js                   # Body archetype config (Power persona)
â”‚   â””â”€â”€ mind.js                   # Mind archetype config (Expert persona)
â”œâ”€â”€ engine/
â”‚   â”œâ”€â”€ ui-auditor.js             # Per-step UI/CSS quality checks
â”‚   â”œâ”€â”€ app-observer.js           # State capture, timing, metrics, content audits
â”‚   â”œâ”€â”€ player-sim.js             # One engine, three personalities
â”‚   â””â”€â”€ review-generator.js       # Scoring, narrative, PRIORITY_FIXES triangulation
â”œâ”€â”€ fixtures/
â”‚   â”œâ”€â”€ mock-apis.js              # Route mocks for all backend APIs
â”‚   â””â”€â”€ mock-data.js              # Persona-specific test datasets
â”œâ”€â”€ helpers/
â”‚   â””â”€â”€ journey-helper.js         # Shared user journey automation
â”œâ”€â”€ sim-runner.spec.js            # Playwright orchestrator (parallel test isolation)
â””â”€â”€ reports/
    â””â”€â”€ (generated JSON reviews + PRIORITY_FIXES_v{N}.md)
```

### Component Responsibilities

| Component | Role | Domain-Agnostic? |
|-----------|------|-------------------|
| **profiles/*.js** | Pure configuration. Each exports the same schema with different weight values. Never contains logic, only numbers, strings, and arrays. | Yes â€” schema is universal, values are domain-specific |
| **engine/ui-auditor.js** | Runs 6+ CSS/layout validators at every interaction step. Checks: single active screen, element overlaps, overflows, inline style violations, ghost elements (zero-size in DOM), text clipping. | Yes â€” works on any web UI |
| **engine/app-observer.js** | Captures a snapshot of application state at every decision point. Records: current screen/view, available options, app state, timing metrics, UI quality signals from the auditor. | Partially â€” snapshot schema is domain-specific |
| **engine/player-sim.js** | The decision engine. Reads a profile config, examines the observer's snapshot, and chooses an action based on the profile's weighted preferences. One engine class, instantiated three times. | Yes â€” weights drive all behavior |
| **engine/review-generator.js** | Takes a complete session log, applies profile evaluation weights, produces structured JSON review with scores. Also generates cross-profile PRIORITY_FIXES. | Yes â€” scoring logic is universal |
| **fixtures/mock-apis.js** | Route mocks for all backend dependencies. Ensures deterministic tests. | No â€” domain-specific routes |
| **fixtures/mock-data.js** | Persona-specific test datasets â€” what each persona would input and what results they'd receive. | No â€” domain-specific data |
| **helpers/journey-helper.js** | Shared user journey automation â€” the primary flow each profile executes. | No â€” domain-specific flows |
| **sim-runner.spec.js** | Playwright orchestrator. Each profile runs as an independent `test()` block (parallel isolation). Final `test()` generates cross-profile summary. | Yes â€” structure is universal |

### Flow

Each persona spec instantiates its scorer â†’ `beforeEach` sets up persona-tuned API mocks â†’ the decision engine plays N sessions using the profile's weighted preferences â†’ each step is observed and audited â†’ `afterAll` generates consolidated report with star rating, written review, and cross-profile PRIORITY_FIXES.

---

## PART 3: PROFILE SCHEMA

Every profile exports an object conforming to this shape. **All behavioral traits are 0â€“1 weights** so the decision engine can blend them probabilistically rather than using rigid if/else trees.

```js
export default {
  // === Identity ===
  name: String,                              // Human name for reports (e.g., "Luna Martinez")
  archetype: "heart" | "body" | "mind",      // Triangulation vertex
  persona_label: String,                     // UX label (e.g., "Casual User")
  user_percentage: String,                   // Segment size (e.g., "60% of users")

  // === Environment ===
  device: "mobile" | "desktop",              // Determines viewport
  viewport: { width: Number, height: Number }, // Exact viewport size

  // === Interaction Style ===
  decision_style: {
    speed: "fast" | "moderate" | "deliberate",
    // "fast" = impulsive, may misclick, doesn't read everything
    // "moderate" = steady pace, reads most content
    // "deliberate" = uses maximum available time, reads everything

    error_tolerance: Number,     // 0-1, how much mistakes/bugs frustrate vs amuse
    randomness_tolerance: Number, // 0-1, acceptance of non-deterministic outcomes
    patience: Number,            // 0-1, willingness to wait, read instructions, explore
  },

  // === Pre-Task Setup ===
  setup_behavior: {
    thoroughness: Number,     // 0-1, reads all options vs picks first available
    optimization: Number,     // 0-1, min-maxes choices vs picks for flavor/feel
    customization: Number,    // 0-1, adjusts all settings vs uses defaults
    loyalty: Number,          // 0-1, sticks with one configuration vs rotates
  },

  // === In-App Decision Weights ===
  // Relative weights (should sum to ~1.0) feeding the decision engine.
  decision_weights: {
    optimal: Number,          // pick the objectively best option
    exploratory: Number,      // pick something new or untried
    aesthetic: Number,        // pick the most visually/emotionally appealing option
    consistent: Number,       // pick what matches previous choices / persona identity
  },

  // === Deal Breakers ===
  // Conditions that automatically drop the score to 1 star for any test that hits them.
  deal_breakers: [String],

  // === Evaluation Criteria ===
  // Each criterion is a weight 0-1 indicating importance to this profile.
  // CUSTOMIZE THESE FOR YOUR DOMAIN â€” structure stays, labels change.
  evaluation: {

    // Presentation & Feel (Heart territory)
    visual_polish: Number,
    animations_and_transitions: Number,
    feedback_and_responsiveness: Number,
    mobile_experience: Number,
    flow_and_rhythm: Number,
    emotional_engagement: Number,
    social_features: Number,

    // Core Logic & Functionality (Body territory)
    functional_depth: Number,
    input_precision: Number,
    fairness_and_balance: Number,
    performance_and_speed: Number,
    error_handling: Number,
    feature_completeness: Number,
    competitive_or_efficiency_features: Number,

    // Depth & Coherence (Mind territory)
    data_transparency: Number,
    configuration_depth: Number,
    content_quality: Number,
    narrative_or_informational_coherence: Number,
    progression_and_persistence: Number,
    domain_accuracy: Number,
    preparation_and_planning_tools: Number,
  },

  // === Review Voice ===
  review_config: {
    voice: String,            // Writing style description
    focus_areas: [String],    // Primary evaluation domains
    pet_peeves: [String],     // Things that trigger negative reviews
    delighters: [String],     // Things that trigger glowing reviews
    star_reviews: {           // Voice-appropriate text at each rating level
      5: { title: String, body: String },
      4: { title: String, body: String },
      3: { title: String, body: String },
      2: { title: String, body: String },
      1: { title: String, body: String },
    }
  }
}
```

---

## PART 4: THREE-PROFILE DESIGN GUIDE

### Heart Profile (Feel / UX / Casual)

**Who they are:** The majority user. Low patience, high aesthetic standards, surface-level domain knowledge. Will abandon at first friction.

**They test:** Visual polish, animations, feedback loops, mobile responsiveness, onboarding friction, dopamine moments, dead air, first impressions, social/sharing features, language accessibility.

**They miss:** Backend bugs that don't surface visually, subtle data errors, missing depth features, edge cases requiring domain expertise.

**Device:** Mobile. Non-negotiable â€” the Heart profile always tests at mobile viewport because UX sins are most visible there.

**Decision pattern:** Fast, impulsive, picks whatever looks most exciting, tolerates randomness, explores broadly but shallowly.

**Deal breakers:** More than {N} steps to first result, ugly/dated UI, jargon without explanation, slow loading (>3s), mandatory account creation before value, walls of text.

### Body Profile (Execution / Logic / Power User)

**Who they are:** The power user. Knows the domain, compares to competitors, wants depth and reliability.

**They test:** Core logic correctness, input responsiveness, strategic/functional depth, fairness, balance, performance, error handling, competitive features, skill expression, data persistence, multi-session workflows.

**They miss:** Aesthetic issues that don't affect function, narrative coherence, onboarding friction (they already know how to use it), social features, accessibility.

**Device:** Desktop. Needs precision input and full-screen data visibility.

**Decision pattern:** Fast but precise, always picks the optimal option, intolerant of errors and lag, exploits edge cases, pushes the system to its limits.

**Deal breakers:** Generic/non-personalized output, missing features competitors have, no way to save/reference past work, inconsistent or unreliable service.

### Mind Profile (Knowledge / Depth / Expert)

**Who they are:** The expert evaluator. Most demanding, evaluates against professional standards. Small audience, outsized influence on reputation.

**They test:** Data transparency, configuration depth, domain accuracy, narrative/informational coherence, progression systems, methodology transparency, content quality, safety/compliance disclaimers, export quality, accessibility compliance.

**They miss:** Performance issues (they're patient), mobile UX (desktop user), social features (solo user), surface-level polish (looks past it to substance).

**Device:** Desktop. Needs screen real estate for data analysis.

**Decision pattern:** Deliberate, reads everything, optimizes within a self-imposed methodology, sticks with one configuration, plans ahead.

**Deal breakers:** Any accuracy/calculation errors, missing methodology transparency, fundamental domain mistakes, no attribution or professional credibility.

### Profile Design Rules

1. **Name them** with real first and last names â€” makes test output readable and gives the team shared vocabulary.
2. **Assign percentages** summing to ~100% â€” creates natural triage priority.
3. **Define deal-breakers** â€” these become highest-priority test assertions.
4. **Write their review voice** â€” how each persona actually talks. Casual uses informal language. Expert uses professional terminology.
5. **Document fully** in `docs/testing/simulated-user-profiles.md`.

---

## PART 5: OBSERVER SNAPSHOT SCHEMA

The app-observer captures this structure at every interaction step:

```js
{
  step: Number,                  // Sequential step counter
  screen: String,                // Current screen/view identifier
  phase: String,                 // Current phase within the screen
  timestamp: String,             // ISO timestamp

  // Application state snapshot (DOMAIN-SPECIFIC â€” adapt to your app)
  appState: {
    // Whatever state your app exposes that profiles need to evaluate.
    // Examples: user data, scores, progress, configuration, inventory, etc.
  },

  // Available choices at this step
  availableOptions: [
    { id: String, label: String, metadata: Object }
  ],

  // What the profile chose and why
  decision: {
    chosen: String,              // ID or label of chosen option
    reason: String,              // Which weight dominated: "optimal (0.6 weight)"
    alternativesConsidered: Number,
  },

  // UI quality signals (from ui-auditor)
  uiSignals: {
    screenClean: Boolean,        // No overlaps, overflows, ghost elements
    feedbackPresent: Boolean,    // Visual/text feedback appeared after action
    transitionSmooth: Boolean,   // Screen transition < 300ms
    contentReadable: Boolean,    // No text clipping, proper sizing
    violations: [String],        // Specific CSS/layout issues found
  },

  // Timing
  timing: {
    decisionTime: Number,        // ms the profile "spent" deciding
    screenTransition: Number,    // ms from action to next screen render
    totalStepTime: Number,       // Total ms for this step
  }
}
```

---

## PART 6: DECISION ENGINE LOGIC

The player-sim decision engine follows this algorithm at every choice point:

```
1. Observer captures current state + available options
2. For each available option, compute a score:
   a. optimal_score    = profile.decision_weights.optimal    Ã— option.objective_value
   b. exploratory_score = profile.decision_weights.exploratory Ã— option.novelty
   c. aesthetic_score   = profile.decision_weights.aesthetic   Ã— option.visual_appeal
   d. consistent_score  = profile.decision_weights.consistent  Ã— option.consistency_with_history
   e. total_score = sum of above
3. Add noise based on profile.decision_style.speed:
   - "fast"       â†’ high noise (Â±30%), simulates impulsive choosing
   - "moderate"   â†’ medium noise (Â±15%)
   - "deliberate" â†’ low noise (Â±5%), nearly deterministic
4. Select highest-scoring option after noise
5. Simulate timing based on profile.decision_style.speed
6. Simulate misclick probability based on speed + device
7. Record decision with reason string for review
```

**How to score options:** The `objective_value`, `novelty`, `visual_appeal`, and `consistency_with_history` metrics are domain-specific. Claude Code must implement these scorers based on the actual app's options. Examples:
- A game scores `objective_value` by damage output or win probability
- A productivity app scores `objective_value` by task completion efficiency
- A creative tool scores `aesthetic` by output visual quality
- An informational app scores `novelty` by whether the user has seen this content before

---

## PART 7: SCORING FRAMEWORK

### Base Scorer Class

```javascript
export class SimulatedUserScorer {
  constructor(personaName, archetype, personaLabel, userPercentage) {
    this.personaName = personaName;
    this.archetype = archetype;
    this.personaLabel = personaLabel;
    this.userPercentage = userPercentage;
    this.scores = [];
    this.timings = [];
    this.notMeasurable = [];
    this.sessionStart = Date.now();
  }

  record(category, score, note) {
    this.scores.push({
      category,
      score: Math.min(5, Math.max(0, score)),
      note,
    });
  }

  recordTiming(label, ms) {
    this.timings.push({ label, ms });
  }

  recordNotMeasurable(area, reason, profileWeight) {
    this.notMeasurable.push({ area, reason, profile_weight: profileWeight });
  }

  overallScore() {
    if (this.scores.length === 0) return 0;
    return parseFloat(
      (this.scores.reduce((a, s) => a + s.score, 0) / this.scores.length).toFixed(1)
    );
  }

  starRating(score) {
    const full = Math.round(score);
    return '[' + 'â˜…'.repeat(full) + 'â˜†'.repeat(5 - full) + ']';
  }

  _bar(score) {
    const filled = Math.round(score);
    return '[' + '#'.repeat(filled) + '-'.repeat(5 - filled) + ']';
  }

  generateReport() {
    const overall = this.overallScore();
    const sessionSec = Math.round((Date.now() - this.sessionStart) / 1000);
    const divider = '='.repeat(70);
    const lines = [
      '', divider,
      `SIMULATED USER REPORT: ${this.personaName}`,
      `  Archetype: ${this.archetype} | Label: ${this.personaLabel} | Segment: ${this.userPercentage}`,
      divider,
      `Overall Score: ${overall}/5.0  ${this.starRating(overall)}`,
      `Session Duration: ${sessionSec}s`,
      '', 'Category Scores:',
    ];

    const maxLen = Math.max(...this.scores.map(s => s.category.length), 10);
    for (const { category, score, note } of this.scores) {
      const pad = ' '.repeat(maxLen - category.length + 2);
      lines.push(`  ${category}${pad}${score.toFixed(1)}/5.0  ${this._bar(score)}  -- ${note}`);
    }

    if (this.timings.length > 0) {
      lines.push('', 'Timings:');
      for (const { label, ms } of this.timings) lines.push(`  ${label}: ${ms}ms`);
    }

    const critical = this.scores.filter(s => s.score < 3.0);
    if (critical.length > 0) {
      lines.push('', 'CRITICAL ISSUES (score < 3.0):');
      for (const { category, score, note } of critical)
        lines.push(`  [FAIL] ${category}: ${score.toFixed(1)} -- ${note}`);
    }

    if (this.notMeasurable.length > 0) {
      lines.push('', 'NOT MEASURABLE (feature roadmap candidates):');
      for (const { area, reason, profile_weight } of this.notMeasurable)
        lines.push(`  [---] ${area} (weight: ${profile_weight}) -- ${reason}`);
    }

    const review = this._generateReview(overall);
    lines.push('', 'Simulated App Store Review:',
      `  Rating: ${Math.round(overall)}/5 stars`,
      `  Title: "${review.title}"`,
      `  Body: "${review.body}"`,
      divider, '');

    return lines.join('\n');
  }

  // Returns structured JSON for machine consumption
  generateJSON() {
    const overall = this.overallScore();
    return {
      reviewer: this.personaName,
      archetype: this.archetype,
      persona_label: this.personaLabel,
      user_percentage: this.userPercentage,
      sessions_played: 1,
      device: this.archetype === 'heart' ? 'mobile' : 'desktop',
      version: this._getNextVersion(),

      rating: {
        overall,
        stars: Math.round(overall),
        by_territory: {
          presentation: this._avgForCategories(['visual_quality', 'comprehension',
            'emotional_tone', 'navigation', 'sharing']),
          core_logic: this._avgForCategories(['end_to_end_journey', 'edge_case_handling',
            'error_recovery', 'interactive_features', 'performance']),
          depth_coherence: this._avgForCategories(['personalization', 'takeaway_value',
            'help_system', 'data_persistence', 'domain_accuracy']),
        }
      },

      scores: this.scores,
      timings: this.timings,
      not_measurable: this.notMeasurable,

      critical_issues: this.scores.filter(s => s.score < 3.0),
      review: this._generateReview(overall),
    };
  }

  _avgForCategories(cats) {
    const matching = this.scores.filter(s => cats.includes(s.category));
    if (matching.length === 0) return null;
    return parseFloat(
      (matching.reduce((a, s) => a + s.score, 0) / matching.length).toFixed(1)
    );
  }

  _getNextVersion() {
    // Implementation: count existing report files in reports/ directory
    return 1;
  }

  /** Override in persona subclasses for voice-appropriate reviews. */
  _generateReview(overall) {
    if (overall >= 4.5) return { title: 'Exceptional', body: 'Highly recommend.' };
    if (overall >= 3.5) return { title: 'Pretty good', body: 'Room for improvement but solid.' };
    if (overall >= 2.5) return { title: 'Needs work', body: 'Several things felt rough.' };
    if (overall >= 1.5) return { title: 'Disappointing', body: 'Multiple issues, might not return.' };
    return { title: 'Unusable', body: 'Deal-breakers hit. Would uninstall.' };
  }
}
```

### Persona Subclass Template

```javascript
// Example: Heart / Casual persona scorer
export class HeartScorer extends SimulatedUserScorer {
  constructor() {
    super(
      '{HEART_NAME}',         // e.g., "Luna Martinez"
      'heart',
      'Casual User',
      '{HEART_PERCENTAGE}% of users'
    );
  }

  _generateReview(overall) {
    if (overall >= 4.5) return {
      title: '{HEART_5STAR_TITLE}',   // e.g., "Obsessed with this!"
      body: '{HEART_5STAR_BODY}'      // e.g., "So fun and easy! Already shared with friends."
    };
    if (overall >= 3.5) return {
      title: '{HEART_4STAR_TITLE}',
      body: '{HEART_4STAR_BODY}'
    };
    if (overall >= 2.5) return {
      title: '{HEART_3STAR_TITLE}',
      body: '{HEART_3STAR_BODY}'
    };
    if (overall >= 1.5) return {
      title: '{HEART_2STAR_TITLE}',
      body: '{HEART_2STAR_BODY}'
    };
    return {
      title: '{HEART_1STAR_TITLE}',
      body: '{HEART_1STAR_BODY}'
    };
  }
}

// Repeat pattern for BodyScorer and MindScorer with their respective voices.
```

### Star Rating Scale

| Stars | Score Range | Meaning |
|-------|-----------|---------|
| 5 | â‰¥ 4.5 | Exceptional â€” would recommend enthusiastically |
| 4 | â‰¥ 3.5 | Good â€” mostly satisfied, minor improvements needed |
| 3 | â‰¥ 2.5 | Adequate â€” some value but noticeable gaps |
| 2 | â‰¥ 1.5 | Disappointing â€” multiple issues, might not return |
| 1 | < 1.5 | Unusable â€” deal-breakers hit, would uninstall |

### Scoring Modes

**Standard Mode** (default for early development): Feature exists = 3.0+, feature works well = 4.0+.

**Brutal Mode** (for mature products nearing release): Feature exists = 2.0, feature works = 3.0, feature *excels* = 5.0.

```javascript
export const BRUTAL_THRESHOLDS = {
  PAGE_LOAD_EXCELLENT: 1000,
  PAGE_LOAD_GOOD: 2000,
  PAGE_LOAD_ACCEPTABLE: 3000,
  API_EXCELLENT: 200,
  API_GOOD: 500,
};

export function scorePerformance(loadTimeMs, type = 'page') {
  const t = BRUTAL_THRESHOLDS;
  if (type === 'page') {
    if (loadTimeMs < t.PAGE_LOAD_EXCELLENT) return 5;
    if (loadTimeMs < t.PAGE_LOAD_GOOD) return 4;
    if (loadTimeMs < t.PAGE_LOAD_ACCEPTABLE) return 3;
    return 2;
  }
  if (type === 'api') {
    if (loadTimeMs < t.API_EXCELLENT) return 5;
    if (loadTimeMs < t.API_GOOD) return 4;
    return 3;
  }
}

export function scoreCompleteness(elements) {
  const present = elements.filter(Boolean).length;
  const total = elements.length;
  if (present === total) return 5;
  if (present >= Math.ceil(total * 0.8)) return 4;
  if (present >= Math.ceil(total * 0.5)) return 3;
  if (present >= 1) return 2;
  return 1;
}
```

---

## PART 8: MOCK INFRASTRUCTURE

All simulated user tests must be deterministic. Mock every backend dependency.

### Mock API Handler

```javascript
// fixtures/mock-apis.js
import { PERSONA_DATA } from './mock-data.js';

export async function mockAPIs(page, overrides = {}) {
  const persona = overrides.persona;
  const data = persona ? PERSONA_DATA[persona] : PERSONA_DATA.default;

  await page.route('**/api/health', route =>
    route.fulfill({ status: 200, contentType: 'application/json',
      body: JSON.stringify({ status: 'ok' }) })
  );

  // Primary resource endpoint â€” adapt to your app
  await page.route('**/api/{PRIMARY_RESOURCE}', async route => {
    if (overrides.delay) await new Promise(r => setTimeout(r, overrides.delay));
    if (overrides.createError)
      return route.fulfill({ status: 500, body: '{"detail":"Server error"}' });
    return route.fulfill({ status: 200, contentType: 'application/json',
      body: JSON.stringify(data.resource) });
  });

  // Add routes for every API your app calls
}
```

### Mock Data

```javascript
// fixtures/mock-data.js
export const PERSONA_DATA = {
  heart: {
    name: '{HEART_NAME}',
    input: { /* form data this persona would enter â€” simple, minimal */ },
    resource: { /* the result they would receive â€” accessible format */ },
  },
  body: {
    name: '{BODY_NAME}',
    input: { /* more detailed, optimization-focused input */ },
    resource: { /* deeper result set with advanced metrics */ },
  },
  mind: {
    name: '{MIND_NAME}',
    input: { /* precise professional-grade input */ },
    resource: { /* maximum-detail result with methodology */ },
  },
};
```

---

## PART 9: TEST SUITES

### Test Structure â€” Two Approaches

This template supports two complementary testing approaches. Use **one or both** depending on project maturity:

**Approach A: Category-Based Tests (10â€“12 per persona)**  
Best for: Web/mobile apps, SaaS tools, informational products. Each test measures one category of experience with explicit assertions.

**Approach B: Session-Based Simulation (N sessions per persona)**  
Best for: Games, interactive tools, exploration-driven products. The decision engine plays full sessions, observer records everything, review-generator scores post-hoc.

Most projects benefit from starting with **Approach A** for clear, debuggable feedback, then layering **Approach B** for holistic session testing once the core is stable.

### Approach A: Category-Based Tests

```javascript
// simulated-users/heart.spec.js
import { test, expect } from '@playwright/test';
import { mockAPIs } from '../fixtures/mock-apis.js';
import { PERSONA_DATA } from '../fixtures/mock-data.js';
import { HeartScorer } from '../engine/scoring-framework.js';
import { completePrimaryFlow } from '../helpers/journey-helper.js';

const scorer = new HeartScorer();
const PERSONA = PERSONA_DATA.heart;

test.describe('{HEART_NAME} â€” Heart / Casual User', () => {
  test.beforeEach(async ({ page }) => {
    await page.setViewportSize({ width: 375, height: 812 }); // Mobile
    await mockAPIs(page, { persona: 'heart' });
  });

  test('End-to-end journey', async ({ page }) => {
    const start = Date.now();
    await page.goto('/');
    scorer.recordTiming('page_load', Date.now() - start);

    const flowTime = await completePrimaryFlow(page, PERSONA.input);
    scorer.recordTiming('flow_completion', flowTime);

    const resultVisible = await page.locator('[data-testid="result"]')
      .isVisible().catch(() => false);

    const totalTime = Date.now() - start;
    let score, note;
    if (resultVisible && totalTime < 20000) {
      score = 5; note = `Result in ${Math.round(totalTime / 1000)}s`;
    } else if (resultVisible) {
      score = 4; note = `Result delivered but took ${Math.round(totalTime / 1000)}s`;
    } else {
      score = 1; note = 'DEAL BREAKER: Completed flow but got no result';
    }
    scorer.record('end_to_end_journey', score, note);
  });

  test('Output comprehension for non-expert', async ({ page }) => {
    await page.goto('/{RESULT_ROUTE}');
    const text = (await page.locator('main').textContent() || '').toLowerCase();

    const accessible = ['{ACCESSIBLE_TERMS}'];
    const accessibleFound = accessible.filter(t => text.includes(t)).length;

    const jargon = ['{JARGON_TERMS}'];
    const jargonFound = jargon.filter(t => text.includes(t));

    let score, note;
    if (jargonFound.length === 0 && accessibleFound >= 3) {
      score = 5; note = `Accessible language, ${accessibleFound} friendly terms, no jargon`;
    } else if (jargonFound.length <= 2) {
      score = 4; note = `Minor jargon: ${jargonFound.join(', ')}`;
    } else {
      score = 2; note = `Too much jargon: ${jargonFound.join(', ')}`;
    }
    scorer.record('comprehension', score, note);
  });

  // ... 8-10 more tests following the same pattern ...

  test.afterAll(() => {
    console.log(scorer.generateReport());
    // Also write JSON: fs.writeFileSync('reports/heart_review_v{N}.json', ...)
  });
});
```

### Approach B: Session-Based Simulation

```javascript
// sim-runner.spec.js
import { test } from '@playwright/test';
import heartProfile from './profiles/heart.js';
import bodyProfile from './profiles/body.js';
import mindProfile from './profiles/mind.js';
import { PlayerSim } from './engine/player-sim.js';
import { AppObserver } from './engine/app-observer.js';
import { UIAuditor } from './engine/ui-auditor.js';
import { ReviewGenerator } from './engine/review-generator.js';

const SESSIONS_PER_PROFILE = 3;

test(`Heart profile â€” ${heartProfile.name}`, async ({ page }) => {
  await page.setViewportSize(heartProfile.viewport);
  const sim = new PlayerSim(heartProfile, new AppObserver(page), new UIAuditor(page));
  const logs = await sim.playSessions(SESSIONS_PER_PROFILE);
  const review = ReviewGenerator.generate(heartProfile, logs);
  ReviewGenerator.writeJSON(review, 'heart');
});

test(`Body profile â€” ${bodyProfile.name}`, async ({ page }) => {
  await page.setViewportSize(bodyProfile.viewport);
  const sim = new PlayerSim(bodyProfile, new AppObserver(page), new UIAuditor(page));
  const logs = await sim.playSessions(SESSIONS_PER_PROFILE);
  const review = ReviewGenerator.generate(bodyProfile, logs);
  ReviewGenerator.writeJSON(review, 'body');
});

test(`Mind profile â€” ${mindProfile.name}`, async ({ page }) => {
  await page.setViewportSize(mindProfile.viewport);
  const sim = new PlayerSim(mindProfile, new AppObserver(page), new UIAuditor(page));
  const logs = await sim.playSessions(SESSIONS_PER_PROFILE);
  const review = ReviewGenerator.generate(mindProfile, logs);
  ReviewGenerator.writeJSON(review, 'mind');
});

// Runs after all profiles â€” generates triangulated summary
test('Generate PRIORITY_FIXES', async () => {
  ReviewGenerator.generatePriorityFixes();
});
```

### Scoring Logic Patterns

**Pattern 1: Threshold-based** (timing / performance)
```javascript
if (totalTime < 15000) score = 5;
else if (totalTime < 25000) score = 4;
else if (totalTime < 40000) score = 3;
else score = 2;
```

**Pattern 2: Count-based** (feature presence)
```javascript
const found = expectedFeatures.filter(f => page.locator(f).isVisible());
if (found.length >= 10) score = 5;
else if (found.length >= 7) score = 4;
else if (found.length >= 4) score = 3;
else score = 2;
```

**Pattern 3: Deal-breaker** (critical requirements)
```javascript
if (contradictions.length === 0) score = 5;
else if (contradictions.length === 1) score = 3;
else score = 1; // Trust destroyed
```

### Test Category Reference

#### Heart / Casual User Tests (10â€“12)

| # | Category | Measures |
|---|----------|----------|
| 1 | End-to-end journey | Full flow completion + timing |
| 2 | Comprehension | Output readable for non-experts |
| 3 | Personalization | Result feels tailored |
| 4 | Emotional tone | Language is empowering, not anxiety-inducing |
| 5 | Edge case handling | Graceful fallback for missing/partial input |
| 6 | Help system | Tooltips/glossary for domain terms |
| 7 | Sharing | Social media / export for casual sharing |
| 8 | Takeaway value | Actionable result they can use |
| 9 | Visual quality | Modern, intentional design |
| 10 | Navigation | Intuitive wayfinding |
| 11 | Error recovery | Friendly errors, no lost work |
| 12 | Interactive features | Secondary flows, chat, exploration |

#### Body / Power User Tests (10â€“12)

| # | Category | Measures |
|---|----------|----------|
| 1 | Full journey (detailed input) | Methodology transparency |
| 2 | Depth of personalization | Specifics referenced in output |
| 3 | Advanced analysis | Domain-specific deep features |
| 4 | Actionable output | Specific, not generic recommendations |
| 5 | Structured planning | Timeline, steps, priorities |
| 6 | Interaction quality | Multi-turn context retention |
| 7 | Feature completeness | All expected features present |
| 8 | AI authenticity | Genuine content vs fluff detection |
| 9 | Data persistence | Survives reload/session break |
| 10 | Interactive elements | Hover states, tooltips, interactivity |
| 11 | Real-time features | Live / current data |
| 12 | Navigation depth | Section tracking, deep linking |

#### Mind / Expert User Tests (10â€“12)

| # | Category | Measures |
|---|----------|----------|
| 1 | Technical completeness | All expected data/calculations |
| 2 | Professional data views | Tables, precise numbers, exportable |
| 3 | Domain accuracy | Verified against known-correct data |
| 4 | Interpretation depth | Expert-level markers present |
| 5 | Accuracy validation | No contradictions to known inputs |
| 6 | Methodology transparency | Attribution, approach described |
| 7 | Safety/compliance | Disclaimers, no overstepping |
| 8 | Professional presentation | Structured, print-worthy |
| 9 | Export quality | PDF/document professionally formatted |
| 10 | Data accuracy | Live data correct and current |
| 11 | Technical rendering | Visualizations technically correct |
| 12 | Accessibility | WCAG, semantic HTML, ARIA |

---

## PART 10: PRIORITY_FIXES OUTPUT FORMAT

After all profiles run, the review-generator produces a triangulated priority list:

```markdown
# PRIORITY_FIXES v{N} â€” {DATE}

## Cross-Profile Agreement (fix these first)
Issues flagged by ALL THREE profiles, ranked by combined severity.

| # | Area | Severity | Heart | Body | Mind | Detail |
|---|------|----------|-------|------|------|--------|
| 1 | {x}  | critical | ðŸ”´    | ðŸ”´   | ðŸ”´   | {detail} |

## Two-Profile Agreement
Issues flagged by exactly 2 profiles.

| # | Area | Severity | Flagged By | Detail |
|---|------|----------|------------|--------|

## Single-Profile Issues
Issues flagged by only 1 profile, grouped by archetype.

### Heart-Only Issues
### Body-Only Issues
### Mind-Only Issues

## Feature Roadmap (Not Yet Measurable)
Aggregated from all profiles' not_measurable arrays, sorted by combined weight.

| # | Area | Combined Weight | Profiles Requesting | Reason |
|---|------|----------------|--------------------|---------| 

## Score Comparison vs Previous Run

| Profile | v{N-1} | v{N} | Delta |
|---------|--------|------|-------|
| Heart   | {x}    | {y}  | {+/-} |
| Body    | {x}    | {y}  | {+/-} |
| Mind    | {x}    | {y}  | {+/-} |
```

---

## PART 11: TEST RUNNER CONFIGURATION

### Playwright Config

```javascript
// playwright.config.js
import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  timeout: 30000,
  retries: 0,              // No retries â€” honest scores only
  fullyParallel: false,     // Tests share scorer state within persona
  reporter: [['list']],

  use: {
    baseURL: 'http://localhost:{DEV_PORT}',
    headless: true,
    screenshot: 'only-on-failure',
    trace: 'retain-on-failure',
  },

  projects: [
    {
      name: 'e2e',
      testDir: './tests/e2e',
      testIgnore: ['**/simulation/**'],
    },
    {
      name: 'simulated-users-categories',
      testDir: './tests/simulation/simulated-users',
      timeout: 60000,
    },
    {
      name: 'simulated-users-sessions',
      testDir: './tests/simulation',
      testMatch: 'sim-runner.spec.js',
      timeout: 120000,
    },
  ],

  webServer: {
    command: '{DEV_SERVER_COMMAND}',
    port: '{DEV_PORT}',
    reuseExistingServer: true,
    timeout: 15000,
  },
});
```

### NPM Scripts

```json
{
  "scripts": {
    "test:e2e": "playwright test --project=e2e",
    "test:sim:categories": "playwright test --project=simulated-users-categories",
    "test:sim:sessions": "playwright test --project=simulated-users-sessions",
    "test:sim": "playwright test --project=simulated-users-categories --project=simulated-users-sessions",
    "test:all": "playwright test"
  }
}
```

---

## PART 12: THE ITERATION LOOP

```
â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
â”‚  1. RUN                                                 â”‚
â”‚     npm run test:sim                                    â”‚
â”‚     â†’ All 3 profiles test independently                 â”‚
â”‚     â†’ Each at their designated viewport                 â”‚
â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¬â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
                   â”‚
â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â–¼â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
â”‚  2. REVIEW                                              â”‚
â”‚     â†’ reports/heart_review_v{N}.json                    â”‚
â”‚     â†’ reports/body_review_v{N}.json                     â”‚
â”‚     â†’ reports/mind_review_v{N}.json                     â”‚
â”‚     â†’ reports/PRIORITY_FIXES_v{N}.md                    â”‚
â”‚       - Cross-profile issue triangulation               â”‚
â”‚       - Priority-ranked fix list                        â”‚
â”‚       - Score comparison vs previous run                â”‚
â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¬â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
                   â”‚
â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â–¼â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
â”‚  3. IMPROVE                                             â”‚
â”‚     â†’ Read PRIORITY_FIXES, fix top-priority items       â”‚
â”‚     â†’ Cross-profile issues first                        â”‚
â”‚     â†’ Then two-profile, then single-profile             â”‚
â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¬â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
                   â”‚
â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â–¼â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
â”‚  4. RE-RUN (version auto-increments)                    â”‚
â”‚     â†’ PRIORITY_FIXES_v{N+1}.md compares vs v{N}        â”‚
â”‚     â†’ "Heart: 3.2 â†’ 4.1 (+0.9)"                        â”‚
â”‚     â†’ Repeat until all profiles score target            â”‚
â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
```

### Triage Priority

1. **Any score < 3.0** â†’ Critical. Fix before release.
2. **Heart scores < 4.0** â†’ Highest priority (largest segment).
3. **Body scores < 3.5** â†’ Important for retention.
4. **Mind scores < 3.0** â†’ Credibility risk.

### Target Scores by Maturity

| Maturity Level | Heart | Body | Mind | Meaning |
|---------------|-------|------|------|---------|
| Alpha | 2.5+ | 2.5+ | 2.5+ | Core works, rough edges everywhere |
| Beta | 3.5+ | 3.5+ | 3.5+ | Usable, some gaps and polish needed |
| Release | 4.0+ | 4.0+ | 4.0+ | Good product, minor improvements possible |
| Polished | 4.5+ | 4.5+ | 4.5+ | Professional quality across all dimensions |

### Tracking Over Time

```
Date        Heart   Body    Mind    Notes
{DATE_1}    2.1     1.8     1.5     Initial implementation
{DATE_2}    3.2     2.8     2.3     First polish pass
{DATE_3}    3.8     3.5     3.2     UX improvements + error handling
{DATE_4}    4.3     4.0     3.8     Feature completeness + accessibility
{DATE_5}    4.6     4.3     4.2     Production-ready polish
```

---

## PART 13: WHAT'S MEASURABLE TODAY VS FLAGGED FOR LATER

**Always measurable via Playwright:**
- Screen transition timing (click â†’ next screen ms)
- Visual feedback presence (elements appearing after actions)
- CSS violations (overlaps, overflows, inline styles, clipping)
- Option count per decision point (depth proxy)
- Task completion rate (does the workflow finish?)
- Content presence (are elements populated?)
- Responsive behavior across viewports
- Error state handling (do error messages appear?)
- DOM structure / semantic HTML / ARIA attributes

**Typically not measurable (flagged as feature roadmap):**
- Sound/audio design
- Haptic feedback
- Real-time multiplayer behavior
- Persistent data across sessions (unless the test runner manages state)
- Third-party API response quality
- Accessibility beyond DOM inspection (screen reader behavior)
- Actual human emotional response

---

## PART 14: DOMAIN ADAPTATION GUIDE

### For Games
- Setup = character/configuration selection
- Decision points = turn-by-turn or real-time action choices
- Heart cares about: animations, sound, drama, social play
- Body cares about: skill expression, optimal play, competitive depth, balance
- Mind cares about: character building, stat transparency, lore, progression

### For Web/Mobile Apps (SaaS, Tools)
- Setup = onboarding, configuration, account creation
- Decision points = feature usage, navigation, data entry
- Heart cares about: onboarding flow, visual design, collaboration features
- Body cares about: speed, keyboard shortcuts, bulk operations, reliability
- Mind cares about: data accuracy, export quality, customization depth

### For Creative Tools
- Setup = project creation, tool selection, canvas setup
- Decision points = tool usage, layer management, export choices
- Heart cares about: inspiration, sharing, community features
- Body cares about: performance, precision tools, undo/redo reliability
- Mind cares about: professional output, format support, workflow coherence

### For Educational / Informational Apps
- Setup = profile creation, topic selection, difficulty setting
- Decision points = content navigation, quiz responses, exploration
- Heart cares about: engagement, gamification, social learning
- Body cares about: content accuracy, assessment fairness, progress tracking
- Mind cares about: depth of material, citation quality, pedagogical coherence

---

## PART 15: KEY DESIGN DECISIONS

1. **Build on existing E2E tests, not from scratch.** If you already have tests, extract their validators into ui-auditor.js and make the infrastructure profile-aware. Don't rewrite what works.

2. **Profiles are config, not code.** One decision engine, N personality configs. Adding a 4th profile is just a new JSON file with no engine changes.

3. **Observer is independent of player.** The observer captures state at every step regardless of who's driving. Future extension: record real human sessions through the same observer.

4. **JSON-first reporting.** Every review is a structured JSON file. Markdown summaries and PRIORITY_FIXES are generated FROM the JSON. Enables tooling, dashboards, and automated triage.

5. **Version tracking is file-based.** Each run stamps v{N} based on how many report sets exist in reports/. Simple, no database needed, git-friendly.

6. **Viewport is profile-bound.** Heart always runs mobile. Body and Mind always run desktop. This is a permanent trait, not configurable per-run.

7. **Parallel test isolation.** Each profile is its own Playwright `test()` block. If one crashes, the others still complete. Never let one failure blind all three perspectives.

8. **"Not measurable" is the feature roadmap.** Every unmeasurable criterion appears in every review as a missing feature. After several iteration cycles, the not_measurable list IS your backlog.

9. **Deterministic mocks.** All backend dependencies are mocked for reproducible scores. Mock data is persona-specific â€” casual users get simple inputs, experts get complex ones.

10. **Two testing approaches coexist.** Category-based tests give debuggable per-feature scores. Session-based simulation gives holistic user experience evaluation. Use both.

---

## PART 16: IMPLEMENTATION SEQUENCE

Build in this order. Each step depends on the previous.

| Step | Component | Why This Order |
|------|-----------|---------------|
| 1 | **ui-auditor.js** | Foundation â€” CSS validators, domain-agnostic, reusable across all profiles |
| 2 | **app-observer.js** | Must capture state before anything can evaluate it. Wire into DOM |
| 3 | **profiles/*.js** | Pure data files following the schema. One per archetype, customized for domain |
| 4 | **fixtures/mock-apis.js + mock-data.js** | Deterministic test infrastructure with persona-specific data |
| 5 | **helpers/journey-helper.js** | Shared flow automation for the primary user journey |
| 6 | **engine/scoring-framework.js** | Base scorer + 3 persona subclasses with voice-appropriate reviews |
| 7 | **engine/player-sim.js** | Decision engine â€” reads profile config + observer snapshot â†’ produces action |
| 8 | **engine/review-generator.js** | Scoring + PRIORITY_FIXES triangulation merge |
| 9 | **Category test specs** | 10â€“12 tests per persona following category guides |
| 10 | **sim-runner.spec.js** | Playwright orchestrator with parallel profile isolation |
| 11 | **Playwright config** | Add simulated-users projects |
| 12 | **First baseline run** | Generate initial scores |
| 13 | **Version comparison** | Add delta tracking to PRIORITY_FIXES for iteration loop |

---

## APPENDIX A: VARIABLE SUBSTITUTION REFERENCE

| Variable | Description | Example |
|----------|-------------|---------|
| `{PROJECT_ROOT}` | Project root directory | `my-app/` |
| `{HEART_NAME}` | Heart persona full name | `Luna Martinez` |
| `{HEART_PERCENTAGE}` | % of users this persona represents | `60` |
| `{BODY_NAME}` | Body persona full name | `Marcus Chen` |
| `{BODY_PERCENTAGE}` | % of users | `25` |
| `{MIND_NAME}` | Mind persona full name | `Dr. Sage Williams` |
| `{MIND_PERCENTAGE}` | % of users | `15` |
| `{HEART_VIEWPORT}` | Mobile viewport dimensions | `{ width: 375, height: 812 }` |
| `{DESKTOP_VIEWPORT}` | Desktop viewport dimensions | `{ width: 1920, height: 1080 }` |
| `{PRIMARY_RESOURCE}` | Main API resource path | `readings`, `reports`, `analyses` |
| `{RESULT_ROUTE}` | URL path to result view | `result/test-id` |
| `{ACCESSIBLE_TERMS}` | Words casual users understand | Domain-accessible vocabulary |
| `{JARGON_TERMS}` | Words casual users don't understand | Technical domain vocabulary |
| `{DEV_PORT}` | Local dev server port | `5173` |
| `{DEV_SERVER_COMMAND}` | Command to start dev server | `npm run dev` |
| `{HEART_5STAR_TITLE}` | Review title in casual voice | `Obsessed with this!` |
| `{HEART_5STAR_BODY}` | Review body in casual voice | `So fun and easy! Already shared.` |
| `{APP_URL}` | Local dev server URL | `http://localhost:5173` |
| `{SESSIONS_PER_PROFILE}` | Sessions per test run | `3` |
| `{TARGET_MATURITY}` | Score threshold for "done" | `4.0` |

---

## APPENDIX B: AGENT IMPLEMENTATION CHECKLIST

- [ ] Read this template fully before starting
- [ ] Identify the app's core user journey (the primary flow each profile will execute)
- [ ] Identify all decision points in the journey (where the user makes choices)
- [ ] Identify all observable state (what can be read from the DOM at each step)
- [ ] Design 3 profiles using the archetype guide (Part 4)
- [ ] Customize the evaluation criteria categories for your domain (Part 14)
- [ ] Write profile configs following the schema (Part 3)
- [ ] Write full persona profiles in `docs/testing/simulated-user-profiles.md`
- [ ] Build `ui-auditor.js` (extract from existing tests if available)
- [ ] Build `app-observer.js` with domain-specific state capture
- [ ] Create `mock-apis.js` with route handlers for all backend APIs
- [ ] Create `mock-data.js` with persona-specific test datasets
- [ ] Create `journey-helper.js` with shared flow automation
- [ ] Create `scoring-framework.js` with base class + 3 persona subclasses
- [ ] Build `player-sim.js` with weighted decision engine (if using session-based testing)
- [ ] Build `review-generator.js` with scoring + PRIORITY_FIXES triangulation
- [ ] Write 10â€“12 category tests per persona following the category guides
- [ ] Build `sim-runner.spec.js` with parallel profile isolation (if using session-based testing)
- [ ] Configure Playwright with simulated-users projects
- [ ] Run first iteration and generate baseline scores
- [ ] Use PRIORITY_FIXES to guide improvements
- [ ] Re-run after every significant change to track improvements
- [ ] Repeat until target maturity level reached

---

## APPENDIX C: ADAPTATION NOTES

### For Backend/API-Only Products
Skip Playwright browser automation. Use your language's test framework, mock at the HTTP client level, score API response quality instead of UI quality. Same report format, same triangulation.

### For Non-JavaScript Projects
Port `SimulatedUserScorer` to Python/Go/Rust/etc. The patterns are language-agnostic: record scores with notes, track timings, generate reports, produce persona-voiced reviews.

### Adding Personas for New Product Tiers
When the product grows (e.g., premium tier), add personas: write their profile, create a scorer subclass, write 10â€“12 tests, add a Playwright project. The system scales linearly.

### Known Results from This Methodology
Systems implementing this pattern have identified: icon-only buttons without aria-labels, toggle switches missing keyboard support, jargon comprehension gaps for casual users, AI-generated fluff patterns in outputs, error recovery UX gaps, missing features visible in competitor comparisons, and tracked quality from ~2.0 average to 4.0+ over 4 weeks of iteration.

---

*This template was forged through two independent projects â€” one building persona-driven app testing, the other building triangulated game simulation â€” and unified into a single system. The conclusion from both: when three different humans tell you what's wrong with your app, you know exactly what to fix next.*