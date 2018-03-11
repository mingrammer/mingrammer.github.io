---
categories:
- go
comments: true
date: 2018-02-01T00:00:00Z
tags:
- oauth2
- tutorial
title: Go에서 OAuth2 인증하기
url: /getting-started-with-oauth2-in-go
---

[OAuth2](https://oauth.net/2/)란, 일종의 인증 프로토콜로써 소셜 인증을 통한 로그인 및 권한 제어를 위해 사용된다. Google, Twitter, Github 등 대부분의 소셜 인증 기능을 지닌 프로바이더들은 표준 인증 방식으로 OAuth2를 채택하고 있으며 그에 따른 OAuth2 API들을 제공하고 있다.

이번 포스팅에서는 Go에서 OAuth2 인증을 처리하는 방법을 다루고자 한다.

Go는 다양한 기능의 내장 라이브러리와 공식 서드파티 라이브러리의 지원이 꽤 잘되어있는 편인데 OAuth2 또한 Go 공식 서드파티 라이브러리가 이미 존재한다. 따라서 별도의 비공식 서드파티 라이브러리를 사용할 필요가 없으며 사실상 이미 준비는 다 되어있다고 보면된다.

이 포스팅에서는 대표적인 OAuth2 프로바이더인 Google을 기준으로 설명을 진행할 것이다. 이 외의 프로바이더에 대해서도 OAuth2 동작방식은 동일하니 사용하려는 프로바이더가 다를 경우엔 일부 설정 및 인증 정보만 바꿔주면 된다. (이 부분은 **인증 정보 설정**을 참고)

우선 코드를 살펴보기 전에 OAuth2의 인증 플로우부터 살펴보도록 하겠다.

<br>

# OAuth2 플로우

OAuth2의 추상적인 플로우를 살펴보면 다음과 같다.

 ![OAuth2 Absctract Flow](../images/2018-02-01-oauth2-abstract-flow.png)

<center>*출처: [Digital Ocean](https://www.digitalocean.com/community/tutorials/an-introduction-to-oauth-2)*</center>

1. 유저가 로그인 페이지에 접속을 한다.
2. 로그인 페이지 접속시 유저를 식별하기 위해 생성한 랜덤한 `state`값을 사용해 구글 로그인 링크를 생성한다.
3. 유저는 반환된 구글 로그인 링크를 클릭해 소셜 로그인을 진행한다.
4. 소셜 로그인 후에 구글 인증 서버는 토큰 발급을 위한 임시 `code` 값과 이전에 전송했던 `state` 값을 미리 등록했던 콜백 URL에 붙여 리다이렉트 한다.
5. 콜백 URL로 호출되는 인증 처리 핸들러에서는 `state` 값이 이전값과 같은지 확인한 뒤, 받은 `code` 값을 사용해 실제 리소스 사용 권한이 담긴 **엑세스 토큰** 을 발급 받기 위해 구글 인증 서버로 요청을 보낸다.
6. 인증 서버로부터 **엑세스 토큰**을 받으면 필요한 리소스를 요청할 수 있게 된다.

<br>

# 준비사항

코드를 작성하기 전에 두 가지 준비해야할 사항이 있다. 그 중 하나는 인증 처리를 위한 의존 라이브러리 설치이며 나머지 하나는 사용할 프로바이더의 OAuth2 API를 사용하기 위한 키값 발급 및 콜백 URL 지정이다.

## 의존성 설치

```bash
go get golang.org/x/oauth2

# (선택사항) 세션 관리는 원하는 형태로 해도 되며, 여기선 gorilla의 sessions를 사용하여 세션을 관리
go get github.com/gorilla/sessions
```

## 키값 발급

OAuth2 API를 사용하기 위해선 API를 제공하는 프로바이더에 애플리케이션을 등록한 뒤 OAuth2 API 사용 권한 인증을 위한 키값들을 발급받아야한다. 구글의 경우 [Google API Console](https://console.developers.google.com)에서 애플리케이션을 등록할 수 있다. 등록 후, **사용자 인증 정보** 페이지에 접속하면 **사용자 인증 정보 만들기**의 **OAuth 클라이언트 ID** 메뉴를 통해 클라이언트 ID와 시크릿 키값을 발급 받을 수 있다.

이렇게 발급받은 클라이언트 ID와 시크릿 키값은 **인증 정보 설정**에서 사용할 것이다.

## 콜백 URL 지정

사용자가 프로바이더 인증 서버에 권한을 요청하면 인증 서버는 미리 등록된 콜백 URL을 통해 토큰 발급시 사용될 임시 코드값을 클라이언트에 전달하게 된다. (위 그림으로 보면 **3**번에서 이 과정이 이루어진다) 따라서 우리는 이 때 사용할 콜백 URL을 좀 전에 만든 애플리케이션에 미리 등록해야한다. 키값을 발급했던 페이지에 있는 **승인된 리디렉션 URI** 칸에 콜백 URL을 지정할 수 있다. 여기에서는 `http://127.0.0.1:1333/auth/callback`로 지정하도록 하자.

준비는 다 끝났다. 그럼 이제 OAuth2 인증을 실제로 구현해보도록 하자. 

<br>

# 예제용 애플리케이션 구성

이 포스팅의 목적은 하나의 완전한 애플리케이션의 구현이 아닌 OAuth2 인증에 초점이 맞춰져 있기 때문에 아주 단순한 구조의 예제용 애플리케이션을 구성해보도록 하겠다.

예제로 사용할 애플리케이션 구조는 다음과 같다.

```
├─ auth.go
├─ auth.html
├─ main.go
└─ main.html
```

* **auth.go** : 인증 관련 정보 설정
* **auth.html** : 인증 시작 페이지
* **main.go** : 핸들러 관리
* **main.html** : 메인 페이지

구조는 매우 단순하며 상세한 인증 플로우는 잠시 후 살펴보도록 하겠다. **main.html**과 **auth.html**는 단순히 인증 링크 접속을 위한 페이지라 아주 단순하다.

```html
<!-- main.html -->
<html>
<head></head>
<body>
    <a href="/auth">Sign In</a>
</body>
</html>
```

```html
<!-- auth.html -->
<html>
<head></head>
<body>
    <!-- href는 로그인 핸들러로부터 반환 받은 Google 로그인 링크가 담긴다 -->
    <a href="{{ . }}">Google Login</a> 
</body>
</html>
```

**main.go**는 페이지 렌더링과 인증을 처리하는 핸들러를 관리한다.

```go
func main() {
    http.HandleFunc("/", RenderMainView)
    http.HandleFunc("/auth", RenderAuthView)
    http.HandleFunc("/auth/callback", Authenticate)

    log.Fatal(http.ListenAndServe(":1333", nil))
}

// 메인 뷰 핸들러
func RenderMainView(w http.ResponseWriter, r *http.Request) {
}

// 랜덤 state 값을 가진 구글 로그인 링크를 렌더링 해주는 뷰 핸들러
// 랜덤 state는 유저를 식별하는 용도로 사용된다
func RenderAuthView(w http.ResponseWriter, r *http.Request) {
}

// Google OAuth 인증 콜백 핸들러
func Authenticate(w http.ResponseWriter, r *http.Request) {
}
```

<br>

# 인증 정보 설정

`auth.go`는 위에서 살펴봤던 OAuth2 인증을 위한 설정값과 인증에 필요한 데이터들을 독립적으로 관리하기위한 용도이다.

```go
// auth.go
const (
    CallBackURL = "http://localhost:1333/auth/callback"
  
    // 인증 후 유저 정보를 가져오기 위한 API
    UserInfoAPIEndpoint = "https://www.googleapis.com/oauth2/v3/userinfo"
  
    // 인증 권한 범위. 여기에서는 프로필 정보 권한만 사용
    ScopeEmail          = "https://www.googleapis.com/auth/userinfo.email"
    ScopeProfile        = "https://www.googleapis.com/auth/userinfo.profile"
)
```

`CallBackURL`은 인증 서버가 권한 요청을 받은 후 리다이렉트할 URL이며, 프로바이더에 등록한 애플리케이션에서 지정한 콜백 URL과 일치해야한다. 

아래 나머지 URL들은 인증 후 발급된 토큰으로 리소스를 요청할 때 사용하는 URL들이다. (여기선, 인증 후 유저 정보를 가져오기 위함)

```go
// auth.go
var OAuthConf *oauth2.Config

func init() {
    OAuthConf = &oauth2.Config{
        ClientID:     "google client id",
        ClientSecret: "google client secret",
        RedirectURL:  CallBackURL,
        Scopes:       []string{ScopeEmail, ScopeProfile},
        Endpoint:     google.Endpoint,
    }
}

// state 값과 함께 Google 로그인 링크 생성
func GetLoginURL(state string) string {
    return OAuthConf.AuthCodeURL(state)
}

// 랜덤 state 생성기
func RandToken() string {
    b := make([]byte, 32)
    rand.Read(b)
    return base64.StdEncoding.EncodeToString(b)
}
```

**oauth2.Config**는 인증 처리를 위한 설정값들을 관리하는 구조체이다. 클라이언트 ID, 시크릿 키값 그리고 콜백 URL등을  지정할 수 있다. 위에서 발급받은 키값들로 설정하면된다. 더 좋은 방법은 키값을 코드에 바로 넣지 않고 환경 변수로 설정해 `os.GetEnv()`로 가져오는 방법이 있다. 실제 프로덕션에서 사용한다면 이 방법을 추천한다.

인증 처리에 필요한 설정값들을 모두 가지고 있어, 사실상 OAuth2 인증 처리를 위한 URL 생성, 토큰 교환과 같은 대부분의 기능들이 이 구조체의 메서드들로 이루어진다.

**GetLoginURL**은 `state` 값을 사용하여 생성한 구글 로그인 링크를 반환한다. 이 때, 이 로그인 링크에는 `OAuthConf`에서 설정한 `RedirectURL`이 따라 붙는다.

<br>

# 인증 처리

인증에 필요한 정보들을 다 설정했으니 이제 실제 인증 처리 과정을 살펴보자.

우선 Google 인증을 하기 전에 로그인 페이지에 접속하는 과정부터 살펴보자.

```go
// main.go
func RenderAuthView(w http.ResponseWriter, r *http.Request) {
    session, _ := store.Get(r, "session")
    session.Options = &sessions.Options{
        Path:   "/auth",
        MaxAge: 300,
     }
    state := RandToken()
    session.Values["state"] = state
    session.Save(r, w)
    RenderTemplate(w, "auth.html", GetLoginURL(state))
}
```

로그인 페이지에 접속하는 순간 `state` 값을 생성해 세션에 저장한 후, 이를 사용해 생성한 구글 로그인 링크를 반환한다. 세션에 저장한 `state` 값은 추후 콜백 인증 핸들러에서 `state` 값을 비교하기 위해 사용된다.

이후 유저는 **auth.html**에 렌더링된 구글 로그인 링크를 통해 구글 로그인을 시도할 것이다. 구글 로그인을 시도하면 위에서 생성된 `state` 값 및 `RedirectURL `과 함께 인증 서버에 권한 요청을 하게 된다. 인증 서버는 요청을 받고 `code` 값을 생성한 뒤 이 값을 `RedirectURL`에 붙여 리다이렉트를 한다.

`RedirectURL`인 `http://127.0.0.1:1333/auth/callback`로 리다이렉트가 되면 `Authenticate` 핸들러가 호출되고 토큰 인증 작업이 시작된다.

```go
// main.go
func Authenticate(w http.ResponseWriter, r *http.Request) {
    session, _ := store.Get(r, "session")
    state := session.Values["state"]

    delete(session.Values, "state")
    session.Save(r, w)

    if state != r.FormValue("state") {
        http.Error(w, "Invalid session state", http.StatusUnauthorized)
        return
    }
  
    ...
}
```

콜백 핸들러가 호출되면 제일 먼저 `state` 값이 유효한지 체크한다. 세션에 저장되어 있는 `state` 값과 비교를 진행하며 한 번 사용된 `state`는 세션에서 삭제한다.

```go
// main.go
func Authenticate(w http.ResponseWriter, r *http.Request) {
    ...
  
    token, err := OAuthConf.Exchange(oauth2.NoContext, r.FormValue("code"))
    if err != nil {
        http.Error(w, err.Error(), http.StatusBadRequest)
        return
    }
  
    ...
}
```

`state` 값이 유효하면 이제 전달받은 `code`를 사용해 인증 서버에 **엑세스 토큰**을 요청한다. `code` 값이 유효하다면 토큰을 정상적으로 받을 수 있다.

```go
// main.go
func Authenticate(w http.ResponseWriter, r *http.Request) {
    ...
  
    client := OAuthConf.Client(oauth2.NoContext, token)
    // UserInfoAPIEndpoint는 유저 정보 API URL을 담고 있음
    userInfoResp, err := client.Get(UserInfoAPIEndpoint)
    if err != nil {
        http.Error(w, err.Error(), http.StatusBadRequest)
        return
    }
    defer userInfoResp.Body.Close()
    userInfo, err := ioutil.ReadAll(userInfoResp.Body)
    if err != nil {
        http.Error(w, err.Error(), http.StatusBadRequest)
        return
    }
    var authUser User
    json.Unmarshal(userInfo, &authUser)
  
    ...
}
```

토큰을 받은 클라이언트는 이제 이 토큰을 가지고 유저 정보 리소스를 요청할 수 있다. 이 때, 요청 가능 데이터에 대한 범위는 아까 **인증 정보 설정**에서 살펴본 `OAuthConf`의 `Scopes`에서 지정한 권한 범위와 일치한다.

요청 데이터가 권한 범위 안에 속한다면 요청 데이터를 정상적으로 받아올 것이다.

```go
// main.go
func Authenticate(w http.ResponseWriter, r *http.Request) {
    ...

    session.Options = &sessions.Options{
        Path:   "/",
        MaxAge: 86400,
    }
    session.Values["user"] = authUser.Email
    session.Values["username"] = authUser.Name
    session.Save(r, w)

    http.Redirect(w, r, "/", http.StatusFound)
}
```

마지막으로 필수는 아니지만 받아온 데이터를 로그인 유지등의 목적으로 계속 사용하고자 한다면 세션에 넣어 관리할 수도 있다.

<br>

# 전체 코드

예제 테스트를 해볼 수 있도록 전체 코드를 공개하겠다. **auth.html**과 **main.html** 코드는 위에서 볼 수 있다.

## auth.go

```go
package main

import (
    "crypto/rand"
    "encoding/base64"

    "golang.org/x/oauth2"
    "golang.org/x/oauth2/google"
)

type User struct {
    Name  string `json:"name"`
    Email string `json:"email"`
}

const (
    CallBackURL = "http://localhost:1333/auth/callback"
  
    UserInfoAPIEndpoint = "https://www.googleapis.com/oauth2/v3/userinfo"
    ScopeEmail          = "https://www.googleapis.com/auth/userinfo.email"
    ScopeProfile        = "https://www.googleapis.com/auth/userinfo.profile"
)

var OAuthConf *oauth2.Config

func init() {
    OAuthConf = &oauth2.Config{
        ClientID:     "google client id",
        ClientSecret: "google client secret",
        RedirectURL:  CallBackURL,
        Scopes:       []string{ScopeEmail, ScopeProfile},
        Endpoint:     google.Endpoint,
    }
}

func GetLoginURL(state string) string {
    return OAuthConf.AuthCodeURL(state)
}

func RandToken() string {
    b := make([]byte, 32)
    rand.Read(b)
    return base64.StdEncoding.EncodeToString(b)
}
```

## main.go

```go
package main

import (
    "encoding/json"
    "html/template"
    "io/ioutil"
    "log"
    "net/http"

    "github.com/gorilla/sessions"
    "golang.org/x/oauth2"
)

var store = sessions.NewCookieStore([]byte("secret"))

func main() {
    http.HandleFunc("/", RenderMainView)
    http.HandleFunc("/auth", RenderAuthView)
    http.HandleFunc("/auth/callback", Authenticate)

    log.Fatal(http.ListenAndServe(":1333", nil))
}

func RenderTemplate(w http.ResponseWriter, name string, data interface{}) {
    tmpl, _ := template.ParseFiles(name)
    tmpl.Execute(w, data)
}

func RenderMainView(w http.ResponseWriter, r *http.Request) {
    RenderTemplate(w, "main.html", nil)
}

func RenderAuthView(w http.ResponseWriter, r *http.Request) {
    session, _ := store.Get(r, "session")
    session.Options = &sessions.Options{
        Path:   "/auth",
        MaxAge: 300,
	}
    state := RandToken()
    session.Values["state"] = state
    session.Save(r, w)
    RenderTemplate(w, "auth.html", GetLoginURL(state))
}

func Authenticate(w http.ResponseWriter, r *http.Request) {
    session, _ := store.Get(r, "session")
    state := session.Values["state"]

    delete(session.Values, "state")
    session.Save(r, w)

    if state != r.FormValue("state") {
        http.Error(w, "Invalid session state", http.StatusUnauthorized)
        return
    }

    token, err := OAuthConf.Exchange(oauth2.NoContext, r.FormValue("code"))
    if err != nil {
        http.Error(w, err.Error(), http.StatusBadRequest)
        return
    }

    client := OAuthConf.Client(oauth2.NoContext, token)
    userInfoResp, err := client.Get(UserInfoAPIEndpoint)
    if err != nil {
        http.Error(w, err.Error(), http.StatusBadRequest)
        return
    }
    defer userInfoResp.Body.Close()
    userInfo, err := ioutil.ReadAll(userInfoResp.Body)
    if err != nil {
        http.Error(w, err.Error(), http.StatusBadRequest)
        return
    }
    var authUser User
    json.Unmarshal(userInfo, &authUser)

    session.Options = &sessions.Options{
        Path:   "/",
        MaxAge: 86400,
    }
    session.Values["user"] = authUser.Email
    session.Values["username"] = authUser.Name
    session.Save(r, w)

    http.Redirect(w, r, "/", http.StatusFound)
}
```

<br>

# 마무리

이제까지 아주 보편적으로 널리 사용되고 있는 OAuth2 인증을 Go로 구현하는 방법을 살펴보았다. OAuth2에 친숙하지 않은 사람이라면 다소 복잡해 보일 수 있지만 OAuth2 플로우만 잘 이해한다면 코드 또한 쉽게 이해할 수 있을 것이다.

예제 코드 수준이라 코드 정리가 덜 되었지만 실제 프로덕션에서는 위 코드중 인증 부분만 잘 떼어내 인증 패키지로 묶어 모듈화 시키는게 좋을 것 같다.

기회가 된다면 다양한 프로바이더의 OAuth2를 인증 체계로 사용하는 하나의 완전한 웹 애플리케이션 튜토리얼을 만들어 보는것도 재밌을 것 같다.

