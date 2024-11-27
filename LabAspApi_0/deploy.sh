### ! 프로젝트 배열 선언(docker-compose.yml api 서비스 명칭 입력)
declare -a PROJECTS=(
    "labaspapi"
    "labaspapi_aaaa"
    "labaspapi_bbbb"
    "labaspapi_cccc"
)

### GitHub Actions 환경에서는 GITHUB_REF를 사용하고, 로컬 환경에서는 git 명령어를 사용
if [ -n "$GITHUB_REF" ]; then
    echo "=============================="
    echo "GitHub Actions 환경에서 실행됩니다. $GITHUB_REF"
    echo "=============================="
    CURRENT_BRANCH=${GITHUB_REF##*/}
else
    echo "=============================="
    echo "로컬 환경에서 실행됩니다."
    echo "=============================="
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
fi

if [ "$CURRENT_BRANCH" != "deploy" ]; then
    echo "=============================="
    echo "현재 브랜치는 $CURRENT_BRANCH 입니다. deploy 브랜치에서만 실행 가능합니다."
    echo "=============================="
    exit 1
fi

### 오류 발생 시 스크립트 종료
set -e

### 로그 기록
LOG_DIR="log/deploy"
mkdir -p "$LOG_DIR"

LOG_FILE="$LOG_DIR/deploy_$(date +'%Y%m%d_%H%M%S').log"
exec > >(while IFS= read -r line; do echo "$(date +'%Y-%m-%d %H:%M:%S') $line"; done | tee -a "$LOG_FILE") 2>&1

### 중복 실행 방지를 위한 PID 파일 설정
# .pid 저장 경로 지정
TEMP_DIR="C:/srtmp/"
mkdir -p "$TEMP_DIR"

# 스크립트의 절대 경로 설정. 현재 스크립트의 위치 기준 경로 설정
SCRIPT_PWD="$(cd "$(dirname "$0")" && pwd)"
# 부모 디렉토리 경로 추출
PARENT_PWD="$(dirname "$SCRIPT_PWD")"
# 부모 디렉토리 이름 추출
PARENT_DIR="$(basename "$PARENT_PWD")"

# 스크립트 디렉토리 이름 추출
SCRIPT_DIR="$(basename "$SCRIPT_PWD")"
PID_FILE="${TEMP_DIR}${SCRIPT_DIR}_deploy.pid"

# 스크립트 종료 시 LOCK_FILE 과 PID_FILE 삭제 예약 trap 설정
trap 'rm -f "$PID_FILE" "$PRUNE_LOCK_FILE" "$GIT_LOCK_FILE"' EXIT

if [ -f "$PID_FILE" ]; then
    if kill -0 $(cat "$PID_FILE") 2>/dev/null; then
        echo "=============================="
        echo "이미 배포가 진행 중입니다. 중복 실행을 방지합니다."
        echo "=============================="
        exit 1
    else
        echo "=============================="
        echo "이전 배포 프로세스가 비정상적으로 종료되었습니다. PID 파일을 삭제하고 새로 시작합니다."
        echo "=============================="
        rm -f "$PID_FILE"
    fi
fi

# 현재 프로세스 ID를 PID 파일에 기록
echo $$ > "$PID_FILE"

### Docker 실행 상태 확인
if ! docker info >/dev/null 2>&1; then
    echo "=============================="
    echo "Docker 가 실행되고 있지 않습니다. 배포를 중단합니다."
    echo "=============================="
    exit 1
fi

HASH_DIR="hash"
mkdir -p "$HASH_DIR"

### Windows 환경에 맞춘 경로
COMPOSE_PATH="docker-compose.yml"
DOCKER_COMPOSE="docker-compose -f $COMPOSE_PATH"
DELAY=5
NGINX_PATH="nginx/nginx.conf"
NGINX_TEMP_PATH="nginx_temp.conf"
NGINX_CONTAINER="$(echo "${SCRIPT_DIR}_nginx" | tr '[:upper:]' '[:lower:]')"

declare -A NEW_ENVS
declare -a RESV_PROJECTS

### 함수 정의
# 새로운 이미지 pull 및 빌드, 컨테이너 시작
deploy_new_env() {
    local project=$1
    local new_env="${project}_${NEW_ENVS[$project]}"

    echo "=============================="
    echo "새로운 환경으로 이미지를 빌드합니다."
    echo "=============================="

    if ! $DOCKER_COMPOSE build --no-cache $new_env; then
        echo "=============================="
        echo "이미지 빌드 실패: $new_env. 배포를 중단합니다."
        echo "=============================="
        notify_failure "$project"
        exit 1
    fi

    echo "=============================="
    echo "새로운 환경으로 컨테이너를 시작합니다."
    echo "=============================="

    if ! $DOCKER_COMPOSE up -d --no-deps $new_env; then
        echo "=============================="
        echo "컨테이너 시작 실패: $new_env. 배포를 중단합니다."
        echo "=============================="
        notify_failure "$project"
        exit 1
    fi

    sleep $DELAY
    RESV_PROJECTS+=("$project")
}

notify_failure() {
    local project=$1
    # 여기에 슬랙, 이메일 또는 다른 알림 시스템을 이용한 알림 로직 추가
    echo "=============================="
    echo "배포 실패 알림: 프로젝트 $project"
    echo "=============================="
}

delete_containers() {
    local int=$1

    for PROJECT in "${RESV_PROJECTS[@]}"; do
        if contains_project "$PROJECT"; then
            local del_env=""
            local msg=""

            if [ "$int" = "1" ]; then
                del_env="${PROJECT}_${NEW_ENVS[$PROJECT]}"
                msg="프로젝트 $PROJECT 의 컨테이너 $del_env 를 중지하고 삭제합니다."
            else # "0"
                del_env="${PROJECT}_$(get_prev_env "${NEW_ENVS[$PROJECT]}")"
                msg="프로젝트 $PROJECT 의 이전 환경 컨테이너 $del_env 를 삭제합니다."
            fi

            echo "=============================="
            echo "$msg"
            echo "=============================="

            $DOCKER_COMPOSE stop "$del_env" && $DOCKER_COMPOSE rm -f "$del_env"
        fi
    done
}

contains_project() {
    local project=$1
    for item in "${PROJECTS[@]}"; do
        if [[ "$item" == "$project" ]]; then
            return 0
        fi
    done
    return 1
}

get_prev_env() {
    local new_env=$1
    if [ "$new_env" = "blue" ]; then
        echo "green"
    else
        echo "blue"
    fi
}

### 스크립트 메인 진입점
# Git에서 최신 변경 사항 반영
git fetch origin deploy

for PROJECT in "${PROJECTS[@]}"; do
    # 각 프로젝트의 현재 블루-그린 상태 검사 후 다음 배포 환경 저장
    if $DOCKER_COMPOSE ps --filter "name=${PROJECT}_blue" --filter "status=running" | grep -q "${PROJECT}_blue"; then
        echo "=============================="
        echo "프로젝트 $PROJECT 의 현재 구동 컨테이너는 블루입니다. 그린으로 전환합니다."
        echo "=============================="
        NEW_ENVS["$PROJECT"]="green"
    elif $DOCKER_COMPOSE ps --filter "name=${PROJECT}_green" --filter "status=running" | grep -q "${PROJECT}_green"; then
        echo "=============================="
        echo "프로젝트 $PROJECT 의 현재 구동 컨테이너는 그린입니다. 블루로 전환합니다."
        echo "=============================="
        NEW_ENVS["$PROJECT"]="blue"
    else
        echo "=============================="
        echo "프로젝트 $PROJECT 의 현재 구동 컨테이너는 없습니다. 블루로 시작합니다."
        echo "=============================="
        NEW_ENVS["$PROJECT"]="blue"
    fi

    # Git을 사용하여 변경 사항 확인, 마지막 배포 커밋이 있는 경우
    LAST_DEPLOYED_COMMIT=$(cat "$HASH_DIR/$PROJECT.hash" 2>/dev/null || echo "")

    if [ -n "$LAST_DEPLOYED_COMMIT" ]; then
        CHANGED_FILES=$(git diff --name-only "$LAST_DEPLOYED_COMMIT"..origin/deploy)
        if echo "$CHANGED_FILES" | grep -iq "^$SCRIPT_DIR/$PROJECT/"; then
            echo "=============================="
            echo "프로젝트 $PROJECT 에 변경 사항이 있습니다. 블루-그린 전환을 시작합니다."
            echo "=============================="
            deploy_new_env "$PROJECT"
        else
            echo "=============================="
            echo "프로젝트 $PROJECT 에 새로운 변경 사항이 없습니다. 배포를 건너뜁니다."
            echo "=============================="
        fi
    else
        # 마지막 배포 커밋이 없는 경우, 모든 변경 사항을 배포
        echo "=============================="
        echo "최근 배포 커밋 정보가 없습니다. 프로젝트 $PROJECT 에 대해 블루-그린 전환을 시작합니다."
        echo "=============================="
        deploy_new_env "$PROJECT"
    fi

done

### 하나 이상 프로젝트 배포 상황 발생
if [ ${#RESV_PROJECTS[@]} -gt 0 ]; then
    echo "=============================="
    echo "기존 nginx.conf 구성 코드를 삭제합니다."
    echo "=============================="
    > "$NGINX_PATH"

    echo "=============================="
    echo "nginx 템플릿에서 새로운 nginx 구성을 복사합니다."
    echo "=============================="

    # nginx_temp.conf 템플릿 치환
    UPSTREAMS=""
    LOCATIONS=""

    for PROJECT in "${PROJECTS[@]}"; do
        if [[ " ${RESV_PROJECTS[@]} " =~ " $PROJECT " ]]; then
            UPSTREAMS+="upstream ${PROJECT}{server ${PROJECT}_${NEW_ENVS[$PROJECT]}:5000;}"$'\n'
        else
            UPSTREAMS+="upstream ${PROJECT}{server ${PROJECT}_$(get_prev_env "${NEW_ENVS[$PROJECT]}"):5000;}"$'\n'
        fi

        PROC_ENDPOINT="${PROJECT#*_}"

        if [ "$PROC_ENDPOINT" = "$PROJECT" ]; then
            PROC_ENDPOINT="svwl"
        fi

        LOCATIONS+="location /${PROC_ENDPOINT}/api/ {proxy_pass http://${PROJECT}/;}"$'\n'
    done

    while IFS= read -r line; do
        line="${line//\{\{upstreams\}\}/$UPSTREAMS}"
        line="${line//\{\{locations\}\}/$LOCATIONS}"
        echo "$line" >> "$NGINX_PATH"
    done < "$NGINX_TEMP_PATH"

    echo "=============================="
    echo "nginx 설정 테스트 및 리로드를 시작합니다."
    echo "=============================="
    if ! $DOCKER_COMPOSE ps --filter "name=$NGINX_CONTAINER" --filter "status=running" | grep -q "$NGINX_CONTAINER"; then
        echo "=============================="
        echo "nginx 서비스가 없습니다. 새로운 nginx 컨테이너를 생성합니다."
        echo "=============================="
        if ! $DOCKER_COMPOSE up -d $NGINX_CONTAINER; then
            echo "=============================="
            echo "nginx 컨테이너 생성에 실패했습니다. 배포를 중단합니다."
            echo "=============================="
            delete_containers "1"
            exit 1
        fi
    else
        $DOCKER_COMPOSE stop "$NGINX_CONTAINER"
        $DOCKER_COMPOSE rm -f "$NGINX_CONTAINER"
        $DOCKER_COMPOSE up -d "$NGINX_CONTAINER"
    fi

    if ! $DOCKER_COMPOSE exec "$NGINX_CONTAINER" nginx -t; then
        echo "=============================="
        echo "nginx 설정 테스트에 실패했습니다. 배포를 중단합니다."
        echo "=============================="
        delete_containers "1"
        exit 1
    fi

    # 프로젝트 이전 환경 컨테이너 중지 및 제거
    delete_containers "0"

    ### Unused(dangling) 상태의 도커 이미지 삭제. 진행 중인 prune 작업이 끝날 때까지 대기
    PRUNE_LOCK_FILE="${TEMP_DIR}${PARENT_DIR}_deploy_prune.lock"

    # 잠금 파일이 있을 경우 대기
    while [ -f "$PRUNE_LOCK_FILE" ]; do
        echo "=============================="
        echo "다른 docker image prune 작업이 실행 중입니다. 완료될 때까지 대기합니다."
        echo "=============================="
        docker image prune -f
        sleep $DELAY
    done

    # 잠금 파일 생성
    echo $$ > "$PRUNE_LOCK_FILE"

    # 배포 완료 후 최신 커밋을 기록
    for PROJECT in "${RESV_PROJECTS[@]}"; do
        git rev-parse origin/deploy > "$HASH_DIR/$PROJECT.hash"
    done
    
    ### *.hash 와 nginx.config 를 deploy 브랜치에 커밋하고 main 에 병합. 중복 실행 방지
    echo "=============================="
    echo "수정된 *.hash 와 nginx.config 를 deploy 브랜치에 커밋하고 main 에 병합합니다."
    echo "=============================="

    GIT_LOCK_FILE="${TEMP_DIR}${PARENT_DIR}_deploy_git.lock"

    # 잠금 파일이 있을 경우 대기
    while [ -f "$GIT_LOCK_FILE" ]; do
        echo "=============================="
        echo "다른 git 작업이 실행 중입니다. 완료될 때까지 대기합니다."
        echo "=============================="
        sleep $DELAY
    done

    # 잠금 파일 생성
    echo $$ > "$GIT_LOCK_FILE"

    git add "$HASH_DIR"/*.hash "$NGINX_PATH"
    git commit -m "Final deployment completed"
    git push origin deploy
    git checkout main
    git merge deploy
    git push origin main
    git checkout main

    echo "=============================="
    echo "배포를 완료했습니다!"
    echo "=============================="
else
    echo "=============================="
    echo "변경 사항이 존재하는 프로젝트가 없습니다. 배포를 종료합니다."
    echo "=============================="
fi
