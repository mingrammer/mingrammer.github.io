---
categories:
- cron
comments: true
date: 2019-08-03T00:00:00Z
tags:
- cron
- scheduling
title: Cron에서 초단위로 스케줄링하기
url: /scheduling-cron-job-in-seconds-interval
---

최근에 2초에 한 번씩 특정 태스크를 수행하는 스크립트를 돌려야하는 일이 생겨서 cron으로 2초 단위 스케줄을 등록하려는데 cron은 최소 스케줄링 단위가 `분`이었기 때문에 cron의 구문을 활용한 일반적인 방식으로는 작업 등록을 할 수 없었다.

이 문제는 `sleep`을 사용해 하나의 스케줄 잡에서 특정 태스크가 일정 간격마다 실행되도록 하는 간단한 편법으로 해결할 수 있다. 즉, 가령 10초에 한 번씩 돌려야하는 태스크가 있다면 해당 태스크를 10초에 한 번씩 총 6번을 수행하는 스크립트를 1분에 한 번씩 돌도록 스케줄링 해주는 것이다.

위 방법을 사용하려면 스크립트를 약간 수정해줘야 하는데, 수정하고 싶지 않거나 수정할 수 없는 경우 또는 스크립트가 아닌 명령어 실행이라면 스케줄을 등록할때 여러개의 같은 잡을 등록하고 스크립트나 명령어 앞에 sleep만 넣어주면 된다.

# 스크립트에서 스케줄링하기

셸 스크립트의 경우 기존 태스크를 루프로 감싸고 안에서 sleep만 걸어주면 된다. 다른 언어를 사용중이라면 각 언어별로 내장된 sleep 함수를 사용하면 된다.

```sh
# original.
task;

# 2 seconds interval.
for i in {1..30}; do
    task;
    sleep 2;
done
```

그 다음 crontab에 1분 스케줄링을 걸어준다.

```sh
# crontab
* * * * * /bin/sh /path/to/script.sh
```

sleep 시간을 동적으로 설정하려면 sleep 시간을 받을 수 있도록 할 수도 있다.

```sh
n=$1
# n seconds interval.
for i in $(seq $((60/$n))); do
    task;
    sleep $n;
done
```

```sh
# crontab
* * * * * /bin/sh /path/to/script.sh 2
```

그런데 만약 task 실행 시간이 충분히 짧지 않다면 실질적인 sleep 시간은 task 실행시간 + sleep 시간이 되기 때문에 스케줄링에 오차가 생길 수 있다. 이 경우는 task를 백그라운드로 실행하면된다.

```sh
n=$1
# n seconds interval.
for i in $(seq $((60/$n))); do
    task &;
    sleep $n;
done
```

# Crontab에서 스케줄링하기

crontab 등록시 스크립트 실행 이전에 sleep을 걸어주면 된다. 단, 첫 스케줄잡은 제외한다. 스크립트를 수정하지 않아도 되기 때문에 가장 편하게 사용할 수 있는 방법이다.

```sh
# crontab
* * * * * /bin/sh /path/to/script.sh
* * * * * sleep 10; /bin/sh /path/to/script.sh
* * * * * sleep 20; /bin/sh /path/to/script.sh
* * * * * sleep 30; /bin/sh /path/to/script.sh
* * * * * sleep 40; /bin/sh /path/to/script.sh
* * * * * sleep 50; /bin/sh /path/to/script.sh
```

1분마다 모두 동시에 실행되지만 sleep이 있어 작업이 지연되므로 10초 간격으로 스케줄링된 것처럼 동작한다.