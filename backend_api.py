from __future__ import annotations

import os
from contextlib import asynccontextmanager
from typing import Any, Dict, List, Optional

from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from sqlalchemy import text, inspect as sa_inspect
from sqlalchemy.ext.asyncio import create_async_engine

DB_HOST = os.getenv("DB_HOST", "mysql")
DB_PORT = int(os.getenv("DB_PORT", "3306"))
DB_USER = os.getenv("DB_USER", "root")
DB_PASS = os.getenv("DB_PASS", "")
DB_NAME = os.getenv("DB_NAME", "tc_bonding_prediction")

APP_MODE = "lite-k8s"
INDEX_CACHE: Dict[str, Dict[str, Any]] = {}


class IngestRequest(BaseModel):
    table: str
    save_name: Optional[str] = None


class QueryRequest(BaseModel):
    save_name: str
    question: str
    product_id: Optional[str] = None
    layer_position: Optional[str] = None
    equipment_id: Optional[str] = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    dsn = f"mysql+aiomysql://{DB_USER}:{DB_PASS}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
    app.state.db_engine = create_async_engine(dsn, pool_pre_ping=True)
    app.state.db_ok = False
    app.state.db_error = None
    try:
        async with app.state.db_engine.connect() as conn:
            await conn.execute(text("SELECT 1"))
        app.state.db_ok = True
    except Exception as exc:
        app.state.db_error = str(exc)
    yield
    await app.state.db_engine.dispose()


app = FastAPI(title="HBM Optimized RAG Lite", lifespan=lifespan)
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])


def api_alias(method: str, path: str):
    def decorator(func):
        app.add_api_route(path, func, methods=[method])
        app.add_api_route(f"/api{path}", func, methods=[method])
        return func
    return decorator


@api_alias("GET", "/health")
async def health(request: Request):
    return {
        "ok": request.app.state.db_ok,
        "mode": APP_MODE,
        "db_host": DB_HOST,
        "database": DB_NAME,
        "error": request.app.state.db_error,
    }


@api_alias("GET", "/status")
async def status_api():
    return {
        "mode": APP_MODE,
        "faiss_indices": list(INDEX_CACHE.keys()),
        "cache_keys": list(INDEX_CACHE.keys()),
        "note": "Lightweight deployment mode without local LLM loading.",
    }


@api_alias("GET", "/db-tables")
async def list_tables(request: Request):
    async with request.app.state.db_engine.connect() as conn:
        tables = await conn.run_sync(lambda sync_conn: sa_inspect(sync_conn).get_table_names())
    return {"ok": True, "tables": tables}


@api_alias("GET", "/schema/preview")
async def schema_preview(request: Request):
    query = text(
        """
        SELECT rag_doc_key, source_type, product_id, layer_position, equipment_id, pass_fail, doc_text
        FROM RAG_DOCUMENT
        LIMIT 3
        """
    )
    async with request.app.state.db_engine.connect() as conn:
        rows = (await conn.execute(query)).mappings().all()
    return {
        "schema": {
            "id_col": "rag_doc_key",
            "text_cols": ["doc_text"],
            "filter_cols": ["product_id", "layer_position", "equipment_id", "pass_fail"],
        },
        "head": [dict(row) for row in rows],
    }


@api_alias("POST", "/ingest")
async def ingest_api(req: IngestRequest, request: Request):
    save_name = req.save_name or req.table
    stmt = text(f"SELECT COUNT(*) AS row_count FROM {req.table}")
    try:
        async with request.app.state.db_engine.connect() as conn:
            row_count = int((await conn.execute(stmt)).scalar() or 0)
        INDEX_CACHE[save_name] = {
            "table": req.table,
            "save_name": save_name,
            "rows": row_count,
            "mode": APP_MODE,
        }
        return {"ok": True, "rows": row_count, "save_name": save_name, "mode": APP_MODE}
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


def _build_query_filters(req: QueryRequest) -> tuple[str, Dict[str, Any]]:
    filters = ["1=1"]
    params: Dict[str, Any] = {}
    if req.product_id:
        filters.append("product_id = :product_id")
        params["product_id"] = req.product_id
    if req.layer_position:
        filters.append("layer_position = :layer_position")
        try:
            params["layer_position"] = int(str(req.layer_position).strip().replace("Layer", "").strip())
        except ValueError:
            params["layer_position"] = req.layer_position
    if req.equipment_id:
        filters.append("equipment_id = :equipment_id")
        params["equipment_id"] = req.equipment_id
    return " AND ".join(filters), params


@api_alias("POST", "/query")
async def query_api(req: QueryRequest, request: Request):
    where_sql, params = _build_query_filters(req)
    stmt = text(
        f"""
        SELECT rag_doc_key, doc_text, source_type, product_id, layer_position, equipment_id, pass_fail
        FROM RAG_DOCUMENT
        WHERE {where_sql}
        ORDER BY bonding_date DESC, rag_doc_id DESC
        LIMIT 5
        """
    )
    async with request.app.state.db_engine.connect() as conn:
        rows = (await conn.execute(stmt, params)).mappings().all()

    if not rows:
        return {
            "answer": "조건에 맞는 문서를 찾지 못했습니다. 제품, 레이어, 장비 조건을 다시 확인하세요.",
            "sources": [],
            "mode": APP_MODE,
        }

    snippets = [str(row["doc_text"]).strip() for row in rows if row.get("doc_text")]
    joined = "\n\n".join(snippets[:3])
    answer = (
        "경량 배포 모드 응답입니다.\n"
        f"질문: {req.question}\n\n"
        "관련 문서 기준 요약:\n"
        f"{joined[:1400]}"
    )
    sources = [
        {
            "marker": f"S{i + 1}",
            "id": row.get("rag_doc_key"),
            "score": round(1.0 / (i + 1), 3),
        }
        for i, row in enumerate(rows)
    ]
    return {"answer": answer, "sources": sources, "mode": APP_MODE}


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8002)
