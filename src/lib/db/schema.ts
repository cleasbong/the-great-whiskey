import { pgTable, uuid, text, timestamp, decimal, integer, boolean, pgEnum, uniqueIndex, date } from 'drizzle-orm/pg-core';
import { relations } from 'drizzle-orm';

export const roleEnum = pgEnum('role', ['admin', 'member']);

export const members = pgTable('members', {
  id: uuid('id').defaultRandom().primaryKey(),
  name: text('name').notNull(),
  email: text('email').notNull().unique(),
  passwordHash: text('password_hash').notNull(),
  role: roleEnum('role').default('member').notNull(),
  avatarUrl: text('avatar_url'),
  invitedAt: timestamp('invited_at'),
  joinedAt: timestamp('joined_at').defaultNow(),
  active: boolean('active').default(true).notNull(),
});

export const bottles = pgTable('bottles', {
  id: uuid('id').defaultRandom().primaryKey(),
  name: text('name').notNull(),
  slug: text('slug').notNull().unique(),
  distillery: text('distillery'),
  region: text('region'),
  country: text('country'),
  type: text('type'),
  age: integer('age'),
  abv: decimal('abv', { precision: 4, scale: 1 }),
  caskType: text('cask_type'),
  priceZar: integer('price_zar'),
  imageUrl: text('image_url'),
  description: text('description'),
  createdAt: timestamp('created_at').defaultNow(),
  createdBy: uuid('created_by').references(() => members.id),
});

export const meetings = pgTable('meetings', {
  id: uuid('id').defaultRandom().primaryKey(),
  title: text('title').notNull(),
  slug: text('slug').notNull().unique(),
  date: date('date').notNull(),
  location: text('location'),
  insights: text('insights'),
  published: boolean('published').default(false).notNull(),
  createdAt: timestamp('created_at').defaultNow(),
  createdBy: uuid('created_by').references(() => members.id),
});

export const meetingAttendees = pgTable('meeting_attendees', {
  meetingId: uuid('meeting_id').notNull().references(() => meetings.id, { onDelete: 'cascade' }),
  memberId: uuid('member_id').notNull().references(() => members.id, { onDelete: 'cascade' }),
}, (table) => ({
  pk: uniqueIndex('meeting_attendees_pk').on(table.meetingId, table.memberId),
}));

export const meetingBottles = pgTable('meeting_bottles', {
  meetingId: uuid('meeting_id').notNull().references(() => meetings.id, { onDelete: 'cascade' }),
  bottleId: uuid('bottle_id').notNull().references(() => bottles.id, { onDelete: 'cascade' }),
  tastingOrder: integer('tasting_order').notNull(),
}, (table) => ({
  pk: uniqueIndex('meeting_bottles_pk').on(table.meetingId, table.bottleId),
}));

export const scores = pgTable('scores', {
  id: uuid('id').defaultRandom().primaryKey(),
  meetingId: uuid('meeting_id').notNull().references(() => meetings.id, { onDelete: 'cascade' }),
  bottleId: uuid('bottle_id').notNull().references(() => bottles.id, { onDelete: 'cascade' }),
  memberId: uuid('member_id').notNull().references(() => members.id, { onDelete: 'cascade' }),
  score: decimal('score', { precision: 3, scale: 1 }).notNull(),
  note: text('note'),
  createdAt: timestamp('created_at').defaultNow(),
}, (table) => ({
  uniqueScore: uniqueIndex('unique_score').on(table.meetingId, table.bottleId, table.memberId),
}));

export const inviteTokens = pgTable('invite_tokens', {
  id: uuid('id').defaultRandom().primaryKey(),
  email: text('email').notNull(),
  token: text('token').notNull().unique(),
  expiresAt: timestamp('expires_at').notNull(),
  used: boolean('used').default(false).notNull(),
  createdBy: uuid('created_by').references(() => members.id),
});

// Relations
export const membersRelations = relations(members, ({ many }) => ({
  scores: many(scores),
  meetingAttendees: many(meetingAttendees),
}));

export const bottlesRelations = relations(bottles, ({ many }) => ({
  scores: many(scores),
  meetingBottles: many(meetingBottles),
}));

export const meetingsRelations = relations(meetings, ({ many }) => ({
  meetingAttendees: many(meetingAttendees),
  meetingBottles: many(meetingBottles),
  scores: many(scores),
}));

export const scoresRelations = relations(scores, ({ one }) => ({
  meeting: one(meetings, { fields: [scores.meetingId], references: [meetings.id] }),
  bottle: one(bottles, { fields: [scores.bottleId], references: [bottles.id] }),
  member: one(members, { fields: [scores.memberId], references: [members.id] }),
}));

export const meetingAttendeesRelations = relations(meetingAttendees, ({ one }) => ({
  meeting: one(meetings, { fields: [meetingAttendees.meetingId], references: [meetings.id] }),
  member: one(members, { fields: [meetingAttendees.memberId], references: [members.id] }),
}));

export const meetingBottlesRelations = relations(meetingBottles, ({ one }) => ({
  meeting: one(meetings, { fields: [meetingBottles.meetingId], references: [meetings.id] }),
  bottle: one(bottles, { fields: [meetingBottles.bottleId], references: [bottles.id] }),
}));
