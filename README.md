# terraform-aws-ecs-sample
- ECSでnginxのコンテナを動かすだけ
- 初めての人にもわかりやすいようにmain.tfに全部詰め込んだ

# 構成
- [x] VPC
- [x] Subnet public a,c
- [x] ALB http
- [x] Security Group
- [x] CloudWatch
- [x] ECS
  - [x] nginx

# Requirements
- terraform
- AWSのIAM作成権限を持ったユーザーのaccess_keyとsecret_key

# Usage

- (最初だけ)

```
terraform init
```

- テスト

```
terraform plan -var "access_key=ACCESS_KEY" -var "secret_key=SECRET_KEY"
```

- 適用

```
terraform apply -var "access_key=ACCESS_KEY" -var "secret_key=SECRET_KEY"
```

- 削除

```
terraform destroy -var "access_key=ACCESS_KEY" -var "secret_key=SECRET_KEY"
```
