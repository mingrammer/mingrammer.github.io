---
categories:
- python
comments: true
date: 2017-03-05T00:00:00Z
tags:
- configuration
- management
title: 파이썬에서 설정값 관리하기
url: /ways-to-manage-the-configuration-in-python
---

서버를 개발하다보면 항상 마주치는 문제가 있는데 바로 설정값 (Configuration)을 어떻게 관리하느냐이다. 비단, 서버 애플리케이션 뿐만 아니라 설정값 관리가 필요한 모든곳에서 마주할 수 있는 이슈이기도하다.

설정값을 관리해봤고 이미 잘 관리하고 있다면 큰 문제가 되지는 않지만, 초보자의 입장에서는 이 설정값들을 어떻게 효율적으로 관리하는지에 대해 많은 어려움을 겪을 수 있다. 특히, 만약에 설정값에 시크릿값이 포함되어 있는 상태에서 Github이나 Bitbucket과 같은 버전 관리 시스템에 코드를 공개하는 경우, 자칫하면 시크릿값을 잘못 관리함으로 인해 큰 피해를 볼 수도 있다. 가령 시크릿값을 탈취해 남의 서버 자원을 비정상적으로 사용하는 경우도 있고, 암호키 값인 경우 서버 애플리케이션을 향한 악의적 공격이나 해킹 문제로 이어질 수도 있다. 실제로 이런 경우는 생각보다 많이 일어나고 있다. 따라서 설정값 관리 특히, 시크릿값 관리는 중요한 문제이다.

나의 경우 주로 서버 애플리케이션을 개발하면서 매 프로젝트마다 서로 다른 방법으로 설정값들을 관리해봤는데 이참에 한 번 정리를 해볼겸, 많은 사람들에게 조금이나마 도움을 주고싶어 여기에 몇 가지 설정값 관리 방법들을 정리해보려고 한다.

나는 주로 파이썬을 사용해서 서버 애플리케이션을 개발해왔기에, 파이썬에서의 관리 방법에 대해서 포스팅을 하려고한다. 파이썬 언어 자체의 특성을 이용한것도 있지만, 기본적인 아이디어는 특정 언어와는 무관하기에 다른 언어에서도 충분히 적용해볼 수 있을 것이다.

이번 포스팅에서 소개할 설정값 관리 방법은 다음과 같다. (단, 여기서 인프라스트럭쳐나 분산 환경과 같은 큰 규모의 시스템에서의 통합적인 설정 관리 방법을 다루지는 않는다. 이는 나중에 따로 포스팅을 해보겠다.)

* 빌트인 데이터 구조를 사용한 설정
* 외부 파일을 통한 설정
* 환경 변수를 사용한 설정
* 동적 로딩을 통한 설정

그럼 이제 각 경우에 대해 살펴보자.

<br>

# 1. 빌트인 데이터 구조를 사용한 설정

가장 쉽고 직관적인 방법이다. 제목 그대로 빌트인 데이터 구조를 사용해 설정값을 관리하는 방법인데, 가장 기본적으로는 다음과 같이 사용할 수 있다.

```python
# config.py
DATABASE_CONFIG = {
    'host': 'localhost',
    'dbname': 'company',
    'user': 'user',
    'password': 'password',
    'port': 3306
}

# main.py
import pymysql
import config

def connect_db(dbname):
    if dbname != config.DATABASE_CONFIG['dbname']:
        raise ValueError("Could not find DB with given name")
    conn = pymysql.connect(host=config.DATABASE_CONFIG['host'],
                           user=config.DATABASE_CONFIG['user'],
                           password=config.DATABASE_CONFIG['password'],
                           db=config.DATABASE_CONFIG['dbname'])
    return conn

connect_db('company')
```

조금 더 복잡한 경우를 들어보자. 예를 들어, 웹 애플리케이션을 개발한다고 하면 보통 개발 환경, 테스트 환경, 프로덕션 환경등에 대한 설정이 각기 다르기 때문에 여러 설정들을 다음과 같이 관리하는것이 좀 더 효율적이다.

```python
# config.py
class Config:
    APP_NAME = 'myapp'
    SECRET_KEY = 'secret-key-of-myapp'
    ADMIN_NAME = 'administrator'

    AWS_DEFAULT_REGION = 'ap-northeast-2'
    
    STATIC_PREFIX_PATH = 'static'
    ALLOWED_IMAGE_FORMATS = ['jpg', 'jpeg', 'png', 'gif']
    MAX_IMAGE_SIZE = 5242880 # 5MB

    
class DevelopmentConfig(Config):
    DEBUG = True
    
    AWS_ACCESS_KEY_ID = 'aws-access-key-for-dev'
    AWS_SECERT_ACCESS_KEY = 'aws-secret-access-key-for-dev'
    AWS_S3_BUCKET_NAME = 'aws-s3-bucket-name-for-dev'

    DATABASE_URI = 'database-uri-for-dev'


class TestConfig(Config):
    DEBUG = True
    TESTING = True
    
    AWS_ACCESS_KEY_ID = 'aws-access-key-for-test'
    AWS_SECERT_ACCESS_KEY = 'aws-secret-access-key-for-test'
    AWS_S3_BUCKET_NAME = 'aws-s3-bucket-name-for-test'
    
    DATABASE_URI = 'database-uri-for-test'
  

class ProductionConfig(Config):
    DEBUG = False

    AWS_ACCESS_KEY_ID = 'aws-access-key-for-prod'
    AWS_SECERT_ACCESS_KEY = 'aws-secret-access-key-for-prod'
    AWS_S3_BUCKET_NAME = 'aws-s3-bucket-name-for-prod'

    DATABASE_URI = 'database-uri-for-prod'


class CIConfig:
    SERVICE = 'travis-ci'
    HOOK_URL = 'web-hooking-url-from-ci-service'
   
# main.py
import sys
import config

...

if __name__ == '__main__':
    env = sys.argv[1] if len(sys.argv) > 2 else 'dev'
    
    if env == 'dev':
        app.config = config.DevelopmentConfig
    elif env == 'test':
        app.config = config.TestConfig
    elif env == 'prod':
        app.config = config.ProductionConfig
    else:
        raise ValueError('Invalid environment name')
   
    app.ci = config.CIConfig
```

같은 프로젝트 내에서 바로 임포트가 가능하며, 빌트인 데이터 구조를 그대로 활용할 수 있기 때문에 사용하기가 편리하다. 단, 만약 버전 관리 시스템을 사용하고 있는 경우 같은 코드베이스에 설정값들이 노출되어 있기 때문에 어떤 설정값이 시크릿값이라면 보안상 이슈가 생길 수가 있다. 따라서, 실제 설정값들 대신 더미 설정값들을 버전 관리 시스템에 올려놓고, 실제 프로덕션 서버에서 직접 설정값을 변경하는 방법으로 해당 이슈를 피할 수 있긴 하지만 조금 번거롭다. 여기서 조금 더 진보된 방법이 **동적 로딩을 통한 설정**인데 이는 뒤에서 살펴보도록 하자.

따라서 이 방법은 설정값에 시크릿값이 없는 경우에 사용하는걸 추천한다.

<br>

# 2. 외부 파일을 통한 설정

이 방법은 위와 다르게 빌트인 데이터 구조가 아닌 외부 파일에 정의된 설정값들을 로드하여 사용하는 방법이다. 설정값을 코드가 아닌 설정값 그 자체로 바라보기 때문에 조금 더 일반적인 접근 방법이다. 간단하게 **ini**와 **json** 포맷의 설정파일을 다루는 방법을 살펴보자.  (참고로 `configparser`는 Python 3.x 버전용이며 Python 2.x 버전에서는 `ConfigParser`를 사용한다)

```yaml
; config.ini
[DEFAULT]
SECRET_KEY = secret-key-of-myapp
ADMIN_NAME = administrator
AWS_DEFAULT_REGION = ap-northeast-2
MAX_IMAGE_SIZE = 5242880

[TEST]
TEST_TMP_DIR = tests
TEST_TIMEOUT = 20

[CI]
SERVICE = travis-ci
HOOK_URL = web-hooking-url-from-ci-service
```

```json
// config.json
{
  "DEFAULT": {
    "SECRET_KEY": "secret-key-of-myapp",
    "ADMIN_NAME": "administrator",
    "AWS_DEFAULT_REGION": "ap-northeast-2",
    "MAX_IMAGE_SIZE": 5242880
  },
  "TEST": {
    "TEST_TMP_DIR": "tests",
    "TEST_TIMEOUT": 20
  },
  "CI": {
    "SERVICE": "travis-ci",
    "HOOK_URL": "web-hooking-url-from-ci-service"
  }
}
```

```python
# main_with_ini.py
import configparser

config = configparser.ConfigParser()
config.read('config.ini')

secret_key = config['DEFAULT']['SECRET_KEY'] # 'secret-key-of-myapp'
ci_hook_url = config['CI']['HOOK_URL'] # 'web-hooking-url-from-ci-service'

# main_with_json.py
import json

with open('config.json', 'r') as f:
    config = json.load(f)

secret_key = config['DEFAULT']['SECRET_KEY'] # 'secret-key-of-myapp'
ci_hook_url = config['CI']['HOOK_URL'] # 'web-hooking-url-from-ci-service'
```

이 외에도 **xml**, **yaml** 등의 다른 포맷을 사용할 수도 있다. 기본적인 접근 방법은 동일하기 때문에 해당 포맷을 파싱만 할 수 있으면 된다.

이 방법의 경우 설정을 코드로부터 분리할 수 있기 때문에, Git의 경우 **.gitignore**에 해당 설정 파일만 명시해두면 버전 관리 시스템으로부터 독립적으로 관리할 수 있다. 물론 이렇게 설정 파일을 버전 관리 시스템에서 무시하는 경우, 설정 변수들이 모두 감춰지기 때문에 다른 개발자가 설정 변수를 조작하기가 어려울 수 있다. 따라서 이런 경우는 다음과 같이 해결을 할 수가 있다.

시크릿값을 포함한 실제 설정 변수들을 가진 파일을 **config.json**이라고 할 때, 이 설정 파일의 포맷만을 명시한 파일을 **config.json.example**와 같은 형태로 두어, 버전 관리 시스템에서는 **config.json** 대신 **config.json.example**만을 관리한다. 이렇게하면 다른 개발자도 포맷을 알 수 있어 설정값들을 조작할 수 있게된다. 단, 다른 개발자의 경우 로컬에서 이를 사용할때에는 **config.json.example**을 **config.json**로 변경 후 설정값들을 채워 넣은 뒤 사용하면된다.

```json
// config.json.example
{
  "DEFAULT": {
    "SECRET_KEY": "...",
    "ADMIN_NAME": "...",
    "AWS_DEFAULT_REGION": "...",
    "MAX_IMAGE_SIZE": 5242880
  },
  "TEST": {
    "TEST_TMP_DIR": "tests",
    "TEST_TIMEOUT": 20
  },
  "CI": {
    "SERVICE": "travis-ci",
    "HOOK_URL": "..."
  }
}
```

<br>

# 3. 환경 변수를 사용한 설정

이 방법은 파이썬 소스 파일이나 설정 파일과 같은 파일이 아닌 시스템의 환경 변수를 사용해 설정값들을 관리하는 방법이다. 

```python
import os
from myapp import app

secret_key = os.environ.get('SECRET_KEY', None)

if not secret_key:
    raise ValueError('You must have "SECRET_KEY" variable')

app.config['SECRET_KEY'] = secert_key
```

별도의 파일로 관리되지 않으므로 시크릿값 등이 노출될 위험이 적으며, 환경 변수만 받아오면 되기 때문에 사용하기가 매우 편리하며 소스 코드 어디에서도 가져다 쓸 수 있다.

물론 이 경우도 모든 환경 변수들을 체계적으로 관리하려면 셸 스크립트 등으로 관리를 해야 하지만, 셸 스크립트와 시스템에 익숙한 개발자라면 이 방법도 좋은 방법일 수 있다. 다만, Apache나 Nginx등의 웹서버와 같이 환경 변수를 사용할 수 없는 환경이라면 다른 방법을 사용해야한다.

<br>

# 4. 동적 로딩을 통한 설정

위에서도 언급했듯이 이는 1번의 **빌트인 데이터 구조를 사용한 설정**의 조금 더 진보된 방법이다. 1번의 경우 프로젝트의 어떤 파일에서 특정 설정 파일을 임포트 해야하는 구조이며, 따라서 설정 파일이 임포트 가능한 위치에 존재해야한다. 그러나 이 방법의 경우, 특정 설정 파일이 어떤 프로젝트 디렉토리에 임포트 가능한 형태로 존재하지 않아도 되며, 심지어는 같은 레포지토리가 아닌 다른 레포지토리로 설정 파일을 관리할 수도 있다.

원리는 단순한데, 설정값이 필요한 소스 파일에서 설정값을 가지고 있는 파이썬 소스 파일의 경로를 동적으로 등록하여 사용하는 방법이다. 즉, 다음과 같다.

```python
# /opt/settings/config.py
DATABASE_CONFIG = {
    'host': 'localhost',
    'dbname': 'company',
    'user': 'user',
    'password': 'password',
    'port': 3306
}

# main.py
import sys
import pymysql

sys.path.append('/opt/settings')
import config

def connect_db(dbname):
    if dbname != config.DATABASE_CONFIG['dbname']:
        raise ValueError("Couldn't not find DB with given name")
    conn = pymysql.connect(host=config.DATABASE_CONFIG['host'],
                           user=config.DATABASE_CONFIG['user'],
                           password=config.DATABASE_CONFIG['password'],
                           db=config.DATABASE_CONFIG['dbname'])
    return conn

connect_db('company')
```

얼핏보면 1번과 다를바가 없어 보이지만, 이 방법의 장점은 파이썬 소스 파일 자체를 파이썬 프로젝트와 분리할 수 있다는 것이다. 즉, 1번과 2번의 장점을 모두 가져오는데, 파이썬 소스 파일을 프로젝트 코드베이스와 분리하여 관리하고 싶을때 적합하다. 

나의 경우, 이전에 설정만을 관리하는 레포지토리와 API 서버 레포지토리를 따로 관리했을때 이 방법을 사용했었다. API 서버 레포지토리는 설정을 임포트해서 사용하기만 하되, 실제 설정값들은 독립적인 다른 레포지토리에서 관리했었다. 그리고 서버 프로비저닝시 설정 레포지토리와 API 서버 레포지토리를 모두 클론해 API 서버에서 설정 소스 파일을 임포트 할 수 있도록 구성하였다.

```bash
# 프로비저닝 스크립트
...
cd /opt/settings
git clone git@github.com/company/config.git

cd /opt/app
git clone git@github.com/company/api-server.git
...
```

이렇게 할 경우, 1번의 장점을 살리면서 설정을 완전히 분리해서 관리할 수 있기 때문에 보안 위험도 최소화 시킬 수 있으며 관리가 한결 수월해진다. 또한 설정 환경의 크기가 커질 경우 설정 레포지토리를 따로 관리하게 되면 설정값들 또한 버전 관리 시스템에서 독립적으로 관리할 수 있게 되어 유지보수 또한 용이해진다.

<br>

이상 4가지의 설정값 관리 방법을 알아보았다. 각 방식별로 장단점이 있으며, 본인의 상황에따라 선택해 사용하면 된다. 물론, 위 4가지를 혼합해 사용할 수도 있고 더 좋은 방법이 있을수도 있다. 특히 시스템이 거대해질 경우 설정 관리만을 위한 서드파티 툴 또는 서비스를 사용하는 경우도 있다.

설정 관리에 어려움을 겪거나 경험이 적은 초보자를 대상으로 한만큼 크게 어려운 내용은 아니지만, 어떤 사람들에게는 도움이 되었으면한다. 더 좋은 설정 관리 방법이나 위에서 언급하지 않은 방법이 있다면 제보해주면 감사하겠다.
