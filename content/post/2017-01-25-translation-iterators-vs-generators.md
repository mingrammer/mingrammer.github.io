---
categories:
- translation
- python
comments: true
date: 2017-01-25T00:00:00Z
tags:
- deep dive
- iterator
- generator
title: '[번역] 이터레이터와 제너레이터'
url: /translation-iterators-vs-generators
---

> [Iterables vs. Iterators. vs Generators](http://nvie.com/posts/iterators-vs-generators/)를 번역한 글입니다. 모든 이미지는 원문에서 발췌하였습니다.

나는 파이썬에서 다음과 같은 개념들간의 정확한 차이점에 대해 가끔씩 혼란스러울때가 있다.

* 컨테이너 (Container)
* 이터레이블 (Iterable)
* 이터레이터 (Iterator)
* 제너레이터 (Generator)
* 제너레이터 표현식 (Generator expression)
* {list, set, dict} 컴프리헨션 ({list, set, dict} comprehension)

나는 이 포스트를 나중에 레퍼런스로써 참고하기위해 작성하고있다.

![relationships](/images/2017-01-25-iter-vs-gen-relationships.png)

<br>

# 컨테이너 (Container)

컨테이너(Container)는 원소들을 가지고 있는 데이터 구조이며 멤버쉽 테스트를 지원한다. (멤버쉽 테스트는 아래에 나온다) 이는 메모리에 상주하는 데이터 구조로, 보통 모든 원소값을 메모리에 가지고 있다. 파이썬에서 잘 알려진 컨테이너는 다음과 같다:

* **list**, deque, ...
* **set**, frozonset, ...
* **dict**, defaultdict, OrderedDict, Counter, ...
* **tuple**, namedtuple, ...
* **str**

컨테이너는 실세계의 컨테이너(박스, 컵보드, 집, 화물 등)처럼 생각하면 되기에 다루기가 쉽다.

기술적으로, 어떤 객체가 특정한 원소를 포함하고 있는지 아닌지를 판단할 수 있으면 컨테이너라고 한다. 다음과 같이 리스트, 셋 또는 튜플에 대해 멤버쉽 테스트를 할 수 있다:

```python
>>> assert 1 in [1, 2, 3]     # lists
>>> assert 4 not in [1, 2, 3]
>>> assert 1 in {1, 2, 3}     # sets
>>> assert 4 not in {1, 2, 3}
>>> assert 1 in (1, 2, 3)     # tuples
>>> assert 4 not in (1, 2, 3)
```

딕셔너리 멤버쉽은 키 값을 체크한다:

```python
>>> d = {1: 'foo', 2: 'bar', 3: 'qux'}
>>> assert 1 in d
>>> assert 4 not in d
>>> assert 'foo' not in d  # 'foo'는 딕셔너리의 키값이 아니다
```

마지막으로 문자열에는 부분문자열이 "포함"되어 있는지를 체크할 수 있다:

```python
>>> s = 'foobar'
>>> assert 'b' in s
>>> assert 'x' not in s
>>> assert 'foo' in s  # 문자열은 부분문자열을 모두 "포함"하고 있다
```

마지막 예제는 조금 이상하지만, 이는 컨테이너 인터페이스가 어떻게 객체를 불투명하게 렌더링 하는지를 보여준다. 문자열은 모든 부분문자열들의 리터럴 복사본을 메모리에 저장하고 있지는 않지만, 의심의 여지 없이 위와 같이 사용할 수 있다.

> **참고**
>
> 대부분의 컨테이너가 자신이 포함하고 있는 모든 원소들을 생성하는 방법을 제공하지만, 이 기능은 이를 컨테이너로 만드는게 아니라 이터레이블로 만듭니다. (잠시 후에 살펴본다) 
>
> 모든 컨테이너가 이터레이블할 필요는 없다. 이의 한 예는 [Bloom filter](https://en.wikipedia.org/wiki/Bloom_filter)이다. 이와 같은 확률적 데이터 구조는 특정 원소를 포함하고 있는지는 판단할 수 있지만, 각각의 개별 원소를 반환하지는 못한다.

<br>

# 이터레이블 (Iterable)

좀 전에도 언급했듯이, 대부분의 컨테이너는 또한 이터레이블(iterable)하다. 그러나 더 많은 것들 또한 이터레이블하다. 일례로 파일 열기, 소켓 열기등이 있다. 컨테이너가 일반적으로 유한할경우, 이터레이블은 무한한 데이터 소스를 나타낼 수도 있다.

**이터레이블(iterable)**은 반드시 데이터 구조일 필요는 없으며 **이터레이터(iterator)**(모든 원소를 반환할 목적으로)를 반환할 수 있는 모든 객체가 가능하다. 이는 조금 어색하게 들릴 수 있지만, 이터레이블과 이터레이터 사이에는 중요한 차이점이 있다. 다음 예시를 보자:

```python
>>> x = [1, 2, 3]
>>> y = iter(x)
>>> z = iter(x)
>>> next(y)
1
>>> next(y)
2
>>> next(z)
1
>>> type(x)
<class 'list'>
>>> type(y)
<class 'list_iterator'>
```

여기서, **y**와 **z**는 각각 이터레이블 **x**로부터 값을 생성해내는 이터레이터의 인스턴스이고 **x**는 이터레이블이다. **y**와 **z**는 예시에서 볼 수 있듯이 상태를 가진다. 이 예시에서, **x**는 데이터 구조(리스트)지만, 이는 필수 요건은 아니다.

> 참고
>
> 종종, 실용적인 이유로, 이터레이블 클래스는 같은 클래스에 **__iter__()**와 **__next__()**를 모두 구현하며, 클래스를 이터레이블과 자체 이터레이터로 만들어주는 **self**를 반환하는 **__iter__()**를 갖는다. 그러나 이터레이터로 다른 객체를 반환해도 전혀 상관이 없다.

마지막으로, 다음과 같이 작성하면:

```python
x = [1, 2, 3]
for elem in x:
    ...
```

실제로 다음과 같은 일이 일어난다:

![iterable-vs-iterator](/images/2017-01-25-iter-vs-gen-iterable-vs-iterator.png)

파이썬 코드를 디스어셈블링(어셈블리 수준으로 코드를 해부함) 해보면 **iter(x)**를 실행시키는데 필요한 **GET_ITER**를 호출하고 있음을 볼 수 있다. **FOR_ITER**는 모든 원소를 반복적으로 가져오기 위해 **next()**를 호출하는것과 동일한 일을 수행하는 명령어지만, 인터프리터에서 속도에 최적화 되어있기 때문에 바이트 코드 명령어에서는 보이지 않는다.

```python
>>> import dis
>>> x = [1, 2, 3]
>>> dis.dis('for _ in x: pass')
  1 		 0 SETUP_LOOP        14 (to 17)
    		 3 LOAD_NAME          0 (x)
	     	 6 GET_ITER
	  >> 	 7 FOR_ITER           6 (to 16)
	     	10 STORE_NAME         1 (_)
	     	13 JUMP_ABSOLUTE      7
	  >>   	16 POP_BLOCK
	  >>   	17 LOAD_CONST         0 (None)         
	     	20 RETURN_VALUE   
```

<br>

# 이터레이터 (Iterator)

그럼 **이터레이터(iterator)**란 무엇인가? 이는 **next()**를 호출할 때 다음값을 생성해내는 상태를 가진 헬퍼 객체이다. **__next__()**를 가진 모든 객체는 이터레이터이다. 값을 생성해내는 방법과는 무관하다.

즉 이터레이터는 값 생성기이다. "다음"값을 요청할 때마다 내부 상태를 유지하고 있기 때문에 다음값을 계산하는 방법을 알고있다.

이터레이터의 예시는 셀 수 없이 많다. **itertools**의 모든 함수는 이터레이터를 반환한다. 일부는 무한 시퀀스를 생성한다:

```python
>>> from itertools import count
>>> counter = count(start=13)
>>> next(counter)
13
>>> next(counter)
14
```

일부는 유한 시퀀스로부터 무한 시퀀스를 생성한다:

```python
>>> from itertools import cycle
>>> colors = cycle(['red', 'white', 'blue'])
>>> next(colors)
'red'
>>> next(colors)
'white'
>>> next(colors)
'blue'
>>> next(colors)
'red'
```

일부는 무한 시퀀스로부터 유한 시퀀스를 생성한다:

```python
>>> from itertools import islice
>>> colors = cycle(['red', 'white', 'blue'])  # 무한
>>> limited = islice(colors, 0, 4)            # 유한
>>> for x in limited:						# 따라서 for 루프에 사용하기에 안전하다
... 	print(x)
red
white
blue
red
```

이터레이터의 내부 구조를 좀 더 잘 이해하기위해, 피보나치수를 생성하는 이터레이터를 만들어보자:

```python
>>> class fib:
...     def __init__(self):
...         self.prev = 0
...         self.curr = 1
...
...     def __iter__(self):
...         return self
...
...     def __next__(self):
...         value = self.curr
...         self.curr += self.prev
...         self.prev = value
...         return value
>>> f = fib()
>>> list(islice(f, 0, 10))
[1, 1, 2, 3, 5, 8, 13, 21, 34, 55]
```

참고로 이 클래스는 이터레이블(**__iter__()** 메서드를 사용하므로)이자 자체 이터레이터(**__next__()** 메서드를 가지므로)이다.

이터레이터 내의 상태는 **prev**와 **curr** 인스턴스값으로 유지되고 있으며, 이터레이터를 호출하는 서브 시퀀스에 사용된다. **next()**를 호출할때마다 두 가지 중요한 작업이 수행된다:

1. 다음 **next()** 호출을 위해 상태를 변경한다
2. 현재 호출에 대한 결괏값을 생성한다

> **핵심 아이디어: 게으른 팩토리 (a lazy factory)**
>
> 바깥에서보면 이터레이터는 값을 요청할때까지 유휴(idle) 상태인 게으른 팩토리처럼 보인다. 이는 하나의 값을 생성한 후에 다시 유휴 상태가 된다. 

<br>

# 제너레이터 (Generator)

드디어, 우리의 목적지에 도착했다! 제너레이터는 내가 파이썬에서 정말 좋아하는 기능이다. 제너레이터는 특별한 종류의 이터레이터이다. (우아한 종류의)

제너레이터를 사용하면 위 예시의 피보나치 시퀀스 이터레이터와 같은 이터레이터를 만들 수 있지만,  **__iter__()**와 **__next__()** 메서드로 클래스를 작성하는걸 피하는 우아하고 간결한 문법을 사용한다.

명쾌하게 정리하면 다음과 같다:

* 모든 제너레이터는 이터레이터이다 (그 반대는 성립하지 않는다)
* 모든 제너레이터는 게으른 팩토리이다 (즉, 값을 그 때 그 때 생성한다)

다음은 제너레이터로 작성된 동일한 피보나치 시퀀스 팩토리이다:

```python
>>> def fib():
...     prev, curr = 0, 1
...     while True:
...         yield curr
...         prev, curr = curr, prev + curr
...
>>> f = fib()
>>> list(islice(f, 0, 10))
[1, 1, 2, 3, 5, 8, 13, 21, 34, 55]
```

와우, 우아하지 않은가? 이 아름다움을 만들어주는 매직 키워드를 보라:

```
yield
```

무슨일이 일어나고 있는지 차근 차근 살펴보자: 우선, **fib**가 일반적인 파이썬 함수로써 정의되었음을 볼 수 있다. 특별할게 없다. 그러나, 함수 몸체(body)에 **return** 키워드가 없음을 주목하라. 이 함수의 반환값을 제너레이터이다. (이터레이터이고 팩토리이자 상태를 가진 헬퍼 객체)

`f = fib()`가 호출될 때, 제너레이터(팩토리)가 인스턴스화되어 반환된다. 이 시점에선 아무런 코드도 실행되지 않는다: 제너레이터는 초기에 유휴 상태에서 시작한다. 좀 더 명확하게는, `prev, curr = 0, 1`은 아직 실행되지 않았다.

그 다음에 제너레이터 인스턴스는 **islice()**로 래핑되었다. 이것 자체도 또한 이터레이터이므로 초기엔 유휴 상태이다. 여전히 아무일도 일어나지 않았다.

그 다음엔 이터레이터가 **list()**로 래핑되었는데 이는 인자들을 모두 소비하여 리스트를 만들어낸다. 이를 위해, **list**는 **islice()** 인스턴스에서 **next()**를 호출하기 시작하며 또한 **islice**는 **f** 인스턴스에서 **next()**를 호출하기 시작한다.

하나씩 짚어보자. 첫번째 호출시, 마침내 코드가 조금씩 실행된다: `prev, curr = 0, 1`이 실행되고, `while True` 루프에 들어가 `yield curr` 구문을 만난다. 이는 현재 **curr** 변수에 저장된 값을 생성하고나서 다시 유휴 상태로 돌아간다.

이 값은 **islice()** 래퍼에 전달되어 생성되고 (아직 10번째 값을 지나지 않았으므로), **list**는 이제 값 **1**을 리스트에 추가할 수 있다.

다음으로, 이는 다음값을 **islice()**에 요청하고, **islice**는 **f**에 다음값을 요청하는데, 이 때 **f**는 이전 상태로부터의 유휴 상태가 풀리며 `prev, curr = curr, prev + curr`를 이어서 실행한다. 다시 `while loop`의 다음 반복에 재진입하여, `yield curr` 구문을 만나 `curr`의 다음값을 반환한다.

이 작업은 결과 리스트가 10개의 원소를 가질때까지 계속 진행되며 **list()**가 **islice()**에 11번째 값을 요청할때, **islice()**는 마지막에 도달했음을 가리키는 `StopIteration` 익셉션을 발생시키고 리스트는 결괏값을 반환한다: 첫 10개의 피보나치 수들을 포함하는 리스트. 참고로 제너레이터는 11번째 **next()** 호출을 받지 않는다. 실제로, 이는 다시 사용되지 않으며, 나중에 가비지 컬렉션에 의해 수집된다. 

<br>

## 제너레이터의 타입

파이썬에는 두 가지 타입의 제너레이터가 있다: 제너레이터 **함수(functions)**와 제너레이터 **표현식(expressions)**. 제너레이터 함수는 몸체에 **yield** 키워드가 나타나는 모든 함수들이다. 우리는 아까 이의 예시를 보았다. **yield** 키워드가 있는것만으로도 함수를 제너레이터 함수로 만들기에 충분한 조건이다.

또 다른 타입의 제너레이터는 리스트 컴프리헨션(list comprehension)과 동일한 제너레이터이다. 이 구문은 제한된 사용 케이스에 대해 매우 우아하다.

제곱수의 리스트를 만들기 위해 이 구문을 사용한다고 해보자:

```python
>>> numbers = [1, 2, 3, 4, 5, 6]
>>> [x * x for x in numbers]
[1, 4, 9, 16, 25, 36]
```

셋 컴프리헨션으로도 동일한 일을 할 수 있다:

```python
>>> {x * x for x in numbers}
{1, 4, 36, 9, 16, 25}
```

또는 딕셔너리 컴프리헨션에서도 마찬가지이다:

```python
>>> {x: x * x for x in numbers}
{1: 1, 2: 4, 3: 9, 4: 16, 5: 25, 6: 36}
```

하지만 제너레이터 표현식 또한 사용할 수 있다 (유의: 이는 튜플 컴프리헨션이 *아니다*)

```python
>>> lazy_squares = (x * x for x in numbers)
>>> lazy_squares
<generator object <genexpr> at 0x10d1f5510>
>>> next(lazy_squares)
1
>>> list(lazy_squares)
[4, 9, 16, 25, 36]
```

참고로, **next()**로 **lazy_squares**에서 첫번째 값을 읽었으므로, 상태는 "두번째" 항목에 위치한다. 따라서 **list()**를 호출하여 전체값을 받아올때는, 제곱수의 일부분만 반환한다. (이는 단지 게으른 행동을 보여준다.) 이는 위의 다른 예제와 마찬가지로 제너레이터 (그리고 따라서, 이터레이터)이다.

<br>

# 정리

제너레이터는 놀랍도록 강력한 프로그래밍 구조이다. 이는 몇가지 중간 변수와 데이터 구조를 가지고 스트리밍 코드를 작성할 수 있게 해준다. 게다가, 이는 메모리/CPU 효율이 더 좋다. 마지막으로, 이는 코드의 라인수를 줄여주는 경향도 있다.

제너레이터를 시작하는 팁: 여러분의 코드에서 다음과 같이 할 수 있는 부분을 찾아보라:

```python
def something():
    result = []
    for ... in ...:
        result.append(x)
   	return result
```

이를 다음으로 교체한다:

```python
def iter_sometime():
    for ... in ...:
        yield x
        
# def something()  # 정말로 리스트 구조가 필요할때만
#     return list(iter_something())
```

