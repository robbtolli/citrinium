---
# This is a top-level comment explaining the file.
citrinium:
  type: project # inline comment on a mapped value
  id: 7f3a2b1c
  outcome: "Ship v1.0 to TestFlight"
  status: active
  # a comment between keys
  area: Health
tags: [project, health] # flow-sequence with a trailing comment
anchors_demo: &shared
  note: "anchor target"
alias_demo: *shared
---
# Project: Ship v1.0

- [ ] First next action
