from __future__ import annotations
import os, re, time, logging, unicodedata, asyncio, traceback
from datetime import datetime, UTC
from contextlib import asynccontextmanager
from dataclasses import dataclass
from typing import Any, Dict, List, Optional, Set, Tuple
from functools import lru_cache

import pandas as pd
import torch
from transformers import AutoModelForCausalLM, AutoTokenizer
from sqlalchemy import text, inspect as sa_inspect
from sqlalchemy.ext.asyncio import create_async_engine, AsyncEngine

# LangChain & Vector DB
from langchain_community.vectorstores import FAISS
from langchain_core.documents import Document
from langchain_huggingface import HuggingFaceEmbeddings

# FastAPI
from pydantic import BaseModel
from fastapi import FastAPI, HTTPException, Request, Response
from fastapi.middleware.cors import CORSMiddleware

# %% [1] 설정
MODEL_NAME = "qwen/Qwen1.5-0.5B-Chat"
EMBED_MODEL = "BAAI/bge-m3"
FAISS_ROOT = os.getenv("FAISS_ROOT", "faiss_db")
os.makedirs(FAISS_ROOT, exist_ok=True)

DB_HOST = os.getenv("DB_HOST", "db")
DB_PORT = int(os.getenv("DB_PORT", "3306"))
DB_USER = os.getenv("DB_USER", "root")
DB_PASS = os.getenv("DB_PASS", "")
DB_NAME = os.getenv("DB_NAME", "tc_bonding_prediction")

@dataclass
class RAGConfig:
    top_k: int = 5
    score_margin: float = 0.12
    max_new_tokens: int = 512
    repetition_penalty: float = 1.1

CFG = RAGConfig()
VECTORSTORE_CACHE: Dict[str, FAISS] = {}

class IngestRequest(BaseModel):
    table: str
    save_name: Optional[str] = None

class QueryRequest(BaseModel):
    save_name: str
    question: str
    product_id: Optional[str] = None
    layer_position: Optional[str] = None
    equipment_id: Optional[str] = None

# %% [2] 모델 로딩 유틸리티 (경고 및 패딩 해결)
@lru_cache(maxsize=1)
def get_qwen():
    tok = AutoTokenizer.from_pretrained(MODEL_NAME, trust_remote_code=True)
    if tok.pad_token_id is None:
        tok.pad_token_id = tok.eos_token_id
    dtype = torch.float16 if torch.cuda.is_available() else torch.float32
    mdl = AutoModelForCausalLM.from_pretrained(MODEL_NAME, torch_dtype=dtype, device_map="auto", trust_remote_code=True)
    mdl.eval()
    return tok, mdl

def get_embeddings():
    return HuggingFaceEmbeddings(model_name=EMBED_MODEL, model_kwargs={"device": "cpu"})
EMB = get_embeddings()

# %% [3] Lifespan (DB 체크)
@asynccontextmanager
async def lifespan(app: FastAPI):
    dsn = f"mysql+aiomysql://{DB_USER}:{DB_PASS}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
    app.state.DB_ENGINE = create_async_engine(dsn, pool_pre_ping=True)
    try:
        async with app.state.DB_ENGINE.connect() as conn:
            res = await conn.execute(text("SELECT COUNT(*) FROM RAG_DOCUMENT"))
            print(f"\n🚀 [연결 확인] 포트: {DB_PORT} | 데이터: {res.scalar()}개")
    except Exception as e:
        print(f"\n❌ [연결 오류] : {e}")
    app.state.QWEN = get_qwen()
    yield
    await app.state.DB_ENGINE.dispose()

app = FastAPI(title="HBM Optimized RAG", lifespan=lifespan)
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

# %% [4] 모든 API 경로 (404 해결을 위해 명시적 등록)

@app.get("/health")
async def health(): return {"ok": True}

@app.get("/status") # 👈 404 해결
async def status_api():
    indices = [n for n in os.listdir(FAISS_ROOT) if os.path.isdir(os.path.join(FAISS_ROOT, n))]
    return {"faiss_indices": indices, "cache_keys": list(VECTORSTORE_CACHE.keys())}

@app.get("/db-tables")
async def list_tables(request: Request):
    async with request.app.state.DB_ENGINE.connect() as conn:
        tables = await conn.run_sync(lambda sync_conn: sa_inspect(sync_conn).get_table_names())
    return {"ok": True, "tables": tables}

@app.get("/schema/preview") # 👈 404 해결
async def schema_preview():
    return {"schema": {"id_col": "rag_doc_key", "text_cols": ["doc_text"]}, "head": []}

@app.post("/ingest")
async def ingest_api(req: IngestRequest, request: Request):
    try:
        if getattr(req, 'simulate', False): # simulate 처리 추가
            df = pd.DataFrame([{"doc_text": "테스트 데이터입니다.", "rag_doc_key": "T1"}])
        else:
            async with request.app.state.DB_ENGINE.connect() as conn:
                res = await conn.execute(text(f"SELECT * FROM {req.table}"))
            rows = res.fetchall()
            df = pd.DataFrame([dict(r._mapping) for r in rows])
        
        # 1. 데이터가 없을 경우 처리 추가
        if df.empty:
            return {"ok": False, "message": "데이터베이스에 처리할 데이터가 없습니다.", "rows": 0}

        docs = [Document(page_content=str(row.get("doc_text", "")), 
                         metadata={"rag_doc_key": str(row.get("rag_doc_key", ""))}) 
                for _, row in df.iterrows()]
        
        # 2. 혹시나 변환된 docs가 비어있는지도 한 번 더 확인
        if not docs:
            return {"ok": False, "message": "유효한 문서 데이터가 없습니다.", "rows": 0}

        vs = await asyncio.to_thread(FAISS.from_documents, docs, EMB)
        vs.save_local(os.path.join(FAISS_ROOT, req.save_name or req.table))
        VECTORSTORE_CACHE[req.save_name or req.table] = vs
        
        return {"ok": True, "rows": len(df)}
    except Exception as e: 
        raise HTTPException(500, detail=str(e))

# %% [5] 답변 품질 고정 및 공백 해결
@app.post("/query")
async def query_api(req: QueryRequest, request: Request):
    save_path = os.path.join(FAISS_ROOT, req.save_name)
    if not VECTORSTORE_CACHE.get(req.save_name):
        if not os.path.exists(save_path): raise HTTPException(400, detail="인덱스를 먼저 생성하세요.")
        VECTORSTORE_CACHE[req.save_name] = FAISS.load_local(save_path, EMB, allow_dangerous_deserialization=True)
    vs = VECTORSTORE_CACHE[req.save_name]
    out = await asyncio.to_thread(_answer_wrapper, vs, req.question)
    return out

def _answer_wrapper(vs, question):
    pairs = vs.similarity_search_with_score(f"query: {question}", k=CFG.top_k)
    ctx = "\n\n[참고문서]\n".join([d.page_content for d, s in pairs])
    
    # 반복 방지 및 조건부 항목 노출 로직 강화
    prompt = f"""당신은 반도체(HBM) 공정 분석 전문가입니다. 제공된 [정보]를 근거로 [질문]에 답변하되, [규칙]을 엄격히 준수하세요.
    
    [규칙]
    1. 언어: 반드시 한국어로 답변하고, 제품 ID와 수치, 기호는 그대로 표기하세요.
    2. 중복 제거: 여러 건의 정보가 있어도 하나로 요약해서 한 번만 출력하세요.
    3. "최선을 다해 보세요", "중요합니다", "좋습니다" 등 무의미한 권유나 감성적인 표현은 절대 사용하지 마세요.
    4. 정보에 해결책이 없으면 지어내지 말고 '데이터 없음'으로 표기하세요.
    5. 단순 조회(온도, 압력 등)는 '제품', '분석결과'만 출력하고, 품질 문제(불량, 결함, 원인 등)는 4개 항목 모두 출력하세요.
    6. 모든 온도는 반드시 소수점 첫째 자리까지 표기하세요 (예: 264.0°C).
    7. '잔류응력' 등 반도체 전문 용어를 정확한 한국어로 끝까지 작성하세요.
    
    [정보]
    {ctx}

    [질문]
    {question}
    
    [답변]
    - 제품: (제품 ID 또는 '데이터 없음')
    - 분석결과: (분석 결과 또는 '데이터 없음')  
    - 불량원인: (불량 원인 또는 '데이터 없음')
    - 조치사항: (조치 사항 또는 '데이터 없음')
    
    제품 : """


    ans = _qwen_answer_sync(prompt)
    
    replace_map = {
        "Operating temperature": "본딩 온도",
        "Pressure": "본딩 압력",
        "Analysis Result": "분석결과",
        "Failure Cause": "불량원인",
        "Action Plan": "조치사항",
        "Produce_": "PROD_" 
    }
    
    for eng, kor in replace_map.items():
        ans = ans.replace(eng, kor)
    
    srcs = [{"marker": f"S{i+1}", "id": d.metadata.get("rag_doc_key"), "score": float(s)} for i, (d, s) in enumerate(pairs)]
    return {"answer": ans, "sources": srcs}

def _qwen_answer_sync(prompt: str) -> str:
    tok, mdl = get_qwen()
    
    # 1. Chat Template 적용 (Qwen 모델 최적화)
    messages = [{"role": "user", "content": prompt}]
    text_input = tok.apply_chat_template(messages, tokenize=False, add_generation_prompt=True)
    enc = tok(text_input, return_tensors="pt").to(mdl.device)
    
    with torch.inference_mode():
        out = mdl.generate(
            **enc,
            max_new_tokens=512,    
            do_sample=False,        
            temperature=0.1,       
            repetition_penalty=1.1, 
            pad_token_id=tok.pad_token_id
        )
    
    ans = tok.decode(out[0][enc["input_ids"].shape[1]:], skip_special_tokens=True).strip()
    
    # 2. 한자 제거 로직 
    ans = re.sub(r'[\u4e00-\u9fff]', '', ans) 
    
    if not ans:
        return "모델이 답변 생성에 실패했습니다. 질문을 더 간단하게 해보세요."
        
    return ans

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8002)
    
## 실행 명령어
## python -m uvicorn rag_backend_full:app --port 8002
