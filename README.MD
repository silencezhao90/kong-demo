# kong网关
使用kong的kubernetes-ingress-controller来搭建属于我们的api网关服务
# kong简介
Kong Gateway是为微服务优化的开源，轻量级API网关
## Kong Gateway中的流量
默认情况下，Kong Gateway在其配置的代理端口8000和8443上侦听流量。它评估传入的客户端API请求，并将其路由到适当的后端API。在路由请求和提供响应时，可以根据需要通过插件应用策略。

例如，在路由请求之前，可能需要客户端进行身份验证。这带来了许多好处，包括：
* 由于Kong Gateway正在处理身份验证，因此该服务不需要自己的身份验证逻辑。
* 该服务仅接收有效请求，因此不会浪费周期来处理无效请求。
* 记录所有请求以集中查看流量。

## 安装部署流程
本次步骤在kubernetes环境下部署，确保kubectl在v1.14版本以上
#### 部署kong
```bash
kubectl apply -k manifests/base
```

查看po状态
```bash
[root@realibox kong-k8s]# kubectl get po -n kong
NAME                            READY   STATUS    RESTARTS   AGE
ingress-kong-7f8f64c5fc-xrsbg   2/2     Running   1          17m
```

查看svc
```bash
[root@realibox kong-k8s]# kubectl get svc -n kong
NAME                      TYPE           CLUSTER-IP       EXTERNAL-IP   PORT(S)                                     AGE
kong-proxy                LoadBalancer   10.96.178.210    <pending>     80:32724/TCP,443:31298/TCP,8100:32415/TCP   25m
kong-validation-webhook   ClusterIP      10.104.253.149   <none>        443/TCP                                     25m
```

运行以下命令
```bash
[root@realibox kong-k8s]# export PROXY_IP=$(kubectl get -o jsonpath="{.spec.clusterIP}" service kong-proxy -n kong)
```

这个时候访问kong服务，响应头包含kong信息。
```bash
curl -i $PROXY_IP
```
#### 运行两个测试服务

##### 以本demo为例，构建服务镜像
```bash
docker build -t kong-test-server apps/test/
```
![](https://realicloud-local.oss-cn-shenzhen.aliyuncs.com/common/zb/kong2.png)

```bash
docker build -t kong-auth-server apps/auth/
```
**在kubernetes环境跑起来**
```bash
kubectl apply -f apps/test/test.yaml
```
```bash
kubectl apply -f apps/auth/auth.yaml
```
**访问服务**
可以看到结果如下，流量经过kong访问到了test和auth
```bash
curl -i $PROXY_IP/test/
```
![](https://realicloud-local.oss-cn-shenzhen.aliyuncs.com/common/zb/kong1.png)
```bash
curl -i $PROXY_IP/auth/
```
![](https://realicloud-local.oss-cn-shenzhen.aliyuncs.com/common/zb/kong3.png)
#### 使用官方插件
##### 设置局部插件
> 注：设置在Ingress或Service，都能使插件生效。以下以Ingress为例，Service同。


查看Ingress资源，可以看到刚刚创建的两个Ingress资源
```bash
kubectl get ingress
```
![](https://realicloud-local.oss-cn-shenzhen.aliyuncs.com/common/zb/kong4.png)

在Ingress资源上配置官方插件
```bash
$ echo '
apiVersion: configuration.konghq.com/v1
kind: KongPlugin
metadata:
  name: add-response-header
config:
  add:
    headers:
    - "demo: injected-by-kong"
plugin: response-transformer
' | kubectl apply -f -
```

将其与Ingress规则相关联
```bash
kubectl patch ingress kong-test-server -p '{"metadata":{"annotations":{"konghq.com/plugins":"add-response-header"}}}'
```
查看ingress信息
![](https://realicloud-local.oss-cn-shenzhen.aliyuncs.com/common/zb/kong5.png)

访问服务，可以看到响应头多了刚刚插件的信息
```
curl -i $PROXY_IP/test/
```
![](https://realicloud-local.oss-cn-shenzhen.aliyuncs.com/common/zb/kong6.png)

##### 设置全局插件
```bash
$ echo "
apiVersion: configuration.konghq.com/v1
kind: KongPlugin
metadata:
  name: global-rate-limit
  labels:
    global: \"true\"
config:
  minute: 5
  limit_by: consumer
  policy: local
plugin: rate-limiting
" | kubectl apply -f -
```
查看插件资源
```bash
kubectl get kp -A
```
![](https://realicloud-local.oss-cn-shenzhen.aliyuncs.com/common/zb/kong7.png)

再次访问服务，响应头多了全局插件信息（全局插件不需要在指定ingress或service配置注解）
```bash
curl -i $PROXY_IP/test/
```
![](https://realicloud-local.oss-cn-shenzhen.aliyuncs.com/common/zb/kong8.png)

#### 安装自定义插件
本demo使用lua实现了两个自定义插件：
[my-custom-plugin](demo/custom-plugins/myheader/handler.lua)：根据配置文件返回指定响应头
[request-uri-pass-auth](demo/custom-plugins/request-uri-pass-auth/handler.lua)：根据配置文件，配置路由白名单，对不符合路由白名单规则的请求作拦截
##### 为插件代码创建ConfigMap
以ConfigMap的方式将插件加载进kong服务里
下面创建这2个自定义插件
```bash
kubectl create configmap kong-plugin-myheader --from-file=demo/custom-plugins/myheader -n kong
```
```bash
kubectl create configmap kong-plugin-request-uri-pass-auth --from-file=demo/custom-plugins/request-uri-pass-auth -n kong
```
##### 查看创建的configmap
```bash
kubectl get configmap -n kong
```
![](https://realicloud-local.oss-cn-shenzhen.aliyuncs.com/common/zb/kong9.png)
#### 更新kong Deployment资源
要使用自定义插件，需要新增自定义插件环境变量，并且将上述生成的插件代码以ConfigMap的方式映射到kong中。
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ingress-kong
  namespace: kong
spec:
  template:
    spec:
      containers:
      - name: proxy
        env:
        - name: KONG_PLUGINS
          value: request-uri-pass-auth,myheader
        - name: KONG_LUA_PACKAGE_PATH
          value: "/opt/?.lua;;"
        volumeMounts:
        - name: plugin-request-uri-pass-auth
          mountPath: /opt/kong/plugins/request-uri-pass-auth
        - name: my-custom-plugin
          mountPath: /opt/kong/plugins/myheader
      volumes:
      - name: plugin-request-uri-pass-auth
        configMap:
          name: kong-plugin-request-uri-pass-auth
      - name: my-custom-plugin
        configMap:
          name: kong-plugin-myheader
```

##### 更新kong Deployment资源
```bash
kubectl apply -k demo/custom-plugins/
```
#### 创建KongPlugin自定义资源
分别对刚刚2个插件创建KongPlugin

myheader.yaml
```yaml
apiVersion: configuration.konghq.com/v1
kind: KongPlugin
metadata:
  name: my-custom-plugin
config:
  header_value: "my first plugin"
plugin: myheader
```

request-uri-pass-auth.yaml
```yaml
apiVersion: configuration.konghq.com/v1
kind: KongPlugin
metadata:
  name: request-uri-pass-auth
config:
  prefixs:
  - "/open/"
plugin: request-uri-pass-auth
```

```bash
[root@localhost kong-demo]# kubectl apply -f demo/custom-plugins/myheader/myheader.yaml
kongplugin.configuration.konghq.com/my-custom-plugin created
```
```bash
[root@localhost kong-demo]# kubectl apply -f demo/custom-plugins/request-uri-pass-auth/request-uri-pass-auth.yaml
kongplugin.configuration.konghq.com/request-uri-pass-auth created
```
**查看KongPlugin**
可以看到官方的KongPlugin和自定义KongPlugin
```bash
kubectl get KongPlugin -A
```
![](https://realicloud-local.oss-cn-shenzhen.aliyuncs.com/common/zb/kong10.png)

> 注意！这里有一个坑！当使用自定义插件的时候。我们需要声明KONG_PLUGINS环境变量，这会导致官方的插件失效。这个时候需要将官方插件也加入到声明的KONG_PLUGINS中。

官方插件失效后访问设置了官方插件注解的服务时返回以下结果
![](https://realicloud-local.oss-cn-shenzhen.aliyuncs.com/common/zb/kong11.png)
以本demo为例，完整的yaml应该为: [custoem-plugin.yaml](demo/custom-plugins/custom-plugin.yaml)
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ingress-kong
  namespace: kong
spec:
  template:
    spec:
      containers:
      - name: proxy
        env:
        - name: KONG_PLUGINS
          value: request-uri-pass-auth,myheader,response-transformer,rate-limiting
        - name: KONG_LUA_PACKAGE_PATH
          value: "/opt/?.lua;;"
        volumeMounts:
        - name: plugin-request-uri-pass-auth
          mountPath: /opt/kong/plugins/request-uri-pass-auth
        - name: my-custom-plugin
          mountPath: /opt/kong/plugins/myheader
      volumes:
      - name: plugin-request-uri-pass-auth
        configMap:
          name: kong-plugin-request-uri-pass-auth
      - name: my-custom-plugin
        configMap:
          name: kong-plugin-myheader
```
##### 更新kong Deployment资源
```bash
kubectl apply -k demo/custom-plugins/
```

## 测试
#### 测试自定义插件是否生效
为test服务添加request-uri-pass-auth插件
```bash
kubectl patch ingress kong-test-server -p '{"metadata":{"annotations":{"konghq.com/plugins":"request-uri-pass-auth"}}}'
```
![](https://realicloud-local.oss-cn-shenzhen.aliyuncs.com/common/zb/kong12.png)
为auth服务添加my-custom-plugin插件
```bash
kubectl patch ingress kong-auth-server -p '{"metadata":{"annotations":{"konghq.com/plugins":"my-custom-plugin"}}}'
```
![](https://realicloud-local.oss-cn-shenzhen.aliyuncs.com/common/zb/kong13.png)
#### 测试自定义插件是否生效
##### 访问test服务
```bash
curl -i $PROXY_IP/test/
```
![](https://realicloud-local.oss-cn-shenzhen.aliyuncs.com/common/zb/kong14.png)
可以看到/test/路由被"request-uri-pass-auth"插件拦截
```bash
curl -i $PROXY_IP/open/
```
![](https://realicloud-local.oss-cn-shenzhen.aliyuncs.com/common/zb/kong15.png)
可以看到，/open/路由没有被拦截，因为"request-uri-pass-auth"插件对/open/路由作了放行。然后还放回了全局插件"rate-limit"信息。自定义插件和官方对全局插件生效。

##### 访问auth服务
```bash
curl -i $PROXY_IP/auth/
```
![](https://realicloud-local.oss-cn-shenzhen.aliyuncs.com/common/zb/kong16.png)
可以看到，返回了"my-custom-plugin"插件信息和"rate-limit"插件信息。自定义插件和官方全局插件生效。

> 注意！KongPlugin资源需要跟对应的svc或ingress处于同一个命名空间。本demo都是声明在default空间。

## 阿里云上使用kong