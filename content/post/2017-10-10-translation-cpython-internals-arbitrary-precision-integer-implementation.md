---
categories:
- translation
- python
comments: true
date: 2017-10-10T00:00:00Z
tags:
- deep dive
- internal
title: "[번역] 파이썬 내부 동작 원리: 임의 정밀도의 정수 구현"
url: /translation-cpython-internals-arbitrary-precision-integer-implementation
---

> [Python internals: Arbitrary-precision integer implementation](https://rushter.com/blog/python-integer-implementation/)을 번역한 글입니다.

여러분은 파이썬을 사용하면서 정수의 크기에 제약이 없다는걸 알아챈 적이 있는가? 이에 대해 한 번 살펴보자.

파이썬은 모든 객체를 C 구조체로 표현한다. 다음 자료 구조는 파이썬의 모든 정수 객체를 담당한다.

```c
struct _longobject {
    PyObject_VAR_HEAD
    digit ob_digit[1];
} PyLongObject;
```

매크로 확장 후, 위 구조체의 단순화된 버전은 다음과 같다.

```c
struct {
    ssize_t ob_refcnt;
    struct _typeobject *ob_type;
    ssize_t ob_size;
    uint32_t ob_digit[1];
}
```

`ob_refcnt` 필드는 가비지 컬렉션 메커니즘에서 사용되는 [레퍼런스 카운팅](http://www.informit.com/articles/article.aspx?p=1357182&seqNum=3) 기법에서 사용되며, `ob_type`은 정수 타입을 나타내는 [구조체](https://docs.python.org/2/c-api/typeobj.html)에 대한 포인터이다.

일반적으로, C/C++과 같은 언어에서는 정수의 정밀도가 64비트로 제한되나, 파이썬은 [임의 정밀도 정수](https://en.wikipedia.org/wiki/Arbitrary-precision_arithmetic)를 언어 차원에서 지원한다. 파이썬 3부터는 더 이상 단순 정수 타입을 지원하지 않기 때문에, 모든 정수가 큰 숫자 (bignum)로 표현된다.

<br>

# 임의의 큰 정수를 저장하는 방법

한 가지 방법은 정수를 숫자들의 배열로 표현하는 것이다. 이를 효율적으로 구현하기 위해선 숫자를 [10진법](https://en.wikipedia.org/wiki/Decimal)에서 각 자릿수가 0부터 2^30-1까지의 단일 숫자를 나타내는 2^30 진법으로 변환해야한다. 플랫폼에 따라, 파이썬은 30 비트의 자릿수를 가진 32 비트의 부호 없는 정수 배열 또는 15 비트의 자릿수를 가진 16 비트의 부호 없는 정수 배열을 사용한다. 이러한 접근법을 사용하면 [추가적인 요구사항](https://github.com/python/cpython/blob/865e4b4f630e2ae91e61239258abb58b488f1d65/Include/longintrepr.h#L9)이 생기기 때문에 정수의 모든 비트를 사용할 수 없다. 위 구조체에서 `ob_digit` 필드는 이러한 배열을 담당한다.

불필요한 연산을 배제하기 위해 CPython은 -2^30 부터 2^30까지의 범위에 있는 정수들에 대해서는 "빠른 경로 (fast path)"를 구현하고 있다. 이 정수값들은 원소가 하나인 배열에 저장되며 고정 32 비트 정수처럼 다뤄진다.

전통적인 접근법과는 다르게, 정수의 부호는 `ob_size` 필드에 별도로 저장된다. 이 필드는 `ob_digit` 배열의 크기를 저장한다.  크기가 2인 배열의 부호를 바꾸기 위해선 `ob_size`를 -2로 변경하면 된다.

CPython 소스 코드의 [주석](https://github.com/python/cpython/blob/c5bace2bf7874cf47ef56e1d8d19f79ad892eef5/Include/longintrepr.h#L70)에서 다음과 같이 설명하고 있다:

```c
/* 큰 정수 표현법.
   절댓값은 다음과 같이 구할 수 있다.
     SUM(for i=0 through abs(ob_size)-1) ob_digit[i] * 2**(SHIFT*i)
   ob_size < 0이면 음수를 나타낸다.
   ob_size == 0이면 0을 나타낸다.
   정규화된 수의 경우, ob_digit[abs(ob_size)-1] (최상위 숫자)은 0이 될 수 없다. 또한, 모든 유효한 i 값에 대해 다음이 성립한다. (MASK는 1 << 30 - 1 또는 1 << 15 - 1)
     0 <= ob_digit[i] <= MASK
   할당 함수는 ob_digit[0] ... ob_digit[abs(ob_size)-1]을 실제로 사용할 수 있도록 추가 메모리를 할당한다.
   
   주의: PyVarObject의 서브타입을 생성하는 제네릭 코드는 정수가 ob_size의 부호 비트를 남용한다는 걸 인지해야함
*/
```

123456789101112131415의 표현식은 다음과 같다:

| | | | |
| -------- | ------ | -------- | -------- |
| ob_size | 3 |||
| ob_digit  | 437976919 | 87719511 | 107 ||

위 표현식을 좀 전에 설명한 알고리즘을 통해 변환하면 다음과 같다:

```latex
(437976919 * 2^(30*0)) + (87719511 * 2^(30*1)) + (107 * 2^(30*2))
```

<br>

# 자주 사용되는 정수들의 최적화

-5부터 256 사이의 작은 정수 객체들은 항상 초기화 도중에 미리 할당된다. 파이썬에서 정수는 불변 (immutable)이기 때문에, 이를 싱글턴으로 사용할 수 있다. 작은 정수가 필요한 경우 파이썬은 새로운 객체를 생성하는 대신 미리 할당된 객체를 가리킨다. 이로 인해 자주 사용되는 정수들에 대한 메모리 공간과 연산 비용을 상당히 많이 아낄 수 있다.

흥미롭게도, `PyLongObject` 구조체는 할당된 모든 정수들에 대해 최소 28 바이트를 할당하기 때문에 64 비트의 C 정수보다 약 3배나 많은 메모리를 사용한다.

<br>

# 수 체계 변환

그럼 이제 파이썬이 정수를 어떻게 배열로 변환하는지에 대해 살펴보자.

부호 없는 64 비트 정수를 파이썬의 정수 표현법으로 변환하는 간단한 예제를 살펴보자. 참고로 다음 코드에서 나오는 bignum은 `PyLongObject`로 직접 변환이 가능한 표준 C 타입에서 지원하는 가장 큰 숫자다. 더 큰 숫자는 문자열이나 바이트 배열에서 변환할 수 있다.

수 체계 변환이 익숙하지 않다면, 이 [튜토리얼](https://www.tutorialspoint.com/computer_logical_organization/number_system_conversion.htm)을 읽어볼 수 있다.

다음은 C 정수를 파이썬 정수로 변환하는 간단한 알고리즘이다:

```python
SHIFT = 30  # 각 자릿수를 나타낼 비트 갯수
MASK = (2 ** SHIFT)
bignum = 18446744073709551615

def split_number(bignum):
    t = abs(bignum)

    num_list = []
    while t != 0:
        # 나머지를 얻는다
        small_int = t % MASK  # 좀 더 효율적인 비트 연산: (t & (MASK-1))
        num_list.append(small_int)

        # 나눗셈의 정수부를 얻는다 (나눗셈 내림)
        t = t // MASK  # 좀 더 효율적인 비트 연산: t >>= SHIFT

    return num_list

def restore_number(num_list):
    bignum = 0
    for i, n in enumerate(num_list):
        bignum += n * (2 ** (SHIFT * i))
    return bignum

num_list = split_number(bignum)
assert bignum == restore_number(num_list)
```

위 알고리즘을 검증하기 위해 파이썬의 내부 표현을 살펴볼 수도 있다:

```python
import ctypes

class PyLongObject(ctypes.Structure):
    _fields_ = [("ob_refcnt", ctypes.c_long),
                ("ob_type", ctypes.c_void_p),
                ("ob_size", ctypes.c_ulong),
                ("ob_digit", ctypes.c_uint * 3)]


bignum = 18446744073709551615

for d in PyLongObject.from_address(id(bignum)).ob_digit:
    print(d)
```

<br>

# 산술 연산

기본 산술 연산은 우리가 이미 알고 있는 기초적인 수학을 사용하여 구현되어 있으나 딱 한 가지 차이점은 배열의 모든 원소를 하나의 '자릿수'로 다룬다는 점이다.

모든 연산은 최소 하나의 객체을 생성해낸다. 가령, `c += 10`을 실행하면 다음과 같은 단계들이 수행된다:

* `10`을 나타내는 미리 할당된 객체의 주소를 가져온다. (10은 작은 정수이므로 새로운 객체를 생성할 필요가 없다.)
* 덧셈의 결과값을 저장할 새로운 정수 객체를 생성한다.
* `c`와 `10`을 더한 후, 결과값을 새로 생성된 객체에 저장한다.
* 변수 `c`를 새 객체의 레퍼런스로 바꾼다.
* 가비지 컬렉터가 나중에 이 객체를 파기할 수 있도록, 이전 `c` 변수의 레퍼런스 카운트를 차감한다.

예시로, [캐리 (carrying)](https://en.wikipedia.org/wiki/Carry_(arithmetic))가 사용되는 덧셈 코드를 살펴보자.

```python
def add_bignum(a, b):
    z = []

    if len(a) < len(b):
        # a가 항상 b보다 크도록 만든다
        a, b = b, a

    carry = 0

    for i in range(0, len(b)):
        carry += a[i] + b[i]
        z.append(carry % MASK)
        carry = carry // MASK

    for i in range(i + 1, len(a)):
        carry += a[i]
        z.append(carry % MASK)
        carry = carry // MASK

    z.append(carry)

    # trailing zeros를 제거한다
    i = len(z)
    while i > 0 and z[i-1] == 0:
        i -= 1
    z = z[0:i]

    return z


a = 8223372036854775807
b = 100037203685477
assert restore_number(add_bignum(split_number(a), split_number(b))) == a + b
```

<br>

# 더 깊이 살펴보기

이 포스트에서 다루지 못한 많은 세부사항들이 더 있다. 정수에 대한 상세한 내용은 CPython ([1](https://github.com/python/cpython/blob/master/Objects/longobject.c), [2](https://github.com/python/cpython/blob/master/Include/longobject.h), [3](https://github.com/python/cpython/blob/master/Include/longintrepr.h)) 소스 코드를 참조하라.

