---
categories:
- algorithm
comments: true
date: 2019-06-02T00:00:00Z
tags:
- aws
- dynamodb
- batchjob
- pattern
- cloud
title: DynamoDB 배치 작업 재시도 구현 (Exponential Backoff)
url: /dynamodb-batch-retry-with-exponential-backoff
---

약 두 달 전에 게임 서버 인프라를 이전하면서 일부 유저 데이터를 RDB와 캐시 디비에서 AWS DynamoDB로 변환 및 이전하는 작업을 진행했었다.

> TMI: 이전에 작성한 [IDC에서 AWS로 데이터 이전하기](/redis-migration)라는 포스팅에서는 내가 담당하고 있는 두 개의 게임중 한 게임의 데이터 이전에 대한 후기를 공유했었다. 당시 이전을 진행한 게임은 작년 11월에 이전이 완료되었고, 그 이후로도 다른 한 게임의 인프라 이전 또한 진행이되어 올해 4월 초에 이전이 완료되었다.
>
> 같은 인프라 이전이지만 두 게임은 서로 마이그레이션 요구사항이 달랐기 때문에 많은 부분이 서로 다른 방식으로 진행되었다. 그 중 특히 데이터 이전의 경우, 첫 번째 게임은 데이터 스키마와 데이터 스토어가 이전과 동일했던 반면, 두 번째 게임은 거의 대부분의 유저 데이터 스키마가 변경되었고 그에 따라 사용하게될 데이터 스토어 또한 달라졌다.

수억건에 달하는 많은 양의 데이터를 최대한 빠른 시간안에 이전해야했기 때문에 프로비저닝 모드가 아닌 온디맨드 모드로 배치 작업을 수행했다. 실행 후 얼마 지나지 않아 예상대로 배치 작업의 속도에 비례해서 다량의 스로틀링이 발생하고 있었다. DynamoDB는 온디맨드 모드여도 최대 **WCU (Write Capacity Unit)**에 한계치가 있어서 그 이상을 넘어가면 스로틀링이 발생하는건 자연스러웠기 때문에 스로틀링 자체는 문제가 되지 않았다. 다만, 스로틀링이 발생하고 있음에도 불구하고 데이터가 예상보다 훨씬 빠른 속도로 들어가고 있는게 조금 의아했었다.

모니터링중 초당 삽입되는 개수와 현재 처리중인 데이터의 인덱스가 안맞는게 이상해서 중간에 작업을 중단하고 속도 대비 예상 데이터 개수와 실제로 저장된 데이터 개수를 비교해봤는데, 역시나 실제로 들어간 데이터 개수는 예상치보다 훨씬 부족한 상태였다. 즉, 중간에 다량의 데이터 쓰기 작업이 실패한셈이다.

디버깅을 해보니 쓰기 요청 속도가 일정 수준을 넘어가는 순간 위와 같은 문제가 발생하기 시작했다. 배치 작업을 요청하는 부분에서 문제가 발생하고 있어 관련 문서를 찾아보니 DynamoDB는 배치 작업 처리시 하나의 요청이라도 성공하면 일부 요청이 실패해도 에러를 반환하지 않고 실패한 요청에 대한 키 또는 값을 다시 반환해준다는 내용을 볼 수 있었다.

요청이 아예 실패하는 케이스에 대한 에러 처리는 하고 있었으나 부분 실패에 대한 처리가 빠져있어 일부 실패한 쓰기 요청들이 모두 무시되면서 데이터가 누락되는 문제가 발생했던 것이다. (결국엔 문서를 제대로 안본게 문제였다..)

# DynamoDB Exponential Backoff 재시도 구현하기

따라서 부분 실패가 발생하면 반환된 키 또는 값으로 다시 배치 작업을 요청하는 재시도 로직을 구현하기로했다. 재시도 전략으로는 공식 문서에서도 권장하고 있는 지수 백오프 (Exponential Backoff) 알고리즘을 사용했다. 지수 백오프 알고리즘은 매우 간단한 알고리즘으로 실패할때마다 (또는 특정 피드백을 받을때마다) 다음 요청까지의 유휴시간 간격을 n배씩 늘리면서 재요청을 지연시키는 알고리즘이다. 이 알고리즘은 TCP 전송 재시도에서부터 다양한 요청 실패의 가능성을 내재하고있는 서비스에서 재시도 전략으로 채택하고 있는 알고리즘이다. (AWS의 다양한 서비스 또는 SDK에서 내부적으로 구현하고 있는 재시도 로직에서도 같은 알고리즘을 사용한다)

일반적으로 **n=2** (Binary Exponential Backoff)를 사용하며 내 경우도 같은 값을 사용했다. 그럼 간단한 지수 백오프를 사용한 DynamoDB 재시도 로직을 구현해보자. 이 포스팅에서는 Go를 기준으로 설명한다.

# 세션 및 DynamoDB 구조체 생성

우선 AWS 자격 인증을 통해 세션을 생성하고 DynamoDB 서비스 객체를 초기화한다.

```go
package main

import (
    "errors"
    "fmt"
    "math"
    "sync"
    "time"

    "github.com/aws/aws-sdk-go/aws"
    "github.com/aws/aws-sdk-go/aws/credentials"
    "github.com/aws/aws-sdk-go/aws/session"
    "github.com/aws/aws-sdk-go/service/dynamodb"
    "github.com/aws/aws-sdk-go/service/dynamodb/dynamodbattribute"
)

// DynamoDB 구조체는 테이블명, 키 리스트, 서비스 객체 (service/dynamodb)를 관리
type DynamoDB struct {
    table string
    conn  *dynamodb.DynamoDB
}

// AWS 인증키 및 설정값 (실사용시 인증키는 하드코딩하지 않는다)
const (
    awsAccessKeyID     = "AKXXXXXXXXXXXXXXXXXX"
    awsSecretAccessKey = "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
    awsRegion          = "ap-northeast-2"
)

// 자격 인증 및 세션 생성
func NewSession() (*session.Session, error) {
    sess, err := session.NewSession(&aws.Config{
        Region:      aws.String(awsRegion),
        Credentials: credentials.NewStaticCredentials(awsAccessKeyID, awsSecretAccessKey, ""),
    })
    if err != nil {
        return nil, errors.New("failed to create an aws session")
    }
    return sess, nil
}

// 서비스 객체 생성 및 DynamoDB 구조체 초기화
func NewDynamoDB(table string) (*DynamoDB, error) {
    sess, err := NewSession()
    if err != nil {
        return nil, err
    }
    ddb := &DynamoDB{
        table: table,
        conn: dynamodb.New(sess, nil),
    }
    return ddb, nil
}
```

그럼 이제 DynamoDB 구조체에 부분 실패시 재시도를 수행해주는 배치 작업 메서드를 작성해보자.

# 재시도 가능한 쓰기 배치 메서드 작성

재시도 가능한 쓰기 배치 작업은 다음과 같은 플로우로 진행된다.

- 빌트인 자료구조로 표현된 값을 DynamoDB 속성값으로 변환
- 변환된 값으로 쓰기 요청 생성
- 쓰기 요청값으로 배치 작업 수행
- 부분 요청 실패시 일정 시간 대기하고 반환된 값으로 배치 작업 재수행
- 모든 요청이 성공하면 종료

`RetryableBatchWrite`는 쓰기 배치 메서드로 **키-값** 리스트를 인자로 받고 에러를 반환한다. DynamoDB가 지원하는 쓰기 배치는 한 번에 요청할 수 있는 아이템의 개수를 최대 25개로 제한하기 때문에 길이부터 검증한다.

```go
// items = [
//     {
//         "k1": "v1",
//         "k2": "v2",
//     },
//     {
//         "k3": "v3",
//         "k4": "v4",
//     },
// ]
func (ddb *DynamoDB) RetryableBatchWrite(items []map[string]interface{}) error {
    if len(items) == 0 {
        return errors.New("you must pass at least one item")
    }
    if len(items) > 25 {
        return errors.New("you must pass items less than or equal to number of 25")
    }
    ...
}
```

인자로 받은 `키-값`의 `값`을 DynamoDB 속성값으로 인코딩 (마샬링)한 뒤, DynamoDB API로 넘길 쓰기 요청을 만든다. (`dynamodb.WriteRequest`)

```go
func (ddb *DynamoDB) RetryableBatchWrite(items []map[string]interface{}) error {
    ...
    // 쓰기 요청용 구조체
    req := []*dynamodb.WriteRequest{}
    for _, item := range items {
        putItem := make(map[string]*dynamodb.AttributeValue)
        for k, v := range item {
            // 값을 DynamoDB 속성값으로 인코딩
            attr, err := dynamodbattribute.Marshal(v)
            if err != nil {
                return err
            }
            putItem[k] = attr
        }
        // 쓰기 요청 목록에 "키-값"을 PutRequest로 추가 (쓰기에는 Put/Delete 두 종류의 타입이 있음)
        req = append(req, &dynamodb.WriteRequest{
            PutRequest: &dynamodb.PutRequest{
                Item: putItem,
            },
        })
    }
    // 인코딩이 완료되면 {테이블명: 쓰기 요청 객체} 맵을 만든다
    // 배치 작업 실패시 반환되는 값과 동일한 포맷이다
    unprocessed := map[string][]*dynamodb.WriteRequest{
        ddb.table: req,
    }
    ...
}
```

다음으로, 위에서 만든 쓰기 요청으로 실제 배치 작업을 수행한다. 배치 작업을 요청하기 전에 재시도 횟수 카운터 변수인 `attempts`를 선언한다. `attempts`가 0보다 커지면 재시도를 수행하고 최대 재시도 횟수 안에 모든 요청을 처리하지 못하면 에러를 반환하도록 한다.

재시도 관련 상수값은 애플리케이션에 맞게 적절한 값으로 설정하면 된다.

```go
const (
    maxRetries      = 10
    minRetryBackoff = 5 * time.Millisecond
    maxRetryBackoff = 1 * time.Second
)

func (ddb *DynamoDB) RetryableBatchWrite(items []map[string]interface{}) error {
    ...
    attempts := 0
    for {
        // 재시도 수행시 재시도 횟수만큼 대기시간을 늘리면서 요청을 지연시킨다
        if attempts > 0 {
            time.Sleep(RetryBackoff(attempts))
        }
        attempts++
        // 배치 작업 수행
        output, err := ddb.conn.BatchWriteItem(&dynamodb.BatchWriteItemInput{
            RequestItems: unprocessed,
        })
        if err != nil {
            return err
        }
        // 일부 요청이 실패한 경우 unprocessed의 테이블키에 쓰기 요청을 담아서 반환해준다
        // 모든 요청이 성공하면 empty map을 반환한다
        // if _, ok := unprocessed[ddb.table]; !ok를 사용해도 된다
        unprocessed = output.UnprocessedItems
        if len(unprocessed) == 0 {
            break
        }
        // 최대 재시도 횟수를 넘기면 에러 반환
        if attempts > maxRetries {
            return errors.New("reached maximum retry attempts")
        }
        // 재시도 수행
    }
    return nil
}
```

`RetryBackoff` 함수는 다음과 같이 구현할 수 있다. 재시도 횟수만큼 최대 시간에 도달할 때까지 2배씩 늘린다.

```go
func RetryBackoff(n int) time.Duration {
    rb := time.Duration(math.Pow(2, float64(n-1))) * minRetryBackoff
    if rb > maxRetryBackoff {
        rb = maxRetryBackoff
    }
    return rb
}
```

이제 위에서 구현한 재시도 가능한 쓰기 배치 메서드가 잘 동작하는지 확인해보기 위해 테스트용 테이블로 `id`와 `stage`를 각각 파티션키, 정렬키로 갖는 `user` 테이블을 만들고 **2,500**개의 데이터를 배치로 넣는 코드를 작성해보자. 테스트는 `50 RCU / 50 WCU` 환경에서 진행되었다.

```go
func main() {
    // DynamoDB 초기화
    ddb, err := NewDynamoDB("user")
    if err != nil {
        panic(err)
    }
    wg := sync.WaitGroup{}
    vals := []map[string]interface{}{}
    // 2,500개 데이터 생성
    for i := 1; i < 2501; i++ {
        vals = append(vals, map[string]interface{}{
            "id":    1,
            "stage": i,
        })
        // 25개씩 배치 처리
        if i%25 == 0 {
            wg.Add(1)
            // 배치 고루틴 생성
            go func(v []map[string]interface{}) {
                defer wg.Done()
                // 배치 작업 수행
                // 테스트 코드에서는 에러를 무시하고 있지만 실사용시에는 적절한 에러처리가 필요하다
                _ = ddb.RetryableBatchWrite(vals)
            }(vals)
            vals = []map[string]interface{}{}
        }
    }
    wg.Wait()
}
```

재시도가 정상적으로 동작하는지 확인하기 위해 요청 간격을 지연시키는 부분에 간단한 로깅을 추가하자.

```
if attempts > 0 {
    time.Sleep(RetryBackoff(attempts))
    fmt.Println(fmt.Sprintf("attempts: %d, left: %d", attempts, len(unprocessed[ddb.table])))
}
```

이제 위 코드를 돌려보면 다음과 같은 재시도 요청들을 볼 수 있으며, 데이터도 실제로 잘 들어감을 확인할 수 있다. (고루틴과 DynamoDB에서의 쓰기 요청이 실제로 어떻게 처리되느냐에 따라 재시도 동작 및 출력값은 매번 다를 수 있다)

```console
attempts: 1, left: 11
attempts: 1, left: 23
attempts: 1, left: 6
attempts: 1, left: 10
attempts: 1, left: 10
...
attempts: 3, left: 9
attempts: 5, left: 7
attempts: 4, left: 5
attempts: 4, left: 6
attempts: 5, left: 4
attempts: 4, left: 5
attempts: 6, left: 5
```

# 재시도 가능한 읽기 배치 메서드 작성

재시도 가능한 읽기 배치 코드는 다음과 같으며 플로우는 쓰기 배치와 동일하므로 과정은 생략하고 차이점만 나열하겠다.

- `키-값` 리스트 대신 `키` 리스트를 인자로 받음
- 에러와 함께 받아온 데이터를 반환
- 한 번에 요청할 수 있는 키의 개수가 100개임
- 쓰기의 경우 인코딩한 데이터를 각각 `WriteRequest`에 `PutRequest` 형태로 담고, 읽기의 경우 인코딩한 키들을 `KeysAndAttribute`의 `Keys`에 한 번에 담는다
- `UnprocessedItems` 대신 `UnprocessedKeys`로 실패값(키) 처리
- `unprocessed[ddb.table]` 대신 `unprocessed[ddb.table].Keys`에 실패값(키)가 담겨져 있음

```go
// keys = [
//     {
//         "k1": "v1",
//         "k2": "v2",
//     },
//     {
//         "k3": "v3",
//         "k4": "v4",
//     },
// ]
func (ddb *DynamoDB) RetryableBatchGet(keys []map[string]interface{}) ([]map[string]interface{}, error) {
    if len(keys) < 1 {
        return nil, errors.New("you must pass at least one key")
    }
    if len(keys) > 100 {
        return nil, errors.New("you must pass keys less than or equal to number of 100")
    }

    // 키 저장용 구조체
    attrKeys := []map[string]*dynamodb.AttributeValue{}
    for _, key := range keys {
        attrKey := map[string]*dynamodb.AttributeValue{}
        for k, v := range key {
            // 값을 DynamoDB 속성값으로 인코딩
            marshaled, err := dynamodbattribute.Marshal(v)
            if err != nil {
                return nil, err
            }
            attrKey[k] = marshaled
        }
        attrKeys = append(attrKeys, attrKey)
    }
    // 키 목록 추가
    unprocessed := map[string]*dynamodb.KeysAndAttributes{
        ddb.table: &dynamodb.KeysAndAttributes{
            Keys: attrKeys,
        },
    }

    // 받아온 데이터 저장용 변수
    items := []map[string]interface{}{}
    attempts := 0
    for {
         // 재시도 수행시 재시도 횟수만큼 대기시간을 늘리면서 요청을 지연시킨다
        if attempts > 0 {
            time.Sleep(RetryBackoff(attempts))
        }
        attempts++
        // 배치 작업 수행
        output, err := ddb.conn.BatchGetItem(&dynamodb.BatchGetItemInput{
            RequestItems: unprocessed,
        })
        if err != nil {
            return nil, err
        }
        // 받아온 데이터 디코딩
        for _, r := range output.Responses[ddb.table] {
            item := map[string]interface{}{}
            for k, v := range r {
                var val interface{}
                // DynamoDB 속성값 디코딩
                dynamodbattribute.Unmarshal(v, &val)
                item[k] = val
            }
            items = append(items, item)
        }
        // 일부 요청이 실패한 경우 unprocessed의 테이블키에 실패한 키를 담아서 반환해준다
        // 모든 요청이 성공하면 empty map을 반환한다
        // if _, ok := unprocessed[ddb.table]; !ok를 사용해도 된다
        unprocessed = output.UnprocessedKeys
        if len(unprocessed) == 0 {
            break
        }
        // 최대 재시도 횟수를 넘기면 에러 반환
        if attempts > maxRetries {
            return nil, errors.New("reached maximum retry attempts")
        }
         // 재시도 수행
    }
    return items, nil
}
```

읽기 배치의 재시도 테스트도 해보자. 읽기의 경우 쓰기보다 빠르게 처리되므로 스로틀링이 잘 걸리도록 **RCU**와 **WCU**를 의도적으로 `10`으로 낮췄다. 실제 상황에서 데이터 요청이 매우 많은 경우에는 **RCU**, **WCU**가 충분히 높아도 스로틀링이 걸릴 수 있다.

```go
func main() {
    // DynamoDB 초기화
    ddb, err := NewDynamoDB("user")
    if err != nil {
        panic(err)
    }
    wg := sync.WaitGroup{}
    keys := []map[string]interface{}{}
    for i := 1; i < 2501; i++ {
        keys = append(keys, map[string]interface{}{
            "id":    1,
            "stage": i,
        })
        // 100개씩 배치 처리
        if i%100 == 0 {
            wg.Add(1)
            // 배치 고루틴 생성
            go func(k []map[string]interface{}) {
                defer wg.Done()
                // 배치 작업 수행
                items, _ := ddb.RetryableBatchGet(k)
                fmt.Println(len(items))
            }(keys)
            keys = []map[string]interface{}{}
        }
    }
    wg.Wait()
}
```

쓰기 배치에서와 동일하게 로깅을 심어보면 다음과 같은 재시도 요청들을 볼 수 있다. 받아온 데이터는 위의 쓰기 배치 테스트시 넣어둔 데이터이다.

```console
...
100
100
attempts: 1, unprocessed: 18
100
100
100
100
100
attempts: 1, unprocessed: 18
100
100
...
```

읽기 배치 또한 잘 동작하는걸 확인할 수 있다.

배치 메서드를 사용하는 부분을 보면 개수 제한과 병렬 처리 때문에 다소 복잡해보이는데 이 부분은 한 메서드로 처리할 수 있도록 한 번 더 래핑해서 사용하면 좀 더 깔끔하게 사용할 수 있다.