---
categories:
- reference
comments: true
date: 2017-02-02T00:00:00Z
tags:
- python
- go
title: Python vs Go 비교 레퍼런스
url: /side-by-side-reference-sheet-of-python-and-go
---

> Python과 Go의 비교 레퍼런스 (각기 버전은 Python 3.5+와 Go 1.7+)
> 
> 각 코드 블록은 Python/Go 순서

<br>

# <a name='version'>버전</a>



## 버전 확인

```shell
// Python
$ python --version
3.5
```
```shell
// Go
$ go version
1.7
```



<br>

# <a name='invocation'>실행</a>



## Hello World

```python
print("Hello, World")
```

```go
import "fmt"

func main() {
  fmt.Println("Hello, World")
}
```

## 프로그램 실행

```shell
$ python3 hello.py
```

```shell
$ go build hello.go
$ ./hello

# 또는 다음과 같이 직접 실행할 수 있음
$ go run hello.go
```

## 파일 확장자

```
.py
```


```
.go
```



<br>

# <a name='grammar'>문법</a>



## 블록 구분자

```python
# 콜론(:)과 들여쓰기(indentation)로 구분   
def main():
    # body
```


```go
// 중괄호로 구분
func main() {
    // body
}
```

## 주석

```python
# 주석

"""
멀티라인 주석
"""
```


```go
// 주석

/*
멀티라인 주석
*/
```

## 컨벤션

```python
# 보통 변수나 함수, 메서드는 스네이크 케이스 사용
variables_use_snake_case = 10
def some_func()

# 클래스는 파스칼 케이스 사용
class SomeClass
```


```go
// 보통 카멜 케이스 사용
variablesUseCamelCase := 10
func someFunc()

// 노출되는 변수나 함수, 타입은 파스칼 케이스 사용
ExportedVariablesUseCapitanCase := 10
type ExportedType struct
```



<br>

# <a name='variables-and-expressions'>변수와 표현식</a>



## 변수

```python
i = 1
s = "string"
```


```go
var i int
i = 1

// var s string = "string"과 동일
s := "string"
```

## 전역 변수

```python
# foo.py:
# 최상위 스코프에 있으면 전역변수로 사용 가능
x = 1

# bar.py:
import foo

print(foo.x)
```


```go
// foo.go:
package foo

// 대문자로 시작하면 타 패키지에서도 참조 가능
var X = 1
// 소문자로 시작하는 변수가 최상위 스코프에 있으면
// 한 패키지에서만 전역 변수로 사용 가능
var y = 1

// bar.go:
package bar

import (
    "fmt"
    "foo"
)

func main() {
    fmt.Println(foo.X)
    // fmt.Println(foo.y)는 불가능
}
```

## 상수

```python
// Python엔 상수라는 개념이 없으며
// 관례적으로만 상수임을 나타내기위해 대문자로된 변수를 사용
PI = 3.14159
```


```go
const PI = 3.14159
```

## 할당

```python
i = 2
```


```go
// 선언과 동시에 할당
i := 2

// 변수 i가 미리 선언되어 있어야함
i = 2
```

## 병렬 할당

```python
x, y = 1, 2
```


```go
x, y := 1, 2

// z, w가 미리 선언되어 있어야함
z, w = 3, 4
```

## 변수값 교환 (Swap)

```python
x, y = y, x
```


```go
x, y = y, x
```

## 증감

```python
i += 1
i -= 1
```


```go
i++
i--
```

## 포인터

```python
# none
```


```go
i := 1

var ptr *int
ptr = &i

// 역참조
j := *ptr
```



<br>

# <a name='types-and-operators'>타입 및 연산자</a>



## 부울타입

```python
True False
```


```go
true false
```

## 정수타입

```python
int
```


```go
int
int8
int16
int32 (rune)
int64

uint8 (byte)
uint16
uint32
uint64
```

## 실수타입

```python
float
```


```go
float32
float64
```


## 널타입

```python
None
```


```go
nil
```

## 타입 사이즈

```python
x = 1
x.__sizeof__()

# sys 모듈을 사용할 때
import sys
sys.getsizeof(x)
```


```go
import "unsafe"

i := 1
unsafe.Sizeof(i)
```


## 논리 연산자

```python
and or not
```


```go
&& || !
```

## 관계 연산자

```python
== != < > <= >=
```


```go
== != < > <= >=
```

## 산술 연산자

```python
+ - * / %
```


```go
+ - * / %
```

## 비트 연산자

```python
<< >> & | ^ ~
```


```go
<< >> & | ^
```

## 삼항연산자

```python
y = 1 if x > 0 else 0
```


```go
// none
```

## 나눗셈 연산

```python
int(1 / 3)  # 정수 나누기
1 / 3  # 실수 나누기

# 참고로 Python2에선 다음과 같다
1 / 3  # 정수 나누기
1 / float(3)  # 실수 나누기  
```


```go
1 / 3 // 정수 나누기
1/ float32(3) // 실수 나누기
```


<br>

# <a name='strings'>문자열</a>


## 타입

```python
str
```


```go
string
```

## 리터럴

```python
"string"
'string'
```


```go
"string"
`string`
```

## 리터럴 개행

```python
s = 'first \n second'
```


```go
s := `first
second`
```

## 문자열 비교

```python
'first' < 'second'
'fisrt' == 'second'
```


```go
"first" < "second"
"first" == "second"
```

## 문자열을 숫자로 변환

```python
i = int('13')
f = float('3.14')
```


```go
import "strconv"

// 두번째 인자는 밑수(base), 세번째 인자는 비트 크기
i, _ := strconv.ParseInt("13", 10, 32)

// 두번째 인자는 비트 크기
f, _ := strconv.ParseFloat("3.14", 32)
```

## 숫자를 문자열로 변환

```python
str(13)
str(3.14)
```


```go
import "strconv"

// 두번째 인자는 밑수(base)
strconv.FormatInt(13, 10)

// 세번째 인자는 소숫점 아래 정확도, 네번째 인자는 비트 크기 
strconv.FormatFloat(3.14, 'f', 4, 32)
```

## Join과 Split

```python
# join
'-'.join('ab', 'cd', 'ef')

# split
'ab-cd-ed'.split('-')
```


```go
import "strings"

// join
parts := []string{"ab", "cd", "ef"}
s := strings.Join(parse, "-")

// split
parts = strings.Split(s, "-")
```

## 문자 인덱스

```python
"hello"[1]  # e
```


```go
import "strings"

strings.Index("hello", "1") // 3
```

## 케이스 변환

```python
"hello".upper()
"hello".lower()
```


```go
import "strings"

strings.ToUpper("hello")
strings.ToLower("HELLO")
```

## 문자열 길이

```python
len("hello")
```


```go
len("hello")
```

## 문자 타입

```python
str
```


```go
rune
```

<br>

# <a name='fixed-arrays'>고정 배열</a>



## 선언 및 초기화

```python
# Python은 고정 배열을 네이티브로 지원하지 않음

# 명시적으로 표기할 순 있지만 길이 변경이 가능함
arr = [0] * 10

# collections 내장 패키지를 사용해 흉내낼 순 있음
# 길이는 보장되지만 일반적인 고정 배열처럼 동작하진 않음
import collections
arr = collections.deque([0] * 10, maxlen=10)
```

```go
// 배열(array)이라고 부름

// 선언
var arr [10]int

// 초기화 리터럴 선언
arr := []int{1, 2, 3}
```

<br>

# <a name='resizable-arrays'>동적 배열</a>



## 선언 및 초기화

```python
# 선언
arr = [] # 또는 list()

# 초기화 선언
arr = [1, 2, 3]
```


```go
// 슬라이스(slice)라고 부름

// 선언. 5는 길이, 10은 수용크기 (capacity)
arr = make([]int, 5, 10)

// 초기화 리터럴 선언
arr := []int{1, 2, 3}
```

## 사이즈

```python
len(arr)
```


```go
// 길이. array도 동일
len(arr)

// capacity 크기. 미리 할당된 메모리로 추가적인 값을 저장할 수 있음
cap(arr)
```

## lookup과 update

```python
# lookup
a = arr[0]

# update
arr[0] = 1
```


```go
// array도 동일

// lookup
a = arr[0]

// update
arr[0] = 1
```

## 배열 순회

```python
# 값 순회
for e in arr:
    print(e)

# 인덱스, 값 순회
for i, e in enumerate(arr):
    print("index : {0}, value : {1}".format(i, e))
```


```go
// array도 동일

// 값 순회
for _, e := range arr {
    fmt.Println(e)
}

// 인덱스, 값 순회
for i, e := range arr {
    fmt.Printf("index : %d, value : %d\n", i, e)
}
```

## 슬라이싱

```python
arr = [1, 2, 3, 4 5]

# [2, 3]
arr[1:3]

# [3, 4, 5]
arr[2:]
```


```go
// array도 동일

arr := []int{1, 2, 3, 4, 5}
# {2, 3}
arr[1:3]

// {3, 4, 5}
arr[2:]
```

## 값 추가

```python
arr = [1, 2, 3]
arr.append(4)
```


```go
arr := []int{1, 2, 3}
arr = append(arr, 4)
```

## 확장

```python
arr = [1, 2]
arr2 = [3, 4]

# [1, 2, 3, 4]
arr3 = arr + arr2

# arr = [1, 2, 3, 4]
arr.extend(arr2)
```


```go
// array도 동일

arr = [1, 2]
arr2 = [3, 4]

// [1, 2, 3, 4]
arr3 := append(a, a2...)
```

## 복사

```python
from copy import deepcopy

arr = [1, 2, 3]

# 얕은 복사 (Shallow copy)
arr2 = arr

# 깊은 복사 (Deep copy)
arr3 = deepcopy(arr)
```


```go
arr := []int{1, 2, 3}

// 얕은 복사 (Shallow copy)
arr2 := arr

// 깊은 복사 (Deep copy)
arr3 := make([]int, len(arr))
copy(arr3, arr)
```



<br>

# <a name='dictionaries'>딕셔너리(맵)</a>



## 선언 

```python
# 선언
d = {} # 또는 dict()

# 초기화 선언
d = {"a": 1, "b": 2}
```


```go
// 선언
d := make(map[string]int)

// 초기화 리터럴 선언
d := map[string]int{"a": 1, "b": 2}
```

## 사이즈

```python
len(d)
```


```go
len(d)
```

## lookup과 update

```python
# lookup
d["a"]

# update
d["a"] = 2
```


```go
// lookup
d["a"]

// update
d["a"] = 2
```

## 키값 확인

```python
# True
'a' in d

# False
'c' in d
```


```go
// ok = true
val, ok = d["a"]

// ok = false
val, ok = d["c"]
```

## 키 삭제

```python
del d['a']
```


```go
delete(d, "a")
```

## 딕셔너리(맵) 순회

```python
# 키만 순회
for k in d.keys(): # 또는 for k in a:
    print(k)

# 값만 순회
for v in d.values():
    print(v)
    
# 키,값 순회
for i, v in d.items():
    print("key : {0}, value : {1}", i, v)
```


```go
// 키만 순회
for i, _ := range d {
    print(k)
}

// 값만 순회
for _, v := range d {
    print(v)
}

// 키,값 순회
for i, v := range d {
    fmt.Printf("key : %s, value : %d", i, v)
}
```

<br>

# <a name='functions'>함수</a>



## 선언

```python
def add(a, b):
    return a + b
```


```go
func add(a int, b int) int {
    return a + b
}

// 같은 타입은 묶을 수도 있음
func add(a, b int) int {
    return a + b
}
```

## 가변 길이 인자

```python
def concat(*args):
    ret = ""
    for s in args:
        ret += s
    return ret       
```


```go
func concat(strs ...string) string {
    var ret = ""
    for _, str := range strs {
        ret += str
    }
    return ret
}
```

## 이름 있는 인자

```python
def add(first=0, second=0):
    return first + second
    
val = add(first=1, second=2)

# 생략하면 위치에 따라 값이 들어감
val = add(1, 2)
```


```go
// none
```


## 다중 반환

```python
def divmod(m, n):
    return m / n, m % n
    
q, r = divmod(7, 3)
```


```go
func divmod(m, n int) (int, int) {
    return m / n, m % n
}

q, r := divmod(7, 3)
```

## 이름 있는 반환값

```python
# none
```


```go
func divmod(m, n int) (q, r int) {
    q = m / n
    r = m % n
    return
}

q, r := divmod(7, 3)
```

<br>

# <a name='conditional-expression'>조건문</a>



## if문

```python
x = 2

if x == 1:
    print("x is 1")
elif x == 2:
    print("x is 2")
else:
    print("x is neither 1 or 2")
```


```go
x := 2

if x == 1 {
    fmt.Println("x is 1")
} else if x == 2 {
    fmt.Println("x is 2")
} else {
    fmt.Println("x is neither 1 or 2")
}
```

## switch문

```python
# none
```


```go
// switch문은 모든 타입을 받을 수 있음

switch i {
case 0, 1:
    fmt.Println("i is boolean")
default:
    fmt.Println("i is not a boolean")
}

// 조건을 무시하면서 case를 통과하려면 "fallthrough"를 사용
```



<br>

# <a name='loops-expression'>반복문</a>



## while문

```python
i = 0

while i < 10:
    i += 1
```


```go
i := 0

for i < 10 {
    i++
}
```

## for문

```python
n = 0

for i in range(10):
    n += i
```


```go
n := 0

for i := 0; i <= 10; i++ {
    n += i
}
```

## for-in(range)문

```python
arr = [1, 2, 3]

for i in arr:
    print(i)
```


```go
arr := []int{1, 2, 3}

for _, v := range arr {
    fmt.Println(v)
}
```



<br>

# <a name='libraries-and-namespaces'>라이브러리 및 네임스페이스</a>



## 라이브러리 로드

```python
import foo

bar = foo.something()
```


```go
import "foo"

bar := foo.Something()
```

## 서브디렉토리에 있는 라이브러리 로드 

```python
import foo.bar
```


```go
import "foo/bar"
```

## 네임스페이스

```python
# 모듈 네임스페이스는 보통 "import"로 불러온 모듈명을 따라감
import os # os
from os import path # path
```


```go
// 모든 소스파일 최상단에 네임스페이스를 선언해야함
package foo
```

## 네임스페이스 별명붙이기 (aliasing)

```python
import foo as fu
```


```go
import fu "foo"
```

## 미사용 임포트

```python
# none
```


```go
import _ "foo"
```



<br>

# <a name='user-defined-types'>사용자 정의 타입</a>



## 정의

```python
# 타입으로써의 정의는 없으며 클래스로 대체
class Exam:
    name = 'example'
    avg = 0
    
    def __init__(self, math, physics, sports, name=""):
        self.math = math
        self.physics = physics
        self.sports = sports
        if name:
            self.name = name
```


```go
type Exam struct {
    name    string
    avg     int
    math    int
    physics int
    sports  int
} 
```

## 초기화

```python
ricky_exam = Exam(100, 92, 93, name="Ricky")
```


```go
rickyExam := Exam{"Ricky", 100, 92, 93}

risaExam := Exam{
    name: "Risa",
    math: 89,
    physics: 78,
    sports: 88,
}
```

## 속성(멤버)값 할당

```python
ricky_exam.math = 97
ricky_exam.sports = 95
```


```go
rickyExam.math = 97
rickyExam.sports = 95
```



<br>

# <a name='error-handling'>에러 처리</a>



## 에러 처리

```python
def divide(n, m):
    if m == 0:
        raise ValueError("divisor is zero")
    return n / m

try:
    q = divide(10, 0)
except Exception as e:
    print(e)
```


```go
import (
    "errors"
    "fmt"
)

func divide(n, m int) (float32, error) {
    if m == 0 {
        return 0,0, errors.New("divisor is zero")
    }
    return n / float32(m), nil
}

q, err := divide(10, 0)
if err != nil {
    fmt.Println(err)
}
```


