# kong网关

# 项目简介
网关服务

# 快速使用
确保kubectl再v1.14以上版本
### 部署kong

```bash
kubectl apply -k manifests/base
```
## 安装自定义插件
#### 为插件代码创建ConfigMap或者Secret

```
kubectl create configmap kong-plugin-myheader --from-file=custom-plugins/myheader -n kong
```
```
kubectl create configmap kong-plugin-request-uri-pass-auth --from-file=custom-plugins/request-uri-pass-auth -n kong
```

```
kubectl get configmap -n kong
```
#### 更新kong Deployment资源

```
kubectl apply -k ./custom-plugins
```
#### 创建KongPlugin自定义资源

```
kubectl apply -f custom-plugins/myheader.yaml
```

```
kubectl apply -f custom-plugins/myheader.yaml
```
查看kongPlugin 

```
kubectl get KongPlugin -A
```
#### 测试
构建测试镜像
```
docker build -t kong-test-myimage ./test-apps
```

```
kubectl apply -f test-app.yaml
```

```
curl -i ip_address/test/
```
完成测试
