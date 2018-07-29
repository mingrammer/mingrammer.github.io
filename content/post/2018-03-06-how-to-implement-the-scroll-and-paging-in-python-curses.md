---
categories:
- python
comments: true
date: 2018-03-06T00:00:00Z
tags:
- curses
- paging
title: 파이썬 curses에서 스크롤 및 페이징 기능 구현하기
url: /how-to-implement-the-scroll-and-paging-in-python-curses
---

TUI 애플리케이션을 개발하다보면 마주치는 어렵지는 않지만 다소 까다로운 문제가 하나 있는데, 바로 TUI 환경에서 화면을 동적으로 제어하는 것이다. 특히 한정된 화면에서 **리스트**를 다루게 된다면 **스크롤(Scroll)** 기능은 필수이며 리스트가 아주 길어질 수 있는 경우라면 **페이징(Paging)** 기능 또한 거의 필수적이게 된다. 이 포스팅에서는 파이썬의 **curses**라는 라이브러리에서 이 두 기능을 구현하는 방법에 대해서 다룰 것이다.

그럼 바로 본론으로 들어가서, **curses**에서 스크롤과 페이징을 구현하는 방법에 대해서 알아보겠다. 참고로 이 포스팅은 curses 튜토리얼은 아니며, 따라서 curses를 이미 사용해봤던 사람들한테 더욱 유용할 것이다.

이 포스팅에서는 전체 소스코드가 아닌 스크롤 및 페이징의 구현부 소스코드만 살펴볼 것이며, 전체 소스코드 및 실행 방법은 [Python Curses Scroll Example](https://github.com/mingrammer/python-curses-scroll-example)을 참고하면 된다. (전체 소스코드 : [tui.py](https://github.com/mingrammer/python-curses-scroll-example/blob/master/tui.py))

<br>

# 스크롤 (Scroll)

스크롤 구현의 아이디어는 간단하다. 전체 리스트에서의 현재 보여지는 윈도우의 최상단 위치와 현재 커서 위치를 기준으로 다음 커서의 위치를 계산하여 커서를 이동시키는 것이다. 이해하기 쉽게 실제 구현부 코드를 살펴보자.

## 구현

다음은 TUI 애플리케이션 실행 후 사용자로부터 키보드 입력을 받는 부분인데 `KEY_UP`과 `KEY_DOWN` 입력을 받게 되면 스크롤을 수행하는 `scroll` 메서드를 실행하게된다. (참고로, `UP=1`, `DOWN=-1`)

```python
def input_stream(self):
    """사용자 입력을 대기하며 입력값에 따라 해당되는 메서드를 실행함"""
    while True:
        self.display()

        ch = self.window.getch()
        if ch == curses.KEY_UP:
            self.scroll(self.UP)
        elif ch == curses.KEY_DOWN:
            self.scroll(self.DOWN)
        elif ch == curses.KEY_LEFT:
            self.paging(self.UP)
        elif ch == curses.KEY_RIGHT:
            self.paging(self.DOWN)
        elif ch == curses.ascii.ESC:
            break
```

스크롤을 구현할 때에는 다음 두 가지를 고려해야한다.

* 현재 커서가 현재 윈도우의 최상단 혹은 최하단에 위치하면서 커서와 윈도우가 모두 움직이는 경우
* 현재 커서가 현재 윈도우의 중간에 위치해 커서만 움직이는 경우

```python
# top: 리스트에서의 현재 윈도우의 최상단 라인의 위치
# current: 현재 보여지는 윈도우 기준 현재 커서 위치
# max_lines: 한 번에 볼 수 있는 최대 항목의 갯수
# bottom: 커서가 위치할 수 있는 최하단 라인의 위치
#
# ┌--------------------------------------┐
# |1. Item                               |
# |--------------------------------------| <- top = 1
# |2. Item                               |
# |3. Item                               |
# |4./Item///////////////////////////////| <- current = 3
# |5. Item                               |
# |6. Item                               |
# |7. Item                               |
# |8. Item                               | <- max_lines = 7
# |--------------------------------------|
# |9. Item                               |
# |10. Item                              | <- bottom = 10
# |                                      |
# |                                      | <- page = 1 (0 and 1)
# └--------------------------------------┘


def scroll(self, direction):
    # 방향에 따른 다음 라인 커서 위치 계산
    next_line = self.current + direction

    # 윈도우 스크롤 업
    # 현재 커서가 윈도우의 상단에 위치하나, 윈도우의 상단 라인이 최상단에 닿지 않았으므로 윈도우 스크롤 업이 가능하다
    if (direction == self.UP) and (self.top > 0 and self.current == 0):
        self.top += direction
        return

    # 윈도우 스크롤 다운
    # 다음 커서가 현재 윈도우의 하단에 위치하나, 커서의 절대 위치가 아직 최하단까지 도달하진 않았으므로 윈도우 스크롤 다운이 가능하다
    if (direction == self.DOWN) and (next_line == self.max_lines) and (self.top + self.max_lines < self.bottom):
        self.top += direction
        return

    # 스크롤 업
    # 현재 커서가 최상단보다 아래에 있으므로 스크롤 업이 가능하다
    if (direction == self.UP) and (self.top > 0 or self.current > 0):
        self.current = next_line
        return

    # 스크롤 다운
    # 다음 커서가 현재 윈도우의 하단보다 위에 있으며, 커서의 절대 위치가 아직 최하단까지 도달하진 않았으므로 스크롤 다운이 가능하다
    if (direction == self.DOWN) and (next_line < self.max_lines) and (self.top + next_line < self.bottom):
        self.current = next_line
```

## 스크롤 데모

* 스크롤 업 : **↑**
* 스크롤 다운 : **↓**

[![asciicast](https://asciinema.org/a/166994.png)](https://asciinema.org/a/166994)

<br>

# 페이징 (Paging)

스크롤은 커서 위치를 조정하면서 동작하는 반면, 페이징은 윈도우의 상단 라인 (`top` 변수)의 위치를 조정하면서 동작한다. 그렇기 때문에 페이징을 구현할 때에는 한가지 유의 해야할 부분이 있는데, 페이징을 하다가 마지막 페이지에 도달했을 때 현재 커서가 마지막 페이지에 나타나는 항목의 리스트보다 아래에 위치하는 경우, 이 커서 위치를 재조정해줘야 한다는 것이다.

## 구현

마찬가지로 키보드 입력을 받는 부분에서 `KEY_LEFT`와 `KEY_RIGHT` 입력을 받게 되면 페이징을 수행하는 `paging` 메서드를 실행하게된다.

 ```python
def paging(self, direction):
    # 윈도우의 상단 위치값과 현재 커서 위치로 현재 페이지와 다음 페이지를 계산
    current_page = (self.top + self.current) // self.max_lines
    next_page = current_page + direction

    # 마지막 페이지에 도달 했을 때 현재 커서가 마지막 페이지에 나타나는 항목의 리스트보다 아래에 있는 경우,
    # 현재 커서를 마지막 페이지 리스트의 마지막 항목 위치로 조정
    if next_page == self.page:
        self.current = min(self.current, self.bottom % self.max_lines - 1)

    # 페이지 업
    # 현재 페이지가 첫 페이지가 아닌 경우, 페이지 업이 가능하다
    # 윈도우 상단의 위치는 음수가 될 수 없으므로, 음수가 될 경우 0으로 조정
    if (direction == self.UP) and (current_page > 0):
        self.top = max(0, self.top - self.max_lines)
        return

    # 페이지 다운
    # 현재 페이지가 마지막 페이지가 아닌 경우, 페이지 다운이 가능하다
    if (direction == self.DOWN) and (current_page < self.page):
        self.top += self.max_lines
        return
 ```

## 페이징 데모

* 페이지 업 : **←**
* 페이지 다운 : **→**

[![asciicast](https://asciinema.org/a/166995.png)](https://asciinema.org/a/166995)

<br>

# 마무리

이제까지 **curses**를 사용해 TUI 환경에서 스크롤과 페이징을 구현하는 기법에 대해서 살펴보았다. 비단 curses가 아니더라도 다른 언어 및 라이브러리를 활용해 TUI 스크롤/페이징을 구현하고자 한다면 기본적인 아이디어는 그대로 차용할 수 있을 것이다. 다음엔 TUI 환경에서 나타날 수 있는 다른 다양한 동작들의 구현에 대해서 포스팅을 해보겠다.

