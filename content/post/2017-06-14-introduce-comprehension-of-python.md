---
categories:
- python
comments: true
date: 2017-06-14T00:00:00Z
tags:
- comprehension
title: 파이썬의 Comprehension 소개
url: /introduce-comprehension-of-python
---

**Comprehension**이란 iterable한 오브젝트를 생성하기 위한 방법중 하나로 파이썬에서 사용할 수 있는 유용한 기능중 하나이다.

파이썬에는 다음과 같은 크게 네 가지 종류의 Comprehension이 있다.

* List Comprehension (LC)
* Set Comprehension (SC)
* Dict Comprehension (DC)
* Generator Expression (GE)

Generator의 경우 comprehension과 형태는 동일하지만 특별히 **expression**이라고 부른다.

그럼 이제 각각의 경우에 대해 간단히 살펴보자. (iterable과 generator에 대해서는 [이 포스팅](https://mingrammer.com/translation-iterators-vs-generators)을 참고하길 바란다.)

<br>

# List Comprehension (LC)

**List comprehension**은 리스트를 쉽게 생성하기 위한 방법이다. 이는 파이썬에서 보편적으로 사용되는 기능으로 조금만 응용하면 다양한 조건으로 리스트를 생성할 수 있는 강력한 기능중 하나이다.

우선 간단한 예제를 하나 살펴보자.

```python
# 20까지의 짝수를 출력하기 위해 다음과 같은 LC를 사용할 수 있다
evens = [x * 2 for x in range(11)]
# [0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20]

# 리스트의 모든 원소값을 정규화 시킨 후 상수값을 더하는 LC
vals = [32, 12, 96, 42, 32, 93, 31, 23, 65, 43, 76]
amount = sum(vals)
norm_and_move = [(x / amount) + 1 for x in vals]
# [1.0587155963302752, 1.0220183486238532, 1.1761467889908257, 1.0770642201834861, 1.0587155963302752, 1.1706422018348623, 1.0568807339449542, 1.0422018348623854, 1.1192660550458715, 1.0788990825688074, 1.1394495412844037]
```

조금 더 복잡한 예제를 살펴보자. (조건을 지닌 LC와 Nested LC)

```python
# 100 이하의 제곱수가 아닌 수를 찾는 LC
from math import sqrt
non_squars = [x for x in range(101) if sqrt(x)**2 != x]
# [2, 3, 5, 6, 7, 8, 10, 12, 13, 15, 18, 19, 20, 23, 24, 26, 28, 29, 31, 32, 37, 38, 40, 43, 45, 48, 50, 51, 52, 58, 59, 60, 61, 63, 65, 66, 72, 73, 75, 76, 77, 78, 80, 82, 87, 89, 92, 94, 95, 96, 97]

# 두 리스트의 원소들의 모든 조합을 찾는 LC
epithets = ['sweet', 'annoying', 'cool', 'grey-eyed']
names = ['john', 'alice', 'james']
epithet_names = [(e, n) for e in epithets for n in names]
# [('sweet', 'john'), ('sweet', 'alice'), ('sweet', 'james'), ('annoying', 'john'), ('annoying', 'alice'), ('annoying', 'james'), ('cool', 'john'), ('cool', 'alice'), ('cool', 'james'), ('grey-eyed', 'john'), ('grey-eyed', 'alice'), ('grey-eyed', 'james')]
```

조금 더 Practical한 예제를 살펴보자.

```python
# a^2 + b^2 = c^2 (a < b < c)를 만족하는 피타고라스 방정식의 해를 찾는 LC
solutions = [(x, y, z) for x in range(1, 30) for y in range(x, 30) for z in range(y, 30) if x**2 + y**2 == z**2]
# [(3, 4, 5), (5, 12, 13), (6, 8, 10), (7, 24, 25), (8, 15, 17), (9, 12, 15), (10, 24, 26), (12, 16, 20), (15, 20, 25), (20, 21, 29)]

# 단어에서 모음을 제거하는 LC
word = 'mathematics'
without_vowels = ''.join([c for c in word if c not in ['a', 'e', 'i', 'o', 'u']])
# 'mthmtcs'

# 행렬을 일차원화 시키는 LC
matrix = [
  [1, 2, 3, 4],
  [5, 6, 7, 8],
  [9, 10, 11, 12],
]
flatten = [e for r in matrix for e in r]
# [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
```

<br>

# Set Comprehension (SC)

**Set comprehension**은 LC와 정확히 동일하며 단지 list가 아닌 set을 생성한다는 것만 다르다.

```python
# 다음의 LC는 중복된 값들을 포함한다
no_primes = [j for i in range(2, 9) for j in range(i * 2, 50, i)]
# [4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30, 32, 34, 36, 38, 40, 42, 44, 46, 48, 6, 9, 12, 15, 18, 21, 24, 27, 30, 33, 36, 39, 42, 45, 48, 8, 12, 16, 20, 24, 28, 32, 36, 40, 44, 48, 10, 15, 20, 25, 30, 35, 40, 45, 12, 18, 24, 30, 36, 42, 48, 14, 21, 28, 35, 42, 49, 16, 24, 32, 40, 48]

# SC를 사용하면 중복값이 없는 집합을 얻을 수 있다
no_primes = {j for i in range(2, 9) for j in range(i * 2, 50, i)}
# {4, 6, 8, 9, 10, 12, 14, 15, 16, 18, 20, 21, 22, 24, 25, 26, 27, 28, 30, 32, 33, 34, 35, 36, 38, 39, 40, 42, 44, 45, 46, 48, 49}
```

<br>

# Dict Comprehension (DC)

**Dict comprehension** 또한 LC와 동일하며 dict를 생성한다.

기본 예제.

```python
# 두 리스트를 하나의 dict로 합치는 DC. 하나는 key, 또 다른 하나는 value로 사용한다
subjects = ['math', 'history', 'english', 'computer engineering']
scores = [90, 80, 95, 100]
score_dict = {key: value for key, value in zip(subjects, scores)}
# {'math': 90, 'history': 80, 'english': 95, 'computer engineering': 100}

# 튜플 리스트를 dict 형태로 변환하는 DC
score_tuples = [('math', 90), ('history', 80), ('english', 95), ('computer engineering', 100)]
score_dict = {t[0]: t[1] for t in score_tuples}
# {'math': 90, 'history': 80, 'english': 95, 'computer engineering': 100}
```

<br>

# Generator Expression (GE)

**Generator expression**은 특별한 형태의 comprehension이다. 이는 한 번에 모든 원소를 반환하지 않고 한 번에 하나의 원소만 반환하는 **generator**를 생성한다.

GE 또한 다른 Comprehension과 동일한 형태로 쉽게 사용할 수 있다.

```python
# 다음 Generator는 제곱수를 만들어낸다
gen = (x**2 for x in range(10))
print(gen)
# <generator object <genexpr> at 0x105bde5c8>
print(next(gen)) # call 1
# 0
print(next(gen)) # call 2
# 1
# 'next' 함수 호출을 10번 반복
print(next(gen)) # call 10
# 81
print(next(gen)) # call 11
"""
Traceback (most recent call last):
  File "<stdin>", line 1, in <module>
StopIteration
"""

# Yes, it is an just generator. You can sum the yielding values.
# GE로 생성한 Generator도 yield를 가진 함수로 생성한 것과 동일한 Generator이기 때문에, 똑같이 sum을 사용할 수 있다. (iterable 객체)
gen = (x**2 for x in range(10))
sum_of_squares = sum(gen)
# 285
```

<br>

이상으로 Comprehension과 Expression에 대해 간단히 살펴보았다. 이는 매우 강력한 기능중 하나로 잘만 활용하면 높은 생산성을 낼 수 있다.