# HBM RAG Cloud

HBM TC Bonding 공정 데이터를 웹에서 조회하고, 조건 기반 질의를 통해 관련 문서를 요약해서 확인할 수 있도록 구성한 제조 데이터 서비스 프로젝트입니다. FastAPI 백엔드, MySQL, Nginx 프론트엔드, Docker Compose, Kubernetes 매니페스트, Jenkins 파이프라인까지 함께 포함해 서비스 구현과 배포 흐름을 한 저장소에 정리했습니다.

## 프로젝트 개요

- 경량 운영 백엔드
  - `backend_api.py`
  - MySQL의 `RAG_DOCUMENT` 테이블을 조회해 조건 기반 검색과 요약 응답 제공
- 확장형 RAG 백엔드 원본
  - `rag_backend_full.py`
  - 더 무거운 RAG/LLM 구성을 실험한 버전

실제 로컬 실행과 Kubernetes 배포 예시는 경량 운영 백엔드를 기준으로 정리되어 있습니다.

## 핵심 기능

- 백엔드 상태 확인
  - `GET /health`
  - `GET /status`
- 데이터베이스 메타 조회
  - `GET /db-tables`
  - `GET /schema/preview`
- 인덱스 캐시 등록용 ingest API
  - `POST /ingest`
- 조건 기반 질의 응답
  - `POST /query`
- 프론트엔드 콘솔에서 API 호출 결과 시각화
- Docker Compose 기반 로컬 구동
- Kubernetes 배포 예시 제공
- Jenkins 기반 이미지 빌드 파이프라인 포함

## 기술 스택

- Frontend: HTML, JavaScript, Nginx
- Backend: FastAPI, SQLAlchemy, aiomysql, Pydantic
- Database: MySQL 8.4
- Infra: Docker Compose, Kubernetes, Jenkins

## 디렉터리 구조

```text
.
├── index.html                  # 메인 콘솔 UI
├── overview.html               # 소개용 랜딩 페이지
├── backend_api.py              # 경량 운영용 FastAPI 백엔드
├── rag_backend_full.py         # 확장형 RAG 백엔드 원본
├── hbm_erd_ddl.sql             # 초기 스키마 및 샘플 데이터
├── docker-compose.yaml         # 로컬 통합 실행
├── Dockerfile.backend
├── Dockerfile.frontend
├── Jenkinsfile                 # 이미지 빌드/푸시 파이프라인
├── k8s/                        # 배포 매니페스트 예시
├── requirements.k8s.txt        # 경량 배포용 의존성
└── requirements.txt            # 확장형 백엔드 의존성
```

## 백엔드 동작 방식

### 1. 경량 운영 백엔드

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
docker compose -f docker-compose.yaml up --build
```

접속 주소:

- Frontend: `http://127.0.0.1:8080`
- Backend: `http://127.0.0.1:8002`

기본 compose 설정은 예시 비밀번호 `change-me`를 사용합니다. 실제 사용 시 환경에 맞게 변경해야 합니다.

## Kubernetes 구성

`k8s/` 디렉터리에는 아래 리소스 예시가 포함되어 있습니다.

- Deployment
  - frontend
  - backend
  - mysql
- Service
  - frontend
  - backend
  - mysql
- ConfigMap
- Secret
- PVC
- Ingress
- Kustomization


## 데이터 초기화

`hbm_erd_ddl.sql`은 MySQL 초기화 스크립트입니다.

- HBM 공정 관련 샘플 스키마 생성
- `tc_bonding_prediction` 데이터베이스 생성
- `RAG_DOCUMENT` 기반 조회 구조 실습 가능

Docker Compose에서는 이 SQL 파일이 컨테이너 시작 시 자동 적용됩니다.

## CI/CD

`Jenkinsfile`

- Python 문법 검사
- 백엔드/프론트엔드 Docker 이미지 빌드
- 레지스트리 푸시

