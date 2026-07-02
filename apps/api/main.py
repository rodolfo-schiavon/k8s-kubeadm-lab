from contextlib import asynccontextmanager
import os

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import psycopg2
from psycopg2.extras import RealDictCursor

DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://demo:k8slab-demo-change-me@postgres-postgresql.data-services.svc.cluster.local:5432/demodb",
)


def get_conn():
    return psycopg2.connect(DATABASE_URL, cursor_factory=RealDictCursor)


def init_db():
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                CREATE TABLE IF NOT EXISTS items (
                    id SERIAL PRIMARY KEY,
                    title TEXT NOT NULL,
                    created_at TIMESTAMPTZ DEFAULT NOW()
                )
                """
            )
        conn.commit()


@asynccontextmanager
async def lifespan(app: FastAPI):
    for attempt in range(30):
        try:
            init_db()
            break
        except Exception:
            import time
            time.sleep(2)
    yield


app = FastAPI(title="K8s Lab Demo API", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class ItemCreate(BaseModel):
    title: str


class Item(BaseModel):
    id: int
    title: str


@app.get("/healthz")
def healthz():
    try:
        with get_conn() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT 1")
        return {"status": "ok", "database": "connected"}
    except Exception as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc


@app.get("/api/items", response_model=list[Item])
def list_items():
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT id, title FROM items ORDER BY id DESC LIMIT 50")
            rows = cur.fetchall()
    return [Item(**row) for row in rows]


@app.post("/api/items", response_model=Item)
def create_item(payload: ItemCreate):
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "INSERT INTO items (title) VALUES (%s) RETURNING id, title",
                (payload.title,),
            )
            row = cur.fetchone()
        conn.commit()
    return Item(**row)
