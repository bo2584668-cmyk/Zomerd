#!/usr/bin/env bash
set -euo pipefail

# CONFIG — ضبط عنوان المستودع لديك هنا (لا تغيّر إذا الريموت مضبوط محليًا)
GIT_REMOTE="https://github.com/bo2584668-cmyk/Zomerd.git"
BRANCH="feature/auth-and-activation"

echo "سيتم إنشاء الملفات، تهيئة git، ثم رفع الفرع '$BRANCH' إلى الريموت: $GIT_REMOTE"
read -p "هل تود المتابعة؟ (y/N) " CONF
if [[ "${CONF:-}" != "y" && "${CONF:-}" != "Y" ]]; then
  echo "ألغيت التنفيذ."
  exit 0
fi

# أنشئ هيكل المجلدات
mkdir -p prisma lib app/(auth) app/api/auth app/api/request-activation app/api/register app/dashboard app/admin app/api/admin/activation-requests app/api/admin/activation-requests/[id]/approve
mkdir -p app/styles

# 1) README
cat > README.md <<'EOF'
# Zomerd

This repository contains the Zomerd news site with authentication and activation workflows.
EOF

# 2) package.json
cat > package.json <<'EOF'
{
  "name": "zomerd",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "prisma:generate": "prisma generate",
    "prisma:migrate": "prisma migrate dev --name init",
    "seed": "ts-node prisma/seed.ts"
  },
  "dependencies": {
    "bcrypt": "^5.1.0",
    "next": "14.4.0",
    "next-auth": "^4.22.1",
    "nodemailer": "^6.9.4",
    "prisma": "^5.13.0",
    "@prisma/client": "^5.13.0",
    "react": "18.2.0",
    "react-dom": "18.2.0",
    "lucide-react": "^0.297.0"
  },
  "devDependencies": {
    "ts-node": "^10.9.1",
    "typescript": "^5.5.6"
  }
}
EOF

# 3) next.config.js
cat > next.config.js <<'EOF'
/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  images: {
    remotePatterns: [
      { protocol: "https", hostname: "**.unsplash.com" },
      { protocol: "https", hostname: "**.plus.unsplash.com" },
    ],
  },
};

module.exports = nextConfig;
EOF

# 4) prisma/schema.prisma
mkdir -p prisma
cat > prisma/schema.prisma <<'EOF'
datasource db {
  provider = "sqlite"
  url      = env("DATABASE_URL")
}

generator client {
  provider = "prisma-client-js"
}

model User {
  id                 Int                 @id @default(autoincrement())
  email              String              @unique
  name               String?
  role               String              @default("user") // "admin" | "owner" | "user"
  password           String?
  isActive           Boolean             @default(false)
  isAdmin            Boolean             @default(false)
  createdAt          DateTime            @default(now())
  posts              Post[]
  activationRequests ActivationRequest[]
}

model Post {
  id         Int      @id @default(autoincrement())
  title      String
  excerpt    String?
  content    String?
  imageUrl   String?
  category   String?
  published  Boolean  @default(false)
  author     User?    @relation(fields: [authorId], references: [id])
  authorId   Int?
  createdAt  DateTime @default(now())
  updatedAt  DateTime @updatedAt
}

model ActivationRequest {
  id         Int      @id @default(autoincrement())
  email      String
  name       String?
  message    String?
  userId     Int?
  status     String   @default("pending") // pending | approved | rejected
  createdAt  DateTime @default(now())
  handledBy  Int?
  handledAt  DateTime?
}
EOF

# 5) prisma/seed.ts
cat > prisma/seed.ts <<'EOF'
// Usage: set env vars then run: npx ts-node prisma/seed.ts
import { PrismaClient } from "@prisma/client";
import bcrypt from "bcrypt";

const prisma = new PrismaClient();

async function main() {
  const adminEmail = process.env.SEED_ADMIN_EMAIL || "admin@example.com";
  const adminPass = process.env.SEED_ADMIN_PASSWORD;
  if (!adminPass) {
    throw new Error("Set SEED_ADMIN_PASSWORD in environment to create admin user.");
  }

  const hashedAdmin = await bcrypt.hash(adminPass, 10);
  const admin = await prisma.user.upsert({
    where: { email: adminEmail },
    update: {},
    create: {
      email: adminEmail,
      name: "Site Admin",
      password: hashedAdmin,
      role: "admin",
      isAdmin: true,
      isActive: true,
    }
  });

  console.log("Admin ensured:", admin.email);

  const ownerEmail = process.env.SEED_OWNER_EMAIL;
  const ownerPass = process.env.SEED_OWNER_PASSWORD;
  if (ownerEmail && ownerPass) {
    const hashedOwner = await bcrypt.hash(ownerPass, 10);
    const owner = await prisma.user.upsert({
      where: { email: ownerEmail },
      update: {},
      create: {
        email: ownerEmail,
        name: "Owner (seeded, pending)",
        password: hashedOwner,
        role: "owner",
        isAdmin: false,
        isActive: false, // pending until admin approves
      }
    });
    console.log("Owner seeded (pending activation):", owner.email);
  } else {
    console.log("No owner seed provided. To seed an owner, set SEED_OWNER_EMAIL and SEED_OWNER_PASSWORD.");
  }
}

main()
  .catch((e) => { console.error(e); process.exit(1); })
  .finally(async () => { await prisma.$disconnect(); });
EOF

# 6) lib/prisma.ts
mkdir -p lib
cat > lib/prisma.ts <<'EOF'
import { PrismaClient } from "@prisma/client";

declare global {
  // Prevent multiple instances during hot reload in dev
  // eslint-disable-next-line no-var
  var prisma: PrismaClient | undefined;
}

export const prisma = global.prisma ?? new PrismaClient();

if (process.env.NODE_ENV !== "production") global.prisma = prisma;
EOF

# 7) app/layout.tsx and globals.css
mkdir -p app
cat > app/layout.tsx <<'EOF'
import "./globals.css";
import { ReactNode } from "react";

export const metadata = {
  title: "زُمرّد نت",
  description: "النافذة الخضراء للأخبار الموثوقة والتحليلات العميقة."
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="ar" dir="rtl">
      <body className="min-h-screen bg-gray-50 font-sans">
        {children}
      </body>
    </html>
  );
}
EOF

cat > globals.css <<'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;

/* Basic RTL support for body */
html[dir="rtl"] {
  direction: rtl;
}
body {
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}
EOF

# 8) app/page.tsx (homepage)
cat > app/page.tsx <<'EOF'
import Image from "next/image";
import Link from "next/link";
import { Calendar, User, ArrowRight, Menu, Search, Bell } from "lucide-react";
import { prisma } from "@/lib/prisma";

// Re-using the mock content as fallback if db empty
const SITE_CONFIG = {
  name: "زُمرّد نت",
  description: "النافذة الخضراء للأخبار الموثوقة والتحليلات العميقة.",
  socials: { twitter: "#", facebook: "#" },
  logoText: "زُمرّد نت",
};

export default async function Home() {
  const featured = await prisma.post.findFirst({ where: { published: true }, orderBy: { createdAt: "desc" } });
  const latest = await prisma.post.findMany({ where: {}, orderBy: { createdAt: "desc" }, take: 9 });

  return (
    <main className="container mx-auto px-4 py-8">
      {/* Header */}
      <header className="sticky top-0 z-50 bg-white shadow-md border-b border-gray-100 mb-6">
        <div className="container mx-auto px-4">
          <div className="flex items-center justify-between h-20">
            <div className="flex items-center gap-4">
              <button className="p-2 hover:bg-gray-100 rounded-lg lg:hidden"><Menu className="w-6 h-6 text-gray-700" /></button>
              <Link href="/" className="text-3xl font-black tracking-tighter text-gray-900">
                <span className="text-green-600">زُمرّد</span> نت
              </Link>
            </div>
            <nav className="hidden lg:flex gap-8">
              <Link href="/category/breaking" className="text-gray-600 font-bold hover:text-green-700">عاجل</Link>
              <Link href="/category/politics" className="text-gray-600 font-bold hover:text-green-700">سياسة</Link>
              <Link href="/category/economy" className="text-gray-600 font-bold hover:text-green-700">اقتصاد</Link>
              <Link href="/auth/login" className="text-gray-600 font-bold hover:text-green-700">دخول</Link>
            </nav>
            <div className="flex items-center gap-3">
              <button className="p-2 text-gray-500 hover:bg-gray-100 rounded-full"><Search className="w-5 h-5" /></button>
              <button className="p-2 text-gray-500 hover:bg-gray-100 rounded-full relative">
                <Bell className="w-5 h-5" />
                <span className="absolute top-1 right-1 h-2 w-2 bg-red-500 rounded-full animate-pulse"></span>
              </button>
            </div>
          </div>
        </div>
      </header>

      {/* Featured */}
      {featured ? (
        <section className="mb-12">
          <div className="grid lg:grid-cols-2 gap-8 items-center bg-white p-6 rounded-3xl shadow-2xl border border-gray-100">
            <div className="relative h-[450px] w-full rounded-2xl overflow-hidden group">
              {featured.imageUrl && <Image src={featured.imageUrl} alt={featured.title} fill className="object-cover transition-transform duration-700 group-hover:scale-105" />}
              <span className="absolute top-4 right-4 bg-red-600 text-white px-4 py-1.5 rounded-full text-sm font-bold shadow-lg">
                {featured.category || "عام"}
              </span>
            </div>
            <div className="space-y-6">
              <div className="flex items-center gap-4 text-base text-gray-500">
                <span className="flex items-center gap-2"><User size={16}/> {featured?.authorId ?? "فريق التحرير"}</span>
                <span className="flex items-center gap-2"><Calendar size={16}/> {featured ? new Date(featured.createdAt).toLocaleDateString('ar-EG') : ""}</span>
              </div>
              <h1 className="text-4xl lg:text-5xl font-black leading-snug text-gray-900">
                {featured?.title}
              </h1>
              <p className="text-xl text-gray-600 leading-relaxed">{featured?.excerpt}</p>
              <Link href={`/news/${featured?.id}`} className="inline-flex items-center gap-3 text-green-700 font-extrabold">
                اقرأ التفاصيل الكاملة <ArrowRight size={20} />
              </Link>
            </div>
          </div>
        </section>
      ) : (
        <div className="mb-12 text-center text-gray-500">لا توجد أخبار مميزة بعد.</div>
      )}

      {/* Latest grid */}
      <section>
        <div className="flex items-center justify-between mb-8">
          <h2 className="text-3xl font-extrabold border-r-4 border-green-600 pr-4 text-gray-900">أحدث النشرات</h2>
          <Link href="/archive" className="text-green-600 font-medium hover:text-black transition">عرض الكل</Link>
        </div>

        <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-8">
          {latest.length ? latest.map(post => (
            <article key={post.id} className="bg-white rounded-xl overflow-hidden shadow-sm hover:shadow-lg transition-all border border-gray-100 group cursor-pointer">
              <div className="relative h-48 overflow-hidden">
                {post.imageUrl && <Image src={post.imageUrl} alt={post.title} fill className="object-cover group-hover:scale-105 transition-transform duration-500"/>}
              </div>
              <div className="p-6">
                <span className="text-sm font-bold uppercase tracking-wider mb-2 block text-green-700">{post.category}</span>
                <h3 className="text-xl font-extrabold mb-3 text-gray-900 leading-snug line-clamp-2 group-hover:text-green-700 transition-colors">{post.title}</h3>
                <p className="text-gray-500 text-sm line-clamp-3 mb-4">{post.excerpt}</p>
                <div className="flex items-center justify-between mt-auto pt-4 border-t border-gray-50">
                  <span className="text-xs text-gray-400 flex items-center gap-1"><Calendar size={12}/>{new Date(post.createdAt).toLocaleDateString('ar-EG')}</span>
                  <Link href={`/news/${post.id}`} className="text-sm font-bold text-gray-900 hover:underline">اقرأ المزيد</Link>
                </div>
              </div>
            </article>
          )) : (
            <div className="col-span-3 text-center text-gray-500">لا توجد مقالات حتى الآن.</div>
          )}
        </div>
      </section>

      {/* Footer */}
      <footer className="bg-gray-900 text-white pt-16 pb-8 mt-16 border-t-8 border-green-600">
        <div className="container mx-auto px-4 text-center text-gray-400">
          © {new Date().getFullYear()} {SITE_CONFIG.name}. جميع الحقوق محفوظة.
        </div>
      </footer>
    </main>
  );
}
EOF

# 9) NextAuth route
mkdir -p app/api/auth/[...nextauth]
cat > app/api/auth/[...nextauth]/route.ts <<'EOF'
// NextAuth Credentials provider for App Router
import NextAuth from "next-auth";
import CredentialsProvider from "next-auth/providers/credentials";
import { prisma } from "@/lib/prisma";
import bcrypt from "bcrypt";

export const authOptions = {
  providers: [
    CredentialsProvider({
      name: "Credentials",
      credentials: {
        email: { label: "Email", type: "text" },
        password: { label: "Password", type: "password" }
      },
      async authorize(credentials) {
        if (!credentials?.email || !credentials?.password) return null;
        const user = await prisma.user.findUnique({ where: { email: credentials.email } });
        if (!user || !user.password) return null;
        const ok = await bcrypt.compare(credentials.password, user.password);
        if (!ok) return null;
        if (!user.isActive) {
          throw new Error("account_not_active");
        }
        return { id: user.id.toString(), email: user.email, name: user.name, role: user.role, isAdmin: user.isAdmin };
      }
    })
  ],
  session: { strategy: "jwt" },
  callbacks: {
    async jwt({ token, user }) {
      if (user) {
        token.role = (user as any).role;
        token.isAdmin = (user as any).isAdmin;
      }
      return token;
    },
    async session({ session, token }) {
      (session as any).user.role = token.role;
      (session as any).user.isAdmin = token.isAdmin;
      return session;
    }
  },
  secret: process.env.NEXTAUTH_SECRET,
};

const handler = NextAuth(authOptions as any);
export { handler as GET, handler as POST };
EOF

# 10) request-activation endpoint
mkdir -p app/api/request-activation
cat > app/api/request-activation/route.ts <<'EOF'
import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";
import nodemailer from "nodemailer";

const ADMIN_EMAIL = process.env.ADMIN_EMAIL;

export async function POST(req: Request) {
  const body = await req.json();
  const { name, email, message } = body;

  if (!email) return NextResponse.json({ error: "email required" }, { status: 400 });

  const ar = await prisma.activationRequest.create({
    data: { email, name, message, status: "pending" }
  });

  if (ADMIN_EMAIL && process.env.SMTP_HOST) {
    const transporter = nodemailer.createTransport({
      host: process.env.SMTP_HOST,
      port: Number(process.env.SMTP_PORT || 587),
      secure: process.env.SMTP_SECURE === "true",
      auth: {
        user: process.env.SMTP_USER,
        pass: process.env.SMTP_PASS,
      },
    });

    const linkToAdmin = `${process.env.NEXT_PUBLIC_SITE_URL || "http://localhost:3000"}/admin`;
    const mail = {
      from: process.env.SMTP_FROM || `no-reply@${process.env.SMTP_HOST}`,
      to: ADMIN_EMAIL,
      subject: `طلب تفعيل حساب جديد: ${email}`,
      html: `<p>تم استلام طلب تفعيل جديد.</p>
             <p><strong>البريد:</strong> ${email}</p>
             <p><strong>الاسم:</strong> ${name || "-"}</p>
             <p><strong>الرسالة:</strong> ${message || "-"}</p>
             <p>لوحة الإدارة: <a href="${linkToAdmin}">${linkToAdmin}</a></p>`,
    };

    try {
      await transporter.sendMail(mail);
    } catch (e) {
      console.error("Mail send failed", e);
    }
  }

  return NextResponse.json({ ok: true, requestId: ar.id });
}
EOF

# 11) register API and pages
mkdir -p app/(auth)
cat > app/(auth)/register/page.tsx <<'EOF'
"use client";
import { useState } from "react";
import { useRouter } from "next/navigation";

export default function RegisterPage() {
  const [email, setEmail] = useState("");
  const [name, setName] = useState("");
  const [message, setMessage] = useState("");
  const router = useRouter();

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    const res = await fetch("/api/register", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ email, name })
    });
    if (res.ok) {
      await fetch("/api/request-activation", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ email, name, message })
      });
      alert("تم إرسال طلب تفعيل. سينتظر تفعيل الأدمن.");
      router.push("/");
    } else {
      alert("حدث خطأ عند التسجيل.");
    }
  }

  return (
    <div className="container mx-auto px-4 py-12">
      <div className="max-w-md mx-auto bg-white p-8 rounded-xl shadow">
        <h2 className="text-2xl font-bold mb-4">تسجيل مستخدم جديد</h2>
        <form onSubmit={handleSubmit} className="space-y-4">
          <input value={name} onChange={e => setName(e.target.value)} placeholder="الاسم" className="w-full p-3 border rounded" />
          <input value={email} onChange={e => setEmail(e.target.value)} placeholder="البريد الإلكتروني" className="w-full p-3 border rounded" />
          <textarea value={message} onChange={e => setMessage(e.target.value)} placeholder="رسالة قصيرة للأدمن (لماذا تريد النشر؟)" className="w-full p-3 border rounded" />
          <button className="w-full bg-green-600 text-white p-3 rounded">التسجيل وطلب التفعيل</button>
        </form>
      </div>
    </div>
  );
}
EOF

cat > app/api/register/route.ts <<'EOF'
// Simple register API that creates a user record with no password (owner should use seed or additional flow to set password)
// For production you must implement proper password setting and verification flow.
import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

export async function POST(req: Request) {
  const { email, name } = await req.json();
  if (!email) return NextResponse.json({ error: "email required" }, { status: 400 });

  // Create as user by default
  const existing = await prisma.user.findUnique({ where: { email } });
  if (existing) return NextResponse.json({ ok: true, message: "user exists" });

  const user = await prisma.user.create({
    data: { email, name, role: "user", isActive: false }
  });

  return NextResponse.json({ ok: true, userId: user.id });
}
EOF

# 12) login page
cat > app/(auth)/login/page.tsx <<'EOF'
"use client";
import { signIn } from "next-auth/react";
import { useState } from "react";
import { useRouter } from "next/navigation";

export default function LoginPage() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const router = useRouter();

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    const res = await signIn("credentials", { redirect: false, email, password });
    // @ts-ignore
    if (res?.error) {
      if (res.error === "account_not_active") {
        alert("حسابك لم يتم تفعيله بعد. انتظر موافقة الأدمن.");
      } else {
        alert("فشل تسجيل الدخول.");
      }
    } else {
      router.push("/dashboard");
    }
  }

  return (
    <div className="container mx-auto px-4 py-12">
      <div className="max-w-md mx-auto bg-white p-8 rounded-xl shadow">
        <h2 className="text-2xl font-bold mb-4">تسجيل الدخول</h2>
        <form onSubmit={handleSubmit} className="space-y-4">
          <input value={email} onChange={(e)=>setEmail(e.target.value)} placeholder="البريد الإلكتروني" className="w-full p-3 border rounded" />
          <input value={password} onChange={(e)=>setPassword(e.target.value)} type="password" placeholder="كلمة المرور" className="w-full p-3 border rounded" />
          <button className="w-full bg-green-600 text-white p-3 rounded">دخول</button>
        </form>
      </div>
    </div>
  );
}
EOF

# 13) dashboard and admin pages
cat > app/dashboard/page.tsx <<'EOF'
"use client";
import { useEffect, useState } from "react";

export default function DashboardPage() {
  const [posts, setPosts] = useState([]);
  useEffect(() => {
    fetch("/api/dashboard/posts").then(r => r.json()).then(data => setPosts(data || []));
  }, []);

  return (
    <div className="container mx-auto px-4 py-12">
      <h1 className="text-2xl font-bold mb-6">لوحة التحكم</h1>
      <div className="mb-4">
        <a href="/dashboard/new" className="bg-green-600 text-white px-4 py-2 rounded">إنشاء مقال جديد</a>
      </div>

      <div className="space-y-4">
        {posts.length ? posts.map((p:any) => (
          <div key={p.id} className="bg-white p-4 rounded shadow">
            <h3 className="font-bold">{p.title}</h3>
            <div className="text-sm text-gray-500">الحالة: {p.published ? "منشور" : "مسودة"}</div>
          </div>
        )) : (
          <div className="text-gray-500">لا توجد مقالات بعد.</div>
        )}
      </div>
    </div>
  );
}
EOF

cat > app/admin/page.tsx <<'EOF'
"use client";
import { useEffect, useState } from "react";

export default function AdminPage() {
  const [reqs, setReqs] = useState<any[]>([]);
  useEffect(() => {
    fetch("/api/admin/activation-requests").then(r => r.json()).then(data => setReqs(data || []));
  }, []);

  async function handleApprove(id:number) {
    await fetch(`/api/admin/activation-requests/${id}/approve`, { method: "POST" });
    setReqs(reqs.filter(r => r.id !== id));
  }

  return (
    <div className="container mx-auto px-4 py-12">
      <h1 className="text-2xl font-bold mb-6">لوحة الأدمن</h1>

      <div className="space-y-4">
        {reqs.length ? reqs.map(r => (
          <div key={r.id} className="bg-white p-4 rounded shadow flex justify-between items-center">
            <div>
              <div className="font-bold">{r.email}</div>
              <div className="text-sm text-gray-500">{r.message}</div>
            </div>
            <div>
              <button onClick={()=>handleApprove(r.id)} className="bg-green-600 text-white px-3 py-1 rounded">موافقة</button>
            </div>
          </div>
        )) : <div className="text-gray-500">لا توجد طلبات تفعيل.</div>}
      </div>
    </div>
  );
}
EOF

# 14) admin API endpoints
cat > app/api/admin/activation-requests/route.ts <<'EOF'
import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

export async function GET() {
  const reqs = await prisma.activationRequest.findMany({ where: { status: "pending" }, orderBy: { createdAt: "desc" } });
  return NextResponse.json(reqs);
}
EOF

mkdir -p app/api/admin/activation-requests/[id]/approve
cat > app/api/admin/activation-requests/[id]/approve/route.ts <<'EOF'
import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

export async function POST(req: Request, { params }: { params: { id: string } }) {
  const id = Number(params.id);
  const ar = await prisma.activationRequest.update({
    where: { id },
    data: { status: "approved", handledAt: new Date() }
  });

  // find or create user and activate
  const email = ar.email;
  const user = await prisma.user.findUnique({ where: { email } });
  if (user) {
    await prisma.user.update({ where: { id: user.id }, data: { isActive: true } });
  } else {
    // create minimal user (no password) — admin can coordinate password reset flow
    await prisma.user.create({ data: { email, name: ar.name, role: "owner", isActive: true } });
  }

  return NextResponse.json({ ok: true });
}
EOF

# 15) .env.example
cat > .env.example <<'EOF'
# Database (SQLite)
DATABASE_URL="file:./dev.db"

# NextAuth
NEXTAUTH_URL="http://localhost:3000"
NEXTAUTH_SECRET="replace-with-strong-random-string"

# SMTP (for sending activation emails)
SMTP_HOST=smtp.example.com
SMTP_PORT=587
SMTP_SECURE=false
SMTP_USER=username
SMTP_PASS=password
SMTP_FROM="no-reply@example.com"

# Admin email to receive activation requests
ADMIN_EMAIL=bo2584668@gmail.com

# Seed credentials (do NOT commit real passwords)
SEED_ADMIN_EMAIL=admin@example.com
SEED_ADMIN_PASSWORD=change_this_securely
SEED_OWNER_EMAIL=bo2584668@gmail.com
SEED_OWNER_PASSWORD=replace-with-secure-password
EOF

# 16) README_AUTH_ADDITION.md
cat > README_AUTH_ADDITION.md <<'EOF'
```markdown
إضافة نظام المصادقة والتفعيل - تعليمات سريعة
-----------------------------------------

1) تثبيت الحزم:
   npm install

2) إعداد متغيرات البيئة:
   - انسخ .env.example إلى .env.local واملأ القيم الحقيقية (DATABASE_URL, NEXTAUTH_SECRET, SMTP_*, ADMIN_EMAIL, SEED_ADMIN_PASSWORD).
   - لا تترك كلمات المرور الحقيقية في ملفات ملتزمة بالمستودع.

3) تهيئة Prisma:
   npx prisma generate
   npx prisma migrate dev --name init
   أو: npx prisma db push

4) عمل seed للمستخدمين:
   (مثال Linux/macOS)
   export SEED_ADMIN_EMAIL="admin@example.com"
   export SEED_ADMIN_PASSWORD="your_admin_password_here"
   export SEED_OWNER_EMAIL="bo2584668@gmail.com"
   export SEED_OWNER_PASSWORD="replace-with-secure-password"
   npx ts-node prisma/seed.ts

5) تشغيل التطوير:
   npm run dev

ملاحظات أمنية:
- كلمة المرور للمالك التي أعطيتها تم وضعها فقط كقيمة env للـ seed. بعد التشغيل غيّر كلمة المالك فورَ الدخول.
- إعداد SMTP ضروري لإرسال طلبات التفعيل للأدمن.
- لا تضع NEXTAUTH_SECRET أو كلمات المرور بشكل علني في الريبو.
