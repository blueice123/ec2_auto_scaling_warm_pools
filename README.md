<center>

# 🌟 EC2 Auto Scaling warm pools 소개 🌟

</center>

<br>

## CTC SA Team 5


- 해당 가이드는 EC2 auto scaling warm pools PoC와 관련하여 동작방식에 대한 가이드 입니다. 
---
<br>
<br>
<br>


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

### 1.1 수명 주기
![image description](images/warm-pools-lifecycle-diagram.png)


# 02. 실습
### 2.1 현재 ASG의 launch 속도 확인 
/script/activities_check.sh 를 실행합니다. 
```bash
 ~/Documents/git/ec2_auto_scaling_warm_pools/scripts/ [master] sh ./activities_check.sh CodeDeploy_MZ-TRAINING-WEB_SERVER-DEPLOY-ASG_d-UGZII4V6A
Launching a new EC2 instance: i-05b12beb88e43320d Duration: 130s
Launching a new EC2 instance: i-0bccd02583599605a Duration: 130s
Launching a new EC2 instance: i-01576a0f2779fd4c8 Duration: 160s
Terminating EC2 instance: i-074bda12617aa6e68 Duration: 130s
Terminating EC2 instance: i-0deb04910a5f0e38f Duration: 98s
Terminating EC2 instance: i-0572f006b2a8c5f0b Duration: 119s
Terminating EC2 instance: i-0e6664a983435d7a8 Duration: 123s
Terminating EC2 instance: i-0a8c0a0fe18b7c7c1 Duration: 144s
Terminating EC2 instance: i-00fc0d0d1a9d254ed Duration: 116s
Launching a new EC2 instance: i-074bda12617aa6e68 Duration: 129s
Launching a new EC2 instance: i-0deb04910a5f0e38f Duration: 155s
Launching a new EC2 instance: i-0e6664a983435d7a8 Duration: 154s
Launching a new EC2 instance: i-00fc0d0d1a9d254ed Duration: 124s
Launching a new EC2 instance: i-0a8c0a0fe18b7c7c1 Duration: 131s
Launching a new EC2 instance: i-0572f006b2a8c5f0b Duration: 161s
Terminating EC2 instance: i-0e34e314b86d47276 Duration: 364s
Terminating EC2 instance: i-0f44c5fb44f51a067 Duration: 421s
Updating load balancers/target groups: Successful. Status Reason: Added: arn:aws:elasticloadbalancing:ap-northeast-2:239234376445:targetgroup/MZ-TRAINING-WEB-SERVER-8080-TG/9a88698c0fccbcf7 (Target Group). Duration: 0s
Updating load balancers/target groups: Successful. Status Reason: Removed: arn:aws:elasticloadbalancing:ap-northeast-2:239234376445:targetgroup/MZ-TRAINING-WEB-SERVER-8080-TG/9a88698c0fccbcf7 (Target Group). Duration: 1s
Launching a new EC2 instance: i-0e34e314b86d47276 Duration: 257s
Launching a new EC2 instance: i-0f44c5fb44f51a067 Duration: 1630s
Terminating EC2 instance: i-0c85f9fb3edc8e4fd Duration: 449s
Launching a new EC2 instance: i-0c85f9fb3edc8e4fd Duration: 126s
Terminating EC2 instance: i-0a479c5213d587a1c Duration: 146s
Updating load balancers/target groups: Successful. Status Reason: Added: arn:aws:elasticloadbalancing:ap-northeast-2:239234376445:targetgroup/MZ-TRAINING-WEB-SERVER-8080-TG/9a88698c0fccbcf7 (Target Group). Duration: 1s
Launching a new EC2 instance: i-0a479c5213d587a1c Duration: 31s
```

현재 ASG의 activity 로그를 가지고 와서 시간을 소요된 시간을 보여 줍니다. 
새로운 인스턴스가 시작될 때에는 대략 140여초 정도 소요되었네요. 

이번에는 warm pools을 추가하고 비교를 해보겠습니다.
```bash
aws autoscaling put-warm-pool \
  --auto-scaling-group-name "CodeDeploy_MZ-TRAINING-WEB_SERVER-DEPLOY-ASG_d-UGZII4V6A" \
  --pool-state Stopped 
```
```bash
aws autoscaling put-warm-pool \
  --auto-scaling-group-name CodeDeploy_MZ-TRAINING-WEB_SERVER-DEPLOY-ASG_d-UGZII4V6A \
  --max-group-prepared-capacity 5 --min-size 5 --pool-state Stopped 
```
![image description](images/min5.png)
![image description](images/instances1.png)

```bash
aws autoscaling describe-warm-pool \
  --auto-scaling-group-name CodeDeploy_MZ-TRAINING-WEB_SERVER-DEPLOY-ASG_d-UGZII4V6A --output table

||+----------------------------------+---------------------------------------+----------------+||
||                                    WarmPoolConfiguration                                    ||
|+-------------------------------------------------+-------------------+-----------------------+|
||            MaxGroupPreparedCapacity             |      MinSize      |       PoolState       ||
|+-------------------------------------------------+-------------------+-----------------------+|
||  5                                              |  5                |  Stopped              ||
|+-------------------------------------------------+-------------------+-----------------------+|
```

만약 처음 세팅한 ASG의 경우에는 desired 값만 변경
```bash
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name CodeDeploy_MZ-TRAINING-WEB_SERVER-DEPLOY-ASG_d-UGZII4V6A \
  --desired-capacity 5
```

기존에 실행 중인 인스턴스가 있는 ASG의 경우에는 업데이트로 변경 
```bash
aws autoscaling update-auto-scaling-group \
  --auto-scaling-group-name CodeDeploy_MZ-TRAINING-WEB_SERVER-DEPLOY-ASG_d-UGZII4V6A \
  --min-size 1 --max-size 6 --desired-capacity 6
```
5대의 인스턴스가 ASG에 include 시키기 위해 running으로 변경되고, 
나머지 5대의 경우 다시 warm-pool에 들어가기 위해 running -> stoped로...
![image description](images/new+provisioning_instances.png)


요청 매개 변수에 --max-group-prepared-capacity, --min-size 값을 넣어야만 동일한 값으로 warm pool instances를 유지합니다.
만약 매개변수를 기입하지 않을 경우 ASG는 동적으로 warm pool 갯수를 관리하게 됩니다. 

--pool-state 매개변수를 `Running`으로 지정하여 수명주기가 완료된 후 인스턴스 상태를 시작 상태로 지정할 수도 있습니다.

API 참고 https://awscli.amazonaws.com/v2/documentation/api/latest/reference/autoscaling/put-warm-pool.html

삭제 
```bash
aws autoscaling delete-warm-pool --auto-scaling-group-name CodeDeploy_MZ-TRAINING-WEB_SERVER-DEPLOY-ASG_d-UGZII4V6A --force 
```
https://awscli.amazonaws.com/v2/documentation/api/latest/reference/autoscaling/delete-warm-pool.html




# 03. 제한사항
### 2.1 Console에서의 설정 지원이 안되며, CLI로만 가능

### 2.2 ASG에 spot과 on-deamond가 혼합되어 있는 경우
```bash
An error occurred (ValidationError) when calling the PutWarmPool operation: You can’t add a warm pool to an Auto Scaling group that has a mixed instances policy or a launch template or launch configuration that requests Spot Instances.
```
![image description](images/mixed_instances.png)



MaxGroupPreparedCapacity이 지정되지 않으면 Amazon EC2 Auto Scaling이 시작되고 그룹의 최대 용량과 원하는 용량 간의 차이를 유지합니다. 에 값을 지정하면 MaxGroupPreparedCapacityAmazon EC2 Auto Scaling은 MaxGroupPreparedCapacity대신 원하는 용량과의 차이를 사용합니다 .

따뜻한 수영장의 크기는 동적입니다. MaxGroupPreparedCapacity및 MinSize동일한 값으로 설정된 경우에만 웜 풀의 절대 크기가 있습니다.

http://docs.amazonaws.cn/autoscaling/ec2/APIReference/API_PutWarmPool.html


### 2.3 Warm-pool의 수명주기 중 실행 과정에서 LB에 attach 함
![image description](images/tg_instances.png)
웜풀을 재지정하는 과정에서 TG에 Unhealthy hosts와 Healthy hosts 메트릭이 변경됨. 
이는 웜풀의 수명주기 때문에.. 

### 2.3 warm-pool을 running으로 설정할 경우 ASG에 적용 받지 않는 서비스 인스턴스가 생성이 됨
```bash
aws autoscaling describe-warm-pool \
  --auto-scaling-group-name CodeDeploy_MZ-TRAINING-WEB_SERVER-DEPLOY-ASG_d-UGZII4V6A --output text --query "WarmPoolConfiguration.PoolState" --query "Instances[*].{Instance:InstanceId,State:LifecycleState}"
i-071282c646a383328     Warmed:Running
```
i-071282c646a383328 인스턴스는 warm-running으로 구동 중
하지만, TG에 인스턴스가 들어가 있어서 실제로는 서비스 중임 
![image description](images/warm-running.png)

하지만, ASG에는 warm-running 인스턴스는 관리되고 있지 않음 
![image description](images/warm-running2.png)

즉, ASG의 Desired capacity와 TG의 Instnaces가 miss match됨 

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
