# HBM RAG Cloud

HBM TC Bonding 공정 데이터를 조회하고 질의응답 형태로 탐색할 수 있는 RAG 기반 웹서비스입니다. FastAPI 백엔드, MySQL, 정적 프론트엔드, Docker Compose, Kubernetes 배포 구성을 함께 포함해 클라우드 배포형 포트폴리오로 정리했습니다.

## 핵심 기능

- 공정 데이터 조회 API
- 스키마 미리보기 API
- 질의 조건 기반 문서 조회 API
- 경량 배포 모드 백엔드 제공
- Docker Compose 로컬 실행
- Kubernetes 배포 매니페스트 포함

## 기술 스택

- Frontend: HTML, JavaScript, Nginx
- Backend: FastAPI, SQLAlchemy, aiomysql
- Database: MySQL
- Infra: Docker, Docker Compose, Kubernetes

## 구성 요소

- `index.html`
  - 사용자 메인 UI
- `overview.html`
  - 서비스 소개 화면
- `backend_api.py`
  - 경량 배포용 FastAPI 백엔드
- `rag_backend_full.py`
  - 확장형 RAG 백엔드 원본 코드
- `docker-compose.yaml`
  - 로컬 통합 실행 구성
- `k8s/`
  - Deployment, Service, Ingress, Secret, ConfigMap 예시

## API

- `GET /health`
- `GET /status`
- `GET /db-tables`
- `GET /schema/preview`
- `POST /ingest`
- `POST /query`

## 로컬 실행

```bash
docker compose -f docker-compose.yaml up --build
```

접속:

- Frontend: `http://127.0.0.1:8080`
- Backend: `http://127.0.0.1:8002`

## 배포 포인트

- 경량 API 백엔드와 확장형 RAG 백엔드를 분리해 운영 제약을 반영
- 프론트엔드, 백엔드, 데이터베이스를 컨테이너 단위로 구성
- Kubernetes 리소스 예시를 함께 포함해 배포 흐름을 보여줄 수 있도록 구성

## 주의 사항

- 공개 저장소 기준으로 민감 정보는 기본값을 제거하거나 예시 값으로 일반화했습니다.
- 실제 배포 시에는 `.env`, Secret, 이미지 경로, Ingress 도메인을 환경에 맞게 다시 설정해야 합니다.

## 포트폴리오 포인트

- 데이터 API와 RAG 질의 흐름을 하나의 서비스로 구성
- Docker Compose와 Kubernetes 매니페스트를 함께 다뤄 배포 역량을 보여줄 수 있음
- 운영 환경 제약을 고려한 경량화 전략을 코드 구조에 반영
