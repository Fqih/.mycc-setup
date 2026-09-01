---
name: fullstack-web
description: Use when building Next.js App Router web apps — TypeScript strict, Server Components default, Server Actions for mutations, Tailwind v4, shadcn/ui, Vercel/Netlify deploy. Trigger on "next.js", "nextjs", "app router", "react component", "tailwind", "shadcn".
---

# fullstack-web

Next.js 15+ App Router patterns. Production-ready, type-safe, deploy-friendly.

## Stack default

| Layer | Tool |
|---|---|
| Framework | Next.js 15+ (App Router) |
| Language | TypeScript strict mode |
| Styling | Tailwind CSS v4 |
| Components | shadcn/ui (Radix primitives) |
| State (server) | Server Components + Server Actions |
| State (client) | Zustand atau Jotai (kalau perlu) |
| Data fetching | TanStack Query (client) / RSC + fetch (server) |
| Form | react-hook-form + Zod |
| Auth | Auth.js (NextAuth v5) atau Clerk |
| DB | Drizzle ORM + PostgreSQL / libSQL |
| Deploy | Vercel (preferred) atau Netlify (sesuai CLAUDE.md) |

## Inisialisasi project

```bash
# create-next-app dengan semua opsi
pnpm create next-app@latest myapp \
    --typescript \
    --tailwind \
    --eslint \
    --app \
    --src-dir \
    --import-alias "@/*" \
    --turbopack

cd myapp
pnpm dlx shadcn@latest init    # shadcn/ui setup
pnpm dlx shadcn@latest add button card dialog form input
```

## Server Components by default

```tsx
// app/dashboard/page.tsx — Server Component (default, no "use client")
import { getUser } from "@/lib/auth";
import { db } from "@/lib/db";

export default async function DashboardPage() {
    const user = await getUser();             // server-only
    const items = await db.select().from(items); // direct DB call, no API route

    return (
        <div className="grid gap-4">
            <h1 className="text-2xl font-bold">Halo, {user.name}</h1>
            <ItemList items={items} />
        </div>
    );
}
```

**Jangan** fetch data di client kalau bisa di server. Server Component = no JS shipped to browser, faster.

## Server Actions untuk mutations

```tsx
// app/actions.ts
"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { db } from "@/lib/db";
import { requireAuth } from "@/lib/auth";

const ItemSchema = z.object({
    title: z.string().min(1).max(200),
    description: z.string().optional(),
});

export async function createItem(formData: FormData) {
    const user = await requireAuth();

    const parsed = ItemSchema.safeParse({
        title: formData.get("title"),
        description: formData.get("description"),
    });
    if (!parsed.success) {
        return { error: parsed.error.flatten() };
    }

    await db.insert(items).values({ ...parsed.data, userId: user.id });
    revalidatePath("/dashboard");
}
```

```tsx
// form pakai Server Action langsung
"use client";
import { createItem } from "@/app/actions";

export function NewItemForm() {
    return (
        <form action={createItem} className="space-y-4">
            <input name="title" required className="..." />
            <textarea name="description" className="..." />
            <button type="submit">Buat</button>
        </form>
    );
}
```

## Type safety end-to-end

```typescript
// tsconfig.json — strict mode WAJIB
{
    "compilerOptions": {
        "strict": true,
        "noUncheckedIndexedAccess": true,
        "exactOptionalPropertyTypes": true
    }
}
```

```typescript
// types/database.ts
import type { InferSelectModel } from "drizzle-orm";
import { items } from "@/lib/db/schema";

export type Item = InferSelectModel<typeof items>;
```

## API routes (kalau tidak bisa pakai Server Action)

```typescript
// app/api/items/route.ts
import { NextResponse } from "next/server";
import { z } from "zod";
import { db } from "@/lib/db";
import { requireAuth } from "@/lib/auth";

const ItemSchema = z.object({
    title: z.string().min(1).max(200),
});

export async function POST(req: Request) {
    const user = await requireAuth();
    const body = await req.json();
    const parsed = ItemSchema.safeParse(body);

    if (!parsed.success) {
        return NextResponse.json({ error: parsed.error.flatten() }, { status: 400 });
    }

    const [item] = await db.insert(items).values({ ...parsed.data, userId: user.id }).returning();
    return NextResponse.json(item, { status: 201 });
}
```

## Auth (Auth.js v5)

```typescript
// auth.ts
import NextAuth from "next-auth";
import GitHub from "next-auth/providers/github";

export const { handlers, auth, signIn, signOut } = NextAuth({
    providers: [GitHub],
    pages: { signIn: "/login" },
});

export async function requireAuth() {
    const session = await auth();
    if (!session?.user) {
        throw new Error("Unauthorized");
    }
    return session.user;
}
```

```tsx
// app/api/auth/[...nextauth]/route.ts
import { handlers } from "@/auth";
export const { GET, POST } = handlers;
```

## shadcn/ui usage

```tsx
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

export function ItemCard({ item }: { item: Item }) {
    return (
        <Card>
            <CardHeader>
                <CardTitle>{item.title}</CardTitle>
            </CardHeader>
            <CardContent>
                <p className="text-sm text-muted-foreground">{item.description}</p>
                <Button variant="outline" size="sm" className="mt-2">
                    Detail
                </Button>
            </CardContent>
        </Card>
    );
}
```

## Deploy ke Netlify (sesuai CLAUDE.md)

```bash
# build
pnpm build

# deploy functions + static
netlify deploy --prod --dir=.next
# atau:
netlify deploy --prod --dir=.next --functions=netlify/functions
```

`netlify.toml`:

```toml
[build]
  command = "pnpm build"
  publish = ".next"

[[plugins]]
  package = "@netlify/plugin-nextjs"
```

## Anti-patterns

❌ `"use client"` di root layout → fatal, harus Server Component
❌ Fetch di `useEffect` instead of Server Component
❌ Hardcoded API URL → pakai `process.env.NEXT_PUBLIC_API_URL`
❌ `any` di TypeScript → strict mode reject
❌ Inline event handler di Server Component → harus Client Component atau Server Action
❌ Import server-only module di client → "use server" only di actions file
❌ Skip `revalidatePath` setelah mutation → cache stale

## Performance checklist

- [ ] Bundle size < 200KB initial JS
- [ ] LCP < 2.5s (target: pakai `next/image` untuk semua image)
- [ ] Server Components default, Client Component seminimal mungkin
- [ ] `next/font` instead of Google Fonts CDN
- [ ] Streaming pakai `<Suspense>` untuk data lambat
- [ ] ISR (`revalidate`) untuk content semi-static

## Common pitfalls

| Pitfall | Solusi |
|---|---|
| Hydration mismatch | Jangan pakai `Date.now()` atau `Math.random()` di render, pakai `useEffect` atau server-only |
| "use client" boundary salah | Pisahkan component interaktif ke file terpisah, import di Server Component |
| Form tidak submit | Cek Server Action ada `"use server"` directive di file terpisah |
| Image tidak muncul | Pakai `next/image`, set `width`/`height` atau `fill` |
| CSS tidak apply | Tailwind v4 pakai `@import "tailwindcss"` di globals.css, bukan `@tailwind base/components/utilities` |
| Deploy 404 di route | Cek `netlify.toml` publish path, harus `.next` |

## Invokation

Auto-trigger saat:
- Edit file di folder `app/`, `components/`, `src/app/`, `src/components/`
- Import dari `next/`, `@/components/ui/`, `@/lib/db`
- User sebut "react", "next.js", "tailwind", "shadcn", "page", "component"
