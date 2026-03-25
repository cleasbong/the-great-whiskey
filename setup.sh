#!/bin/bash
set -e
echo "Setting up The Great Whiskey..."

# Tailwind config
cat > tailwind.config.ts << 'TAILWIND'
import type { Config } from 'tailwindcss';
const config: Config = {
  content: ['./src/**/*.{js,ts,jsx,tsx,mdx}'],
  theme: {
    extend: {
      colors: {
        whiskey: { DEFAULT: '#D4A017', light: '#E8C547', dark: '#B8860B' },
        surface: { DEFAULT: '#1A1A1A', light: '#242424', dark: '#0F0F0F' },
      },
      fontFamily: { heading: ['var(--font-heading)'], body: ['var(--font-body)'] },
    },
  },
  plugins: [require('tailwindcss-animate')],
};
export default config;
TAILWIND

# PostCSS config
cat > postcss.config.js << 'POSTCSS'
module.exports = { plugins: { tailwindcss: {}, autoprefixer: {} } };
POSTCSS

# Next config
cat > next.config.ts << 'NEXTCONFIG'
import type { NextConfig } from 'next';
const nextConfig: NextConfig = {
  output: 'standalone',
  images: { remotePatterns: [{ protocol: 'https', hostname: '**' }] },
};
export default nextConfig;
NEXTCONFIG

# .gitignore
cat > .gitignore << 'GITIGNORE'
node_modules/
.next/
.env
*.env.local
drizzle/
.DS_Store
GITIGNORE

# Auth config
mkdir -p src/lib
cat > src/lib/auth.ts << 'AUTH'
import NextAuth from 'next-auth';
import Credentials from 'next-auth/providers/credentials';
import { compare } from 'bcryptjs';
import { db } from './db';
import { members } from './db/schema';
import { eq } from 'drizzle-orm';

export const { handlers, signIn, signOut, auth } = NextAuth({
  providers: [
    Credentials({
      name: 'credentials',
      credentials: {
        email: { label: 'Email', type: 'email' },
        password: { label: 'Password', type: 'password' },
      },
      async authorize(credentials) {
        if (!credentials?.email || !credentials?.password) return null;
        const [user] = await db.select().from(members).where(eq(members.email, credentials.email as string));
        if (!user || !user.active) return null;
        const isValid = await compare(credentials.password as string, user.passwordHash);
        if (!isValid) return null;
        return { id: user.id, name: user.name, email: user.email, role: user.role };
      },
    }),
  ],
  callbacks: {
    async jwt({ token, user }) {
      if (user) { token.role = (user as any).role; token.id = user.id; }
      return token;
    },
    async session({ session, token }) {
      if (session.user) { (session.user as any).role = token.role; (session.user as any).id = token.id; }
      return session;
    },
  },
  pages: { signIn: '/login' },
  session: { strategy: 'jwt' },
});
AUTH

# Auth route handler
mkdir -p src/app/api/auth/"[...nextauth]"
cat > src/app/api/auth/"[...nextauth]"/route.ts << 'AUTHROUTE'
import { handlers } from '@/lib/auth';
export const { GET, POST } = handlers;
AUTHROUTE

# Middleware
cat > src/middleware.ts << 'MIDDLEWARE'
import { auth } from '@/lib/auth';
import { NextResponse } from 'next/server';

export default auth((req) => {
  const isLoggedIn = !!req.auth;
  const isAdmin = (req.auth?.user as any)?.role === 'admin';
  const { pathname } = req.nextUrl;

  if (pathname.startsWith('/admin') && !isAdmin) {
    return NextResponse.redirect(new URL('/login', req.nextUrl));
  }
  if (pathname.startsWith('/dashboard') && !isLoggedIn) {
    return NextResponse.redirect(new URL('/login', req.nextUrl));
  }
  if (pathname.startsWith('/members') && !isLoggedIn) {
    return NextResponse.redirect(new URL('/login', req.nextUrl));
  }
  return NextResponse.next();
});

export const config = { matcher: ['/admin/:path*', '/dashboard/:path*', '/members/:path*'] };
MIDDLEWARE

# Utils
cat > src/lib/utils.ts << 'UTILS'
import { type ClassValue, clsx } from 'clsx';
import { twMerge } from 'tailwind-merge';

export function cn(...inputs: ClassValue[]) { return twMerge(clsx(inputs)); }

export function slugify(text: string): string {
  return text.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '');
}

export function formatScore(score: string | number): string {
  return Number(score).toFixed(1);
}
UTILS

# Global CSS
mkdir -p src/app
cat > src/app/globals.css << 'CSS'
@tailwind base;
@tailwind components;
@tailwind utilities;

@layer base {
  :root {
    --background: 0 0% 6%;
    --foreground: 0 0% 96%;
    --card: 0 0% 10%;
    --card-foreground: 0 0% 96%;
    --primary: 43 78% 46%;
    --primary-foreground: 0 0% 6%;
    --secondary: 0 0% 14%;
    --secondary-foreground: 0 0% 96%;
    --muted: 0 0% 14%;
    --muted-foreground: 0 0% 63%;
    --accent: 43 78% 46%;
    --accent-foreground: 0 0% 6%;
    --border: 0 0% 16%;
    --ring: 43 78% 46%;
    --radius: 0.5rem;
  }
}

@layer base {
  * { @apply border-border; }
  body { @apply bg-background text-foreground; }
}
CSS

# Layout
cat > src/app/layout.tsx << 'LAYOUT'
import type { Metadata } from 'next';
import { Inter } from 'next/font/google';
import './globals.css';
import { Navbar } from '@/components/navbar';

const inter = Inter({ subsets: ['latin'], variable: '--font-body' });

export const metadata: Metadata = {
  title: 'The Great Whiskey',
  description: 'Private whiskey tasting club',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className="dark">
      <body className={`${inter.variable} font-body antialiased min-h-screen bg-surface-dark`}>
        <Navbar />
        <main className="container mx-auto px-4 py-8">{children}</main>
      </body>
    </html>
  );
}
LAYOUT

# Navbar component
mkdir -p src/components
cat > src/components/navbar.tsx << 'NAVBAR'
import Link from 'next/link';
import { auth } from '@/lib/auth';

export async function Navbar() {
  const session = await auth();
  const isAdmin = (session?.user as any)?.role === 'admin';

  return (
    <nav className="border-b border-border bg-surface/80 backdrop-blur-sm sticky top-0 z-50">
      <div className="container mx-auto px-4 h-16 flex items-center justify-between">
        <Link href="/" className="flex items-center gap-3">
          <span className="text-xl font-bold text-whiskey">The Great Whiskey</span>
        </Link>
        <div className="flex items-center gap-6">
          <Link href="/bottles" className="text-sm text-muted-foreground hover:text-foreground transition-colors">Bottles</Link>
          <Link href="/meetings" className="text-sm text-muted-foreground hover:text-foreground transition-colors">Meetings</Link>
          {session ? (
            <>
              <Link href="/dashboard" className="text-sm text-muted-foreground hover:text-foreground transition-colors">Dashboard</Link>
              {isAdmin && <Link href="/admin" className="text-sm text-whiskey hover:text-whiskey-light transition-colors">Admin</Link>}
            </>
          ) : (
            <Link href="/login" className="text-sm bg-whiskey text-surface-dark px-4 py-2 rounded-md font-medium hover:bg-whiskey-light transition-colors">Login</Link>
          )}
        </div>
      </div>
    </nav>
  );
}
NAVBAR

# Home page
cat > src/app/page.tsx << 'HOMEPAGE'
import Link from 'next/link';
import { db } from '@/lib/db';
import { bottles, scores, meetings } from '@/lib/db/schema';
import { desc, avg, sql } from 'drizzle-orm';

export default async function HomePage() {
  const topBottles = await db
    .select({
      name: bottles.name,
      slug: bottles.slug,
      distillery: bottles.distillery,
      avgScore: avg(scores.score).as('avg_score'),
    })
    .from(bottles)
    .leftJoin(scores, sql`${bottles.id} = ${scores.bottleId}`)
    .groupBy(bottles.id)
    .orderBy(desc(sql`avg_score`))
    .limit(3);

  const recentMeetings = await db.select().from(meetings).orderBy(desc(meetings.date)).limit(1);

  return (
    <div className="space-y-16">
      {/* Hero */}
      <section className="text-center py-20">
        <h1 className="text-5xl md:text-7xl font-bold text-whiskey mb-4">The Great Whiskey</h1>
        <p className="text-xl text-muted-foreground max-w-2xl mx-auto">A private whiskey tasting club. We drink, we score, we debate.</p>
        <div className="mt-8 flex gap-4 justify-center">
          <Link href="/bottles" className="bg-whiskey text-surface-dark px-6 py-3 rounded-md font-medium hover:bg-whiskey-light transition-colors">Explore Bottles</Link>
          <Link href="/meetings" className="border border-whiskey text-whiskey px-6 py-3 rounded-md font-medium hover:bg-whiskey/10 transition-colors">View Meetings</Link>
        </div>
      </section>

      {/* Top Rated */}
      <section>
        <h2 className="text-2xl font-bold mb-6">Top Rated</h2>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          {topBottles.map((b) => (
            <Link key={b.slug} href={`/bottles/${b.slug}`} className="bg-surface rounded-lg p-6 border border-border hover:border-whiskey/50 transition-colors">
              <h3 className="text-lg font-semibold">{b.name}</h3>
              <p className="text-sm text-muted-foreground">{b.distillery}</p>
              <p className="text-3xl font-bold text-whiskey mt-4">{Number(b.avgScore).toFixed(1)}</p>
              <p className="text-xs text-muted-foreground">avg score</p>
            </Link>
          ))}
        </div>
      </section>

      {/* Latest Meeting */}
      {recentMeetings[0] && (
        <section>
          <h2 className="text-2xl font-bold mb-6">Latest Session</h2>
          <Link href={`/meetings/${recentMeetings[0].slug}`} className="block bg-surface rounded-lg p-6 border border-border hover:border-whiskey/50 transition-colors">
            <h3 className="text-xl font-semibold">{recentMeetings[0].title}</h3>
            <p className="text-muted-foreground">{new Date(recentMeetings[0].date).toLocaleDateString('en-ZA', { year: 'numeric', month: 'long', day: 'numeric' })}</p>
          </Link>
        </section>
      )}
    </div>
  );
}
HOMEPAGE

echo "Setup complete! Run: npm install && npm run db:push && npm run db:seed && npm run dev"
