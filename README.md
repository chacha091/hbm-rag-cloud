
HBM TC Bonding 공정 데이터를 조회하고 조건 기반 질의를 수행할 수 있도록 구성한 제조 데이터 서비스 프로젝트입니다.

## 디렉터리 구조

```text
.
├── backend/
│   ├── backend_api.py
│   ├── rag_backend_full.py
│   ├── requirements.k8s.txt
│   ├── requirements.txt
│   └── Dockerfile
├── frontend/
│   ├── index.html
│   ├── overview.html
│   ├── nginx.conf
│   └── Dockerfile
├── data/
│   └── hbm_erd_ddl.sql
├── infra/
│   ├── ci/
│   │   └── Jenkinsfile
│   ├── dev/
│   └── k8s/
│       ├── deployment-*.yaml
│       ├── service-*.yaml
│       ├── ingress-app.yaml
│       ├── secret-*.yaml
│       └── kustomization.yaml
├── docker-compose.yaml
├── .gitignore
└── README.md
```

## 프로젝트 개요

- 경량 백엔드
  - `backend/backend_api.py`
  - MySQL의 `RAG_DOCUMENT` 테이블을 조회하고 조건 기반 응답을 생성하는 실제 실행 경로
- 확장형 RAG 백엔드
  - `backend/rag_backend_full.py`
  - 더 무거운 RAG/LLM 구성을 실험한 참고 구현

실제 로컬 실행과 배포 예시는 경량 운영 백엔드를 기준으로 맞춰져 있습니다.

## 핵심 기능

- 상태 확인 API
  - `GET /health`
  - `GET /status`
- DB 메타 조회
  - `GET /db-tables`
  - `GET /schema/preview`
- 캐시 등록용 ingest API
  - `POST /ingest`
- 조건 기반 질의 응답
  - `POST /query`
- 제조 콘솔에서 API 호출 결과 시각화
- Docker Compose 로컬 실행
- Kubernetes 배포 매니페스트 제공
- Jenkins 기반 이미지 빌드 파이프라인 제공

## 기술 스택

- Frontend: HTML, JavaScript, Nginx
- Backend: FastAPI, SQLAlchemy, aiomysql, Pydantic
- Database: MySQL 8.4
- Infra: Docker Compose, Kubernetes, Jenkins


## 백엔드 동작 방식

### 1. 경량 백엔드

`backend_api.py`는 LLM을 직접 로드하지 않고 DB 중심 API로 동작합니다.

- 시작 시 MySQL 연결 상태 확인
- `RAG_DOCUMENT` 테이블의 샘플 레코드와 스키마 노출
- `product_id`, `layer_position`, `equipment_id` 조건으로 문서 필터링
- 최근 문서 5건을 기준으로 경량 요약 응답 생성

### 2. 확장형 RAG 백엔드

`rag_backend_full.py`는 더 무거운 RAG/LLM 백엔드 실험 코드를 보존한 파일입니다.

## 프론트엔드 화면

`index.html`은 제조 콘솔 형태 UI로 구성되어 있으며 아래 API를 직접 호출할 수 있습니다.

- Health
- Status
- Schema Preview
- DB Tables
- Ingest
- Query

`overview.html`은 서비스 소개용 랜딩 페이지입니다.

## 로컬 실행

```bash
docker compose up --build
```

접속 주소:

- Frontend: `http://127.0.0.1:8080`
- Backend: `http://127.0.0.1:8002`

Compose는 `data/hbm_erd_ddl.sql`을 MySQL 초기화 스크립트로 자동 마운트합니다.

## 폴더별 역할

### `backend/`

- 운영용 API와 확장형 RAG 백엔드 코드 보관
- 경량 배포용 의존성과 전체 의존성 분리
- 백엔드 컨테이너 빌드 파일 포함

### `frontend/`

- 제조 콘솔 메인 UI
- 소개용 랜딩 페이지
- Nginx 설정 및 프론트 컨테이너 빌드 파일 포함

### `data/`

- DB 초기화용 SQL 보관
- 샘플 스키마와 `tc_bonding_prediction` 데이터 생성

### `infra/ci/`

- Jenkins 파이프라인 보관
- 문법 검사, Docker 이미지 빌드, 레지스트리 푸시 흐름 정의

### `infra/k8s/`

- Kubernetes 배포 예시
- ConfigMap, Secret, PVC, Deployment, Service, Ingress, Kustomize 포함
