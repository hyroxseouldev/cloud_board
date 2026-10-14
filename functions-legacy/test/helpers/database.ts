import { PGlite } from '@electric-sql/pglite';
import { readFile, readdir } from 'node:fs/promises';
import type pg from 'pg';
export async function database() {
  const db = new PGlite();
  const dir = new URL('../../drizzle/', import.meta.url);
  for (const file of (await readdir(dir)).filter((name) => name.endsWith('.sql')).sort())
    await db.exec(await readFile(new URL(file, dir), 'utf8'));
  let tail = Promise.resolve();
  async function acquire() {
    const previous = tail;
    let release!: () => void;
    tail = new Promise<void>((resolve) => {
      release = resolve;
    });
    await previous;
    return release;
  }
  const query = async (sql: string, params?: unknown[]) => db.query(sql, params);
  const pool = {
    query: async (sql: string, params?: unknown[]) => {
      const release = await acquire();
      try {
        return await query(sql, params);
      } finally {
        release();
      }
    },
    connect: async () => {
      const release = await acquire();
      return { query, release };
    },
  } as unknown as pg.Pool;
  return { db, pool };
}
