---
categories:
- python
comments: true
date: 2017-03-20T00:00:00Z
tags:
- deep dive
- asterisk
title: 파이썬의 Asterisk(*) 이해하기
url: /understanding-the-asterisk-of-python
---

파이썬은 타 언어에 비해 비교적 연산자 및 연산의 종류가 풍부한 편이다.

특히 파이썬이 지원하는 많은 연산자중 하나인 **Asterisk(\*)**는 단순히 곱셈 이상의 여러 의미를 갖는 연산들을 가능케한다. 이번 포스트에서는 파이썬을 좀 더 파이썬스럽게 (보통 *Pythonic하다*라고 표현한다) 쓰기 위해 이 **Asterisk(\*)**로 할 수 있는 여러 연산들을 살펴보고자 한다.

파이썬에서 **Asterisk(\*)**는 다음과 같은 상황에서 사용되는데 크게 4가지의 경우가 있다.

* 곱셈 및 거듭제곱 연산으로 사용할 때
* 리스트형 컨테이너 타입의 데이터를 반복 확장하고자 할 때
* 가변인자 (Variadic Arguments)를 사용하고자 할 때
* 컨테이너 타입의 데이터를 Unpacking 할 때

그럼 이제 각 경우에 대해서 **Asterisk(\*)**가 어떻게 쓰이는지 살펴보자.

<br>

# 1. 곱셈 및 거듭제곱 연산으로 사용할 때

이미 다들 알고 있는 곱셈 연산으로 사용할 수 있으며, 파이썬은 곱셈 뿐만 아니라 거듭제곱 연산까지 내장 기능으로 지원하고 있다.

```shell
>>> 2 * 3
6
>>> 2 ** 3
8
>>> 1.414 * 1.414
1.9993959999999997
>>> 1.414 ** 1.414
1.6320575353248798
```

<br>

# 2. 리스트형 컨테이너 타입의 데이터를 반복 확장하고자 할 때

파이썬에서는 **\***을 숫자형 데이터 뿐만 아니라 리스트형 컨테이너 타입에서 데이터를 반복적으로 확장하기 위해 사용할 수도 있다.

```python
# 길이 100의 제로값 리스트 초기화
zeros_list = [0] * 100

# 길이 100의 제로값 튜플 선언
zeros_tuple = (0,) * 100

# 리스트 3배 확장 후 연산
vector_list = [[1, 2, 3]]
for i, vector in enumerate(vector_list * 3):
    print("{0} scalar product of vector: {1}".format((i + 1), [(i + 1) * e for e in vector]))
# 1 scalar product of vector: [1, 2, 3]
# 2 scalar product of vector: [2, 4, 6]
# 3 scalar product of vector: [3, 6, 9]
```

<br>



# 3. 가변인자 (Variadic Parameters)를 사용하고자 할 때

우리는 종종 어떤 함수에서 가변인자를 필요로 할 때가 있다. 예를 들어, 들어오는 인자의 갯수를 모른다거나, 그 어떤 인자라도 모두 받아서 처리를 해야하는때가 있다.

파이썬에서는 인자의 종류가 2가지가 있는데 하나는 **positional arguments**이고, 하나는 **keyword arguments**이다. 전자는 말그대로 위치에 따라 정해지는 인자이며, 후자는 키워드를 가진 즉, 이름을 가진 인자를 말한다.

variadic positional/keyword arguments를 살펴보기 전에 간단하게 positional arguments과 keyword arguments에 대해 살펴보겠다.

```python
# 2~4명의 주자로 이루어진 달리기 대회 랭킹을 보여주는 함수
def save_ranking(first, second, third=None, fourth=None):
    rank = {}
    rank[1], rank[2] = first, second
    rank[3] = third if third is not None else 'Nobody'
    rank[4] = fourth if fourth is not None else 'Nobody'
    print(rank)    

# positional arguments 2개 전달
save_ranking('ming', 'alice')
# positional arguments 2개와 keyword argument 1개 전달
save_ranking('alice', 'ming', third='mike')
# positional arguments 2개와 keyword arguments 2개 전달 (단, 하나는 positional argument 형태로 전달)
save_ranking('alice', 'ming', 'mike', fourth='jim')
```

위의 함수는 `first`, `second`라는 두 개의 positional arguments를 받으며 `third`, `fourth`라는 두 개의 keyword arguments를 받고 있다. positional arguments의 경우 생략이 불가능하며 갯수대로 정해진 위치에 인자를 전달해야한다. 그러나 keyword arguments의 경우 함수 선언시 디폴트값을 설정할 수 있으며, 만약 인자를 생략할 시 해당 디폴트값이 인자의 값으로 들어간다. 즉, 이 형태의 인자는 생략이 가능하다. 따라서, 여기서 알 수 있는건 keyword arguments의 경우 생략이 가능하기 때문에, positional arguments 이전에 선언될 수는 없다. 즉, 다음의 코드는 에러를 발생시킨다.

```python
def save_ranking(first, second=None, third, fourth=None):
    ...
```

그런데 세 번째를 보면 positional arguments가 3개, keyword argument가 1개 전달되고 있다. 눈치가 빠른 사람을 알겠지만, keyword arguments의 경우 선언된 위치만 동일할 경우 키워드를 제외하고 positional arguments 형태로 전달이 가능하다. 즉, 위에서 `mike`는 자동적으로 `third`라는 키로 전달이 된다.

여기까지가 파이썬의 arguments에 관한 기본적인 설명이다. 그런데, 여기서 한 가지 문제를 맞닥뜨릴 수 있다. 만약, 최대 4명의 주자가 아닌 10명 또는 그 이상의 정해지지 않은 주자가 있다고 해보자. 이 경우엔 10개의 인자를 선언하기도 번거로우며, 특히, 주자의 수가 미정일 경우 위와 같은 형태로는 처리가 불가능하다. 이 때 사용하는게 바로 **가변인자 (Variadic Arguments)**이다. 가변인자는 좀 전에 위에서 설명한 positional arguments와 keyword arguments에 모두 사용할 수 있으며, 사용 방법은 다음과 같다.

<br>

## positional arguments만 받을 때

```python
def save_ranking(*args):
    print(args)
save_ranking('ming', 'alice', 'tom', 'wilson', 'roy')
# ['ming', 'alice', 'tom', 'wilson', 'roy']
```

<br>

## keyword arguments만 받을 때

```python
def save_ranking(**kwargs):
    print(kwargs)
save_ranking(first='ming', second='alice', fourth='wilson', third='tom', fifth='roy')
# {'first': 'ming', 'second': 'alice', 'fourth': 'wilson', 'third': 'tom', 'fifth': 'roy'}
```

<br>

## positional arguments와 keyword arguments를 모두 받을 때

```python
def save_ranking(*args, **kwargs):
    print(args)
    print(kwargs)
save_ranking('ming', 'alice', 'tom', fourth='wilson', fifth='roy')    
# ('ming', 'alice', 'tom')
# {'fourth': 'wilson', 'fifth': 'roy'}
```

<br>

위에서 `*args`는 임의의 갯수의 positional arguments를 받음을 의미하며, `**kwargs`는 임의의 갯수의 keyword arguments를 받음을 의미한다. 이 때 `*args`, `**kwargs` 형태로 가변인자를 받는걸 **packing**이라고 한다.

위의 예시에서 볼 수 있듯이, 임의의 갯수와 임의의 키값을 갖는 인자들을 전달하고 있다. positional 형태로 전달되는 인자들은 `args`라는 *list*에 저장되며, keyword 형태로 전달되는 인자들은 `kwargs`라는 *dict*에 저장된다.

아까 positional과 keyword의 선언 순서를 언급했었는데, keyword는 positional보다 앞에 선언할 수 없기 때문에 다음의 코드는 에러를 발생시킨다.

```python
def save_ranking(**kwargs, *args):
    ...
```

이 가변인자는 매우 일반적으로 사용되는 기능으로 많은 오픈소스 코드에서도 쉽게 찾아볼 수 있다. 보통 오픈소스의 경우 코드의 일관성을 위해 `*args`이나 `**kwargs`와 같이 관례적으로 사용되는 인자명을 사용하지만, `*required`나 `**optional`과 같이 인자명은 일반 변수와 같이 원하는대로 지정이 가능하다. (단, 만약 오픈소스 프로젝트를 하고 있고, 인자에 특별한 의미가 있지 않은 일반적인 가변인자라면 `*args`와 `**kwargs`와 같이 관례를 따르는게 좋다.)

<br>

# 4. 컨테이너 타입의 데이터를 Unpacking 할 때

**\***는 컨테이너 타입의 데이터를 unpacking 하는 경우에도 사용될 수 있다. 이는 3번과 유사한 원리로, 종종 사용할만한 기능(연산)이다. 가장 쉬운 예로, 다음과 같이 우리가 *list*나 *tuple* 또는 *dict* 형태의 데이터를 가지고 있고 어떤 함수가 가변인자를 받는 경우에 사용할 수 있다.

```python
from functools import reduce

primes = [2, 3, 5, 7, 11, 13]

def product(*numbers):
    p = reduce(lambda x, y: x * y, numbers)
    return p

product(*primes)
# 30030

product(primes)
# [2, 3, 5, 7, 11, 13]
```

`product()` 함수가 가변인자를 받고 있기 때문에 우리는 리스트의 데이터를 모두 unpacking하여 함수에 전달해야한다. 이 경우 함수에 값을 전달할 때 `*primes`와 같이 전달하면 `primes` 리스트의 모든 값들이 unpacking되어 `numbers`라는 리스트에 저장된다. 만약 이를 `primes` 그대로 전달한다면 이 자체가 하나의 값으로 쓰여 `numbers`에는 `primes`라는 원소가 하나 존재하게 된다.

*tuple*도 *list*와 정확히 동일하게 동작하며 *dict*의 경우 **\*** 대신 **\****을 사용하여 동일한 형태로 사용할 수 있다.

```python
headers = {
    'Accept': 'text/plain',
    'Content-Length': 348,
    'Host': 'http://mingrammer.com'
}

def pre_process(**headers):
    content_length = headers['Content-Length']
    print('content length: ', content_length)
    
    host = headers['Host']
    if 'https' not in host:
        raise ValueError('You must use SSL for http communication')
        
pre_process(**headers)
# content length:  348
# Traceback (most recent call last):
#   File "<stdin>", line 1, in <module>
#   File "<stdin>", line 7, in pre_process
# ValueError: You must use SSL for http communication
```

또 다른 형태의 unpacking이 한 가지 더 존재하는데, 이는 함수의 인자로써 사용하는게 아닌 리스트나 튜플 데이터를 다른 변수에 가변적으로 unpacking 하여 사용하는 형태이다.

```python
numbers = [1, 2, 3, 4, 5, 6]

# unpacking의 좌변은 리스트 또는 튜플의 형태를 가져야하므로 단일 unpacking의 경우 *a가 아닌 *a,를 사용
*a, = numbers
# a = [1, 2, 3, 4, 5, 6]

*a, b = numbers
# a = [1, 2, 3, 4, 5]
# b = 6

a, *b, = numbers
# a = 1
# b = [2, 3, 4, 5, 6]

a, *b, c = numbers
# a = 1
# b = [2, 3, 4, 5]
# c = 6
```

여기서 `*a`, `*b`로 받는 부분들은 우변의 리스트 또는 튜플이 unpacking된 후, 다른 변수들에 할당된 값 외의 나머지 값들을 다시 하나의 리스트로 packing한다. 이는 3번에서 살펴본 가변인자 packing과 동일한 개념이다.

<br>

# 결론

이상으로 크게 4가지의 **Asterisk(*)**를 활용한 연산들을 살펴보았다. 하나의 연산자로 여러가지 연산들을 할 수 있다는 점이 흥미로웠으며, 위의 대부분은 Pythonic한 코드를 짜기 위한 기본적인 내용들이다. 이 중 특히 3번의 경우 매우 자주 사용되는 중요한 기능이자 파이썬 초보자들이 자주 헷갈려하는 부분이기에 초보자라면 더더욱 잘 숙지하였으면 좋겠다. 

다음에도 파이썬의 다른 흥미로운 내용들을 다뤄보겠다.