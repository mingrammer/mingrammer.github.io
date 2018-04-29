---
categories:
- testing
comments: true
date: 2018-04-29T00:00:00Z
tags:
- unittest
- time
- random
title: 시간에 의존하는 코드를 위한 테스트 작성하기
url: /writing-unit-test-for-time-dependent-code
---

그동안 귀찮고 번거롭다는 이유로 테스트 코드 작성을 매번 미루고 있다가 최근 들어 테스트 코드 작성에 습관을 들이고자 조금씩 테스트 코드 작성 비중을 높이고 있다. 며칠 전에도 필요한 커맨드라인 툴을 만들면서 테스트 코드를 작성하고 있었는데 한 가지 문제에 봉착했다.

보통 유닛 테스트를 하게 되면 어떤 특정한 조건하에서 혹은 특정한 정적인 데이터셋을 가지고 우리가 작성한 함수나 메서드를 테스트하곤한다. 그러나 내가 테스트하려던 코드는 정적인 데이터가 아닌 시시각각 변하는 즉, 시간에 의존하는 데이터를 가지고 있었기에, 어떤 특정한 테스트 케이스들을 미리 정해놓고 테스트하기가 어려운 상황이었다.

그리하여 이 포스팅에서는 이처럼 시간에 의존하는 데이터들을 다루는 코드를 테스트하는 방법에 대해서 소개하려고한다. 물론, 여기서 소개하는 내용들은 이미 잘 알려진 방법들이며 특별한 내용은 없으나 혹여나 여러분이 필자처럼 테스트 코드 작성에 조금 서툴다면 유익할 수도 있다.

> 참고로 이 포스팅에서는 Go 언어로 작성된 코드를 사용한다. 아이디어는 동일하므로 각자 언어에 맞게 적용하면 된다.

<br>

# 랜덤 시드 고정

예측할 수 없는 데이터의 대표적인 예는 바로 랜덤 데이터이다. 컴퓨터에서의 랜덤은 보통 시드(Seed)라는 초기값에 따라 일정한 규칙으로 값을 생성해내는 방식으로 동작한다. 따라서, 시드가 고정되어 있으면 랜덤은 동일한 값을 생성해내는데, 그렇기 때문에 보통은 유닉스 타임스탬프를 랜덤의 시드값으로 두어 시간에 따라 값이 변하게 만들어 실제 랜덤처럼 보이도록 코드를 작성하곤한다. 이 때문에 일반적인 경우, 랜덤 데이터는 시간에 의존적이라고 해도 무방하다.

그럼 이제 테스트 코드를 작성하기 전에 테스트를 위한 함수 하나를 작성해보자.

```go
// main.go
package main

import (
    "fmt"
    "math/rand"
    "time"
)

func RandFruit() string {
    set := []string{"apple", "melon", "banana", "mango"}
    index := rand.Intn(4) // 0 ~ 3 사이의 임의의 정수값 생성
    return set[index]
}

func main() {
    rand.Seed(time.Now().UnixNano())
    fmt.Println(RandFruit())
}
```

위 코드는 문자열 리스트에서 임의의 원소를 추출하는 코드이다. 이 코드를 실행하게 되면 `RandFruit` 함수는 무작위로 한 원소를 뽑아 반환한다. 그렇다면 이런 함수에 대한 테스트 코드는 어떻게 작성할 수 있을까?

사실 답은 이미 위에 적혀있다. 컴퓨터에서의 랜덤은 시드값을 기준으로 생성되기 때문에 단순히 시드값을 고정 시켜주면 된다. 즉, 테스트 함수 바디 안에서 시드값을 고정시키면 테스트하려는 함수는 동일한 값만을 반환하게 되어 Example 테스트가 가능해진다. (Go에서는 `// Output:`이라는 특별한 형태의 주석으로 Example 테스트를 지원한다)

> Example 테스트는 Go가 아니더라도 단순히 출력이 예상 Output과 같은지 검사하는 테스트이기 때문에 타 언어에서도 충분히 작성할 수 있는 형태이다.

```go
// main_test.go
package main

import (
    "fmt"
    "math/rand"
)

func ExampleRandFruit() {
    rand.Seed(11)
    fmt.Print(RandFruit())
    // Output: apple
}
```

<br>

# 몽키 패치를 통한 시간 고정

어느 정도 예측은 가능하나 정확한 예측이 어렵고 제어하기 어려운 데이터중 하나가 시간 데이터이다. 예측이 어느 정도 가능하다고는 했으나 테스트가 언제 실행될지는 알 수 없기 때문에 사실상 이 또한 예측이 불능하다고 볼 수 있다. 그렇다면 시간에 의존하는 코드를 위한 테스트 작성 또한 랜덤 테스트처럼 그 시간을 고정하면 해결되는 문제이다. 그러나 시간의 경우 랜덤 시드값과 달리 개발자가 제어하기 어려운 부분이다. 시간은 시스템 레벨에서 운영체제가 관리하고 있는데 시스템을 건드려서 시간을 조작한다한들 단순히 애플리케이션 테스트를 위해 시스템을 건드는건 그리 좋은 방법은 아니다. 또한 이는 시스템 시간을 조작한 머신이 아니면 무용지물이다.

따라서, 시스템 시간을 조작하는 대신 프로그래밍 언어 레벨에서 시간 정보를 가져오는 내장 패키지나 외부 패키지를 오버라이딩 혹은 래핑하는 방식으로 시간을 제어하는 방법을 사용하는게 깔끔할 것이다. 보통 이런 방식을 [몽키 패치](https://en.wikipedia.org/wiki/Monkey_patch)라고 한다. 몽키 패치 혹은 몽키 패칭이란 런타임중에 프로그램의 메모리를 직접 건드려 소스를 변형하는 행위를 말한다. 따라서, 몽키 패칭은 일반적인 경우에는 안티패턴으로 여겨진다. 실제 애플리케이션 로직 코드에서 몽키 패칭을 사용하는건 필자 또한 매우 지양하는바이며 테스트 코드와 같이 일부 제한된 환경에서만 사용하는걸 권한다.

그럼 우리는 이제 시간 데이터를 다루는 패키지 또는 해당 패키지의 특정 함수를 몽키 패칭하여 시간을 고정하여 테스트를 수행할 것이다. 설명은 장황했으나 사실 코드 레벨에서 보면 아주 간단하다.

그럼 이제 테스트 코드를 작성하기 전에 테스트를 위한 함수 몇개를 작성해보자.

```go
// example.go
package example

import (
    "fmt"
    "time"
)

func NewFakeLog(delta time.Duration) string {
    return fmt.Sprintf(
        RandIPv4Address(),
        RandUsername(),
        RandNumber(0, 1000),
        time.Now().Add(delta).Format(time.RFC3339),
        RandHTTPMethod(),
        RandResourceURI(),
        RandStatusCode(),
        RandNumber(0, 30000),
    )
}

func CheckUserType(user *User) string {
    now := time.Now()
    mod := user.Modified
    switch {
    // 7일 이내 접속 유저
    case mod.After(now.AddDate(0, 0, -7)):
        return "active"
    // 14일 이내 접속 유저
    case mod.After(now.AddDate(0, 0, -14)):
        return "returnable"
    // 14일 이내 미접속 유저
    default:
        return "human"
    }
}

func GetLuckySeven() (string, bool) {
    now := time.Now()
    // 일수가 7의 배수이면 경험치 2배 아이템을 지급한다
    if (now.Day() % 7 == 0) {
        return "lucky_double_exp", true
    }
    return "", false
}
```

위 함수들은 각기 다른 형태로 시간 데이터에 의존하고 있다. 따라서 함수의 실행 시점에 따라 그 결과가 달라질 수 있기 때문에 일반적인 방법으로는 테스트 코드를 작성하기가 어렵다. 따라서, 조금 전에 소개한 몽키 패치를 활용하여 위 함수들에 대한 테스트 코드를 작성해보고자 한다.

테스트 코드 작성은 단순히 테스트 함수 내에서 테스트 대상 함수를 실행하기전에 미리 시간 함수를 몽키 패칭 해두면 된다. 그리고 몽키 패칭을 한 뒤 함수 테스트까지 마치면 몽키 패치를 해제(몽키 언패치) 해주도록 하자.

여기서는 [`monkey`](github.com/bouk/monkey)라는 몽키 패치 라이브러리를 사용할 것이다. (Python 유저라면 [`freezegun`](https://github.com/spulec/freezegun)이라는 시간을 프리징해주는 라이브러리가 있다. 이 또한 내장 `datetime` 패키지를 래핑하는 몽키 패치용 라이브러리이다)

```go
// example_test.go
package example

import (
    "fmt"
    "github.com/bouk/monkey"
    "github.com/stretchr/testify/assert"
    "math/rand"
    "testing"
    "time"
)

func ExampleNewFakeLog() {
    // NewFakeLog의 경우 랜덤/시간 데이터를 모두 사용하고 있으므로 랜덤 시드 또한 고정해준다
    rand.Seed(11)
    
    // 고정된 시간만 나오도록 time.Now 메서드를 몽키 패치한다
    // 현재 시간을 2018년 4월 22일 9시 30분으로 고정
    monkey.Patch(time.Now, func() time.Time {return time.Date(2018, 04, 22, 9, 30, 0, 0, time.UTC)})
    // 테스트 메서드가 끝나면 time.Now를 몽키 언패치한다
    defer monkey.Unpatch(time.Now)
    
    fmt.Println(NewFakeLog(0))
    // Output: 222.83.191.222 - Kozey7157 697 [2018-04-22T09:30:00Z] "DELETE /innovate/next-generation" 302 24570
}

func TestCheckUserType(t *testing.T) {
    user := &User{
        Name: "mingrammer",
        Github: "https://github.com/mingrammer",
        Avatar: "https://mingrammer.com/images/avatar@2x.png",
        ...
        Modified: time.Date(2018, 04, 04, 12, 30, 0, 0, time.UTC),
    }
    
    // 현재 시간을 2018년 4월 10일 9시 30분으로 고정
    monkey.Patch(time.Now, func() time.Time {return time.Date(2018, 04, 10, 9, 30, 0, 0, time.UTC)})
    assert.Equal(t, "active", CheckUserType(user), "Given user is active user")
    
    // 현재 시간을 2018년 4월 17일 9시 30분으로 고정
    monkey.Patch(time.Now, func() time.Time {return time.Date(2018, 04, 17, 9, 30, 0, 0, time.UTC)})
    assert.Equal(t, "returnable", CheckUserType(user), "Given user is returnable")
    
    // 현재 시간을 2018년 4월 24일 9시 30분으로 고정
    monkey.Patch(time.Now, func() time.Time {return time.Date(2018, 04, 24, 9, 30, 0, 0, time.UTC)})
    assert.Equal(t, "human", CheckUserType(user), "Given user is human user")
    
    // 테스트 메서드가 끝나면 time.Now를 몽키 언패치한다
    monkey.Unpatch(time.Now)
}

func TestGetLuckySeven(t *testing.T) {
    // 현재 시간을 2018년 4월 7일 9시 30분으로 고정
    monkey.Patch(time.Now, func() time.Time {return time.Date(2018, 04, 07, 9, 30, 0, 0, time.UTC)})
    ls, ok := GetLuckySeven()
    assert.True(t, ok, "Today should be lucky day")
    assert.Equal(t, "lucky_double_exp", ls, "Today should be lucky day")
    
    // 현재 시간을 2018년 4월 9일 9시 30분으로 고정
    monkey.Patch(time.Now, func() time.Time {return time.Date(2018, 04, 09, 9, 30, 0, 0, time.UTC)})
    ls, ok = GetLuckySeven()
    assert.False(t, ok, "Today shouldn't be lucky day")
    assert.Equal(t, "", ls, "Today shouldn't be lucky day")
    
    // 테스트 메서드가 끝나면 time.Now를 몽키 언패치한다
    monkey.Unpatch(time.Now)
}
```

몽키 패치를 통해 현재 시간을 원하는값으로 설정할 수 있게되어 시간에 의존적인 코드를 아주 쉽고 편하게 테스트할 수 있게 되었다. 일반적으로 시간 데이터를 다루는 코드는 이처럼 몽키 패치를 사용해서 테스트 하는걸 추천한다. 다만, 위에서도 언급했지만 테스트와 같이 제한된 환경 외에서 몽키 패칭을 남용하는건 지양하길 바란다.

<br>

# 매개변수화

매개변수화는 랜덤과 시간 데이터를 사용하는 모든 코드에 활용할 수 있는 방법이다. 말 그대로 랜덤이나 시간 데이터를 내부에서 선언하거나 생성하지 않고 매개변수를 통해 받아 사용하는 방식이다. 따라서 꼭 시드를 고정하거나 몽키 패칭을 하지 않더라도 제한된 조건 하에서 테스트를 보다 쉽게 할 수 있다.

처음에 살펴본 코드에 매개변수화를 적용하면 다음과 같이 변형할 수 있다.

```go
func RandFruit(index int) string {
    set := []string{"apple", "melon", "banana", "mango"}
    return set[index]
}

func main() {
    rand.Seed(time.Now().UnixNano())
    index := rand.Intn(4) // 0 ~ 3 사이의 임의의 정수값 생성
    fmt.Println(RandFruit(index))
}
```

이렇게 매개변수화를 하면 다음과 같이 테스트가 가능해진다.

```go
func ExampleRandFruit() {
    fmt.Print(RandFruit(0))
    // Output: apple
}
```

시간 데이터도 마찬가지로 시간 파라미터를 추가하면된다.

```go
func GetLuckySeven(date time.Time) (string, bool) {
    if (date.Day() % 7 == 0) {
        return "lucky_double_exp", true
    }
    return "", false
}
```

```go
func TestGetLuckySeven(t *testing.T) {
    now := time.Date(2018, 04, 07, 9, 30, 0, 0, time.UTC)}
    ls, ok := GetLuckySeven(now)
    assert.True(t, ok, "Today should be lucky day")
    assert.Equal(t, "lucky_double_exp", ls, "Today should be lucky day")
    
    now = time.Date(2018, 04, 09, 9, 30, 0, 0, time.UTC)})
    ls, ok = GetLuckySeven(now)
    assert.False(t, ok, "Today shouldn't be lucky day")
    assert.Equal(t, "", ls, "Today shouldn't be lucky day")
}
```

이렇게 랜덤 및 시간 데이터를 매개변수화하면 별다른 시드 고정이나 몽키 패치를 하지 않아도 몽키 패치를 한 것처럼 테스트 코드 작성이 가능하기 때문에 테스트 코드 작성에 대한 공수를 줄일 수 있다.

물론 이 또한 완벽한 방법은 아니다. 처음부터 코드를 위와 같이 작성하면 모르겠으나 그렇지 않은 경우에는 테스트의 편리함을 위해 모든 랜덤 및 시간 데이터를 파라미터로 만들어야하는 문제가 생길 수 있다. 또한, 랜덤 및 시간 데이터의 매개변수화 자체가 불필요한 작업이거나 이로 인해 유지보수하기 어려운 형태가 만들어질수도 있기 때문에 매개변수화를 해도 괜찮은 상황이 아니라면 이보단 몽키 패치를 활용하는게 더 나을 것 같다.

이상으로 랜덤 및 시간 데이터를 다루는 코드를 위한 테스트 코드 작성 방법에 대해서 살펴보았다. 아주 흔하고 난이도 있는 내용도 아니지만 테스트 초보인 누군가에게는 도움이 되었으면 한다.

다음에도 기회가 된다면 다른 여러 테스트 방법에 대해서 다뤄보도록 하겠다.