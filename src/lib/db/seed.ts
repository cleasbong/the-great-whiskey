import { drizzle } from 'drizzle-orm/postgres-js';
import postgres from 'postgres';
import { hash } from 'bcryptjs';
import * as schema from './schema';

const connectionString = process.env.DATABASE_URL!;
const client = postgres(connectionString);
const db = drizzle(client, { schema });

async function seed() {
  console.log('Seeding database...');

  // Create members
  const passwordHash = await hash('changeme123', 12);
  const memberData = [
    { name: 'Nic', email: 'nic@thegreatwhiskey.com', role: 'admin' as const },
    { name: 'Reece', email: 'reece@thegreatwhiskey.com', role: 'member' as const },
    { name: 'Gilby', email: 'gilby@thegreatwhiskey.com', role: 'member' as const },
    { name: 'Ala', email: 'ala@thegreatwhiskey.com', role: 'member' as const },
    { name: 'Ethan', email: 'ethan@thegreatwhiskey.com', role: 'member' as const },
    { name: 'George', email: 'george@thegreatwhiskey.com', role: 'member' as const },
    { name: 'Alex', email: 'alex@thegreatwhiskey.com', role: 'member' as const },
    { name: 'LT', email: 'lt@thegreatwhiskey.com', role: 'member' as const },
  ];

  const members = await db.insert(schema.members).values(
    memberData.map(m => ({ ...m, passwordHash }))
  ).returning();

  const memberMap = Object.fromEntries(members.map(m => [m.name, m.id]));
  console.log('Members created:', Object.keys(memberMap));

  // Create bottles
  const bottleData = [
    {
      name: 'GlenDronach 12 Year Old',
      slug: 'glendronach-12',
      distillery: 'GlenDronach',
      region: 'Highland',
      country: 'Scotland',
      type: 'Single Malt',
      age: 12,
      abv: '43.0',
      caskType: 'Pedro Ximenez & Oloroso Sherry',
      priceZar: 900,
    },
    {
      name: 'Ardbeg Wee Beastie 5 Year Old',
      slug: 'ardbeg-wee-beastie',
      distillery: 'Ardbeg',
      region: 'Islay',
      country: 'Scotland',
      type: 'Single Malt',
      age: 5,
      abv: '47.4',
      caskType: 'Bourbon & Oloroso Sherry',
      priceZar: 550,
    },
    {
      name: 'Benriach 12 Year Old',
      slug: 'benriach-12',
      distillery: 'Benriach',
      region: 'Speyside',
      country: 'Scotland',
      type: 'Single Malt',
      age: 12,
      abv: '46.0',
      caskType: 'Sherry, Bourbon & Port',
      priceZar: 650,
    },
  ];

  const bottles = await db.insert(schema.bottles).values(bottleData).returning();
  const bottleMap = Object.fromEntries(bottles.map(b => [b.slug, b.id]));
  console.log('Bottles created:', Object.keys(bottleMap));

  // Create Meeting 1
  const [meeting] = await db.insert(schema.meetings).values({
    title: 'Session 1 - The Beginning',
    slug: 'session-1-the-beginning',
    date: '2025-11-01',
    published: true,
    insights: 'Our inaugural tasting session revealed the group has a clear preference for sherried whiskies. GlenDronach 12 was the unanimous winner with remarkable score consistency across all members.',
  }).returning();

  // Add all members as attendees
  await db.insert(schema.meetingAttendees).values(
    members.map(m => ({ meetingId: meeting.id, memberId: m.id }))
  );

  // Add bottles to meeting
  await db.insert(schema.meetingBottles).values([
    { meetingId: meeting.id, bottleId: bottleMap['ardbeg-wee-beastie'], tastingOrder: 1 },
    { meetingId: meeting.id, bottleId: bottleMap['glendronach-12'], tastingOrder: 2 },
    { meetingId: meeting.id, bottleId: bottleMap['benriach-12'], tastingOrder: 3 },
  ]);

  // Add scores
  const scoreData = [
    // GlenDronach 12
    { member: 'George', bottle: 'glendronach-12', score: '9.0', note: 'vanilla/citrus/nutty' },
    { member: 'Ala', bottle: 'glendronach-12', score: '8.4', note: 'sweet/vanilla' },
    { member: 'Alex', bottle: 'glendronach-12', score: '9.1', note: 'excellent' },
    { member: 'Gilby', bottle: 'glendronach-12', score: '7.8', note: 'Fruity/Dried' },
    { member: 'Ethan', bottle: 'glendronach-12', score: '8.8', note: 'Gun' },
    { member: 'Nic', bottle: 'glendronach-12', score: '8.5', note: 'Lucid' },
    { member: 'Reece', bottle: 'glendronach-12', score: '8.4', note: 'Amid-able' },
    { member: 'LT', bottle: 'glendronach-12', score: '8.3', note: 'amazing' },
    // Ardbeg Wee Beastie
    { member: 'George', bottle: 'ardbeg-wee-beastie', score: '7.5', note: 'Smokey' },
    { member: 'Ala', bottle: 'ardbeg-wee-beastie', score: '7.0', note: 'Boma by the ocean' },
    { member: 'Alex', bottle: 'ardbeg-wee-beastie', score: '7.8', note: 'piety' },
    { member: 'Gilby', bottle: 'ardbeg-wee-beastie', score: '8.2', note: 'Oaky/Smokey' },
    { member: 'Ethan', bottle: 'ardbeg-wee-beastie', score: '7.3', note: 'harsh' },
    { member: 'Nic', bottle: 'ardbeg-wee-beastie', score: '7.8', note: 'Ash' },
    { member: 'Reece', bottle: 'ardbeg-wee-beastie', score: '8.3', note: 'complicated' },
    { member: 'LT', bottle: 'ardbeg-wee-beastie', score: '7.0', note: 'fire' },
    // Benriach 12
    { member: 'George', bottle: 'benriach-12', score: '6.5', note: 'Spicy' },
    { member: 'Ala', bottle: 'benriach-12', score: '6.2', note: 'slight smoke, sweet on the lips' },
    { member: 'Alex', bottle: 'benriach-12', score: '7.0', note: 'light in a good way' },
    { member: 'Gilby', bottle: 'benriach-12', score: '7.4', note: 'scintillating' },
    { member: 'Ethan', bottle: 'benriach-12', score: '5.5', note: 'rough' },
    { member: 'Nic', bottle: 'benriach-12', score: '6.9', note: 'Vanilla' },
    { member: 'Reece', bottle: 'benriach-12', score: '8.7', note: 'scintillating' },
    { member: 'LT', bottle: 'benriach-12', score: '8.0', note: 'smooth' },
  ];

  await db.insert(schema.scores).values(
    scoreData.map(s => ({
      meetingId: meeting.id,
      bottleId: bottleMap[s.bottle],
      memberId: memberMap[s.member],
      score: s.score,
      note: s.note,
    }))
  );

  console.log('Scores seeded: 24 entries');
  console.log('Seed complete!');
  process.exit(0);
}

seed().catch(e => { console.error(e); process.exit(1); });
