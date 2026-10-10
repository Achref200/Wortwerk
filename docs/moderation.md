# Community moderation (development slice)

## Current controls

- Public groups are curated and published by trusted tooling.
- Joining requires authentication, an age 16+ self-attestation, and acceptance
  of rules version 1. The system stores attestation time, not date of birth.
- Messages are plain text, 1–2,000 characters, reject links and control
  characters, and are limited to 10 per member per 10 seconds.
- Message writes are callable-only and idempotent. A member may report a
  message once. Three distinct reporters hide it from group message reads.
- Members can block another member; the client filters blocked authors from
  the visible conversation.

These are early safeguards, not a complete moderation program. The current
block filter is client-side, so Firestore still returns visible messages from
blocked users to a group member. The app has no profanity or German-learning
scope filter, human moderator console, appeals, moderator response tracking,
group creation, or direct messages.

## Operator review

1. Open the Firebase Console for the development or staging project and inspect
   `reports` and `groups/{groupId}/messages/{messageId}`.
2. Verify the report refers to the message and review its reason and timestamp.
   Do not copy learner content into external services.
3. A message reported by three distinct members is hidden automatically. For
   an earlier urgent safety issue, use the trusted Admin SDK workflow to set
   the message's `status` to `hidden` and record the action through the team's
   approved incident process.
4. Document the review outcome, action, and owner in the team's restricted
   support system. Do not store sensitive incident details in public group
   documents.

Before production, assign a staffed review owner and response target, build a
moderator tool with an auditable action log, define an appeals and escalation
policy, and test query privacy for blocked users. Confirm age, consent,
retention, and reporting policies with the product owner for each launch
region. Direct messages remain disabled until mutual friendship, recipient
controls, reporting, block enforcement, and abuse response are implemented.
