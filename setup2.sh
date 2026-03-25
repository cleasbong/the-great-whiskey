#!/bin/bash
set -e
echo "Setting up pages and Docker..."

# Login page
mkdir -p src/app/login
cat > src/app/login/page.tsx << 'LOGIN'
'use client';
import { useState } from 'react';
import { signIn } from 'next-auth/react';
import { useRouter } from 'next/navigation';

export default function LoginPage() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const router = useRouter();

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError('');
    const res = await signIn('credentials', { email, password, redirect: false });
    if (res?.error) { setError('Invalid email or password'); setLoading(false); return; }
    router.push('/dashboard');
  }

  return (
    <div className="min-h-[80vh] flex items-center justify-center">
      <div className="w-full max-w-md">
        <div className="bg-surface rounded-lg border border-border p-8">
          <h1 className="text-2xl font-bold text-center mb-2">Welcome back</h1>
          <p className="text-muted-foreground text-center text-sm mb-8">The Great Whiskey Members Area</p>
          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label className="block text-sm font-medium mb-2">Email</label>
              <input type="email" value={email} onChange={e => setEmail(e.target.value)} required
                className="w-full bg-surface-dark border border-border rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-1 focus:ring-whiskey" />
            </div>
            <div>
              <label className="block text-sm font-medium mb-2">Password</label>
              <input type="password" value={password} onChange={e => setPassword(e.target.value)} required
                className="w-full bg-surface-dark border border-border rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-1 focus:ring-whiskey" />
            </div>
            {error && <p className="text-red-400 text-sm">{error}</p>}
            <button type="submit" disabled={loading}
              className="w-full bg-whiskey text-surface-dark font-medium py-2 rounded-md hover:bg-whiskey-light transition-colors disabled:opacity-50">
              {loading ? 'Signing in...' : 'Sign in'}
            </button>
          </form>
        </div>
      </div>
    </div>
  );
}
LOGIN

# Bottles list page
mkdir -p src/app/bottles
cat > src/app/bottles/page.tsx << 'BOTTLES'
import Link from 'next/link';
import { db } from '@/lib/db';
import { bottles, scores } from '@/lib/db/schema';
import { avg, sql, desc } from 'drizzle-orm';

export default async function BottlesPage({ searchParams }: { searchParams: { region?: string; type?: string } }) {
  const allBottles = await db
    .select({
      id: bottles.id, name: bottles.name, slug: bottles.slug,
      distillery: bottles.distillery, region: bottles.region, country: bottles.country,
      type: bottles.type, age: bottles.age, abv: bottles.abv, priceZar: bottles.priceZar,
      avgScore: avg(scores.score).as('avg_score'),
    })
    .from(bottles)
    .leftJoin(scores, sql`${bottles.id} = ${scores.bottleId}`)
    .groupBy(bottles.id)
    .orderBy(desc(sql`avg_score`));

  const regions = [...new Set(allBottles.map(b => b.region).filter(Boolean))];
  const types = [...new Set(allBottles.map(b => b.type).filter(Boolean))];

  const filtered = allBottles.filter(b => {
    if (searchParams.region && b.region !== searchParams.region) return false;
    if (searchParams.type && b.type !== searchParams.type) return false;
    return true;
  });

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-3xl font-bold mb-2">Bottle Archive</h1>
        <p className="text-muted-foreground">Every whiskey the club has tried, ranked by average score.</p>
      </div>

      {/* Filters */}
      <div className="flex gap-4 flex-wrap">
        <Link href="/bottles" className={`px-3 py-1 rounded-full text-sm border ${!searchParams.region && !searchParams.type ? 'border-whiskey text-whiskey' : 'border-border text-muted-foreground hover:border-whiskey/50'}`}>All</Link>
        {regions.map(r => (
          <Link key={r} href={`/bottles?region=${r}`} className={`px-3 py-1 rounded-full text-sm border ${searchParams.region === r ? 'border-whiskey text-whiskey' : 'border-border text-muted-foreground hover:border-whiskey/50'}`}>{r}</Link>
        ))}
      </div>

      {/* Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {filtered.map((b) => (
          <Link key={b.slug} href={`/bottles/${b.slug}`} className="bg-surface rounded-lg border border-border hover:border-whiskey/50 transition-colors overflow-hidden group">
            <div className="p-6">
              <div className="flex items-start justify-between mb-4">
                <div>
                  <h3 className="font-semibold group-hover:text-whiskey transition-colors">{b.name}</h3>
                  <p className="text-sm text-muted-foreground">{b.distillery}</p>
                </div>
                <div className="text-right">
                  <p className="text-2xl font-bold text-whiskey">{b.avgScore ? Number(b.avgScore).toFixed(1) : '--'}</p>
                  <p className="text-xs text-muted-foreground">/ 10</p>
                </div>
              </div>
              <div className="flex flex-wrap gap-2 text-xs">
                {b.region && <span className="bg-surface-dark px-2 py-1 rounded">{b.region}</span>}
                {b.type && <span className="bg-surface-dark px-2 py-1 rounded">{b.type}</span>}
                {b.age && <span className="bg-surface-dark px-2 py-1 rounded">{b.age}yr</span>}
                {b.abv && <span className="bg-surface-dark px-2 py-1 rounded">{b.abv}%</span>}
              </div>
              {b.priceZar && <p className="text-sm text-muted-foreground mt-3">R{b.priceZar}</p>}
            </div>
          </Link>
        ))}
      </div>
    </div>
  );
}
BOTTLES

# Meetings list page
mkdir -p src/app/meetings
cat > src/app/meetings/page.tsx << 'MEETINGS'
import Link from 'next/link';
import { db } from '@/lib/db';
import { meetings, meetingBottles, bottles, scores } from '@/lib/db/schema';
import { desc, avg, sql, eq } from 'drizzle-orm';

export default async function MeetingsPage() {
  const allMeetings = await db.select().from(meetings).orderBy(desc(meetings.date));

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-3xl font-bold mb-2">Sessions</h1>
        <p className="text-muted-foreground">Every tasting session in club history.</p>
      </div>
      <div className="space-y-4">
        {allMeetings.map((m, i) => (
          <Link key={m.id} href={`/meetings/${m.slug}`} className="block bg-surface rounded-lg border border-border hover:border-whiskey/50 transition-colors p-6">
            <div className="flex items-center justify-between">
              <div>
                <span className="text-xs text-whiskey font-medium">Session {allMeetings.length - i}</span>
                <h3 className="text-lg font-semibold mt-1">{m.title}</h3>
                <p className="text-sm text-muted-foreground">{new Date(m.date).toLocaleDateString('en-ZA', { year: 'numeric', month: 'long', day: 'numeric' })}</p>
              </div>
              <span className="text-whiskey text-2xl">→</span>
            </div>
          </Link>
        ))}
      </div>
    </div>
  );
}
MEETINGS

# Dockerfile
cat > Dockerfile << 'DOCKERFILE'
FROM node:22-alpine AS base
WORKDIR /app

FROM base AS deps
COPY package.json package-lock.json* ./
RUN npm ci

FROM base AS builder
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build

FROM base AS runner
ENV NODE_ENV=production
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
COPY --from=builder /app/public ./public
EXPOSE 3000
ENV PORT=3000
CMD ["node", "server.js"]
DOCKERFILE

# Docker Compose
cat > docker-compose.yml << 'COMPOSE'
services:
  db:
    image: postgres:16-alpine
    restart: unless-stopped
    environment:
      POSTGRES_USER: whiskey
      POSTGRES_PASSWORD: ${DB_PASSWORD:-whiskey_secret}
      POSTGRES_DB: thegreatwhiskey
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U whiskey"]
      interval: 5s
      timeout: 5s
      retries: 5

  app:
    build: .
    restart: unless-stopped
    environment:
      DATABASE_URL: postgresql://whiskey:${DB_PASSWORD:-whiskey_secret}@db:5432/thegreatwhiskey
      NEXTAUTH_SECRET: ${NEXTAUTH_SECRET}
      NEXTAUTH_URL: ${NEXTAUTH_URL:-http://localhost:3000}
    ports:
      - "3000:3000"
    depends_on:
      db:
        condition: service_healthy

  nginx:
    image: nginx:alpine
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/conf.d/default.conf
      - ./nginx/certs:/etc/nginx/certs
    depends_on:
      - app

volumes:
  postgres_data:
COMPOSE

# Nginx config
mkdir -p nginx
cat > nginx/nginx.conf << 'NGINX'
server {
  listen 80;
  server_name _;
  location / {
    proxy_pass http://app:3000;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection 'upgrade';
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_cache_bypass $http_upgrade;
  }
}
NGINX

echo "Done! Pages and Docker config created."
