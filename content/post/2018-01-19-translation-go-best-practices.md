---
categories:
- translation
comments: true
date: 2018-01-19T00:00:00Z
tags:
- best practices
- go
title: '[번역] Go best practices'
url: /translation-go-best-practices
draft: true
---

> [Go best practices, six years in](https://peter.bourgon.org/go-best-practices-2016/#repository-structure)을 번역한 글입니다.

(*이 글은 원래 QCon London 2016에서 연설한 내용이다. [비디오와 슬라이드는 이 링크에서 볼 수 있다](https://www.infoq.com/presentations/go-patterns)*)

2014년에 나는 첫 GopherCon에서 [프로덕션 환경에서의 모범 사례 (Best Practices in Production Environments)](https://peter.bourgon.org/go-in-production/)라는 제목으로 발표를 했었다. [SoundCloud](https://soundcloud.com/)에서 우리는 얼리 어답터였으며, 이 시점까지 약 2년간 한 가지 형태 혹은 다른 형태로 프로덕션에서 Go 코드를 작성하고, 운영하며 유지보수를 해왔다. 우리는 여러 교훈을 얻었고, 얻은 교훈중 일부를 선정하여 전달하고자 했다.

그 이후로, 나는 SoundCloud의 인프라 스트럭쳐 팀에서 풀타임 Go 개발자로 일을 해왔으며, 현재는 [Weaveworks](https://www.weave.works/)에서 [Weave Scope](https://www.weave.works/products/weave-scope/)와 [Weave Mesh](https://github.com/weaveworks/mesh)를 개발하고있다. 나는 또한 마이크로서비스를 위한 오픈소스 툴킷인 [Go kit](https://github.com/go-kit/kit) 개발도 열심히 하고 있다. 그리고 지속적으로 Go 커뮤니티에서 활동을하며 유럽과 미국 전역에서 열리는 밋업과 컨퍼런스에서 많은 개발자들을 만나고 그들의 성공과 실패담들을 여럿 들어왔다.

2015년 11월 Go가 릴리즈된지 6주년을 맞아, 나는 첫 번째 이야기를 다시 생각해보았다. 어떤 모범 사례들이 지속적으로 회자되는가? 어떤 사례들이 낡았으며 생산성을 감소시키는가? 새로운 사례들이 생겨나고 있는가? 3월에, 나는 [QCon London](https://qconlondon.com/)에서 2014년의 모범 사례들을 검토하며 2016년에는 Go가 어떻게 발전했는지를 살펴보기 위한 발표를 할 기회가 생겼다. 그 발표의 내용들이 바로 여기에 있다.

각 챕터별로 핵심 내용들은 링크가 걸려 있는 Top Tip으로 강조를 해놨다.

> **Top Tip** — 이 팁들을 잘 숙지하여 여러분의 Go 실력을 향상 시키십시오!

목차는 다음과 같다.

- [개발 환경](#%EA%B0%9C%EB%B0%9C-%ED%99%98%EA%B2%BD)
- [레포지토리 구조](#%EB%A0%88%ED%8F%AC%EC%A7%80%ED%86%A0%EB%A6%AC-%EA%B5%AC%EC%A1%B0)
- [포맷팅과 스타일](#%ED%8F%AC%EB%A7%B7%ED%8C%85%EA%B3%BC-%EC%8A%A4%ED%83%80%EC%9D%BC)
- [설정](#%EC%84%A4%EC%A0%95)
- [프로그램 설계](#%ED%94%84%EB%A1%9C%EA%B7%B8%EB%9E%A8-%EC%84%A4%EA%B3%84)
- [로깅과 측정](#%EB%A1%9C%EA%B9%85%EA%B3%BC-%EC%B8%A1%EC%A0%95)
- [테스팅](#%ED%85%8C%EC%8A%A4%ED%8C%85)
- [의존성 관리](#%EC%9D%98%EC%A1%B4%EC%84%B1-%EA%B4%80%EB%A6%AC)
- [빌드 및 배포](#%EB%B9%8C%EB%93%9C-%EB%B0%8F-%EB%B0%B0%ED%8F%AC)
- [결론](#%EA%B2%B0%EB%A1%A0)
10. [결론](#결론)

<br>

# 개발 환경

Go에는 GOPATH를 중심으로 한 개발 환경 컨벤션이 있다. 2014년에 나는 하나의 전역 GOPATH를 사용하길 강력히 권장했으나, 현재 나의 입장은 조금 유연해졌다. 물론 나는 여전히 이게 가장 좋은 아이디어라고 생각한다. 하지만 이는 여러분의 프로젝트나 팀에 따라 달라질 수 있으며, 다른 접근법들 또한 좋은 아이디어일 수 있다.

만약 여러분 혹은 여러분의 회사가 주로 바이너리 기반의 프로그램을 만드는 경우, 프로젝트별로 GOPATH를 사용하면 여러 이점들을 얻을 수 있다. 이러한 경우를 위해 Dave Cheney와 많은 기여자들이 만든 표준 Go 툴을 대체하는 [gb](https://getgb.io/)라는 새로운 도구도 있다. 많은 사람들이 이를 활용한 성공 사례들을 내놓고 있다.

일부 Go 개발자들은 `$HOME/go/external:$HOME/go/internal`와 같이 두 개의 GOPATH를 사용한다. Go 툴은 이와 같은 경우도 처리할 수 있는데 `go get`은 첫 번째 경로에다가 페치를 하기때문에, 서드 파티와 내부 코드의 엄격한 분리가 필요한 경우 유용할 수 있다.

한 가지 내가 관찰할 수 있었던건 일부 개발자들이 `GOPATH/bin`을 `PATH`에 추가하는걸 잊고 있다는 것이다. 이는 `go get`으로 가져온 바이너리를 쉽게 실행할 수 있도록 해주며, `go install`의 코드 빌드 메커니즘을 좀 더 쉽게 만들어 준다. 추가하지 않을 이유가 없다.

> **Top Tip** — $GOPATH/bin을 $PATH에 추가하면 설치된 바이너리에 쉽게 엑세스 할 수 있다.

에디터와 통합 개발 환경 (IDEs)에 대해서도 많은 점진적인 발전이 있었다. 만약 여러분이 빔(vim) 워리어라면 삶은 결코 나아지지 않았을 것이다. [Fatih Arslan](https://twitter.com/fatih)의 지칠줄 모르는 유능한 노력에 감사해하라. [vim-go](https://github.com/fatih/vim-go)는 훌륭할 뿐만 아니라 최고다. 
나는 이맥스(emacs)에 익숙하진 않지만 [Dominik Honnef](https://twitter.com/dominikhonnef)의 [go model.el](https://github.com/dominikh/go-mode.el)은 여전히 이맥스쪽에서 큰 인기를 끌고 있다.

여전히 많은 사람들이 [Submit Text](https://www.sublimetext.com/) + [GoSublime](https://github.com/DisposaBoy/GoSublime)을 잘 사용하고 있다. 속도로 승부하기는 어렵지만 요즘은 Electron 기반의 에디터에도 많은 관심이 쏠리고 있다. [Atom](https://atom.io/) + [go-plus](https://atom.io/packages/go-plus)는 많은 팬들을 가지고 있으며, 특히 언어를 자바스크립트로 자주 전환해야하는 개발자들에게 유용하다. [Visual Studio Code](https://code.visualstudio.com/) + [vscode-go](https://github.com/Microsoft/vscode-go)가 다크호스로 떠오르고 있는데, 이는 서브라임 텍스트보단 느리지만 아톰보단 빠르며, click-to-definition과 같은 나에게 있어 중요한 기능들을 기본적으로 훌륭하게 지원하고 있다. 나는 [Thomas Adam](https://github.com/tecbot)이 이를 소개해준 이후로 약 반 년간 매일 사용하고 있다.

풀스택 IDE로는, 애초에 Go 개발을 목표로 한 [LiteIDE](https://github.com/visualfc/liteide)가 있으며 정기적으로 업데이트가 되고 있고 확실한 팬층을 가지고 있다. [IntelliJ Go Plugin](https://github.com/go-lang-plugin-org/go-lang-idea-plugin) 또한 꾸준히 개선되고 있다.

<br>  

<br>

# 레포지토리 구조

***Update**: Ben Johnson이 쓴 전형적인 비즈니스 애플리케이션을 위한 훌륭한 조언들을 제공하는 [Standard Package Layout](https://medium.com/@benbjohnson/standard-package-layout-7cdbc8391fc1)라는 훌륭한 글이 있다.*

***Update** 약간 수정된 Tim Hockin의 [go-build-template](https://github.com/thockin/go-build-template)는 더 나은 일반적인 모델로 입증되었다. 나는 원글로부터 이 부분을 조금 수정했다.*



<br>

# 포맷팅과 스타일



<br>

# 설정



<br>

# 프로그램 설계



<br>

# 로깅과 측정



<br>

# 테스팅



<br>

# 의존성 관리



<br>

# 빌드 및 배포



<br>

# 결론

