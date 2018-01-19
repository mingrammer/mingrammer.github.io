---
categories:
- go
comments: true
date: 2017-12-11T00:00:00Z
tags:
- cgo
- compile
title: 맥에서 리눅스로 CGO 라이브러리 크로스 컴파일하기
url: /cgo-cross-compile-for-mac-for-linux
---

최근에 Go 프로젝트를 macOS에서 CentOS로 크로스 컴파일 해야하는 일이 생겼다.

Go는 일반적으로 컴파일에 관여하는 환경 변수 설정만으로 매우 쉽게 크로스 컴파일이 가능하지만 `cgo` 기반으로 개발된 라이브러리를 사용한 애플리케이션을 크로스 컴파일 하는 경우에는 조금 다르다. `cgo` 기반의 라이브러리의 경우 별도의 C 컴파일러를 요구하는 경우가 있기 때문에 기존의 방법으로는 크로스 컴파일이 불가능하다.

따라서, `cgo` 기반의 라이브러리를 사용하는 Go 애플리케이션을 다른 OS로 컴파일 해야하는 경우 별도의 크로스 컴파일러를 사용해 빌드를 진행해야한다. 내가 최근에 사용하기도 했던 대표적인 `cgo` 기반의 Go 라이브러리로는 mattn이 만든 `go-sqlite3` 라이브러리가 있다. `go-sqlite3`의 경우 Github에도 빌드 관련 [이슈](https://github.com/mattn/go-sqlite3/issues/491)가 자주 올라온다.

다음과 같이 `go-sqlite3` 패키지를 호스트 OS (macOS) 용으로 빌드하는 경우에는 아무런 문제가 없다.

```go
// main.go
package main

import (
    "database/sql"
    "fmt"
    _ "github.com/mattn/go-sqlite3"
    "log"
    "os"
)

func main() {
    os.Remove("log.db")

    db, err := sql.Open("sqlite3", "./foo.db")
    if err != nil {
        log.Fatal(err)
    }
    defer db.Close()

    fmt.Println(db)
}
```

```bash
$ go build
$ file cross-compile-example
cross-compile-example: Mach-O 64-bit executable x86_64
```

아무 문제없이 macOS용 바이너리가 생성되었다.

이제 위 코드를 `linux/amd64`용으로 크로스 컴파일 해보자.

```bash
$ GOOS=linux GOARCH=amd64 go build
# github.com/mattn/go-sqlite3
../../mattn/go-sqlite3/sqlite3_go18.go:18:10: undefined: SQLiteConn
```

SQLiteConn이 정의되지 않았다는 에러가 발생하였다. 실제로 SQLiteConn가 정의된 [소스 코드](https://github.com/mattn/go-sqlite3/blob/master/sqlite3.go)와 cgo 플래그가 정의된 [소스 코드](https://github.com/mattn/go-sqlite3/blob/b8d537f91a262b86fc5dfae4fd5a5c282d2b95fd/sqlite3_libsqlite3.go)를 보면 C 코드가 포함되어 있는데 이 부분에서 에러가 발생한걸로 보인다. 따라서 이를 리눅스용으로 컴파일 하기 위해선 macOS에서 사용할 수 있는 리눅스용 컴파일러를 `CC` 환경 변수로 지정해야 한다.

나의 경우 macOS에서 사용할 수 있는 리눅스용 C/C++ 크로스 컴파일러로 [CrossGCC](http://crossgcc.rts-software.org/doku.php?id=compiling_for_linux)를 사용하였다. [이 사이트](http://crossgcc.rts-software.org/doku.php?id=compiling_for_linux)에 접속하여 타겟 리눅스의 아키텍쳐 비트수에 맞는 크로스 컴파일러를 macOS에 설치하고 설치된 크로스 컴파일러 바이너리 경로를 `$PATH`에 등록하기만 하면 된다. (설치 경로: `/usr/local/gcc-4.8.1-for-linux[32/64]/`)

```bash
$ ls /usr/local/gcc-4.8.1-for-linux64 -la
-rwxr-xr-x   1 root  wheel  1072832 10 13  2013 x86_64-pc-linux-addr2line
-rwxr-xr-x   2 root  wheel  1115744 10 13  2013 x86_64-pc-linux-ar
-rwxr-xr-x   2 root  wheel  1723952 10 13  2013 x86_64-pc-linux-as
-rwxr-xr-x   2 root  wheel   870360 10 13  2013 x86_64-pc-linux-c++
-rwxr-xr-x   1 root  wheel  1071740 10 13  2013 x86_64-pc-linux-c++filt
-rwxr-xr-x   1 root  wheel   866192 10 13  2013 x86_64-pc-linux-cpp
-rwxr-xr-x   1 root  wheel    41068 10 13  2013 x86_64-pc-linux-elfedit
-rwxr-xr-x   2 root  wheel   870360 10 13  2013 x86_64-pc-linux-g++
-rwxr-xr-x   2 root  wheel   866104 10 13  2013 x86_64-pc-linux-gcc
-rwxr-xr-x   2 root  wheel   866104 10 13  2013 x86_64-pc-linux-gcc-4.8.1
-rwxr-xr-x   1 root  wheel    39288 10 13  2013 x86_64-pc-linux-gcc-ar
-rwxr-xr-x   1 root  wheel    39384 10 13  2013 x86_64-pc-linux-gcc-nm
-rwxr-xr-x   1 root  wheel    39392 10 13  2013 x86_64-pc-linux-gcc-ranlib
-rwxr-xr-x   1 root  wheel   421340 10 13  2013 x86_64-pc-linux-gcov
-rwxr-xr-x   1 root  wheel  1161332 10 13  2013 x86_64-pc-linux-gprof
-rwxr-xr-x   4 root  wheel  1929396 10 13  2013 x86_64-pc-linux-ld
-rwxr-xr-x   4 root  wheel  1929396 10 13  2013 x86_64-pc-linux-ld.bfd
-rwxr-xr-x   2 root  wheel  1089744 10 13  2013 x86_64-pc-linux-nm
-rwxr-xr-x   2 root  wheel  1306216 10 13  2013 x86_64-pc-linux-objcopy
-rwxr-xr-x   2 root  wheel  2014804 10 13  2013 x86_64-pc-linux-objdump
-rwxr-xr-x   2 root  wheel  1115736 10 13  2013 x86_64-pc-linux-ranlib
-rwxr-xr-x   1 root  wheel   431520 10 13  2013 x86_64-pc-linux-readelf
-rwxr-xr-x   1 root  wheel  1079092 10 13  2013 x86_64-pc-linux-size
-rwxr-xr-x   1 root  wheel  1072808 10 13  2013 x86_64-pc-linux-strings
-rwxr-xr-x   2 root  wheel  1306216 10 13  2013 x86_64-pc-linux-strip
```

```bash
export PATH="${PATH}:/usr/local/gcc-4.8.1-for-linux64/bin"
```

이제 이 크로스 컴파일러를 사용해 `linux/amd64`용으로 다시 컴파일을 해보자.

```bash
# CC로 gcc 크로스 컴파일러를 지정한다
# CGO_ENABLED를 1로 설정해 CGO 사용을 명시한다
$ CC=x86_64-pc-linux-gcc GOOS=linux GOARCH=amd64 CGO_ENABLED=1 go build
$ file cross-compile-example
cross-compile-example: ELF 64-bit LSB executable, x86-64, version 1 (SYSV), dynamically linked, interpreter /lib64/ld-linux-x86-64.so.2, for GNU/Linux 2.4.0, not stripped
```

드디어 macOS에서 cgo 기반의 라이브러리를 사용하는 애플리케이션을 `linux/amd64` 바이너리로 크로스 컴파일 하는데에 성공하였다. 실제로 CentOS 7기반의 머신에서 애플리케이션을 구동하면 잘 동작한다.

단, OS에 따라 다르지만 생성된 바이너리가 동적 링킹을 사용하고 있어 사용하고 있는 타겟 OS에 라이브러리에서 요구하는 특정 C 라이브러리가 없거나 버전이 맞지 않는 경우에는 별도의 작업이 더 필요할 수도 있다.

사실 이 문제는 크로스 컴파일러만 설치하면 해결되는 문제라 내용은 크게 별건 없지만 누군가에게는 도움이 되었으면 한다.

<br>