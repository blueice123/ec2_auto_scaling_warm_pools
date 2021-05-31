# 🌟 EC2 Auto Scaling warm pools 소개 🌟
<center> 
**<문서 개정 이력 >**
</center>

<center>

|버전|발행일|작성자/검토자|비고|
|:--:|:--:|:--:|:--:|
|v0.1|2021.05.28|하수용|초안 작성|

</center>

<br>
<br>
<br>

# Tables of Contents

<br>

[[_TOC_]]

<br>
<br>
<br>

# 01. Ec2 Auto Scaling warm pool이란?
Amazon EC2 Auto Scaling  웜 풀은 애플리케이션 인스턴스를 사전 초기화하여 애플리케이션을 더 빠르게 확장하고 지속적으로 실행되는 인스턴스 수를 줄여 비용을 절감 할 수 있도록 지원합니다. 

웜 풀을 통해 고객은 애플리케이션 트래픽을 신속하게 처리 할 준비가 된 사전 초기화 된 EC2 인스턴스 풀을 생성하여 애플리케이션의 탄력성을 개선 할 수 있습니다.

기존 warm pool이 적용되지 않은 Auto scale의 수명주기는 아래와 같습니다.
![image description](images/auto_scaling_lifecycle.png)

만약 warm pool이 적용되어 있다면, 아래와 같이 수명주기 다이어그램에 변경됩니다. 
![image description](images/warm-pools-lifecycle-diagram2.png)

보시는 바와 같이 Auto Scaling group에 warm pool이 추가되는 것을 알 수 있습니다.
AutoScaling은 인스턴스의 추가가 발생할 떄 warm pool에서 stopped된 인스턴스 혹은 running되고 있는 인스턴스를 ASG InService로 상태 전환하는 것을 알 수 있습니다. 

# 02. 실습
### 2.1 현재 ASG의 launch 속도 확인 
먼저 기존의 ASG의 신규 인스턴스가 `Launch` 상태부터 `InService` 상태까지 어느정도 시간이 걸리는지 측정을 해보겠씁니다.
이를 위해 `./script/activities_check.sh` 를 실행합니다. 
```bash
 ~/Documents/git/ec2_auto_scaling_warm_pools/ [master] sh ./scripts/activities_check.sh [AutoScale_Name]
Launching a new EC2 instance: i-05b12beb88e43320d Duration: 130s
Launching a new EC2 instance: i-0bccd02583599605a Duration: 130s
Launching a new EC2 instance: i-01576a0f2779fd4c8 Duration: 160s
Launching a new EC2 instance: i-074bda12617aa6e68 Duration: 129s
Launching a new EC2 instance: i-0deb04910a5f0e38f Duration: 155s
Launching a new EC2 instance: i-0e6664a983435d7a8 Duration: 154s
Launching a new EC2 instance: i-00fc0d0d1a9d254ed Duration: 124s
Launching a new EC2 instance: i-0a8c0a0fe18b7c7c1 Duration: 131s
Launching a new EC2 instance: i-0572f006b2a8c5f0b Duration: 161s
......
```

현재 ASG의 activity 로그를 가지고 와서 시간을 소요된 시간을 보여 줍니다. 
새로운 인스턴스가 시작될 때에는 대략 140여초 정도 소요되었네요. 

이번에는 warm pools을 추가하고 비교를 해보겠습니다.
  - AWS CLI 참고 
    - [put-warm-pool](https://awscli.amazonaws.com/v2/documentation/api/latest/reference/autoscaling/put-warm-pool.html) 


```bash
aws autoscaling put-warm-pool \
  --auto-scaling-group-name "AutoSclae_Name" \
  --pool-state Stopped 
```
  - `--pool-state` 매개변수를 `Running`으로 지정하여 인스턴스를 시작상태로 웜풀에 대기시킬 수도 있습니다. 다만 이 경우 비용상의 이점이 없어지며, ASG에서 관리되지 않는 웜풀 내의 인스턴스가 로드밸런서에 서비스에 InService되므로 개인적으로 사용하지 않는것을 권해 드립니다. 
  - 위의 명령어와 같이 `--max-group-prepared-capacity` 옵션을 지정하지 않으면 ASG의 MAX-Desired capcity 값이 자동으로 정의됩니다. 
  - 즉, ASG에 MIN값 1, MAX값 5, Desired값이 1일 때 warm pool의 수량은 MAX-Desired이므로 4가 됩니다.
  - 이렇게 설정을하면 ASG의 MAX 값이 변경될 때마다 동적으로 변경됩니다.
  - 만약 위 명령과 같이 동적으로 warm pool의 크기를 지정하지 않고, 수치를 딱 정하고 싶을 때에는 아래와 같이 `--max-group-prepared-capacity` `--min-size` 옵션을 부여 합니다.  


```bash
aws autoscaling put-warm-pool \
  --auto-scaling-group-name AutoSclae_Name \
  --max-group-prepared-capacity 5 --min-size 5 --pool-state Stopped 
```
  
명령을 수행하면 아래와 같이 인스턴스들이 launching 되었다가 stopped 되는 것을 확인할 수 있습니다. 
  - [주의] ASG의 `Health check grace period` 값에 충분한 값이 없다면, 상태 검증이 안된 웜풀 인스턴스들이 LoadBalancer에 InService 될 수도 있으니 주의합니다. 

![image description](images/min5.png)

이때 ASG의 상태를 보면 warm pool은 ASG에서 관리하는 대상이 아니므로 instances의 갯수는 그대로 1대를 유지하게 됩니다. 
![image description](images/instances1.png)


만약 Warm pool의 상태를 확인하고 싶으시다면 아래와 같은 명령을 수행합니다. 
  - AWS CLI 참고 
    - [describe-warm-pool](https://awscli.amazonaws.com/v2/documentation/api/latest/reference/autoscaling/describe-warm-pool.html) 


```bash
aws autoscaling describe-warm-pool \
  --auto-scaling-group-name AutoSclae_Name --output table

||+----------------------------------+---------------------------------------+----------------+||
||                                    WarmPoolConfiguration                                    ||
|+-------------------------------------------------+-------------------+-----------------------+|
||            MaxGroupPreparedCapacity             |      MinSize      |       PoolState       ||
|+-------------------------------------------------+-------------------+-----------------------+|
||  5                                              |  5                |  Stopped              ||
|+-------------------------------------------------+-------------------+-----------------------+|
```


이제 Warm pool의 상태 변화를 확인하기 위해 ASG의 max size 값과 desired를 변경해봅니다. 
  - AWS CLI 참고 
    - [update-auto-scaling-group](https://awscli.amazonaws.com/v2/documentation/api/latest/reference/autoscaling/update-auto-scaling-group.html) 

```bash
aws autoscaling update-auto-scaling-group \
  --auto-scaling-group-name AutoSclae_Name \
  --min-size 1 --max-size 6 --desired-capacity 6
```

warm pool에 속한 5대의 인스턴스가 ASG에 InService되기 위해 running 상태로 변경되고, 
웜풀이 비어있으므로, 다시 채우기 위해 새로운 5대 인스턴스가 running -> stoped로 상태 변경 됩니다. 
![image description](images/new+provisioning_instances.png)


ASG 변경 후 launcching 재확인 
```bash
 ~/Documents/git/ec2_auto_scaling_warm_pools/ [master*] sh ./scripts/activities_check.sh CodeDeploy_MZ-TRAINING-WEB_SERVER-DEPLOY-ASG_d-J2J307R9A
Launching a new EC2 instance from warm pool: i-04b60b6d4c60e9bd1 Duration: 126s
Launching a new EC2 instance from warm pool: i-02cd17757f97f1206 Duration: 96s
Launching a new EC2 instance from warm pool: i-0fe674a2c2e8dd771 Duration: 95s
Launching a new EC2 instance from warm pool: i-04e13b936687c3632 Duration: 72s
Launching a new EC2 instance from warm pool: i-0ad85c4d050aba286 Duration: 69s
```
  - 위에서 확인할 수 있듯이 warm pool에서 시작된 인스턴스가 새롭게 시작된 인스턴스보다 약간 빠른것을 알 수 있습니다.
  - 실제로 테스트해 본 결과 [가이드 문서](https://aws.amazon.com/ko/blogs/compute/scaling-your-applications-faster-with-ec2-auto-scaling-warm-pools/)와 같이 획기적으로 시간이 줄지는 않았습니다.



이제 warm pool 환경을 삭제해 줍니다. 
  - AWS CLI 참고 
    - [delete-warm-pool](https://awscli.amazonaws.com/v2/documentation/api/latest/reference/autoscaling/delete-warm-pool.html) 


```bash
aws autoscaling delete-warm-pool --auto-scaling-group-name AutoSclae_Name --force 
```


# 03. 주의 및 제한사항
### 2.1 Console에서의 설정 지원이 안되며, CLI로만 가능
아직까지는 콘솔에서 warm pool을 제어하실 수는 없으며, CLI, CDK를 통해서만 지원됩니다. 
그리고, 한번 지정해두면 CodeDeploy를 통해 ASG가 복제되는 상황에서도 설정이 유지되므로 배포 과정에서 매번 설정할 필요는 없습니다. 


### 2.2 ASG에 Spot과 On-demand가 혼합되어 있는 경우 웜풀을 지원하지 않습니다. 
ASG에 Spot와 On-demand가 혼합되어 있는 경우 웜풀을 지원하지 않습니다. 
물론 Spot으로만 Launch template이 설정되어 있다면 이 또한 지원하지 않습니다. 

```bash
An error occurred (ValidationError) when calling the PutWarmPool operation: You can’t add a warm pool to an Auto Scaling group that has a mixed instances policy or a launch template or launch configuration that requests Spot Instances.
```
![image description](images/mixed_instances.png)


### 2.3 Warm-pool의 수명주기 중 실행 과정에서 LB에 attach 함
![image description](images/tg_instances.png)
웜풀을 재지정하는 과정에서 TG에 Unhealthy hosts와 Healthy hosts 메트릭이 변경됩니다. 
이는 ASG의 Health check grace period 설정이 EC2 내의 서비스가 올라오기 전 검사를 하기 때문으로 Health check grace period을 적절한 값으로 늘려주어야 합니다. 


### 2.3 Warm-pool을 running으로 설정할 경우 ASG에 적용 받지 않는 서비스 인스턴스가 생성이 됨
Warm pool은 기본적으로 ASG에 적용 받지 않습니다. 
만약 웜풀의 `--state running`으로 설정하였을 경우 ASG에 적용 받지 않은 인스턴스가 생성이 되어 LoadBalancer에 Attach 됩니다. 

웜풀의 상태를 보면 i-071282c646a383328는 Warmed:Running 상태를 가집니다. 
```bash
aws autoscaling describe-warm-pool \
  --auto-scaling-group-name AutoSclae_Name --output text --query "WarmPoolConfiguration.PoolState" --query "Instances[*].{Instance:InstanceId,State:LifecycleState}"
i-071282c646a383328     Warmed:Running
```

하지만, LB의 Target group에 인스턴스가 들어가 있어서 실제로는 서비스 중이며, 
![image description](images/warm-running.png)

하지만, ASG에는 warm-running 인스턴스는 관리되고 있지 않습니다. 
![image description](images/warm-running2.png)

즉, ASG의 Desired capacity와 TG의 Instnaces 갯수가 가 miss match 됩니다. 


### 2.4 warm-pool이 적용된 상태로 CodeDeploy를 통한 배포를 실행하면 이후 ASG도 동일한 warm-pool 설정을 상속 받음
CodeDeploy를 배포하는 환경에서도 이전의 ㅁㄴㅎ전혀 문제될게 없습
ㅇ

### 2.5 warm-pool에 의해 stopped된 인스턴스를 수동으로 상태 변경(예, running)할 경우 설정이 꼬이게 됩니다. 
또한 ASG에 의해 hook을 걸지 않으므로 CodeDeploy로 배포한 최신 소스코드를 내려 받지 않아 과거의 소스코드로 서비스할 수 있습니다. 
이 부분은 주의 하셔야 합니다.



# **Agenda**
### 1. Headings 로 제목/주제 입력하기 !
- 1-1. Headings 사용법
- 1-2. Headings 사용 예시
- 1-3. 줄긋기

### 2. 폰트 수정하기 !
### 3. 리스트 사용하기 !
### 4. 링크 삽입하기 !
### 5. 이미지 삽입하기 !
### 6. 표 만들기 !
### 7. 코드블럭 사용하기 !
<br>

### 추가적인 기능 활용하기 !
- 체크 박스 기능 넣기
- 토글 기능 넣기
- GIF 삽입하기
- MOV 삽입하기

<br>
<br>



# 1. Headings 로 제목/주제 입력하기 !

<!-- Heading -->
- Headings를 활용하여 제목/주제 입력을 손쉽게 작성할 수 있습니다.
- **Gitlab**에서는 6가지 종류를 지원하고 있습니다.
  - **Notion**에서는 3가지 종류만 지원하고 있습니다.
    - **#**, **##**, ***###*** 세 가지 Heading만 지원

<br>
<br>

## 1-1. Headings 사용법

``` plain text
# This is a H1
## This is a H2
### This is a H3
#### This is a H4
##### This is a H5
###### This is a H6
```

- **H1** 과 **H2** Headings의 경우, {-텍스트 밑에 줄긋기-}가 기본적으로 들어갑니다.
- 기본적으로 Headings 를 사용하시면 Bold 효과가 어느 정도 적용되어 출력됩니다.
  - Headings에 추가적인 Bold 효과 적용도 가능합니다. ~~크게 부각되어 보이지는 않습니다~~
- 평문과 크기가 비슷한 Headings는 H6 입니다. 😆



<br>

## 1-2. Headings 사용 예시

# Heading 1
## Heading 2
### Heading 3
#### Heading 4
##### Heading 5
###### Heading 6
Paragraph

<br>


<br>

## 1-3. 줄긋기

<!-- Line -->

``` plain text
___  >> Underscore [ Shift + _ ] 를 세 번 입력하시면 줄긋기가 가능합니다
```

<br>

___

<br>

- Underscore 세 번 이상은 모두 줄을 그을 수 있습니다 ✏️
  - 3번 or 4번 or 5번



<br>
<br>
<br>

# 2. 폰트 수정하기 !

- Gitlab에서는 다음과 같은 폰트 수정을 제공하고 있습니다.
  - 여기서 부터 텍스트 수정 필요 + 하단 테스트 방법도 포함

<br>

## 2-1. 폰트 수정 방법 !

``` plain text
*single asterisks*
_single underscores_
**double asterisks**
__double underscores__
~~cancelline~~
```

<br>

### 테스트

<br>

plain text  
*single asterisks*  
_single underscores_  
**double asterisks**  
__double underscores__  
~~cancelline~~  


<br>


<br>

## 2-2. 폰트 수정 예시

<!-- Text attributes -->
This is the **bold** text and this is the *italic* text and let's do ~~strikethrough~~.

<br>
<br>

## 2-3. 폰트 색상 넣기

- Gitlab에서 폰트 자체의 색상을 바꾸기 위해서는 custom class를 정의하여 사용할 수 있지만 과정이 다소 복잡해질 수 있습니다.
- 폰트의 뒷 배경 색상을 넣는 것은 비교적 쉽게 적용할 수 있습니다 😁
<br>
<br>
<br>
<!-- Text Coloring -->

{+green+} {-red-}

{+green+} 

{-red-}

<br>

```diff
+ this text is highlighted in green
- this text is highlighted in red
```

<br>
<br>

## 인용문 넣기 !

<!-- Quote -->
> Don't forget to code your dream 

<br>
<br>

# 3. 리스트 사용하기 !

<!-- Bullet list -->
Fruits:
🍎
🍋

Other fruits:
🍑
🍏

<br>
<br>

<!-- Numbered list -->
Numbers:
1. first
2. second
3. third

<br>
<br>

# 4. 링크 삽입하기 !

<!-- Link -->
Click [Here](https://aws.amazon.com/ko/)

<br>
Click [Here](https://aws.amazon.com/ko/){:target="_blank"}

<br>
<a href="http://example.com/" target="_blank">Hello, world!</a>

<br>
<br>
<br>

# 5. 이미지 삽입하기 !

<!-- Image -->
![image description](images/aws_white.jpg)


# 6. 표 만들기 !

<!-- Table -->
|Header|Description|
|:--:|:--:|
|Cell1|Cell2|
|Cell3|Cell4|
|Cell5|Cell6|

<br>
<br>

# 7. 코드블럭 사용하기 !

<!-- Code -->
To print message in the console, use `print("your message"` and ..

```python
print("Hello World!")
```

<br>

```java
public class Main {
    public static void main(String[] args) {
        System.out.println("Goodbye, World!");
    }
}
```


<br>
<br>
<br>
<br>

# Next & Advanced Step !!

<br>

<!-- PR Description Example -->
# What is AWS?

`Amazon Web Services(AWS)`는 전 세계적으로 분포한 데이터 센터에서 200개가 넘는 완벽한 기능의 서비스를 제공하는, 세계적으로 가장 포괄적이며, 널리 채택되고 있는 클라우드 플랫폼입니다. 빠르게 성장하는 스타트업, 가장 큰 규모의 엔터프라이즈, 주요 정부 기관을 포함하여 수백만 명의 고객이 AWS를 사용하여 비용을 절감하고, 민첩성을 향상시키고 더 빠르게 혁신하고 있습니다.

<br>
<br>


|Feature|Description|
|--|--|
|Feature1|<img src="images/aws_white.jpg" width="400"><br>Feature1. AWS Official Logo_ver1|
|Feature2|<img src="images/aws_black.png" width="400"><br>Feature2. AWS Official Logo_ver2|

<br>
<br>
<br>

# 체크 박스 기능 넣기

## Before release
- [x] Finish my changes
- [ ] Push my commits to GitHub
- [ ] Open a pull request

<br>
<br>

# 토글 기능 넣기 !

- 노션에서 제공하는 **Toggle List** 와 유사한 기능을 사용할 수 있습니다.
  - 노션에서는 {+ > + 스페이스바 +} 로 해당 토글을 활성화 시킬 수 있습니다.
- Gitlab Markdown에서 지원하는 고유 기능은 아니며, HTML을 활용하여 사용할 수 있습니다.
  - details 활용

<br>

## 토글 (Expander) 사용법

``` plain text
<details>
<summary>접기/펼치기 버튼</summary>
토글 안에 적을 내용 작성
</details>
```

<br>
<br>

## 토글 사용 예시

<details>
<summary><b>Gitlab Flavored Markdown Guide</b></summary>
[Guide Link](https://docs.gitlab.com/ee/user/markdown.html)
</details>

<br>
<br>
<br>

## GIF 삽입하기 !

- Gitlab에 gif 파일을 삽입하는 방법을 알아봅니다.
- gif 파일은 코드 및 스크립트의 동작 방식 등을 효과적으로 소개할 수 있습니다 😎 

<br>

## GIF 파일 삽입 방법
- gif 파일 삽입 방법은 image 파일 삽입 방식과 동일합니다.
  - gif 파일 자체가 여러장의 이미지를 빠르게 넘기는 방식으로 제공하는 것으로 이해하면 좋을 것 같습니다.
  - Gitlab에서 지원하는 image 관련 포맷은 아래와 같습니다.
  - {-.png-}, {-.jpg-}, {-.gif-}


``` plain text
![GIF 파일에 대한 설명](GIF 파일 경로)
```

<br>


## GIF 파일 삽입 예시

#### **GIF 파일 삽입 예시 - 1**

![아라찌!](GIFs/sample_gif.gif)

<br>
<br>

#### **GIF 파일 삽입 예시 - 2**

![Headings](GIFs/sample_gif_2.gif)

<br>
<br>

#### **GIF 파일 삽입 예시 - 3**

![Headings](GIFs/sample_gif_3.gif)

<br>
<br>

## MOV 삽입하기

<br>
<br>
