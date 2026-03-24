Unslop profile for VMware technical blog posts for sysadmins.

---

## Phrases to never use

- "best practice" / "best practices" — in headers, subheaders, or body text
- "at scale" / "at enterprise scale"
- "zero downtime" / "zero-downtime" (as a promise or near-promise)
- "common pitfalls" / "common gotchas" (as a section title or anywhere)
- "in practice" (as an authority claim with no named environment)
- "production-grade" / "enterprise-grade" (as floating intensifiers)
- "in plain English"
- "keep in mind"
- "the elephant in the room"
- "one of the most important" / "the single most important"
- "battle-tested" / "proven" / "mature" / "robust" (as uncited credentials)
- "well within reach"
- "real-world example" (when what follows is a hypothetical)
- "Here's the thing" / "Here's the bottom line"
- "That's where [X] comes in"
- "Think of it like" / "Think of it as"
- "In other words" (when the restatement is equally technical)
- "The key insight:" / "The key difference:" / "The key architectural shift:"
- "The catch is:"
- "just [verb]" — as in "just enable NIOC," "just tag the objects"
- "straightforward" / "manageable" / "not steep" (re: learning curve) — especially in conclusions
- "well within reach"
- "most administrators" / "most environments" (without citing basis)

---

## Opening patterns to avoid

- The 2 AM Problem: opening with a relatable disaster scenario (server fails at 2 AM, big deadline coming) that positions the technology as the hero
- The Misconception Setup: opening with a rhetorical question the reader "probably" has ("aren't they basically the same thing?") then promising to resolve it
- The Direct Hook that assumes the reader's current state: "If you're still running NSX-V, you already know..."
- The Neutral One-Sentence Definition: "[Technology] is VMware's [adjective]-based [noun], giving you..."
- Using "you" within the first three sentences to claim shared experience the writer cannot have

---

## Closing patterns to avoid

- The Reassurance Close: minimizing difficulty after a body that described substantial complexity ("manageable," "the learning curve is real but not steep," "well within reach")
- The Pithy Verdict: two or three compressed sentences that pretend to resolve what the post didn't ("Both matter. Neither replaces the other.")
- The Comment-Bait Pivot: "Have questions about [topic]? Drop them in the comments."
- Any conclusion that contradicts the complexity described in the body

---

## Structural patterns to avoid

- The nine-section skeleton: hook → explainer → prerequisites → numbered procedure → configuration notes → "Common Pitfalls" → monitoring → reassuring close. If you are writing this structure, stop.
- A dedicated "Common Pitfalls" or "Common Gotchas" section. It performs exhaustiveness it cannot deliver. The actual pitfalls listed are generic across entirely different topics.
- Numbered implementation steps that present a multi-step process as a linear waterfall with no branching, no error states, and no rollback paths — then bury error handling in a separate "troubleshooting" section.
- Tables of numeric thresholds (CPU Ready %, RAM sizing, RPO targets) without citing VMware documentation or acknowledging environment dependency.
- Feature comparison tables followed by a "When to choose X vs Y" bullet list followed by "The Verdict."
- Self-referential phrases: "this guide walks you through," "by the end of this guide," "this walkthrough assumes."

---

## Rhetorical devices to avoid

- Analogies that end technical explanation rather than begin it: once the reader nods at the metaphor, never returning to the technical reality the metaphor glossed over
  - Specific analogies seen in the corpus to never reuse: "save game feature," "photocopying a document into a fireproof safe," "if Kubernetes is Linux, TKG is Red Hat," "a single shipping container"
- "But" as a one-word paragraph opener used to perform honesty while minimizing the complexity it just acknowledged
- The colon-assertion: "[claim]: [restatement of claim at same depth]"
- Parenthetical complexity-burying: putting the most operationally critical caveat in parentheses at the end of a sentence
- Rhetorical questions attributed to the reader ("Who does what?" "What's the difference?") that assume rather than learn the reader's actual confusion

---

## Tonal habits to avoid

- Hedging words ("typically," "usually," "often," "in most cases," "depending on") mixed with absolute commands ("never," "always," "must," "required," "critical") in the same paragraph — this creates the impression of nuance while asserting binary rules
- Performed candor: criticizing a VMware product or Broadcom pricing for one paragraph, then concluding with a recommendation for that product anyway
- False authority claims: "in practice," "proven," "battle-tested," "most administrators" — without a named environment, customer, version, or failure incident
- Complexity minimization in conclusions after the body established that complexity is real

---

## When you catch yourself reaching for any of the above

Stop. The pattern is a substitute for thinking. Write something specific instead: a specific version number, a specific failure mode you can name, a specific threshold and its source, a specific condition under which the advice does not apply. If you cannot be specific, say so rather than being generically authoritative.

Vary structure. Not every post needs prerequisites before procedure, or a gotchas section at all. Not every conclusion needs to reassure the reader. Not every comparison needs a verdict.
