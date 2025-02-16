# Apache Superset

Apache Superset은 데이터 시각화 및 대시보드 관리를 위한 강력한 오픈소스 데이터 탐색 도구입니다.  
다양한 데이터베이스와의 연결을 지원하며, 사용자가 대화형 차트와 대시보드를 쉽게 생성할 수 있도록 도와줍니다.

---

## 📂 스크립트 소개

### `run_install.sh`
- **설명**: Superset 설치 및 실행을 자동화하는 스크립트.
- **기능**:
  - 리포지토리 클론 및 브랜치 설정.
  - Docker Compose를 이용한 Superset 시작 및 구성.
  - 포트 변경, 요구 사항 파일 생성, 로고 추가, 사용자 정의 설정 적용.
  - 관리자 비밀번호 초기화.

### `run_content.sh`
- **설명**: Superset 데이터 관리 및 역할/대시보드 작업을 자동화하는 스크립트.
- **기능**:
  - 대시보드 및 역할의 내보내기 및 가져오기.
  - 샘플 데이터 로드.

---

## 📋 도커 설치 정보

| **이름**            | **버전**  | **비고**         |
|---------------------|-----------|------------------|
| **Docker Engine**   | 27.4.1    |                  |
| **Docker Compose**  | v2.32.1   |                  |

---

## 📋 Superset 설치 정보

| **버전**      | **설명**                                    | **링크**                                                                                     | **비고**         |
|---------------|---------------------------------------------|---------------------------------------------------------------------------------------------|------------------|
| **4.0.1**     | Apache Superset 4.0.1 Docker 이미지 사용   | [Superset GitHub Releases](https://github.com/apache/superset/releases/tag/4.0.1)           |                  |

---

## ⚙️ 참고 사항

(추가적으로 작성할 내용)

---

## 📂 파일 및 폴더 구조

```plaintext
superset/
├── superset_4.0.1
│   ├── custom.png                     # 사용자 정의 로고
│   ├── dashboard_export_20241225T030621.zip   # 대시보드 내보내기 파일
│   ├── dashboard_export_20241225T030624.zip   # 대시보드 내보내기 파일
│   ├── roles_sample.json              # 역할 샘플 JSON 파일
│   ├── run_content.sh                 # Superset 데이터 작업 자동화 스크립트
│   └── run_install.sh                 # Superset 설치 및 실행 자동화 스크립트
└── README.md                          # Superset 설정 및 스크립트 설명 파일
```

---

## 🔗 참고 자료

- [Superset 공식 사이트](https://superset.apache.org/)
- [Superset GitHub 저장소](https://github.com/apache/superset)
- [Superset Docker Hub](https://hub.docker.com/r/apache/superset)


