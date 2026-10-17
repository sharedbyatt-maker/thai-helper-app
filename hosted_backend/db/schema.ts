import { sqliteTable, integer, text } from 'drizzle-orm/sqlite-core';
export const revisions = sqliteTable('revisions', {
  id: integer('id').primaryKey({ autoIncrement: true }),
  payload: text('payload').notNull(),
  publishedAt: text('published_at').notNull(),
});
export const drafts = sqliteTable('draft', {
  id: integer('id').primaryKey(),
  payload: text('payload').notNull(),
  version: integer('version').notNull().default(0),
});
export const admins = sqliteTable('admin_owner', {
  id: integer('id').primaryKey(),
  userId: text('user_id').notNull(),
});
export const telegramSettings = sqliteTable('telegram_settings', {
  id: integer('id').primaryKey(), sealed: text('sealed').notNull(), username: text('username').notNull(),
  ownerId: text('owner_id'), pairHash: text('pair_hash'), pairUntil: integer('pair_until'),
  generation: integer('generation').notNull().default(0),
});
export const telegramReceipts = sqliteTable('telegram_receipts', {
  id: text('id').primaryKey(), requestId: text('request_id').notNull(), revision: integer('revision'),
  response: text('response').notNull(), createdAt: integer('created_at').notNull(),
});
export const telegramPending = sqliteTable('telegram_pending', {
  id: text('id').primaryKey(), ownerId: text('owner_id').notNull(), payload: text('payload').notNull(),
  expires: integer('expires').notNull(), used: integer('used').notNull().default(0),
});
export const telegramSession = sqliteTable('telegram_session', {
  id: integer('id').primaryKey(), source: text('source').notNull(),
});

// One-use owner-confirmed replacements retain the prior price/draft data.
export const historyReplacements = sqliteTable('history_replacements', {
  id: text('id').primaryKey(), requestId: text('request_id').notNull(),
  createdAt: text('created_at').notNull(), appliedAt: text('applied_at'),
  backupJson: text('backup_json').notNull(), summaryJson: text('summary_json').notNull(),
});

export const alertSubscribers = sqliteTable('alert_subscribers', {
  chatId: text('chat_id').primaryKey(), bot: text('bot').notNull(), direction: text('direction').notNull(),
  mode: text('mode').notNull(), threshold: integer('threshold'), active: integer('active').notNull().default(1),
  version: integer('version').notNull().default(1), evaluatedRevision: integer('evaluated_revision').notNull().default(0),
  lastSignature: text('last_signature').notNull().default(''), createdAt: integer('created_at').notNull(),
});
export const alertOutbox = sqliteTable('alert_outbox', {
  id: text('id').primaryKey(), chatId: text('chat_id').notNull(), subscriptionVersion: integer('subscription_version').notNull(),
  revision: integer('revision').notNull(), payload: text('payload').notNull(), status: integer('status').notNull().default(0),
  attempts: integer('attempts').notNull().default(0), nextAttempt: integer('next_attempt').notNull().default(0),
});

// Removed publications remain recoverable without remaining public.
export const revisionTrash = sqliteTable('revision_trash', {
  id: integer('id').primaryKey(), payload: text('payload').notNull(),
  publishedAt: text('published_at').notNull(), deletedAt: text('deleted_at').notNull(),
  requestId: text('request_id').notNull(),
});
