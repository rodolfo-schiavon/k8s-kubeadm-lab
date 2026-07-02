"use client";

import { FormEvent, useEffect, useState } from "react";

type Item = { id: number; title: string };

const API_URL = process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000";

export default function Home() {
  const [items, setItems] = useState<Item[]>([]);
  const [title, setTitle] = useState("");
  const [error, setError] = useState("");

  async function loadItems() {
    try {
      const res = await fetch(`${API_URL}/api/items`);
      if (!res.ok) throw new Error(await res.text());
      setItems(await res.json());
      setError("");
    } catch (e) {
      setError(String(e));
    }
  }

  useEffect(() => {
    loadItems();
  }, []);

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    if (!title.trim()) return;
    const res = await fetch(`${API_URL}/api/items`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ title }),
    });
    if (!res.ok) {
      setError(await res.text());
      return;
    }
    setTitle("");
    await loadItems();
  }

  return (
    <main>
      <h1>K8s Lab Demo</h1>
      <p>Frontend Next.js + API FastAPI + PostgreSQL no cluster kubeadm.</p>
      <form onSubmit={onSubmit} style={{ display: "flex", gap: 8, marginBottom: 16 }}>
        <input
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          placeholder="Novo item"
          style={{ flex: 1, padding: 8 }}
        />
        <button type="submit">Salvar</button>
      </form>
      {error && <p style={{ color: "crimson" }}>{error}</p>}
      <ul>
        {items.map((item) => (
          <li key={item.id}>{item.title}</li>
        ))}
      </ul>
    </main>
  );
}
