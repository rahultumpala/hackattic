To build local image and push to Amazon ECR

```shell
aws ecr get-login-password --region your-region | docker login --username AWS --password-stdin account-id.dkr.ecr.your-region.amazonaws.com

docker buildx build . -t  account-id.dkr.ecr.your-region.amazonaws.com/repo:tag

docker push account-id.dkr.ecr.your-region.amazonaws.com/repo:tag
```