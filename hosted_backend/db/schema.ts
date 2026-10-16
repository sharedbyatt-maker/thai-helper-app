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
