# Contract: The Zone Lookup

This feature exposes no new HTTP route or form — it is a read-only display addition to existing,
already-authenticated screens. The "contract" every touched controller/view depends on is the small,
shared Ruby interface below (see `data-model.md` for full field detail; `research.md` R1–R3 for rationale).

## `LockerMapEntry.zone_names_for(pairs) -> Hash`

**Guarantees**:
- Never raises for a `nil` or blank `floor`/`locker_number` in any pair — such a pair is simply normalized
  away and never present as a key in the result.
- Never issues more than one database query, regardless of `pairs.size`.
- Returns `{}` for an empty or all-blank input, without querying.
- A pair present in the Locker Map today is always present in the result at the moment of the call; a
  rename, a locker's removal from its zone, or the zone's deletion is reflected on the very next call —
  there is no caching layer to invalidate.

**Callers depend on**: batching every row's pair once per request (admin account directory, locker search
list, swap-history table) rather than calling this once per row.

## `LockerMapEntry.zone_name_for(floor, locker_number) -> String | nil`

**Guarantees**: identical to `.zone_names_for` for a single pair; returns `nil` (not `""` or an exception)
when the pair is not currently declared, when the Locker Map has never had anything declared in it, or when
`floor`/`locker_number` is blank.

**Callers depend on**: `nil` being the one and only "don't show a zone" signal — every view checks `if
zone_name` (or equivalent presence check), never a separate error path (FR-005).

## `LockerSwapProposal#locker_sides -> [[floor, locker_number], [floor, locker_number]]`

**Guarantees**: always returns exactly two pairs, in `[requester_side, recipient_side]` order, using live
attributes for a `pending?`/`accepted?` proposal and the frozen `*_at_resolution` attributes for a settled
one — the same source `floor_and_locker_summary` already reads, so the two never disagree about which
floor/locker a given proposal is "about" at any point in its lifecycle.

**Callers depend on**: being able to pass the flattened result of many proposals' `#locker_sides` straight
into a single `LockerMapEntry.zone_names_for` call, to resolve an entire history table's worth of zones in
one query.
