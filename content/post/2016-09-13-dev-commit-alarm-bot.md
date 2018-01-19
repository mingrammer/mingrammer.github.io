---
categories:
- bot
comments: true
date: 2016-09-13T00:00:00Z
tags:
- bot
title: 일일커밋 알림봇 개발기
url: /dev-commit-alarm-bot
---

얼마 전부터 일일코딩/일일커밋에 도전하고 있다. 일일커밋이란, 말 그대로 하루에 적어도 하나의 커밋은 하자!라는 뜻으로 매일 매일 발전해 나가겠다는 의미를 가지기도한다.
사실 몇 달 전부터 해볼까 해볼까만 하다가 개발자 친구중 한 명이 몇 주 전부터 일일커밋을 하기 시작한걸 보고 자극을 받아 이참에 한 번 해보자!해서 바로 시작했다.

나는 현재 집에서만 작업(~~백수~~)을 하고 있기 때문에 개발을 하거나 공부를 하면서 자연스럽게 일일커밋을 달성할 수 있다. 그러나 일정이 생긴다거나 나중에 입사를 해 조금씩 바빠지기 시작한다면, 의식적으로 인지하지 않는 이상 일일커밋을 못할 수도 있을 것 같았다.

그래서 누가 하루마다 나한테 커밋좀 하라고 알려주면 좋겠다는 생각을했고, 이 부분은 위에서 언급한 친구도 동의를하여 커밋 알람봇을 개발하기로 하였다. (개발하겠다고 말하자마자 레포를 파고 바로 시작하였다.)

기능은 다음과 같은데 개발기를 작성하기가 민망할정도로 간단하다.

`Github에서 오늘자 커밋이 없을 경우 Slack DM으로 커밋 독촉(?) 알림 메시지를 날리는것이다.`

나는 돈이 없기 때문에 위 기능을 위한 주기적 태스크를 돌려줄 서버를 띄울 수가 없었다. 돈이 있어도 겨우 이 정도가지고 서버를 돌리고 싶지는 않았다. 그래서 단순히 '일정주기'(트리거) 마다 Github의 커밋 여부  체크 후  DM만 쏴주면 되기때문에 `AWS Lambda`를 사용하기로 했다.

Slack은 Incoming webhook을 제공하고, Github도 각종 Git Data를 가져올 수 있는 API를 제공하기 때문에 내가 할 일은 그냥 둘을 이어주는 스크립트를 짜는게 전부였다.

사실 너무 간단한 기능이라 설명할 게 많지 않아서 개발 도중 나타난 이슈에 대한 이야기를 중심으로 하려고한다. 내가 직면한 문제는 다음과 같다.

1. AWS Lambda 배포의 번거로움
2. 오늘자 Commit을 조회하는데에 시간이 오래 걸림

우선, AWS Lambda 배포의 번거로움은 [apex](https://github.com/apex/apex)를 사용하여 쉽게 해결할 수 있었다. `apex`는 간단히 말해서 AWS Lambda management tool이라고 할 수 있는데, Lambda 배포 및 관리를 쉽게 만들어준다. 기존대로라면 필요한 파일 및 폴더등을 .zip으로 만들고, aws cli에서 필요 옵션들을 타이핑하여 배포를 해야하는데 apex에서는 명령어 하나로 이 모든게 자동화된다. 물론, 굳이 apex를 안쓰고 shell script로 작성해도 단일 명령으로 배포가 가능하다. 그러나 배포해야할 Lambda function들이 많아지고 이에 따라 늘어나는 Lambda 세팅 변수 관리와 버전 관리등이 많아진다면 apex가 훨씬 편리하다.
apex의 기본 사용법은 다음과 같으며 자세한 내용은 [공식 문서](https://github.com/apex/apex/tree/master/docs)를 참고하면 될 것 같다.

```
$ curl https://raw.githubusercontent.com/apex/apex/master/install.sh | sh
$ apex init
$ apex deploy
$ apex invoke function_name // Lambda function 실행. 테스트 용도로 사용할 수 있음.
```

Lambda function 개발이 끝나면 다음 명령어로 배포를 할 수 있다.

```
$ apex deploy
```

이게 끝이다. 물론 Deploy전에 AWS 계정과 Lambda ARN 설정이 필요하다.

다음으로 Commit 조회에 대한 이슈이다. 나는 PyGithub라는 Python용 Github API 라이브러리를 사용했다. 처음엔 그냥 로그인 후 보유한 Repository를 모두 순회하며, 각 Repository의 Commit을 가져와 날짜를 비교한 뒤 오늘자 Commit만 저장하는 리스트를 만들었었다.

```python
today = datetime.datetime.today()
today_date = datetime.datetime(today.year, today.month, today.day)
time_delta = today_date - timedelta(days=1)

username = 'username'
password = 'password'

client = Github(username, password)

commits = []

for repo in client.get_user(username).get_repos():
    commits.extend(repo.get_commits(since=time_delta, author=g.get_user().login).get_page(0))

if len(commits) == 0:
    # push message to slack
```

그러나 위처럼 모든 Repo를 가져오고 그 안에서 Commit들을 가져오게 되면 그 숫자 만큼의  API call이 발생하기 때문에 많은 레포를 가졌을 경우, 매우 심각한 성능 저하 현상이 일어난다. 그래서 이 스크립트는 그대로 쓸 수가 없었다.

그럼 어떻게 해야 이를 해결할 수 있을까 고민하며 Github API 사이트를 둘러보다 Activity 데이터의 `Events` API에 주목했다. 이 API를 사용하면 어떤 특정 사용자의 이벤트 리스트를 가져올 수 있는데 여기서 이벤트란, 사용자의 거의 모든 활동 내역을 포함한다. 예를 들면, 푸시를 했다는 `PushEvent`, 이슈를 남겼다는 `IssueEvent`, 풀 리퀘스트를 날렸다는 `PullRequestEvent`등등이 있다. 아! 그럼 이벤트 리스트에서 `PushEvent`와 `PullRequestEvent`를 받아오면 되겠구나!하며 바로 수정 작업에 들어갔다.

```python
today = datetime.datetime.today()
today_date = datetime.datetime(today.year, today.month, today.day)
today_date_ko = today_date - datetime.timedelta(hours=9)

username = 'username'
password = 'password'

client = Github(username, password)

commit_events = []

for event in client.get_user(username).get_events():
    if event.created_at > today_date_ko and event.type in ['PushEvent', 'PullRequestEvent']:
        commit_evnts.append(event)

if len(commit_events) == 0:
    # push message to slack
```

이처럼 Repo가 아닌 Event들을 가져오게되면, 모든 Repo를 순회할 필요가 없어 API call을 아낄 수 있으며 그에 따라 아까 발생하던 심각한 성능 저하 문제를 해결할 수 있다. 그러나 이 스크립트도 아직 완벽하진않다. 왜냐하면 Events API는 호출 시 모든 이벤트를 가져오지 않고, 한번에 최근 30개의 이벤트만을 가져오기 때문에 위의 루프는 최대 10번(Events API는 최근 300개 까지의 이벤트만 가져옴)의 Events API call을 발생시킬 수도 있다.
그런데 조금 전에 말했듯이  Events API는 이벤트를 시간 순서대로 가져온다. 즉, 루프를 순회하며 어떤 특정 이벤트가 오늘 날짜가 아닐 경우 그 뒤의 이벤트는 검사할 필요가 없다.

```python
...

for event in client.get_user(username).get_events():
    if event.created_at > today_date_ko:
        if event.type in ['PushEvent', 'PullRequestEvent']:
            commit_events.append(event)
    else:
        break

if len(commit_events) == 0:
    # push message to slack
```

최종 스크립트가 완성되었다. 이제 이를 Slack webhook과 연동하고 배포를 하면 원하던 기능이 완성된다!

> "그렇다면 굳이 Commit 리스트를 만들지않고, 발견될 시 바로 break하면 되지 않느냐"고 할 수도 있다. 맞다. 바로 break를 하면 성능이 좀 더 올라간다. 그러나 오늘자 Commit 리스트를 만든건 추후 커밋 알림뿐 아니라 오늘의 커밋에 대한 Stats도 제공하고자 해서이다

----

만약 오늘 커밋을 안했다면 .. 이렇게 잘 날아온다.

![commit](/images/2016-09-13-commit.png)

----

모든 소스코드는 [여기](https://github.com/geekhub-lab/commit-alarm)에 공개 되어있다. (~~이슈와 PR은 언제나 환영이다!~~)
