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
