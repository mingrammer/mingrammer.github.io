---
categories:
- go
comments: true
date: 2020-04-18T00:00:00Z
tags:
- go
- modules
- github
title: Go 프라이빗 모듈 가져오기
url: /go-modules-private-repo
---

이번 글에서는 프라이빗 저장소에 저장된 Go 패키지를 가져오는 방법에 대해 알아보려고 한다. 먼저 프라이빗 모듈을 가져오기 전에 간단하게 go get의 동작 방식부터 짚고 넘어가도록 하자.

# Go Get 동작 방식

외부 패키지를 가져오는 `go get` 명령어는 기본적으로 import path를 보고 어떤 vcs를 사용하는지 판단한 뒤, 해당 vcs에 맞는 스키마를 통해 패키지를 다운로드 받는다. 이 글에서 import path로부터 vcs를 판단하는 모든 단계를 설명하지는 않지만, 기본적으로 import path가 **github.com**으로 시작하면 해당 패키지는 **github.com** 호스팅과 **git vcs**를 사용한다고 판단하며 `https://`와 `git+ssh://` 스키마 순서로 다운로드를 시도한다. 따라서 이미 ssh를 사용하고 있다면 ssh로 접근할 수 있는 모든 프라이빗 저장소의 패키지를 가져올 수 있다.

> 물론, ssh를 사용하지 않은 상태에서는 프라이빗 모듈을 가져올 수 없기 때문에 git config에서 ssh를 사용하도록 설정해줘야 한다.

하지만 [Go modules](https://github.com/golang/go/wiki/Modules)가 추가된 Go 1.13부터는 패키지 다운로드 과정에 두 단계가 추가되면서, 모듈을 사용하는 프로젝트에서 프라이빗 패키지를 가져오려고 하면 다음과 같은 에러가 발생한다. (`GO111MODULE` 값에 따라 모듈이 활성화된 디렉토리에서 발생하며, `GO111MODULE`이 `auto`일 경우 모듈이 활성화되지 않은 디렉토리에서는 발생하지 않음)

```
go: downloading github.com/orgname/app v1.0.1
go get github.com/orgname/app/cmd/app: github.com/orgname/app@v1.0.1: verifying module: github.com/orgname/app@v1.0.1: reading https://sum.golang.org/lookup/github.com/orgname/app@v1.0.1: 410 Gone
	server response: not found: github.com/orgname/app@v1.0.1: invalid version: unknown revision v1.0.1
```

이 에러는 Go 1.13부터 추가된 모듈 프록시 ([**proxy.golang.org**](https://proxy.golang.org))와 체크섬 데이터베이스 ([**sum.golang.org**](https://sum.golang.org) )와 관련이 있는데, 정확히는 체크섬 데이터베이스와 관련된 문제이다.

# Go 모듈 동작 방식

Go 1.13 부터 (모듈 활성화시) `go get`은 패키지를 다운로드 받기 전에 먼저 프록시 서버와 체크섬 디비 서버를 접근하게 된다. 프록시 서버는 말그대로 Go 모듈에 대한 프록시 서버이며 미러 서버처럼 동작한다. 체크섬 디비는 다운로드된 모듈의 체크섬과 데이터베이스의 체크섬을 비교하여 다운로드 받은 모듈의 유효성을 검증하려는 (Go에서는 인증이라고 부름) 용도로 사용된다. Go 1.13에서는 프록시 및 체크섬 디비와 관련된 환경 변수가 추가 되었는데 이는 `go env`를 통해 확인할 수 있다.

```
GO111MODULE="auto"
GONOPROXY=""
GONOSUMDB=""
GOPRIVATE=""
GOPROXY="https://proxy.golang.org,direct"
GOSUMDB="sum.golang.org"
...
```

각 환경 변수의 의미는 다음과 같다.

| 환경 변수 | 의미                                      |
| --------- | ----------------------------------------- |
| GONOPROXY | 프록시 사용에서 제외할 경로 목록          |
| GONOSUMDB | 체크섬 검증에서 제외할 경로 목록          |
| GOPRIVATE | 프록시와 체크섬 검증에서 제외할 경로 목록 |
| GOPROXY   | 프록시 서버 주소 목록                     |
| GOSUMDB   | 체크섬 디비 서버 주소                     |

따라서, 디폴트 설정에서 `go get`은 다음과 같이 동작한다.

- https://proxy.golang.org에서 미러링된 모듈 검색
  - 없으면 direct에서 검색 (direct는 특수값으로 저장소에 직접 접근함을 의미)
- 모듈을 발견하면 다운로드 받고 `go.sum` 파일에서 체크섬 유무 검사
  - 체크섬이 없으면 https://sum.golang.org에 접근하여 체크섬 값을 가져옴
- `go.sum` 업데이트

눈치가 빠른 사람이라면 여기서 위에서 발생한 에러의 원인을 찾았을 것이다. direct를 제외한 프록시 서버와 체크섬 서버는 기본적으로 퍼블릭 서버이며 퍼블릭 모듈들을 인덱싱하기 때문에 프라이빗 모듈에 대한 체크섬을 가지고 있지 않으며, 따라서 체크섬을 가져오는 단계에서 실패하게 된다. 

이 문제를 해결하는 데는 두 가지 방법이 있다. 하나는 프라이빗 모듈에 대해 체크섬 디비를 사용하지 않는 것이고, 다른 하나는 프라이빗 체크섬 디비를 구축하여 사용하는 것이다. 하지만 생각해보면 내부 패키지는 변조될 가능성이 매우 낮기 때문에 체크섬 디비를 꼭 사용할 필요는 없으므로 첫 번째 방식을 사용하는 것이 가장 쉽고 간단하다.

그럼 이제 체크섬 디비를 우회하는 방법에 대해서 알아보자.

# 프라이빗 모듈 접근

## GOPRIVATE, GONOSUMDB

위에서 이미 설명했듯이, 이 두 환경 변수를 사용하면 체크섬 검증 또는 프록시 접근과 체크섬 검증 모두를 우회할 수 있다. 방법은 간단하며, 검증을 제외할 경로만 설정해주면 된다.

```shell
$ GOPRIVATE=github.com/orgname go get -v github.com/orgname/app
$ GONOSUMDB=github.com/orgname go get -v github.com/orgname/app

# 다음 명령어로 Go 환경 변수를 영구 적용할 수 있다.
$ go env -w GOPRIVATE=github.com/orgname
```

이렇게 하면 `github.com/orgname`경로에 포함된 모든 모듈에 대해서는 프록시 접근과 체크섬 검증 또는 체크섬 검증을 무시한다. **GOPRIVATE** 같은 경우는 **GONOPROXY**와 **GONOSUMDB**를 함께 사용한 것과 동일한 효과를 내며, 프록시조차 접근하지 않기 때문에 좀 더 강력한 옵션이다. 프라이빗 저장소이면 퍼블릭 프록시를 접근할 이유가 없기 때문에 이 옵션을 사용하길 추천한다. (이름 그대로 프라이빗 모듈을 위한 옵션임)

> 당연한 얘기지만, 프록시와 체크섬을 제외한 direct로 가져오는 방식은 기존과 동일하기 때문에 기본적으로 ssh 접근 가능해야한다.

## GOSUMDB

특정 경로를 제외하는 대신 GOSUMDB 옵션 자체를 off하여 모든 모듈에 대해 체크섬 검증을 무시하는 방법이다.

```shell
$ GOSUMDB=off go get -v github.com/orgname/app
```

> off가 아닌 empty string은 안된다. GOSUMDB가 empty이면 GOSUMDB 대신 GOPROXY에 나열된 프록시 서버에서 사용할 수 있는 체크섬 디비를 검색하기 때문에 마찬가지 이유로 실패한다.

# CI에서도 접근하기

CI 얘기는 사실 git 설정에 대한 이슈지만 참고 정도로 적어둔다. 좀 전에 언급했듯이 direct 접근은 기존과 동일하기 때문에 어쨌든 git으로 프라이빗 저장소에 접근할 수 있는 환경이 우선되어야 한다. CI에서는 ssh보다 access token을 통한 접근이 일반적이므로 다음과 같이 git config로 url만 바꿔주면 된다.

```shell
$ # GitHub Actions 기준. ACCESS_TOKEN 넣는 부분만 맞춰주면 된다.
$ git config --global url."https://x-access-token:${{ secrets.ACCESS_TOKEN }}@github.com/".insteadOf "https://github.com/"
```

그 다음, 같은 방식으로 **GOPRIVATE**을 설정해주면 체크섬을 우회하고 프라이빗 모듈에 접근할 수 있다.