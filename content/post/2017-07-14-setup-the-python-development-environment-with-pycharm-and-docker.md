---
categories:
- python
- docker
comments: true
date: 2017-07-14T00:00:00Z
tags:
- pycharm
- docker
title: PyCharm + Docker로 파이썬 개발환경 셋업하기 (Dockerization)
url: /setup-the-python-development-environment-with-pycharm-and-docker
---

보통 파이썬 프로젝트를 시작하면 주로 **virtualenv**를 사용해 파이썬 환경(파이썬 버전, 패키지들을 모두 포함)을 독립적으로 분리시킨 가상 환경에서 작업을 한다. 

그러나 여기엔 한 가지 한계점이 있는데 **virtualenv**를 사용하면 파이썬 환경은 독립적으로 구성할 수 있지만 OS 환경까지 독립적으로 구성할 순 없다는 점이다. 즉, 프로젝트가 파이썬뿐만 아니라 OS 레벨 혹은 시스템 레벨까지 독립적으로 구성해야하는 경우엔 **virtualenv**는 애초에 적합하지 않다.

최근에 파이썬 프로젝트를 하나 시작했는데 이 프로젝트가 바로 이 경우이다. 물론 OS나 시스템 레벨을 직접 건드리는 부분은 없지만 하나의 (네트워크) 시스템 환경을 구축하는 작업이었기에 아예 독립적으로 구성하는게 나아보였다.

그렇다면 대안은 독립적인 머신을 사용하거나 Vagrant와 같은 VM을 사용하는건데 나의 경우엔 Vagrant는 조금 부담스럽고 좀 더 가볍게 구성하고자 [**Docker**](https://www.docker.com/)를 사용하였다. 나는 프로젝트 크기가 크거나 IDE의 도움이 필요한 경우 주로 **PyCharm**으로 작업을 하는데 Docker는 터미널에서 작업하다보니 두 프로그램간의 스위칭이 너무 불편하였다. 마침 PyCharm에서 Docker를 지원하고 있었고 한 번 연동해서 써본 결과 나름 만족스러웠기에 이를 기록 및 공유하고자 이번 포스트를 쓰게되었다.

그러면 바로 본론으로 들어가서 파이썬 프로젝트를 Docker 기반으로 개발하는 전체 과정을 살펴보기위해 Docker 컨테이너를 만든 뒤, 그 위에 Flask 애플리케이션을 띄워보고 PyCharm에서 Docker를 연동하여 좀 더 편리한 개발환경을 셋업해보자.

<br>

목차는 다음과 같다.

<hr>

* **프로젝트 생성하기**
  * 프로젝트 구조 잡기


* **도커 (Docker) 세팅하기**
  * 도커 설치
  * (macOS에 해당) 도커 머신 생성
  * 도커 파일 생성 및 도커 이미지 빌드
  * 도커 컨테이너 실행
* **파이참 (PyCharm) 세팅하기** 
  * 리모트 도커 연결
  * Flask 애플리케이션 서버 실행하기

<br>

# 프로젝트 생성하기

<hr>

### 1. 프로젝트 구조 잡기

우선 도커에 띄우고자 하는 파이썬 프로젝트가 있어야한다. 물론 그냥 단순히 프로젝트용 디렉토리 하나만 있어도되며, 기존에 작업중이던 파이썬 프로젝트여도 상관없다. (프로젝트를 Docker 기반의 애플리케이션으로 만드는 작업을 보통 **Dockerization**이라고 부른다.)

여기선 파이썬 프로젝트 디렉토리를 하나 생성하고 간단한 Flask 애플리케이션 코드를 작성해보자. 또한 `requirements.txt`에 `Flask` 패키지를 명시하자. 

```shell
mkdir python-docker && cd python-docker
echo "Flask==0.12.2" > requirements.txt
touch app.py
```

```python
# app.py
from flask import Flask

app = Flask('app')


@app.route('/')
def index():
    return "I'm from docker"


if __name__ == '__main__':
    app.run(host='0.0.0.0', debug=True)
```

<br>

# 도커 (Docker) 세팅하기

<hr>

### 1. 도커 설치

기본적으로 도커가 이미 설치되어 있다고 가정하고 시작하기는 하지만 혹시나 설치가 안되어 있다면 [여기](https://docs.docker.com/engine/installation/)에서 다운로드를 할 수 있다. (macOS에서 **brew**를 사용한다면 `brew install docker`로 간편하게 설치가 가능하다)

<br>

### 2. (macOS에 해당) 도커 머신 생성

도커는 LXC 위에서 동작하기 때문에 Docker를 구동하기 위한 VM이 필요하다. VirtualBox를 사용해 도커 머신을 생성하자. 도커를 설치하면 함께 설치되는 Docker VM을 관리할 수 있는`docker-machine` 커맨드를 사용하여 도커 머신을 생성할 수 있다.

```shell
# <machine-name>은 여러분이 원하는 이름으로 설정하라. (필자는 테스트용으로 pyapp-container를 사용하였다)
# docker-machine create <machine-name> --driver virtualbox
docker-machine create pyapp-container --driver virtualbox
```

생성된 도커 머신을 사용하기 위해선 해당 머신에 대한 설정값들을 환경변수로 export 해야한다.

```shell
# <machine-name>은 여러분이 원하는 이름으로 설정하라. (필자는 테스트용으로 pyapp-container를 사용하였다)
# eval $(docker-machine env <machine-name>)
eval $(docker-machine env pyapp-container)
```

위 커맨드를 실행하면 다음의 커맨드들이 실행되어 필요한 환경변수들이 설정된다. (`DOCKER_HOST`는 다를 수 있음)

```shell
export DOCKER_TLS_VERIFY="1"
export DOCKER_HOST="tcp://192.168.99.104:2376"
export DOCKER_CERT_PATH="/Users/ming/.docker/machine/machines/pyapp-container"
export DOCKER_MACHINE_NAME="pyapp-container"
```

<br>

### 3. 도커 파일 생성 및 도커 이미지 빌드

도커 컨테이너를 띄우기 위해서는 이미지(image)가 필요하다. 이미지는 도커 컨테이너를 띄우기 위한 일종의 스냅샷이다. OS 이미지의 그 이미지라고 생각하면 된다. 우리는 우리의 파이썬 프로젝트를 위한 이미지를 만들 것이다.

도커는 **Dockerfile**이라고 하는 도커 이미지를 구성하고 빌드하기 위한 명령어들을 저장해놓는 파일을 지원한다. 그럼 이제 우리가 사용할 이미지를 빌드하기 위한 도커 파일을 작성해보자. (아까 우리가 생성한 프로젝트 디렉토리에 작성하면 된다.) 여기서는 컨테이너 OS로 **Ubuntu 16.04**를 사용할 것이다. (원한다면 다른 OS를 써도 무방하며 명령어를 해당 OS에 맞게 변경하면 된다)

```dockerfile
# 베이스 이미지로 ubuntu:16.04 사용 
FROM ubuntu:16.04

# 메인테이너 정보 (옵션)
MAINTAINER <your-nickname> <<your-email>>

# 환경변수 설정 (옵션)
ENV PATH /usr/local/bin:$PATH
ENV LANG C.UTF-8

# 기본 패키지들 설치 및 Python 3.6 설치
RUN apt-get update
RUN apt-get install -y software-properties-common
RUN add-apt-repository -y ppa:fkrull/deadsnakes
RUN apt-get update
RUN apt-get install -y --no-install-recommends python3.6 python3.6-dev python3-pip python3-setuptools python3-wheel gcc
RUN apt-get install -y git

# pip 업그레이드
RUN python3.6 -m pip install pip --upgrade

# 여러분의 현재 디렉토리의 모든 파일들을 도커 컨테이너의 /python-docker 디렉토리로 복사 (원하는 디렉토리로 설정해도 됨)
ADD . /python-docker

# 5000번 포트 개방 (Flask 웹 애플리케이션을 5000번 포트에서 띄움)
EXPOSE 5000

# 작업 디렉토리로 이동
WORKDIR /python-docker

# 작업 디렉토리에 있는 requirements.txt로 패키지 설치
RUN pip3 install -r requirements.txt

# 컨테이너에서 실행될 명령어. 컨테이거나 실행되면 app.py를 실행시킨다.
CMD python3.6 app.py
```

그럼 이제 위 Dockerfile을 빌드해서 실제 이미지를 만들어보자.

```shell
# image-name은 빌드할 도커 이미지명이다. 보통 <image-name>:<tag> 형태의 이름을 사용한다.
# dockerfile-path-directory는 Dockerfile이 위치한 디렉토리 경로를 의미한다.
# 여기선 현재 프로젝트 디렉토리에 있으므로 "."을 사용
# docker build -t <image-name> <dockerfile-path-directory>
docker build -t pyapp:latest .
```

첫 빌드시에는 베이스 이미지를 받아와 모든 필요한 패키지들을 설치하고 모든 커맨드를 처음부터 실행하므로 조금 오래 걸릴 수도 있다. 하지만 한 번 빌드한 뒤부터는 캐시를 사용하기 때문에 빌드 속도가 빨라질 것이다.

빌드가 끝나면 이미지가 잘 생성되었는지 확인해보자.

```shell
docker images
```

실행 결과

```
REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
pyapp               latest              372c329c5b81        10 minutes ago      504MB
<none>              <none>              b4bf2c8f2db7        12 minutes ago      504MB
<none>              <none>              5bc7893eac21        13 minutes ago      504MB
<none>              <none>              40cc5664f60f        14 minutes ago      504MB
<none>              <none>              33d5f2c12640        15 minutes ago      504MB
<none>              <none>              e9565431de17        17 minutes ago      504MB
<none>              <none>              e598babfa1be        About an hour ago   504MB
<none>              <none>              a0a69fd8fdf2        8 hours ago         504MB
<none>              <none>              2fdab6374fe3        8 hours ago         498MB
ubuntu              16.04               d355ed3537e9        3 weeks ago         119MB
```

아래 `<none>`으로 보이는 것들은 `pyapp` 이미지 빌드 도중 중간 중간 생성된 이미지들이다. `pyapp` 이미지가 제대로 생성되었음을 볼 수 있다.

<br>

### 4. 도커 컨테이너 실행

마지막이다! 이제 위에서 만든 도커 머신과 이미지를 가지고 실제 도커 컨테이너 인스턴스를 실행해보자. 다음의 커맨드를 통해 컨테이너를 실행해보자.

```shell
# docker run --name <machine-name> -d -p 8080:5000 -v $(pwd):/python-docker <image-name>
docker run --name pyapp-container -d -p 8080:5000 -v $(pwd):/python-docker pyapp:latest
```

* `--name` 옵션으로 우리가 사용할 도커 머신명을 지정한다.
* `-d` 옵션으로 도커 컨테이너를 백그라운드로 실행시킨다.
* `-v` 옵션으로 호스트 디렉토리와 도커 디렉토리의 디스크 볼륨을 마운트한다. 따라서, 호스트에서 해당 디렉토리의 파일을 수정하면 도커 컨테이너에도 반영된다.
* `-p` 옵션으로 포트를 맵핑한다. `8080:5000`의 의미는 호스트에서 8080 포트 접속시 도커 컨테이너의 5000 포트 프로세스가 맵핑된다는 소리다. (5000 포트에서 열린 프로세스가 반응)

도커 컨테이너가 실행되면 다음과 같이 컨테이너의 ID가 보일 것이다 (ID는 다를 수 있음)

```
f76cb8a34bd1f258b799cd0ab84d8a611851a62b92fdb729882a003ec0473229
```

그럼 이제 도커 컨테이너에서 실행된 Flask 애플리케이션에 접속해보자. 접속 방법은 리눅스와 macOS가 조금 다른데 왜냐하면 위에서도 언급했지만 macOS의 경우 도커를 위한 VM을 띄우고 이 위에서 도커 컨테이너를 실행했으므로 VM IP로 접속해야하기 때문이다. (리눅스 환경이라면 호스트에서 도커를 바로 띄울 수 있으므로 `localhost`로 접속이 가능하다.) 

따라서 macOS의 경우 다음 명령어를 통해 VM의 IP를 얻어온 다음 해당 IP의 `8080` 포트로 접속하면된다.

```shell
# macOS에만 해당
docker-machine ip pyapp-container
```

도커 컨테이너에서 실행된 Flask 애플리케이션에 요청을 날려보자. (웹 브라우저에서 접속해도된다.)

```shell
# Linux: curl localhost:8080
curl 192.168.99.104:8080
# I'm from docker
```

우리는 Flask 애플리케이션을 성공적으로 도커 컨테이너 위에 올렸고 실행까지 성공했다. 이제 PyCharm에서 Flask 애플리케이션에 기능을 좀 더 추가해보자. 그런데 우리는 방금 애플리케이션을 도커 컨테이너 위에 올렸으니 PyCharm에 도커를 연동하여 바로 도커 위에서 작업할 수 있는 환경을 만들어보자.

<br>

# 파이참 (PyCharm) 세팅하기

### 1. 리모트 도커 연결

PyCharm에서 좀 전에 실행한 도커 컨테이너를 연결해보자. `Preferences` 메뉴의 `Build, Execution, Deployment > Docker` 메뉴로 들어가면 다음과 같은 화면이 나온다.

![docker preference](../images/2017-07-14-docker-preference.png)

`+` 버튼을 눌러 설정을 추가하고 이름을 설정한다. (필자의 경우 **Pyapp Docker**로 설정했음을 볼 수 있다)

아래의 `Import credentials from Docker Machine` 체크박스를 활성화 한 뒤 Machine에서 아까 생성하고 실행한 **pyapp-container**를 선택한 후 `OK`를 눌러 설정을 마친다. 그러면 아래와 같은 도커뷰가 보일 것이고 **Pyapp Docker**에서 다음과 같은 정보들을 볼 수 있다.

![docker view](../images/2017-07-14-docker-view.png)

`Log` 탭에서는 도커 컨테이너 안에서 실행되고 프로세스들의 로그를 볼 수 있는데 Flask 애플리케이션을 실행한 로그와 접속 로그가 잘 보인다. 성공적으로 도커를 연결했음을 볼 수 있다. 이 외의 `Port Bindings`나 `Volume Bindings` 탭을 보면 우리가 아까 `docker run` 커맨드로 명시했던 모든 맵핑 테이블을 볼 수 있다. (필요한 경우 PyCharm에서 +/- 버튼으로 동적으로 추가/제거를 할 수 있다.)

그러나 아직 할 일이 한 가지 남았다. 도커는 연결했지만 PyCharm과 도커 컨테이너 내부의 파이썬 인터프리터는 아직 연결하지 않았다. 우리는 로컬 환경이 아닌 독립된 도커 컨테이너에서 모든 파이썬 버전 및 패키지들을 설치하고 관리할 것이므로 로컬 환경의 인터프리터가 아닌 도커 내부의 인터프리터를 사용해야한다. `Preferences`에 들어가 `interpreter`로 검색을 하면 인터프리터 설정 화면이 나온다.

![python interpreter preference](../images/2017-07-14-python-interpreter-preference.png)

`Add Remote`를 선택한 후 `Docker` 버튼을 눌러 컨테이너를 선택한다. 이미지 로딩에 조금 시간이 걸릴 수 있는데 조금 기다리면 된다. 그리고 인터프리터 **path**는 `/usr/bin/python3.6`으로 적는다.

![select interpreter](../images/2017-07-14-select-interpreter.png)

`OK`를 누르면 인터프리터와 패키지들이 로딩되고 잠시 후 다음과 같은 화면을 볼 수 있다.

![packages list](../images/2017-07-14-packages-list.png)

우리가 처음에 도커 이미지를 빌드할 때 설치했던 파이썬 패키지들이 잘 보이는걸로 봐서 도커 컨테이너의 인터프리터가 성공적으로 연결되었음을 알 수 있다.

이렇게 인터프리터를 연결하면 우리는 이제 로컬 파이썬이 아닌 리모트 도커 컨테이너의 파이썬 환경을 그대로 사용할 수 있게된다. 이것으로 로컬 PyCharm 작업 환경과 도커 컨테이너 환경을 완벽하게 연동하였다.

<br>

### 2. Flask 애플리케이션 수정 및 동작 확인

이제 애플리케이션을 수정해보자. `app.py`의 `index` 함수 아래에 다음과 같은 코드를 추가해보자.

```python
@app.route('/me')
def me():
    return "I'm mingrammer on docker"
```

파일을 저장하면 도커뷰의 `Log` 탭의 내용이 조금 바뀔 것이다. 디버그 모드에서 파일을 수정하면 Flask는 웹서버를 재실행하는데 컨테이너에서 Flask 웹서버가 정상적으로 재실행 되었음을 볼 수 있다.

![changed docker view](../images/2017-07-14-changed-docker-view.png)

따라서 우리는 로컬 환경에서 작업한 코드를 실시간으로 도커와 동기화 하였고, 이를 PyCharm에서도 확인할 수 있게 되었다. (도커와의 코드 동기화는 도커 자체의 기능으로 PyCharm과는 관련이 없다. 다만 이제 이를 PyCharm에서 모두 확인할 수 있다는 것이다.)

정상적으로 반영되었는지 확인하기 위해 추가한 엔드포인트로 요청을 날려보자.

```shell
# Linux: curl localhost:8080/me
curl 192.168.99.104:8080/me
# I'm mingrammer on docker
```

위와 같은 응답이 날아온다면 성공적으로 반영이 된 것이다. (Olleh!)

<br>

이상으로 파이썬 프로젝트를 **Dockerize**하는 방법과 도커를 PyCharm과 연동하는 과정을 살펴보았다. 이 외에도 도커와 PyCharm으로 할 수 있는일은 무궁무진하다. 다만 여기서는 튜토리얼 수준으로만 다뤄보았다. 애초에 예시로 든 애플리케이션이 매우 간단하여 복잡한 세팅이나 작업이 필요없기도하다.

다음에는 단일 웹 애플리케이션이 아닌 데이터베이스 서버, 캐시 서버등의 좀 더 복잡한 환경과 아키텍쳐에서 도커를 활용하는 방법들을 포스팅 해보겠다.